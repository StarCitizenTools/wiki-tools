package commlink

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/StarCitizenTools/wiki-tools/scripts/internal/httpx"
)

// Endpoints are the upstreams the importer reads. Tests point them at a fake
// server.
type Endpoints struct {
	API     string // Star Citizen Wiki API comm-link collection
	RSI     string // RSI site root
	Wayback string // Wayback Machine CDX endpoint
}

// DefaultEndpoints are the live upstreams.
func DefaultEndpoints() Endpoints {
	return Endpoints{
		API:     "https://api.star-citizen.wiki/api/comm-links",
		RSI:     "https://robertsspaceindustries.com",
		Wayback: "https://web.archive.org/cdx/search/cdx",
	}
}

// The sources a candidate can be found by.
const (
	FoundByTitle  = "api-title"
	FoundBySeries = "rsi-series"
)

// Candidate is one upstream report.
type Candidate struct {
	ID      int
	Title   string
	RSIURL  string
	Created string // API created_at, RFC 3339
	Posted  string // RSI's series listing Posted date, YYYY-MM-DD, when it is absolute
	Text    string // API plain text, en_EN
	FoundBy []string
}

// Disagreement is a report only one discovery source found.
type Disagreement struct {
	ID      int    `json:"id"`
	Title   string `json:"title"`
	FoundBy string `json:"foundBy"`
}

type apiRecord struct {
	ID           int               `json:"id"`
	Title        string            `json:"title"`
	RSIURL       string            `json:"rsi_url"`
	CreatedAt    string            `json:"created_at"`
	Translations map[string]string `json:"translations"`
}

func (r apiRecord) candidate(foundBy string) Candidate {
	return Candidate{
		ID:      r.ID,
		Title:   strings.TrimSpace(r.Title),
		RSIURL:  r.RSIURL,
		Created: r.CreatedAt,
		Text:    r.Translations["en_EN"],
		FoundBy: []string{foundBy},
	}
}

// FetchTitleMatches reads every API comm-link whose title contains query and
// keeps those keep accepts. The API honours page[size] up to 200; limit and
// per_page are ignored.
func FetchTitleMatches(ctx context.Context, web *httpx.Client, ep Endpoints, query string, keep func(string) bool) ([]Candidate, error) {
	var out []Candidate
	for page := 1; ; page++ {
		q := url.Values{"filter[title]": {query}, "page[size]": {"200"}, "page[number]": {strconv.Itoa(page)}}
		body, err := web.Do(ctx, http.MethodGet, ep.API+"?"+q.Encode(), "")
		if err != nil {
			return nil, fmt.Errorf("api title search page %d: %w", page, err)
		}
		var res struct {
			Data []apiRecord `json:"data"`
			Meta struct {
				LastPage int `json:"last_page"`
			} `json:"meta"`
		}
		if err := json.Unmarshal(body, &res); err != nil {
			return nil, fmt.Errorf("decoding api title search page %d: %w", page, err)
		}
		for _, r := range res.Data {
			if keep(r.Title) {
				out = append(out, r.candidate(FoundByTitle))
			}
		}
		if len(res.Data) == 0 || page >= res.Meta.LastPage {
			return out, nil
		}
	}
}

// FetchRecord reads one comm-link from the API.
func FetchRecord(ctx context.Context, web *httpx.Client, ep Endpoints, id int) (Candidate, error) {
	body, err := web.Do(ctx, http.MethodGet, fmt.Sprintf("%s/%d", ep.API, id), "")
	if err != nil {
		return Candidate{}, fmt.Errorf("api comm-link %d: %w", id, err)
	}
	var res struct {
		Data apiRecord `json:"data"`
	}
	if err := json.Unmarshal(body, &res); err != nil {
		return Candidate{}, fmt.Errorf("decoding api comm-link %d: %w", id, err)
	}
	return res.Data.candidate(FoundBySeries), nil
}

