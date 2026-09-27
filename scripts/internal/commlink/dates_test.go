package commlink

import (
	"context"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestFirstCapture(t *testing.T) {
	const rsiURL = "https://robertsspaceindustries.com/en/comm-link/transmission/18180-Squadron-42-Monthly-Report-May-2021"
	var asked []string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		u := r.URL.Query().Get("url")
		asked = append(asked, u)
		if q := r.URL.Query(); q.Get("matchType") != "prefix" || q.Get("collapse") != "urlkey" || q.Has("limit") {
			t.Errorf("query = %s, want a urlkey-collapsed prefix query with no row limit", r.URL.RawQuery)
		}
		if strings.Contains(u, "/en/") {
			io.WriteString(w, `[["timestamp"],["20250218102005"]]`)
			return
		}
		io.WriteString(w, `[["timestamp"],["20210613000000"],["20210609173241"]]`)
	}))
	defer srv.Close()

	cache, _ := LoadCache(filepath.Join(t.TempDir(), "cache.json"))
	want := time.Date(2021, 6, 9, 17, 32, 41, 0, time.UTC)
	for range 2 {
		got, err := cache.FirstCapture(context.Background(), testWeb(t), Endpoints{Wayback: srv.URL}, rsiURL)
		if err != nil || !got.Equal(want) {
			t.Errorf("FirstCapture = %v, %v; want %v", got, err, want)
		}
	}
	wantAsked := []string{
		"robertsspaceindustries.com/comm-link/transmission/18180-",
		"robertsspaceindustries.com/en/comm-link/transmission/18180-",
	}
	if strings.Join(asked, " ") != strings.Join(wantAsked, " ") {
		t.Errorf("asked %v, want %v once: the second call reads the cache", asked, wantAsked)
	}
}

// No capture is not cached: the next run asks the Wayback Machine again.
func TestFirstCaptureNone(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { io.WriteString(w, `[]`) }))
	defer srv.Close()
	cache, _ := LoadCache(filepath.Join(t.TempDir(), "cache.json"))
	const rsiURL = "https://robertsspaceindustries.com/comm-link/transmission/1-X"
	got, err := cache.FirstCapture(context.Background(), testWeb(t), Endpoints{Wayback: srv.URL}, rsiURL)
	if err != nil || !got.IsZero() {
		t.Errorf("FirstCapture = %v, %v; want zero time", got, err)
	}
	if _, ok := cache.Captures[rsiURL]; ok {
		t.Error("an empty answer was cached")
	}
}

func TestResolveDate(t *testing.T) {
	at := func(s string) time.Time { v, _ := time.Parse("2006-01-02T15:04:05", s); return v }
	ingest := []string{"2026-05-25"}
	cases := []struct {
		name, posted, paged, api string
		capture                  time.Time
		date, source             string
		asked                    bool
		why                      string // when nothing dates the report
	}{
		{"rsi posted date wins", "2018-05-03", "2018-05-02", "2018-05-04T00:00:00+00:00", at("2019-08-22T00:00:00"), "2018-05-03", DateRSI, false, ""},
		{"page date before the api and wayback", "", "2022-05-18", "2026-05-25T00:00:00+00:00", at("2022-05-18T20:09:22"), "2022-05-18", DatePage, false, ""},
		{"api date before the capture", "", "", "2018-05-03T00:00:00+00:00", at("2019-08-22T10:00:00"), "2018-05-03", DateAPI, true, ""},
		{"api date on the capture day", "", "", "2021-06-09T00:00:00+00:00", at("2021-06-09T17:32:41"), "2021-06-09", DateAPI, true, ""},
		{"api date with no capture", "", "", "2021-06-09T00:00:00+00:00", time.Time{}, "2021-06-09", DateAPI, true, ""},
		{"ingest api date rejected", "", "", "2026-05-25T00:00:00+00:00", at("2021-06-02T23:20:57"), "2021-06-02", DateWayback, true, ""},
		{"api date after the capture rejected", "", "", "2026-03-20T00:00:00+00:00", at("2026-03-04T09:00:00"), "2026-03-04", DateWayback, true, ""},
		{"no api date", "", "", "", at("2023-02-02T04:02:02"), "2023-02-02", DateWayback, true, ""},
		{"nothing to date by: ingest api date", "", "", "2026-05-25T00:00:00+00:00", time.Time{}, "", "", true, "falls on the ingest date 2026-05-25"},
		{"nothing to date by: no api date", "", "", "", time.Time{}, "", "", true, "the API has no created_at"},
		{"nothing to date by: bad api date", "", "", "May 2021", time.Time{}, "", "", true, `created_at "May 2021" does not parse`},
	}
	for _, c := range cases {
		asked := false
		capture := func() (time.Time, error) { asked = true; return c.capture, nil }
		date, source, err := ResolveDate(c.posted, c.paged, c.api, ingest, capture)
		why := ""
		if err != nil {
			why = err.Error()
		}
		if date != c.date || source != c.source || asked != c.asked || (c.why == "") != (err == nil) || !strings.Contains(why, c.why) {
			t.Errorf("%s: ResolveDate = %q %q %v (wayback asked %v), want %q %q %q (asked %v)", c.name, date, source, err, asked, c.date, c.source, c.why, c.asked)
		}
	}
	if _, _, err := ResolveDate("", "", "2021-06-09T00:00:00+00:00", ingest, func() (time.Time, error) { return time.Time{}, errors.New("down") }); err == nil || !strings.Contains(err.Error(), "wayback lookup failed: down") {
		t.Errorf("a failed Wayback lookup was reported as %v", err)
	}
}
