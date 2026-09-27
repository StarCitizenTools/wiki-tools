// Command commlinks plans the Comm-Link pages of one RSI series or channel that
// the wiki is missing: a wikitext file per page, and a plan listing each page's
// images, publication date, added links and fidelity result.
//
//	commlinks                                             # write out/commlinks/plan.json and pages/
//	commlinks -diff                                       # same, listing each page to create; exit 1 if one is missing or a review entry is new
//	commlinks -only 16000,17712,19956 -out out/commlinks-scratch  # plan only these RSI ids, into a scratch dir
//	commlinks -only 16000 -refresh -out out/commlinks-scratch     # re-plan an id the wiki already has, marked "refresh": true
//	commlinks -config cmd/commlinks/config.chairman.json  # another series, into out/commlinks-chairman
//	commlinks -config cmd/commlinks/config.serialized-fiction.json  # a channel, into out/commlinks-serialized-fiction
//
// It does not write to the wiki. Publishing goes through the MediaWiki MCP
// server, uploads first, then pages.
package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"maps"
	"os"
	"os/signal"
	"path/filepath"
	"slices"
	"sort"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/StarCitizenTools/wiki-tools/scripts/internal/commlink"
	"github.com/StarCitizenTools/wiki-tools/scripts/internal/httpx"
	"github.com/StarCitizenTools/wiki-tools/scripts/internal/mediawiki"
)

const (
	defaultConfig   = "cmd/commlinks/config.json"
	wikiEndpoint    = "https://starcitizen.tools/api.php"
	userAgent       = "StarCitizenTools-wiki-tools/1.0 (https://github.com/StarCitizenTools/wiki-tools)"
	namespacePrefix = "Comm-Link:"

	exitDrift       = 1
	exitRailTripped = 2
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}

// parsed is a converted report. page is final unless complete is false: a
// name that takes the publication date, which dateErr says could not be found.
type parsed struct {
	c                commlink.Candidate
	page             string
	complete         bool
	date, dateSource string
	dateErr          error
	blocks           []commlink.Block
	labels           []string
}

