package commlink

import (
	"context"
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
	cases := []struct {
		api     string
		capture time.Time
		date    string
		source  string
		ok      bool
	}{
		{"2021-06-09T00:00:00+00:00", at("2021-06-09T17:32:41"), "2021-06-09", DateAPI, true},
		{"2021-05-05T00:00:00+00:00", at("2021-05-06T16:46:38"), "2021-05-05", DateAPI, true},
		{"2026-05-25T00:00:00+00:00", at("2021-06-02T23:20:57"), "2021-06-02", DateWayback, true},
		{"2021-05-01T00:00:00+00:00", at("2021-05-06T00:00:00"), "2021-05-06", DateWayback, true},
		{"", at("2023-02-02T04:02:02"), "2023-02-02", DateWayback, true},
		{"2021-06-09T00:00:00+00:00", time.Time{}, "", "", false},
	}
	for _, c := range cases {
		date, source, ok := ResolveDate(c.api, c.capture)
		if date != c.date || source != c.source || ok != c.ok {
			t.Errorf("ResolveDate(%q, %v) = %q %q %v, want %q %q %v", c.api, c.capture, date, source, ok, c.date, c.source, c.ok)
		}
	}
}
