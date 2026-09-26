package commlink

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"time"

	"github.com/StarCitizenTools/wiki-tools/scripts/internal/httpx"
)

// Where a page's publication date came from.
const (
	DateAPI     = "api"
	DateWayback = "wayback"
)

// corroboration is how far before the first capture an API date may fall and
// still be trusted. The API's created_at is an ingest date for many reports
// (2026-05-25 for every report from late 2021), and RSI's own Date: field shows
// the day it is fetched, so neither is trusted alone.
const corroboration = 3 * 24 * time.Hour

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

// ResolveDate picks a page's publication date: the API date when the first
// capture corroborates it, else the capture's UTC day. ok is false when there is
// no capture to judge by.
func ResolveDate(apiCreated string, firstCapture time.Time) (date, source string, ok bool) {
	if firstCapture.IsZero() {
		return "", "", false
	}
	c := firstCapture.UTC()
	captureDay := time.Date(c.Year(), c.Month(), c.Day(), 0, 0, 0, 0, time.UTC)
	if api, err := time.Parse(time.RFC3339, apiCreated); err == nil {
		apiDay := time.Date(api.Year(), api.Month(), api.Day(), 0, 0, 0, 0, time.UTC)
		if !apiDay.After(captureDay) && captureDay.Sub(apiDay) <= corroboration {
			return apiDay.Format("2006-01-02"), DateAPI, true
		}
	}
	return captureDay.Format("2006-01-02"), DateWayback, true
}
