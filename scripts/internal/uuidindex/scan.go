package uuidindex

import (
	"context"
	"encoding/json"
	"fmt"
	"net/url"
	"sort"
	"strconv"
	"strings"

	"github.com/StarCitizenTools/wiki-tools/scripts/internal/mediawiki"
)

// ScanOptions configures a scan.
type ScanOptions struct {
	// Client reads the wiki. It is rate-limited and read-only.
	Client *mediawiki.Client
	// Progress, when set, receives human-readable progress lines.
	Progress func(string)
}

// ScanProperties reads every uuid annotation via SMW — the property half of
// Scan, exported for tools that need the annotated-uuid set without the
// UUID: namespace listing. Progress may be nil. The int is API requests made.
func ScanProperties(ctx context.Context, client *mediawiki.Client, progress func(string)) (*PropertyScan, int, error) {
	s := &scanner{opts: ScanOptions{Client: client, Progress: progress}}
	props := NewPropertyScan()
	for _, prop := range Properties {
		if err := s.askProperty(ctx, prop, props); err != nil {
			return nil, s.requests, fmt.Errorf("scanning property %s: %w", prop, err)
		}
	}
	s.logf("scanned %d uuids (%d invalid, %d ignored)", len(props.Holders), len(props.Invalid), len(props.Ignored))
	return props, s.requests, nil
}

// Scan reads both sides of the reconciliation from the wiki: every uuid
// annotation via SMW, and every page of the UUID: namespace with its redirect
// target. Anonymous and read-only throughout.
func Scan(ctx context.Context, opts ScanOptions) (*ScanResult, error) {
	s := &scanner{opts: opts}

	// TitleFor assumes the namespace capitalises the first letter of a title.
	// That is configurable per namespace ($wgCapitalLinkOverrides), and if it
	// were ever turned off here every planned title would differ from the
	// existing one — the apply step would duplicate the entire index rather
	// than fail. One request buys a startup error instead.
	s.requests++
	nsCase, err := opts.Client.NamespaceCase(ctx, Namespace)
	if err != nil {
		return nil, fmt.Errorf("checking namespace %d: %w", Namespace, err)
	}
	if nsCase != "first-letter" {
		return nil, fmt.Errorf("namespace %d is %q, not first-letter: title normalisation in "+
			"TitleFor no longer holds and the plan would target the wrong titles", Namespace, nsCase)
	}

	props, propRequests, err := ScanProperties(ctx, opts.Client, opts.Progress)
	if err != nil {
		return nil, err
	}
	s.requests += propRequests

	redirects, err := s.allPages(ctx, "redirects")
	if err != nil {
		return nil, fmt.Errorf("listing redirects: %w", err)
	}
	others, err := s.allPages(ctx, "nonredirects")
	if err != nil {
		return nil, fmt.Errorf("listing non-redirects: %w", err)
	}
	s.logf("listed %d namespace pages (%d redirects)", len(redirects)+len(others), len(redirects))

	pages := make([]NSPage, 0, len(redirects)+len(others))
	for _, title := range others {
		pages = append(pages, NSPage{Title: title})
	}
	resolved, err := s.resolve(ctx, redirects)
	if err != nil {
		return nil, fmt.Errorf("resolving redirect targets: %w", err)
	}
	pages = append(pages, resolved...)
	sort.Slice(pages, func(i, j int) bool { return pages[i].Title < pages[j].Title })
	s.logf("resolved %d redirect targets (%d requests total)", len(resolved), s.requests)

	return &ScanResult{Properties: props, Pages: pages, Requests: s.requests}, nil
}

type scanner struct {
	opts     ScanOptions
	requests int
}

func (s *scanner) logf(format string, args ...any) {
	if s.opts.Progress != nil {
		s.opts.Progress(fmt.Sprintf(format, args...))
	}
}

// askProperty pages through [[<prop>::+]] and feeds every value into the scan.
//
// The limit is deliberately large: SMW's $smwgQMaxOffset (default 5000)
// silently resets any larger offset to zero, so offset pagination cannot walk
// a big result set — it cycles. One request under the server's max limit
// avoids the wall entirely; the non-advancing-continuation check below turns
// the wall into a loud error instead of an infinite loop if the annotation
// count ever outgrows it.
func (s *scanner) askProperty(ctx context.Context, prop string, into *PropertyScan) error {
	const limit = 10000
	for offset := 0; ; {
		var res struct {
			mediawiki.Response
			Continue *int `json:"query-continue-offset"`
			Query    struct {
				Results json.RawMessage `json:"results"`
			} `json:"query"`
		}
		form := url.Values{
			"action": {"ask"},
			"query":  {fmt.Sprintf("[[%s::+]]|?%s|limit=%d|offset=%d", prop, prop, limit, offset)},
			"format": {"json"},
		}
		s.requests++
		if err := s.opts.Client.Request(ctx, form, &res); err != nil {
			return err
		}

		// SMW serialises results as an object, except that an empty result set
		// comes back as an array. Anything else means the response was not
		// what we think it is, and treating that as "no annotations" would
		// hand the reconciler an empty side — so it is an error, not a return.
		switch head := firstRune(res.Query.Results); head {
		case '{':
			var subjects map[string]struct {
				Fulltext  string              `json:"fulltext"`
				Namespace int                 `json:"namespace"`
				Printouts map[string][]string `json:"printouts"`
			}
			if err := json.Unmarshal(res.Query.Results, &subjects); err != nil {
				return fmt.Errorf("decoding subjects at offset %d: %w", offset, err)
			}
			for _, subject := range subjects {
				for _, value := range subject.Printouts[prop] {
					into.Add(subject.Fulltext, subject.Namespace, prop, value)
				}
			}
		case '[':
			return nil // empty result set
		default:
			return fmt.Errorf("unexpected ask results at offset %d: wanted an object or an empty "+
				"array, got %s", offset, snippet(res.Query.Results))
		}

		if res.Continue == nil {
			return nil
		}
		if *res.Continue <= offset {
			return fmt.Errorf("continuation did not advance (offset %d -> %d): the result set has "+
				"outgrown offset pagination (SMW max offset); shard the scan by uuid prefix", offset, *res.Continue)
		}
		offset = *res.Continue
	}
}

