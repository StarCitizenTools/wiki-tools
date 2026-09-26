package commlink

import (
	"context"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestFirstCapture(t *testing.T) {
	var asked []string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		u := r.URL.Query().Get("url")
		asked = append(asked, u)
		if r.URL.Query().Get("matchType") != "prefix" {
			t.Errorf("matchType = %q", r.URL.Query().Get("matchType"))
		}
		if strings.Contains(u, "/en/") {
			io.WriteString(w, `[["timestamp"],["20250218102005"]]`)
			return
		}
		io.WriteString(w, `[["timestamp"],["20210613000000"],["20210609173241"]]`)
	}))
	defer srv.Close()

	got, err := FirstCapture(context.Background(), testWeb(t), Endpoints{Wayback: srv.URL},
		"https://robertsspaceindustries.com/en/comm-link/transmission/18180-Squadron-42-Monthly-Report-May-2021")
	if err != nil {
		t.Fatal(err)
	}
	if want := time.Date(2021, 6, 9, 17, 32, 41, 0, time.UTC); !got.Equal(want) {
		t.Errorf("FirstCapture = %v, want %v", got, want)
	}
	want := []string{
		"robertsspaceindustries.com/comm-link/transmission/18180-",
		"robertsspaceindustries.com/en/comm-link/transmission/18180-",
	}
	if strings.Join(asked, " ") != strings.Join(want, " ") {
		t.Errorf("asked %v", asked)
	}
}

func TestFirstCaptureNone(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { io.WriteString(w, `[]`) }))
	defer srv.Close()
	got, err := FirstCapture(context.Background(), testWeb(t), Endpoints{Wayback: srv.URL},
		"https://robertsspaceindustries.com/comm-link/transmission/1-X")
	if err != nil || !got.IsZero() {
		t.Errorf("FirstCapture = %v, %v; want zero time", got, err)
	}
}

func TestResolveDate(t *testing.T) {
	at := func(s string) time.Time { v, _ := time.Parse("2006-01-02T15:04:05", s); return v }
	ingest := []string{"2026-05-25"}
	cases := []struct {
		name, posted, api string
		capture           time.Time
		date, source      string
		asked             bool
	}{
		{"rsi posted date wins", "2018-05-03", "2018-05-04T00:00:00+00:00", at("2019-08-22T00:00:00"), "2018-05-03", DateRSI, false},
		{"api date before the capture", "", "2018-05-03T00:00:00+00:00", at("2019-08-22T10:00:00"), "2018-05-03", DateAPI, true},
		{"api date on the capture day", "", "2021-06-09T00:00:00+00:00", at("2021-06-09T17:32:41"), "2021-06-09", DateAPI, true},
		{"api date with no capture", "", "2021-06-09T00:00:00+00:00", time.Time{}, "2021-06-09", DateAPI, true},
		{"ingest api date rejected", "", "2026-05-25T00:00:00+00:00", at("2021-06-02T23:20:57"), "2021-06-02", DateWayback, true},
		{"api date after the capture rejected", "", "2026-03-20T00:00:00+00:00", at("2026-03-04T09:00:00"), "2026-03-04", DateWayback, true},
		{"no api date", "", "", at("2023-02-02T04:02:02"), "2023-02-02", DateWayback, true},
		{"nothing to date by", "", "2026-05-25T00:00:00+00:00", time.Time{}, "", "", true},
	}
	for _, c := range cases {
		asked := false
		capture := func() (time.Time, error) { asked = true; return c.capture, nil }
		date, source, err := ResolveDate(c.posted, c.api, ingest, capture)
		if err != nil || date != c.date || source != c.source || asked != c.asked {
			t.Errorf("%s: ResolveDate = %q %q %v (wayback asked %v), want %q %q (asked %v)", c.name, date, source, err, asked, c.date, c.source, c.asked)
		}
	}
	if _, _, err := ResolveDate("", "2021-06-09T00:00:00+00:00", ingest, func() (time.Time, error) { return time.Time{}, errors.New("down") }); err == nil {
		t.Error("a failed Wayback lookup was not reported")
	}
}