var (
	hubItem = regexp.MustCompile(`href="/comm-link/[a-z0-9-]+/(\d+)-`)
	// hubPosted is an item's publication time. RSI writes it as an absolute
	// "2021-08-04 20:17:28" for older items and as "3 weeks ago" for recent ones.
	hubPosted = regexp.MustCompile(`Posted:\s*<span class="value">\s*(\d{4}-\d{2}-\d{2})[ \d:]*</span>`)
)

// maxSeriesPages bounds the series walk. RSI answers an unknown series slug with
// every comm-link (over 300 pages) instead of an error.
const maxSeriesPages = 60

// SeriesItem is one comm-link of RSI's series listing. Posted is its YYYY-MM-DD
// publication date, or "" when the listing gives only a relative age.
type SeriesItem struct {
	ID     int
	Posted string
}

// FetchSeries lists the comm-links RSI files under a series slug, newest first.
func FetchSeries(ctx context.Context, web *httpx.Client, ep Endpoints, series string) ([]SeriesItem, error) {
	seen := map[int]bool{}
	var items []SeriesItem
	for page := 1; page <= maxSeriesPages; page++ {
		payload, _ := json.Marshal(map[string]any{
			"channel": "", "series": series, "type": "", "text": "", "sort": "publish_new", "page": page,
		})
		body, err := web.DoContentType(ctx, http.MethodPost, ep.RSI+"/api/hub/getCommlinkItems", string(payload), "application/json")
		if err != nil {
			return nil, fmt.Errorf("rsi series %q page %d: %w", series, page, err)
		}
		var res struct {
			Success int    `json:"success"`
			Data    string `json:"data"`
		}
		if err := json.Unmarshal(body, &res); err != nil {
			return nil, fmt.Errorf("decoding rsi series %q page %d: %w", series, page, err)
		}
		if res.Success != 1 {
			return nil, fmt.Errorf("rsi series %q page %d: success=%d", series, page, res.Success)
		}
		found := hubItem.FindAllStringSubmatchIndex(res.Data, -1)
		if len(found) == 0 {
			return items, nil
		}
		for i, m := range found {
			id, _ := strconv.Atoi(res.Data[m[2]:m[3]])
			if seen[id] {
				continue
			}
			seen[id] = true
			end := len(res.Data)
			if i+1 < len(found) {
				end = found[i+1][0]
			}
			item := SeriesItem{ID: id}
			if p := hubPosted.FindStringSubmatch(res.Data[m[1]:end]); p != nil {
				if _, err := time.Parse("2006-01-02", p[1]); err == nil {
					item.Posted = p[1]
				}
			}
			items = append(items, item)
		}
	}
	return nil, fmt.Errorf("rsi series %q has more than %d pages; is the slug right?", series, maxSeriesPages)
}

// Union merges the title matches with the series items, fetching any report
// only the series knows, and lists the reports found by one source only. A
// report carries the series listing's Posted date; one only the title search
// found has none.
func Union(ctx context.Context, titled []Candidate, series []SeriesItem, fetch func(context.Context, int) (Candidate, error)) ([]Candidate, []Disagreement, error) {
	byID := map[int]*Candidate{}
	for i := range titled {
		c := titled[i]
		byID[c.ID] = &c
	}
	for _, it := range series {
		if c, ok := byID[it.ID]; ok {
			c.FoundBy = append(c.FoundBy, FoundBySeries)
			c.Posted = it.Posted
			continue
		}
		c, err := fetch(ctx, it.ID)
		if err != nil {
			return nil, nil, err
		}
		c.FoundBy = []string{FoundBySeries}
		c.Posted = it.Posted
		byID[it.ID] = &c
	}
	ids := make([]int, 0, len(byID))
	for id := range byID {
		ids = append(ids, id)
	}
	sort.Ints(ids)
	var out []Candidate
	var dis []Disagreement
	for _, id := range ids {
		c := byID[id]
		out = append(out, *c)
		if len(c.FoundBy) == 1 {
			dis = append(dis, Disagreement{ID: id, Title: c.Title, FoundBy: c.FoundBy[0]})
		}
	}
	return out, dis, nil
}