func run() error {
	var (
		out        = flag.String("out", "", "directory for plan.json, pages/ and the download cache (default out/commlinks, or out/commlinks-NAME for a config.NAME.json)")
		configPath = flag.String("config", defaultConfig, "path to the importer config")
		doDiff     = flag.Bool("diff", false, "list each page to create; exit 1 if a page is missing or a review entry is not in knownReview")
		only       = flag.String("only", "", "comma-separated RSI ids to plan; every other report is skipped")
		refresh    = flag.Bool("refresh", false, "re-plan a -only id even when a wiki page already stores it, marking its entry \"refresh\": true")
		interval   = flag.Duration("interval", 500*time.Millisecond, "minimum spacing between upstream requests")
		maxCreate  = flag.Int("max-create", 10, "refuse to plan more page creations than this")
		quiet      = flag.Bool("quiet", false, "suppress progress output")
	)
	flag.Parse()

	if *out == "" {
		*out = defaultOut(*configPath)
	}
	outs, err := seriesOuts(*configPath)
	if err != nil {
		return err
	}
	if err := validateOnlyRefresh(*only, *refresh, *out, outs); err != nil {
		return err
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	progress := func(string) {}
	if !*quiet {
		progress = func(s string) { fmt.Fprintln(os.Stderr, s) }
	}

	cfg, err := commlink.LoadConfig(*configPath)
	if err != nil {
		return err
	}
	onlyIDs, err := parseIDs(*only)
	if err != nil {
		return err
	}

	web := httpx.New(httpx.Options{Interval: *interval, UserAgent: userAgent, MaxTries: 4, Timeout: 5 * time.Minute})
	defer web.Close()
	wiki, err := mediawiki.New(mediawiki.Config{Endpoint: wikiEndpoint, UserAgent: userAgent})
	if err != nil {
		return err
	}
	defer wiki.Close()
	ep := commlink.DefaultEndpoints()
	cache, err := commlink.LoadCache(filepath.Join(*out, "cache.json"))
	if err != nil {
		return err
	}

	// --- discover -------------------------------------------------------------
	var found []commlink.Candidate
	if cfg.APIChannel != "" {
		progress("reading the API's " + cfg.APIChannel + " channel")
		found, err = commlink.FetchChannelMatches(ctx, web, ep, cfg.APIChannel)
	} else {
		progress("searching the API for titles containing " + cfg.TitleQuery)
		found, err = commlink.FetchTitleMatches(ctx, web, ep, cfg.TitleQuery, cfg.MatchesTitle)
	}
	if err != nil {
		return err
	}
	listing, listedBy, slug, fetchListing := cfg.Series+" series", commlink.FoundBySeries, cfg.Series, commlink.FetchSeries
	if cfg.Channel != "" {
		listing, listedBy, slug, fetchListing = cfg.Channel+" channel", commlink.FoundByChannel, cfg.Channel, commlink.FetchChannel
	}
	progress("reading RSI's " + listing)
	listed, err := fetchListing(ctx, web, ep, slug)
	if err != nil {
		return err
	}
	if !slices.ContainsFunc(listed, func(it commlink.SeriesItem) bool { return it.Posted != "" }) {
		fmt.Fprintf(os.Stderr, "warning: RSI's %s listing gives no absolute Posted date for any of its %d reports; "+
			"if its span.value markup changed, every date falls back to the API or the Wayback Machine\n", listing, len(listed))
	}
	candidates, disagreements, unfetched, err := commlink.Union(ctx, found, listed, listedBy, func(ctx context.Context, id int) (commlink.Candidate, error) {
		return commlink.FetchRecord(ctx, web, ep, id)
	})
	if err != nil {
		return err
	}
	existing, err := commlink.ExistingIDs(ctx, wiki)
	if err != nil {
		return err
	}
	for id, page := range cfg.Covered() {
		if _, ok := existing[id]; !ok {
			existing[id] = page
		}
	}
	var missing []commlink.Candidate
	for _, c := range candidates {
		if wanted(c.ID, existing, onlyIDs, *refresh) {
			missing = append(missing, c)
		}
	}
	progress(fmt.Sprintf("%d reports upstream; %d to plan", len(candidates), len(missing)))

	plan := &commlink.Plan{Generated: time.Now().UTC(), Disagreements: disagreements}
	review := func(c commlink.Candidate, page, reason string, detail ...string) {
		plan.Review = append(plan.Review, commlink.ReviewEntry{ID: c.ID, RSITitle: c.Title, Page: page, Reason: reason, Detail: detail})
	}
	for _, r := range unfetched {
		if wanted(r.ID, existing, onlyIDs, *refresh) {
			plan.Review = append(plan.Review, r)
		}
	}

	// --- convert --------------------------------------------------------------
	var pages []parsed
	var headings []string
	for i, c := range missing {
		progress(fmt.Sprintf("[%d/%d] converting %d %s", i+1, len(missing), c.ID, c.Title))
		// The name can take the date and the page's own title, so both come
		// first; every title check and file name below uses the name. From
		// here on the report's title is the one its infobox shows.
		date, dateSource, dateErr := commlink.ResolveDate(c.Posted, c.Created, cfg.APIIngestDates, func() (time.Time, error) {
			return cache.FirstCapture(ctx, web, ep, c.RSIURL)
		})
		body, err := commlink.FetchBlocks(ctx, web, cfg, c)
		c.Title = cfg.ReportTitle(c.Title, body.Title)
		page, complete := cfg.PageName(c.Title, date)
		if err != nil {
			review(c, page, commlink.ReasonFetch, err.Error())
			continue
		}
		blocks := commlink.VideoLinks(body.Blocks)
		for _, b := range blocks {
			if b.Kind == commlink.Heading {
				headings = append(headings, b.Text)
			}
		}
		pages = append(pages, parsed{c: c, page: page, complete: complete, date: date, dateSource: dateSource, dateErr: dateErr, blocks: blocks, labels: body.Labels})
	}

	// Word casing and the common-word link filter learn from every report's
	// API text; heading labels only from the reports converted above.
	var corpus strings.Builder
	for _, c := range candidates {
		corpus.WriteString(c.Text)
		corpus.WriteString("\n")
	}
	caser := commlink.NewHeadCaser(headings, corpus.String())
	vocab, err := buildVocabulary(ctx, wiki, cfg, corpus.String(), progress)
	if err != nil {
		return err
	}

	var titles []string
	for _, p := range pages {
		if p.complete {
			titles = append(titles, namespacePrefix+p.page)
		}
	}
	statuses, err := wiki.TitleStatusesAnyNamespace(ctx, titles)
	if err != nil {
		return err
	}

	// --- plan each page -------------------------------------------------------
	var files []pageFile
	planned := map[string]string{}
	claimed := map[string]int{} // title -> the first report of this run to pass this check there
	for i, p := range pages {
		progress(fmt.Sprintf("[%d/%d] planning %s", i+1, len(pages), p.page))
		title := namespacePrefix + p.page
		// existing holds a planned report's id only under -refresh.
		stored := existing[p.c.ID]
		// An incomplete name is no title to check: the report is undated.
		if p.complete {
			if detail := titleConflict(p.c.ID, title, stored, statuses[title] == mediawiki.TitleExists, claimed[title]); detail != "" {
				review(p.c, p.page, commlink.ReasonTitleExists, detail)
				continue
			}
			claimed[title] = p.c.ID
		}
		if p.dateErr != nil {
			review(p.c, p.page, commlink.ReasonNoDate, p.dateErr.Error())
			continue
		}
		imgs, err := commlink.PlanImages(ctx, web, wiki, cache, planned, cfg, p.c.Title, p.page, p.date, p.blocks)
		if saveErr := cache.Save(); saveErr != nil {
			return saveErr
		}
		if err != nil {
			review(p.c, p.page, commlink.ReasonImages, err.Error())
			continue
		}
		deduped := commlink.DedupeImages(p.blocks, imgs.File)
		body, links := vocab.Apply(commlink.RenderBody(deduped, caser, imgs.File))
		series := cfg.ReportSeries(p.c.Title, p.c.Series)
		text := commlink.Infobox(commlink.PageMeta{
			RSITitle: p.c.Title, URL: commlink.InfoboxURL(p.c.RSIURL),
			Series: series, Type: cfg.InfoboxType, Date: p.date,
		}) + "\n" + body
		if api, words, short := commlink.APITextWords(p.c.Text, body); short && !cfg.AcceptsAPIText(p.c.ID) {
			review(p.c, p.page, commlink.ReasonAPIText, fmt.Sprintf(
				"the API text has %d words, under half the page body's %d: the API may not have finished scraping the report", api, words))
			continue
		}
		if lost := commlink.Missing(p.c.Text, text, p.labels, cfg.IgnoredLine); len(lost) > 0 {
			review(p.c, p.page, commlink.ReasonFidelity, lost...)
			continue
		}
		file := commlink.PageFileName(p.page)
		files = append(files, pageFile{name: file, text: text})
		entry := commlink.PageEntry{
			ID: p.c.ID, RSITitle: p.c.Title, Page: p.page, URL: commlink.InfoboxURL(p.c.RSIURL),
			Date: p.date, DateSource: p.dateSource, Wikitext: filepath.Join("pages", file),
			Images: imgs.Plans, Links: links, MissingImages: imgs.Missing, Refresh: stored != "",
		}
		if cfg.SeriesFromReport {
			entry.Series = series
		}
		plan.Create = append(plan.Create, entry)
		maps.Copy(planned, imgs.Added)
	}
	if err := cache.Save(); err != nil {
		return err
	}
	sort.Slice(plan.Create, func(i, j int) bool { return plan.Create[i].ID < plan.Create[j].ID })
	sort.Slice(plan.Review, func(i, j int) bool { return plan.Review[i].ID < plan.Review[j].ID })

	// The cap is checked before pages/ and plan.json are touched, so a tripped
	// rail leaves the last plan and its pages in step; the rejected plan is
	// written beside them to read.
	rejected := len(plan.Create) > *maxCreate
	dest := filepath.Join(*out, "plan.json")
	rejectedDest := filepath.Join(*out, "plan.rejected.json")
	if rejected {
		dest = rejectedDest
		if err := writeJSON(dest, plan); err != nil {
			return err
		}
	} else {
		if err := writePages(filepath.Join(*out, "pages"), files); err != nil {
			return err
		}
		if err := writeJSON(dest, plan); err != nil {
			return err
		}
		if err := os.Remove(rejectedDest); err != nil && !errors.Is(err, os.ErrNotExist) {
			return err
		}
	}
	progress("wrote " + dest)

	fmt.Fprintf(os.Stderr, "\n%s against %s\n", listing, wikiEndpoint)
	if *doDiff {
		for _, line := range plan.CreateLines() {
			fmt.Fprintf(os.Stderr, "  create %s\n", line)
		}
	}
	for _, line := range plan.Report() {
		fmt.Fprintf(os.Stderr, "  %s\n", line)
	}
	if rejected {
		fmt.Fprintf(os.Stderr, "\nrefusing to plan %d creations (limit %d); read %s, then re-run with -max-create if they are real\n", len(plan.Create), *maxCreate, dest)
		os.Exit(exitRailTripped)
	}
	if *doDiff && plan.Drift(cfg.KnownReview) {
		fmt.Fprintf(os.Stderr, "\nTo publish, work through %s via the MediaWiki MCP server.\n", dest)
		os.Exit(exitDrift)
	}
	return nil
}

// pageFile is one page's wikitext, held until the plan passes the creation cap.
type pageFile struct{ name, text string }

// writePages replaces dir's contents with files.
func writePages(dir string, files []pageFile) error {
	if err := os.RemoveAll(dir); err != nil {
		return err
	}
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}
	for _, f := range files {
		if err := os.WriteFile(filepath.Join(dir, f.name), []byte(f.text), 0o644); err != nil {
			return err
		}
	}
	return nil
}

