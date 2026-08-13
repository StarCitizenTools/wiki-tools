package uuidindex

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"sort"
	"strconv"
	"strings"

	"github.com/StarCitizenTools/wiki-tools/scripts/internal/httpx"
)

// ScanOptions configures a scan.
type ScanOptions struct {
	// Client issues the (rate-limited) HTTP requests.
	Client *httpx.Client
	// Endpoint is the full action API URL, e.g. https://starcitizen.tools/api.php
	Endpoint string
	// Progress, when set, receives human-readable progress lines.
	Progress func(string)
}

// Scan reads both sides of the reconciliation from the wiki: every uuid
// annotation via SMW, and every page of the UUID: namespace with its redirect
// target. Anonymous and read-only throughout.
func Scan(ctx context.Context, opts ScanOptions) (*ScanResult, error) {
	s := &scanner{opts: opts}

	props := NewPropertyScan()
	for _, prop := range Properties {
		if err := s.askProperty(ctx, prop, props); err != nil {
			return nil, fmt.Errorf("scanning property %s: %w", prop, err)
		}
	}
	s.logf("scanned %d uuids (%d invalid, %d ignored)", len(props.Holders), len(props.Invalid), len(props.Ignored))

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

// get performs one API request and decodes the response, surfacing API-level
// errors (which arrive with HTTP 200) as Go errors.
func (s *scanner) get(ctx context.Context, form url.Values, out any) error {
	s.requests++
	// POST keeps long title batches clear of URL-length limits.
	body, err := s.opts.Client.Do(ctx, http.MethodPost, s.opts.Endpoint, form.Encode())
	if err != nil {
		return err
	}
	var apiErr struct {
		Error *struct {
			Code string `json:"code"`
			Info string `json:"info"`
		} `json:"error"`
	}
	if err := json.Unmarshal(body, &apiErr); err != nil {
		return fmt.Errorf("decoding response: %w", err)
	}
	if apiErr.Error != nil {
		return fmt.Errorf("api error %s: %s", apiErr.Error.Code, apiErr.Error.Info)
	}
	return json.Unmarshal(body, out)
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
		if err := s.get(ctx, form, &res); err != nil {
			return err
		}

		// SMW serialises an empty result map as a JSON array.
		if !strings.HasPrefix(strings.TrimSpace(string(res.Query.Results)), "{") {
			return nil
		}
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
func (s *scanner) allPages(ctx context.Context, filter string) ([]string, error) {
	var titles []string
	continueFrom := ""
	for {
		var res struct {
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
		if err := s.get(ctx, form, &res); err != nil {
			return nil, err
		}
		for _, p := range res.Query.Allpages {
			titles = append(titles, p.Title)
		}
		if res.Continue == nil {
			return titles, nil
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
	for start := 0; start < len(titles); start += batchSize {
		batch := titles[start:min(start+batchSize, len(titles))]

		var res struct {
			Query struct {
				Redirects []struct {
					From string `json:"from"`
					To   string `json:"to"`
				} `json:"redirects"`
				Pages []struct {
					Title   string `json:"title"`
					Missing bool   `json:"missing"`
				} `json:"pages"`
			} `json:"query"`
		}
		form := url.Values{
			"action":        {"query"},
			"titles":        {strings.Join(batch, "|")},
			"redirects":     {"1"},
			"format":        {"json"},
			"formatversion": {"2"},
		}
		if err := s.get(ctx, form, &res); err != nil {
			return nil, err
		}

		// The redirects list covers every hop of a chain; only the first hop
		// away from a requested title is that title's own target.
		requested := map[string]struct{}{}
		for _, t := range batch {
			requested[t] = struct{}{}
		}
		missing := map[string]struct{}{}
		for _, p := range res.Query.Pages {
			if p.Missing {
				missing[p.Title] = struct{}{}
			}
		}
		targets := map[string]string{}
		for _, r := range res.Query.Redirects {
			if _, ok := requested[r.From]; ok {
				targets[r.From] = r.To
			}
		}
		for _, title := range batch {
			target := targets[title]
			_, targetMissing := missing[target]
			pages = append(pages, NSPage{
				Title:         title,
				Redirect:      true,
				Target:        target,
				TargetMissing: target != "" && targetMissing,
			})
		}
		if len(pages)%2500 < batchSize {
			s.logf("resolving redirect targets: %d/%d", len(pages), len(titles))
		}
	}
	return pages, nil
}
