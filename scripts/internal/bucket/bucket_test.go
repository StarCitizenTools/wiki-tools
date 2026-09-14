package bucket

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
	"time"

	"github.com/StarCitizenTools/wiki-tools/scripts/internal/mediawiki"
)

// newClient serves canned action-API bodies from handler and counts calls.
func newClient(t *testing.T, handler func(form url.Values) string) (*mediawiki.Client, *int) {
	t.Helper()
	requests := 0
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requests++
		body, _ := io.ReadAll(r.Body)
		form, err := url.ParseQuery(string(body))
		if err != nil {
			t.Fatalf("parsing form: %v", err)
		}
		if got := form.Get("formatversion"); got != "2" {
			t.Errorf("formatversion = %q, want 2 (booleans must arrive as JSON booleans)", got)
		}
		io.WriteString(w, handler(form))
	}))
	t.Cleanup(srv.Close)
	c, err := mediawiki.New(mediawiki.Config{Endpoint: srv.URL, UserAgent: "bucket-test", Interval: time.Millisecond})
	if err != nil {
		t.Fatalf("New: %v", err)
	}
	t.Cleanup(c.Close)
	return c, &requests
}

// pagedQuery is the query builder Rows takes, recording each offset asked for.
func pagedQuery(asked *[]string) func(int) string {
	return func(offset int) string {
		q := fmt.Sprintf(`bucket("entity").select("page_name").limit(%d).offset(%d).run()`, PageSize, offset)
		*asked = append(*asked, q)
		return q
	}
}

// recordSleeps replaces the backoff sleep for the duration of one test.
func recordSleeps(t *testing.T) *[]time.Duration {
	t.Helper()
	var got []time.Duration
	prev := sleep
	sleep = func(d time.Duration) { got = append(got, d) }
	t.Cleanup(func() { sleep = prev })
	return &got
}

// recordWarnings captures the rate-limit stderr notice for the duration of one
// test instead of writing to the process's real stderr.
func recordWarnings(t *testing.T) *bytes.Buffer {
	t.Helper()
	var buf bytes.Buffer
	prev := warn
	warn = &buf
	t.Cleanup(func() { warn = prev })
	return &buf
}

func TestRowsRetriesRateLimitedPage(t *testing.T) {
	slept := recordSleeps(t)
	warnings := recordWarnings(t)
	n := 0
	var served []string
	client, requests := newClient(t, func(form url.Values) string {
		served = append(served, form.Get("query"))
		if n++; n <= 2 {
			// The rate limiter's envelope: HTTP 200, no error, no query echo.
			return `{}`
		}
		return `{"bucketQuery":"bucket(\"entity\")","bucket":[{"page_name":"Avenger Titan","size":2}]}`
	})

	var asked []string
	rows, made, err := Rows(context.Background(), client, "entity", pagedQuery(&asked))
	if err != nil {
		t.Fatalf("Rows: %v", err)
	}
	if *requests != 3 || made != 3 {
		t.Errorf("requests = %d (reported %d), want 3 (two throttled, one served)", *requests, made)
	}
	// A retry must re-ask for the same page; advancing the offset would skip rows.
	for i, q := range served {
		if !strings.Contains(q, ".offset(0)") {
			t.Errorf("attempt %d asked %q, want the same .offset(0) page", i+1, q)
		}
	}
	if want := []time.Duration{5 * time.Second, 10 * time.Second}; len(*slept) != 2 || (*slept)[0] != want[0] || (*slept)[1] != want[1] {
		t.Errorf("backoff = %v, want %v", *slept, want)
	}
	if len(rows) != 1 || rows[0]["size"] != float64(2) {
		t.Errorf("rows = %v, want the page served after the retries", rows)
	}
	// A run against the real corpus with no output looks like a hang; each
	// retry must announce itself.
	for _, want := range []string{"retrying in 5s", "retrying in 10s"} {
		if !strings.Contains(warnings.String(), want) {
			t.Errorf("stderr = %q, want it to contain %q", warnings.String(), want)
		}
	}
}