// allPages lists the titles of the UUID: namespace, filtered to redirects or
// non-redirects.
//
// Listing and resolving are separate passes because they cannot be combined:
// the API rejects list=allpages as a generator together with redirect
// resolution ("Use gapfilterredir=nonredirects instead of redirects"), so a
// generator cannot both enumerate redirects and report their targets.
func (s *scanner) allPages(ctx context.Context, filter string) ([]string, error) {
	var titles []string
	continueFrom := ""
	for {
		var res struct {
			mediawiki.Response
			Continue *struct {
				Apcontinue string `json:"apcontinue"`
			} `json:"continue"`
			Query struct {
				Allpages []struct {
					Title string `json:"title"`
				} `json:"allpages"`
			} `json:"query"`
		}
		form := url.Values{
			"action":        {"query"},
			"list":          {"allpages"},
			"apnamespace":   {strconv.Itoa(Namespace)},
			"apfilterredir": {filter},
			"aplimit":       {"500"},
			"format":        {"json"},
			"formatversion": {"2"},
		}
		if continueFrom != "" {
			form.Set("apcontinue", continueFrom)
		}
		s.requests++
		if err := s.opts.Client.Request(ctx, form, &res); err != nil {
			return nil, err
		}
		for _, p := range res.Query.Allpages {
			titles = append(titles, p.Title)
		}
		if res.Continue == nil {
			return titles, nil
		}
		// Same reasoning as askProperty: a continuation that does not move
		// forward is an infinite loop, so fail rather than spin.
		if res.Continue.Apcontinue <= continueFrom {
			return nil, fmt.Errorf("allpages continuation did not advance (%q -> %q)",
				continueFrom, res.Continue.Apcontinue)
		}
		continueFrom = res.Continue.Apcontinue
	}
}

// resolve looks up each redirect's direct target, batching titles through the
// query API's redirect resolution (which reads the redirect table rather than
// parsing wikitext).
func (s *scanner) resolve(ctx context.Context, titles []string) ([]NSPage, error) {
	const batchSize = 50 // anonymous cap on titles per query
	pages := make([]NSPage, 0, len(titles))
	logged := 0
	for start := 0; start < len(titles); start += batchSize {
		batch := titles[start:min(start+batchSize, len(titles))]

		var res struct {
			mediawiki.Response
			Query struct {
				Redirects []struct {
					From string `json:"from"`
					To   string `json:"to"`
				} `json:"redirects"`
			} `json:"query"`
		}
		form := url.Values{
			"action":        {"query"},
			"titles":        {strings.Join(batch, "|")},
			"redirects":     {"1"},
			"format":        {"json"},
			"formatversion": {"2"},
		}
		s.requests++
		if err := s.opts.Client.Request(ctx, form, &res); err != nil {
			return nil, err
		}

		// The redirects list covers every hop of a chain; only the first hop
		// away from a requested title is that title's own target. A double
		// redirect therefore resolves to the next redirect, which is what
		// MediaWiki itself serves, so the plan retargets it rather than
		// silently following the chain.
		requested := map[string]struct{}{}
		for _, t := range batch {
			requested[t] = struct{}{}
		}
		targets := map[string]string{}
		for _, r := range res.Query.Redirects {
			if _, ok := requested[r.From]; ok {
				targets[r.From] = r.To
			}
		}
		for _, title := range batch {
			pages = append(pages, NSPage{Title: title, Redirect: true, Target: targets[title]})
		}
		if len(pages)-logged >= 2500 {
			logged = len(pages)
			s.logf("resolving redirect targets: %d/%d", len(pages), len(titles))
		}
	}
	return pages, nil
}

// firstRune returns the first non-space byte of raw JSON, or 0 if it is empty.
func firstRune(raw json.RawMessage) byte {
	trimmed := strings.TrimSpace(string(raw))
	if trimmed == "" {
		return 0
	}
	return trimmed[0]
}

// snippet trims a JSON fragment for inclusion in an error message.
func snippet(raw json.RawMessage) string {
	const max = 120
	s := strings.TrimSpace(string(raw))
	if s == "" {
		return "nothing"
	}
	if len(s) > max {
		return s[:max] + "…"
	}
	return s
}