// wanted reports whether the run plans report id: one no wiki page stores, or
// any under -refresh, and only an -only id when -only lists some.
func wanted(id int, existing map[int]string, only map[int]bool, refresh bool) bool {
	_, stored := existing[id]
	return (!stored || refresh) && (len(only) == 0 || only[id])
}

// titleConflict is why report id cannot be planned at title, or "" when it
// can. stored is the page the wiki stores id on ("" for none), taken whether a
// page exists at title, and claimedBy the id of an earlier report of this run
// planned at title (0 for none).
func titleConflict(id int, title, stored string, taken bool, claimedBy int) string {
	switch {
	case claimedBy != 0:
		return fmt.Sprintf("RSI number %d in this run has the same page name", claimedBy)
	case stored != "" && stored != title:
		return fmt.Sprintf("the wiki stores RSI number %d on %s, not on this title", id, stored)
	case taken && stored == "":
		return "a page has this title, but no page stores RSI number " + strconv.Itoa(id)
	}
	return ""
}

// defaultOut is the directory a config's full plan is written to, so each
// series keeps its own: out/commlinks for config.json, out/commlinks-NAME for
// config.NAME.json or NAME.json.
func defaultOut(configPath string) string {
	name := strings.TrimSuffix(filepath.Base(configPath), ".json")
	name = strings.TrimPrefix(strings.TrimPrefix(name, "config"), ".")
	if name == "" {
		return "out/commlinks"
	}
	return "out/commlinks-" + name
}