func TestRowsAcceptsAnEmptyPage(t *testing.T) {
	slept := recordSleeps(t)
	client, requests := newClient(t, func(url.Values) string {
		// A query that matched nothing: no echo, but a bucket array all the same.
		return `{"bucketQuery":"","bucket":[]}`
	})

	var asked []string
	rows, _, err := Rows(context.Background(), client, "mission", pagedQuery(&asked))
	if err != nil {
		t.Fatalf("Rows: %v", err)
	}
	if *requests != 1 {
		t.Errorf("requests = %d, want 1 (an empty page is an answer, not a throttle)", *requests)
	}
	if len(*slept) != 0 {
		t.Errorf("backoff = %v, want none", *slept)
	}
	if len(rows) != 0 {
		t.Errorf("rows = %v, want none", rows)
	}
}

func TestRowsWalksUntilAShortPage(t *testing.T) {
	// A full page means there may be more; only a short page ends the walk.
	full := make([]string, PageSize)
	for i := range full {
		full[i] = fmt.Sprintf(`{"page_name":"Page %d"}`, i)
	}
	client, _ := newClient(t, func(form url.Values) string {
		if strings.Contains(form.Get("query"), ".offset(0)") {
			return `{"bucketQuery":"q","bucket":[` + strings.Join(full, ",") + `]}`
		}
		return `{"bucketQuery":"q","bucket":[{"page_name":"Last"}]}`
	})

	var asked []string
	rows, requests, err := Rows(context.Background(), client, "entity", pagedQuery(&asked))
	if err != nil {
		t.Fatalf("Rows: %v", err)
	}
	if len(rows) != PageSize+1 {
		t.Errorf("rows = %d, want %d", len(rows), PageSize+1)
	}
	if requests != 2 {
		t.Errorf("requests = %d, want 2", requests)
	}
	want := []string{".offset(0)", fmt.Sprintf(".offset(%d)", PageSize)}
	if len(asked) != 2 || !strings.Contains(asked[0], want[0]) || !strings.Contains(asked[1], want[1]) {
		t.Errorf("asked %v, want offsets %v", asked, want)
	}
}

func TestRowsFailsWhenRateLimitPersists(t *testing.T) {
	recordSleeps(t)
	recordWarnings(t)
	client, requests := newClient(t, func(url.Values) string { return `{}` })

	var asked []string
	_, _, err := Rows(context.Background(), client, "vehicle_stats", pagedQuery(&asked))
	if err == nil {
		t.Fatal("Rows: want an error once the backoff is exhausted")
	}
	if !strings.Contains(err.Error(), "vehicle_stats") || !strings.Contains(err.Error(), "offset 0") {
		t.Errorf("error %q must name the bucket and the offset", err)
	}
	if want := len(backoff) + 1; *requests != want {
		t.Errorf("requests = %d, want %d (one try per backoff step, plus the first)", *requests, want)
	}
}

// The Bucket API sends `error` as a bare string, unlike the rest of the action
// API's {code, info} object; apiError must decode either shape and its message
// must be the server's own text, not a JSON-decode complaint.
func TestAPIErrorDecodesStringShape(t *testing.T) {
	var e apiError
	if err := e.UnmarshalJSON([]byte(`"bucket does not exist"`)); err != nil {
		t.Fatalf("UnmarshalJSON: %v", err)
	}
	if e.Error() != "bucket does not exist" {
		t.Errorf("Error() = %q, want the server's own text", e.Error())
	}
}

func TestAPIErrorDecodesObjectShape(t *testing.T) {
	var e apiError
	if err := e.UnmarshalJSON([]byte(`{"code":"internal_api_error","info":"something broke"}`)); err != nil {
		t.Fatalf("UnmarshalJSON: %v", err)
	}
	if e.Error() != "something broke" {
		t.Errorf("Error() = %q, want the info text", e.Error())
	}
}

func TestRowsSurfacesAPIError(t *testing.T) {
	client, _ := newClient(t, func(url.Values) string {
		return `{"error":"bucket does not exist"}`
	})
	var asked []string
	_, _, err := Rows(context.Background(), client, "nonesuch", pagedQuery(&asked))
	if err == nil {
		t.Fatal("Rows: want an error when the API reports one")
	}
	if !strings.Contains(err.Error(), "bucket does not exist") {
		t.Errorf("error %q must contain the server's text", err)
	}
}
