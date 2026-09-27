package commlink

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"regexp"
	"slices"
	"strings"
	"time"

	"github.com/StarCitizenTools/wiki-tools/scripts/internal/httpx"
)

// Where a page's publication date came from.
const (
	DateRSI     = "rsi"
	DatePage    = "page"
	DateAPI     = "api"
	DateWayback = "wayback"
)

var commLinkPath = regexp.MustCompile(`robertsspaceindustries\.com/(?:en/)?comm-link/([a-z0-9-]+)/(\d+)-`)

// FirstCapture is a comm-link's first Wayback capture, read through the cache.
// An empty answer is not cached: the Wayback Machine is sometimes down.
func (c *Cache) FirstCapture(ctx context.Context, web *httpx.Client, ep Endpoints, rsiURL string) (time.Time, error) {
	if s, ok := c.Captures[rsiURL]; ok {
		return time.Parse(time.RFC3339, s)
	}
	t, err := firstCapture(ctx, web, ep, rsiURL)
	if err == nil && !t.IsZero() {
		c.Captures[rsiURL] = t.Format(time.RFC3339)
	}
	return t, err
}

// firstCapture returns the earliest Wayback Machine capture of a comm-link, over
// its URL with and without the /en/ locale segment, or the zero time when there
// is none. The CDX answer is sorted by URL, then time, so it is collapsed to one
// row per URL rather than cut to a row limit, which could drop a later URL's
// earlier capture.
func firstCapture(ctx context.Context, web *httpx.Client, ep Endpoints, rsiURL string) (time.Time, error) {
	m := commLinkPath.FindStringSubmatch(rsiURL)
	if m == nil {
		return time.Time{}, fmt.Errorf("not a comm-link url: %s", rsiURL)
	}
	prefix := fmt.Sprintf("robertsspaceindustries.com/comm-link/%s/%s-", m[1], m[2])
	var first time.Time
	for _, p := range []string{prefix, strings.Replace(prefix, ".com/", ".com/en/", 1)} {
		q := url.Values{"url": {p}, "matchType": {"prefix"}, "output": {"json"}, "collapse": {"urlkey"}, "fl": {"timestamp"}}
		body, err := web.Do(ctx, http.MethodGet, ep.Wayback+"?"+q.Encode(), "")
		if err != nil {
			return time.Time{}, fmt.Errorf("wayback %s: %w", p, err)
		}
		if strings.TrimSpace(string(body)) == "" {
			continue
		}
		var rows [][]string
		if err := json.Unmarshal(body, &rows); err != nil {
			return time.Time{}, fmt.Errorf("decoding wayback %s: %w", p, err)
		}
		for _, row := range rows[min(1, len(rows)):] { // row 0 is the header
			if len(row) != 1 {
				continue
			}
			t, err := time.Parse("20060102150405", row[0])
			if err == nil && (first.IsZero() || t.Before(first)) {
				first = t
			}
		}
	}
	return first, nil
}

// ResolveDate picks a page's publication date: RSI's own Posted date from its
// series listing; else the date the page itself shows (paged, see
// ParseFragment); else the API's created_at, unless it is one of ingest (days
// the API imported reports in bulk) or falls after the first Wayback capture;
// else the first capture's UTC day. capture is called only when neither RSI
// date is known. The error says why nothing dates the report, or that the
// Wayback lookup failed.
func ResolveDate(posted, paged, apiCreated string, ingest []string, capture func() (time.Time, error)) (date, source string, err error) {
	if posted != "" {
		return posted, DateRSI, nil
	}
	if paged != "" {
		return paged, DatePage, nil
	}
	first, err := capture()
	if err != nil {
		return "", "", fmt.Errorf("wayback lookup failed: %w", err)
	}
	day := func(t time.Time) time.Time {
		t = t.UTC()
		return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC)
	}
	api, apiErr := time.Parse(time.RFC3339, apiCreated)
	apiDay := day(api).Format("2006-01-02")
	if apiErr == nil && !slices.Contains(ingest, apiDay) && (first.IsZero() || !day(api).After(day(first))) {
		return apiDay, DateAPI, nil
	}
	if !first.IsZero() {
		return day(first).Format("2006-01-02"), DateWayback, nil
	}
	why := "the API's created_at falls on the ingest date " + apiDay
	switch {
	case apiCreated == "":
		why = "the API has no created_at"
	case apiErr != nil:
		why = fmt.Sprintf("the API's created_at %q does not parse", apiCreated)
	}
	return "", "", errors.New("RSI's listing has no posted date, " + why + ", and the Wayback Machine has no capture")
}
