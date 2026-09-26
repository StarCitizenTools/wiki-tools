// Command commlinks plans the Comm-Link pages of one RSI series that the wiki
// is missing: a wikitext file per page, and a plan listing each page's images,
// publication date, added links and fidelity result.
//
//	commlinks                                             # write out/commlinks/plan.json and pages/
//	commlinks -diff                                       # same; exit 1 if a page is missing or a review entry is new
//	commlinks -only 16000,17712,19956 -out out/commlinks-scratch  # plan only these RSI ids, into a scratch dir
//
// It does not write to the wiki. Publishing goes through the MediaWiki MCP
// server, uploads first, then pages.
package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"maps"
	"os"
	"os/signal"
	"path/filepath"
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
	defaultOut      = "out/commlinks"
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

type parsed struct {
	c      commlink.Candidate
	page   string
	blocks []commlink.Block
}

func run() error {
	var (
		out        = flag.String("out", defaultOut, "directory for plan.json, pages/ and the download cache")
		configPath = flag.String("config", defaultConfig, "path to the importer config")
		doDiff     = flag.Bool("diff", false, "exit 1 if a page is missing or a review entry is not in knownReview")
		only       = flag.String("only", "", "comma-separated RSI ids to plan; every other report is skipped")
		interval   = flag.Duration("interval", 500*time.Millisecond, "minimum spacing between upstream requests")
		maxCreate  = flag.Int("max-create", 200, "refuse to plan more page creations than this")
		quiet      = flag.Bool("quiet", false, "suppress progress output")
	)
	flag.Parse()

	if *only != "" && *out == defaultOut {
		return fmt.Errorf("-only needs -out: a partial run would replace the full plan in %s", defaultOut)
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
	progress("searching the API for titles containing " + cfg.TitleQuery)
	titled, err := commlink.FetchTitleMatches(ctx, web, ep, cfg.TitleQuery, cfg.MatchesTitle)
	if err != nil {
		return err
	}
	progress("reading RSI's " + cfg.Series + " series")
	series, err := commlink.FetchSeries(ctx, web, ep, cfg.Series)
	if err != nil {
		return err
	}
	candidates, disagreements, err := commlink.Union(ctx, titled, series, func(ctx context.Context, id int) (commlink.Candidate, error) {
		return commlink.FetchRecord(ctx, web, ep, id)
	})
	if err != nil {
		return err
	}
	existing, err := commlink.ExistingIDs(ctx, wiki)
	if err != nil {
		return err
	}
	var missing []commlink.Candidate
	for _, c := range candidates {
		if _, ok := existing[c.ID]; ok {
			continue
		}
		if len(onlyIDs) > 0 && !onlyIDs[c.ID] {
			continue
		}
		missing = append(missing, c)
	}
	progress(fmt.Sprintf("%d reports upstream; %d to plan", len(candidates), len(missing)))

	plan := &commlink.Plan{Generated: time.Now().UTC(), Disagreements: disagreements}
	review := func(c commlink.Candidate, page, reason string, detail ...string) {
		plan.Review = append(plan.Review, commlink.ReviewEntry{ID: c.ID, RSITitle: c.Title, Page: page, Reason: reason, Detail: detail})
	}

	// --- convert --------------------------------------------------------------
	var pages []parsed
	var headings []string
	for i, c := range missing {
		page := cfg.PageName(c.Title)
		progress(fmt.Sprintf("[%d/%d] converting %d %s", i+1, len(missing), c.ID, c.Title))
		blocks, err := commlink.FetchBlocks(ctx, web, c)
		if err != nil {
			review(c, page, commlink.ReasonFetch, err.Error())
			continue
		}
		blocks = commlink.VideoLinks(blocks)
		for _, b := range blocks {
			if b.Kind == commlink.Heading {
				headings = append(headings, b.Text)
			}
		}
		pages = append(pages, parsed{c: c, page: page, blocks: blocks})
	}

	// Heading case and the common-word link filter learn from every report's
	// text, not just the missing ones.
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

	titles := make([]string, len(pages))
	for i, p := range pages {
		titles[i] = namespacePrefix + p.page
	}
	taken, err := commlink.PagesExist(ctx, wiki, titles)
	if err != nil {
		return err
	}

	// --- plan each page -------------------------------------------------------
	pagesDir := filepath.Join(*out, "pages")
	if err := os.RemoveAll(pagesDir); err != nil {
		return err
	}
	if err := os.MkdirAll(pagesDir, 0o755); err != nil {
		return err
	}
	planned := map[string]string{}
	for i, p := range pages {
		progress(fmt.Sprintf("[%d/%d] planning %s", i+1, len(pages), p.page))
		if taken[namespacePrefix+p.page] {
			review(p.c, p.page, commlink.ReasonTitleExists, "a page has this title, but no page stores RSI number "+strconv.Itoa(p.c.ID))
			continue
		}
		date, dateSource, err := commlink.ResolveDate(p.c.Posted, p.c.Created, cfg.APIIngestDates, func() (time.Time, error) {
			return firstCapture(ctx, web, ep, cache, p.c.RSIURL)
		})
		if err != nil {
			review(p.c, p.page, commlink.ReasonNoDate, "wayback lookup failed: "+err.Error())
			continue
		}
		if date == "" {
			review(p.c, p.page, commlink.ReasonNoDate, "RSI's listing has no posted date, the API date is an ingest date, and the Wayback Machine has no capture of "+p.c.RSIURL)
			continue
		}
		imgs, err := commlink.PlanImages(ctx, web, wiki, cache, planned, cfg, p.c.Title, p.page, date, p.blocks)
		if saveErr := cache.Save(); saveErr != nil {
			return saveErr
		}
		if err != nil {
			review(p.c, p.page, commlink.ReasonImages, err.Error())
			continue
		}
		body, links := vocab.Apply(commlink.RenderBody(p.blocks, caser, imgs.File))
		text := commlink.Infobox(commlink.PageMeta{
			RSITitle: p.c.Title, URL: commlink.InfoboxURL(p.c.RSIURL),
			Series: cfg.InfoboxSeries, Type: cfg.InfoboxType, Date: date,
		}) + "\n" + body
		if lost := commlink.Missing(p.c.Text, text, cfg.IgnoredLine); len(lost) > 0 {
			review(p.c, p.page, commlink.ReasonFidelity, lost...)
			continue
		}
		file := commlink.PageFileName(p.page)
		if err := os.WriteFile(filepath.Join(pagesDir, file), []byte(text), 0o644); err != nil {
			return err
		}
		plan.Create = append(plan.Create, commlink.PageEntry{
			ID: p.c.ID, RSITitle: p.c.Title, Page: p.page, URL: commlink.InfoboxURL(p.c.RSIURL),
			Date: date, DateSource: dateSource, Wikitext: filepath.Join("pages", file),
			Images: imgs.Plans, Links: links, MissingImages: imgs.Missing,
		})
		maps.Copy(planned, imgs.Added)
	}
	if err := cache.Save(); err != nil {
		return err
	}
	sort.Slice(plan.Create, func(i, j int) bool { return plan.Create[i].ID < plan.Create[j].ID })
	sort.Slice(plan.Review, func(i, j int) bool { return plan.Review[i].ID < plan.Review[j].ID })

	// The cap is checked after writing, so a tripped rail leaves the plan to read.
	rejected := len(plan.Create) > *maxCreate
	dest := filepath.Join(*out, "plan.json")
	if rejected {
		dest = filepath.Join(*out, "plan.rejected.json")
	}
	if err := writeJSON(dest, plan); err != nil {
		return err
	}
	progress("wrote " + dest)

	fmt.Fprintf(os.Stderr, "\n%s series against %s\n", cfg.Series, wikiEndpoint)
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

// firstCapture reads a comm-link's first Wayback capture through the cache. An
// empty answer is not cached: the Wayback Machine is sometimes down.
func firstCapture(ctx context.Context, web *httpx.Client, ep commlink.Endpoints, cache *commlink.Cache, rsiURL string) (time.Time, error) {
	if s, ok := cache.Captures[rsiURL]; ok {
		return time.Parse(time.RFC3339, s)
	}
	t, err := commlink.FirstCapture(ctx, web, ep, rsiURL)
	if err != nil {
		return time.Time{}, err
	}
	if !t.IsZero() {
		cache.Captures[rsiURL] = t.Format(time.RFC3339)
	}
	return t, nil
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
	exists, err := commlink.PagesExist(ctx, wiki, targets)
	if err != nil {
		return nil, err
	}
	// An alias whose target is missing is dropped: a red link is worse than none.
	aliases := map[string]string{}
	for term, target := range cfg.Aliases {
		if exists[target] {
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
