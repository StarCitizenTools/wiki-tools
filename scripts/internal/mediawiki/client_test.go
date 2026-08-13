package mediawiki

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strconv"
	"strings"
	"testing"
	"time"
)

func newTestClient(t *testing.T, handler func(form url.Values) string) (*Client, *int) {
	t.Helper()
	requests := 0
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requests++
		body, _ := io.ReadAll(r.Body)
		form, err := url.ParseQuery(string(body))
		if err != nil {
			t.Fatalf("parsing form: %v", err)
		}
		io.WriteString(w, handler(form))
	}))
	t.Cleanup(srv.Close)
	c, err := New(Config{Endpoint: srv.URL, UserAgent: "test", Interval: time.Millisecond})
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	t.Cleanup(c.Close)
	return c, &requests
}

func TestTitleStatuses(t *testing.T) {
	client, requests := newTestClient(t, func(form url.Values) string {
		titles := strings.Split(form.Get("titles"), "|")
		if len(titles) > 50 {
			t.Fatalf("batch of %d titles, want <= 50", len(titles))
		}
		resp := map[string]any{"query": map[string]any{
			"normalized": []map[string]string{{"from": "dominance-1 Scattergun", "to": "Dominance-1 Scattergun"}},
			"pages": []map[string]any{
				{"title": "Dominance-1 Scattergun", "missing": true},
				{"title": "Cup"},
				{"title": "Bad<Title", "invalid": true},
			},
		}}
		b, _ := json.Marshal(resp)
		return string(b)
	})

	got, err := client.TitleStatuses(context.Background(),
		[]string{"dominance-1 Scattergun", "Cup", "Bad<Title"})
	if err != nil {
		t.Fatalf("TitleStatuses: %v", err)
	}
	want := map[string]TitleStatus{
		"dominance-1 Scattergun": TitleMissing, // keyed by caller's string, via normalized reversal
		"Cup":                    TitleExists,
		"Bad<Title":              TitleInvalid,
	}
	for title, status := range want {
		if got[title] != status {
			t.Errorf("%q = %q, want %q", title, got[title], status)
		}
	}
	if len(got) != len(want) {
		t.Errorf("result len = %d, want %d (every input must appear)", len(got), len(want))
	}
	if *requests != 1 {
		t.Errorf("requests = %d, want 1", *requests)
	}
}

func TestTitleStatusesBatches(t *testing.T) {
	client, requests := newTestClient(t, func(form url.Values) string {
		titles := strings.Split(form.Get("titles"), "|")
		pages := make([]map[string]any, len(titles))
		for i, title := range titles {
			pages[i] = map[string]any{"title": title, "missing": true}
		}
		b, _ := json.Marshal(map[string]any{"query": map[string]any{"pages": pages}})
		return string(b)
	})

	titles := make([]string, 120)
	for i := range titles {
		titles[i] = "Page " + strconv.Itoa(i)
	}
	got, err := client.TitleStatuses(context.Background(), titles)
	if err != nil {
		t.Fatalf("TitleStatuses: %v", err)
	}
	if len(got) != 120 {
		t.Errorf("results = %d, want 120", len(got))
	}
	if *requests != 3 {
		t.Errorf("requests = %d, want 3 (batches of 50)", *requests)
	}
}

func TestTitleStatusesNormalizationCollision(t *testing.T) {
	client, _ := newTestClient(t, func(form url.Values) string {
		// Simulate API normalization: "cup" normalizes to "Cup"
		resp := map[string]any{"query": map[string]any{
			"normalized": []map[string]string{{"from": "cup", "to": "Cup"}},
			"pages": []map[string]any{
				{"title": "Cup"},
			},
		}}
		b, _ := json.Marshal(resp)
		return string(b)
	})

	got, err := client.TitleStatuses(context.Background(),
		[]string{"Cup", "cup"})
	if err != nil {
		t.Fatalf("TitleStatuses: %v", err)
	}

	// Both "Cup" and "cup" should appear in results with the same status
	if got["Cup"] != TitleExists {
		t.Errorf("got[\"Cup\"] = %q, want %q", got["Cup"], TitleExists)
	}
	if got["cup"] != TitleExists {
		t.Errorf("got[\"cup\"] = %q, want %q", got["cup"], TitleExists)
	}
	// Every input title must appear in the result
	if len(got) != 2 {
		t.Errorf("result len = %d, want 2 (both inputs must appear)", len(got))
	}
}
