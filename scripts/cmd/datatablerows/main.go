// Command datatablerows counts the rows of every grid rendered by a live
// {{Data table}} call, so a row count taken before a DataGrid deploy can be
// compared against one taken after.
//
//	datatablerows                 # print title\tindex\trows to stdout
//	datatablerows -out before.tsv # also write the same report to a file
//
// It reads the wiki only: the row counts come from the AGGrid REST endpoint
// each rendered grid already exposes, not from anything this tool writes.
package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/StarCitizenTools/wiki-tools/scripts/internal/datatable"
	"github.com/StarCitizenTools/wiki-tools/scripts/internal/httpx"
	"github.com/StarCitizenTools/wiki-tools/scripts/internal/mediawiki"
)

const (
	wikiEndpoint = "https://starcitizen.tools/api.php"
	restBase     = "https://starcitizen.tools"
	userAgent    = "StarCitizenTools-wiki-tools/1.0 (https://github.com/StarCitizenTools/wiki-tools)"
	template     = "Template:Data table"
)

func main() {
	out := flag.String("out", "", "also write the tab-separated report to this file")
	interval := flag.Duration("interval", 300*time.Millisecond, "minimum spacing between requests")
	flag.Parse()

	anyError, err := run(*out, *interval)
	if err != nil {
		fmt.Fprintln(os.Stderr, "datatablerows:", err)
		os.Exit(1)
	}
	if anyError {
		os.Exit(1)
	}
}

// reportLine is one row of the tab-separated output.
type reportLine struct {
	title string
	index int
	rows  string
}

func run(out string, interval time.Duration) (anyError bool, err error) {
	client, err := mediawiki.New(mediawiki.Config{Endpoint: wikiEndpoint, UserAgent: userAgent, Interval: interval})
	if err != nil {
		return false, err
	}
	defer client.Close()

	rest := httpx.New(httpx.Options{Interval: interval, UserAgent: userAgent, MaxTries: 4, Timeout: 30 * time.Second})
	defer rest.Close()

	ctx := context.Background()

	titles, err := embeddedTitles(ctx, client)
	if err != nil {
		return false, fmt.Errorf("listing pages embedding %s: %w", template, err)
	}

	var lines []reportLine
	for _, title := range titles {
		html, err := parseHTML(ctx, client, title)
		if err != nil {
			return false, fmt.Errorf("parsing %s: %w", title, err)
		}

		grids, hasError := datatable.ScanGrids(html)
		if hasError {
			anyError = true
			if len(grids) == 0 {
				lines = append(lines, reportLine{title: title, index: 0, rows: "error"})
				continue
			}
			for _, g := range grids {
				lines = append(lines, reportLine{title: title, index: g.Index, rows: "error"})
			}
			continue
		}

		for _, g := range grids {
			n, err := fetchRowCount(ctx, rest, g)
			if err != nil {
				return false, fmt.Errorf("fetching rows for %s grid %d: %w", title, g.Index, err)
			}
			lines = append(lines, reportLine{title: title, index: g.Index, rows: strconv.Itoa(n)})
		}
	}

	sort.Slice(lines, func(i, j int) bool {
		if lines[i].title != lines[j].title {
			return lines[i].title < lines[j].title
		}
		return lines[i].index < lines[j].index
	})

	var buf strings.Builder
	for _, l := range lines {
		fmt.Fprintf(&buf, "%s\t%d\t%s\n", l.title, l.index, l.rows)
	}
	fmt.Print(buf.String())

	if out != "" {
		if err := os.WriteFile(out, []byte(buf.String()), 0o644); err != nil {
			return anyError, err
		}
	}
	return anyError, nil
}

// embeddedTitles lists every namespace-0 page embedding Template:Data table,
// direct calls and calls reached only through {{Manufacturer products}}
// alike: every one of them renders a real grid whose row count matters here.
func embeddedTitles(ctx context.Context, client *mediawiki.Client) ([]string, error) {
	var titles []string
	eicontinue := ""
	for {
		form := url.Values{
			"action":        {"query"},
			"list":          {"embeddedin"},
			"eititle":       {template},
			"einamespace":   {"0"},
			"eilimit":       {"500"},
			"format":        {"json"},
			"formatversion": {"2"},
		}
		if eicontinue != "" {
			form.Set("eicontinue", eicontinue)
		}
		var res struct {
			mediawiki.Response
			Query struct {
				EmbeddedIn []struct {
					Title string `json:"title"`
				} `json:"embeddedin"`
			} `json:"query"`
			Continue struct {
				EIContinue string `json:"eicontinue"`
			} `json:"continue"`
		}
		if err := client.Request(ctx, form, &res); err != nil {
			return nil, err
		}
		for _, e := range res.Query.EmbeddedIn {
			titles = append(titles, e.Title)
		}
		if res.Continue.EIContinue == "" {
			break
		}
		eicontinue = res.Continue.EIContinue
	}
	sort.Strings(titles)
	return titles, nil
}

// parseHTML renders a page the same way a visitor would, so ScanGrids sees
// exactly the markup (and any inline error) a browser would.
func parseHTML(ctx context.Context, client *mediawiki.Client, title string) (string, error) {
	form := url.Values{
		"action":        {"parse"},
		"page":          {title},
		"prop":          {"text"},
		"format":        {"json"},
		"formatversion": {"2"},
	}
	var res struct {
		mediawiki.Response
		Parse struct {
			Text string `json:"text"`
		} `json:"parse"`
	}
	if err := client.Request(ctx, form, &res); err != nil {
		return "", err
	}
	return res.Parse.Text, nil
}

// fetchRowCount reads one grid's row count from the AGGrid REST endpoint the
// extension serves for it; the count is len(rows), not the response's
// "total" (omitted unless the grid paginates server-side, which none here do).
func fetchRowCount(ctx context.Context, client *httpx.Client, g datatable.Grid) (int, error) {
	restURL := fmt.Sprintf("%s/rest.php/aggrid/v0/grid/%s/%s/%d/rows", restBase, g.PageID, g.Token, g.Index)
	body, err := client.Do(ctx, http.MethodGet, restURL, "")
	if err != nil {
		return 0, err
	}
	var res struct {
		Rows []struct{} `json:"rows"`
	}
	if err := json.Unmarshal(body, &res); err != nil {
		return 0, fmt.Errorf("decoding %s: %w", restURL, err)
	}
	return len(res.Rows), nil
}