// seriesOuts lists the full-plan directory of every series: the default out
// of each config*.json beside configPath, and of configPath itself.
func seriesOuts(configPath string) ([]string, error) {
	configs, err := filepath.Glob(filepath.Join(filepath.Dir(configPath), "config*.json"))
	if err != nil {
		return nil, err
	}
	outs := []string{defaultOut(configPath)}
	for _, c := range configs {
		outs = append(outs, defaultOut(c))
	}
	return outs, nil
}

// validateOnlyRefresh checks the -only/-refresh/-out combination: -only needs
// a scratch -out that is none of seriesOuts, where the series' full plans are
// written, since a partial run would replace one; and -refresh needs -only,
// since without it every existing report would be replanned.
func validateOnlyRefresh(only string, refresh bool, out string, seriesOuts []string) error {
	if only != "" {
		for _, s := range seriesOuts {
			if samePath(out, s) {
				return fmt.Errorf("-only needs a scratch -out: a partial run would replace the full plan in %s", s)
			}
		}
	}
	if refresh && only == "" {
		return fmt.Errorf("-refresh needs -only: it re-plans specific ids, not a full run")
	}
	return nil
}

// samePath reports whether a and b name one directory, compared absolute when
// both resolve.
func samePath(a, b string) bool {
	if absA, err := filepath.Abs(a); err == nil {
		if absB, err := filepath.Abs(b); err == nil {
			return absA == absB
		}
	}
	return filepath.Clean(a) == filepath.Clean(b)
}

func parseIDs(s string) (map[int]bool, error) {
	ids := map[int]bool{}
	for _, f := range strings.Split(s, ",") {
		f = strings.TrimSpace(f)
		if f == "" {
			continue
		}
		id, err := strconv.Atoi(f)
		if err != nil {
			return nil, fmt.Errorf("-only: %q is not an id", f)
		}
		ids[id] = true
	}
	return ids, nil
}

func buildVocabulary(ctx context.Context, wiki *mediawiki.Client, cfg *commlink.Config, corpus string, progress func(string)) (*commlink.Vocabulary, error) {
	var titles []string
	for _, cat := range cfg.LinkCategories {
		members, err := commlink.CategoryMembers(ctx, wiki, cat)
		if err != nil {
			return nil, fmt.Errorf("category %s: %w", cat, err)
		}
		titles = append(titles, members...)
	}
	disambiguation, err := commlink.CategoryMembers(ctx, wiki, "Disambiguation pages")
	if err != nil {
		return nil, err
	}
	var targets []string
	for _, target := range cfg.Aliases {
		targets = append(targets, target)
	}
	statuses, err := wiki.TitleStatuses(ctx, targets)
	if err != nil {
		return nil, err
	}
	// An alias whose target is missing is dropped: a red link is worse than none.
	aliases := map[string]string{}
	for term, target := range cfg.Aliases {
		if statuses[target] == mediawiki.TitleExists {
			aliases[term] = target
		} else {
			progress("alias target does not exist, dropped: " + target)
		}
	}
	progress(fmt.Sprintf("link vocabulary from %d category titles and %d aliases", len(titles), len(aliases)))
	return commlink.BuildVocabulary(titles, aliases, disambiguation, cfg.Stoplist, cfg.NoLink, corpus), nil
}

func writeJSON(dest string, v any) error {
	enc, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(dest), 0o755); err != nil {
		return err
	}
	return os.WriteFile(dest, append(enc, '\n'), 0o644)
}
