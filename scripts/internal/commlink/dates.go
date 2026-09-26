package commlink

import (
	"context"
	"encoding/json"
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
	DateAPI     = "api"
	DateWayback = "wayback"
)

var commLinkPath = regexp.MustCompile(`robertsspaceindustries\.com/(?:en/)?comm-link/([a-z0-9-]+)/(\d+)-`)

// FirstCapture returns the earliest Wayback Machine capture of a comm-link, over
// its URL with and without the /en/ locale segment, or the zero time when there
// is none.
func FirstCapture(ctx context.Context, web *httpx.Client, ep Endpoints, rsiURL string) (time.Time, error) {
	m := commLinkPath.FindStringSubmatch(rsiURL)
	if m == nil {
		return time.Time{}, fmt.Errorf("not a comm-link url: %s", rsiURL)
	}
	prefix := fmt.Sprintf("robertsspaceindustries.com/comm-link/%s/%s-", m[1], m[2])
	var first time.Time
	for _, p := range []string{prefix, strings.Replace(prefix, ".com/", ".com/en/", 1)} {
		q := url.Values{"url": {p}, "matchType": {"prefix"}, "output": {"json"}, "limit": {"50"}, "fl": {"timestamp"}}
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
// series listing; else the API's created_at, unless it is one of ingest (days
// the API imported reports in bulk) or falls after the first Wayback capture;
// else the first capture's UTC day. capture is called only when there is no
// Posted date. date is "" when nothing dates the report.
func ResolveDate(posted, apiCreated string, ingest []string, capture func() (time.Time, error)) (date, source string, err error) {
	if posted != "" {
		return posted, DateRSI, nil
	}
	first, err := capture()
	if err != nil {
		return "", "", err
	}
	day := func(t time.Time) time.Time {
		t = t.UTC()
		return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC)
	}
	if api, err := time.Parse(time.RFC3339, apiCreated); err == nil {
		apiDay := day(api).Format("2006-01-02")
		if !slices.Contains(ingest, apiDay) && (first.IsZero() || !day(api).After(day(first))) {
			return apiDay, DateAPI, nil
		}
	}
	if first.IsZero() {
		return "", "", nil
	}
	return day(first).Format("2006-01-02"), DateWayback, nil
}
