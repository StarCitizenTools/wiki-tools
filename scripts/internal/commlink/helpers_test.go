package commlink

import (
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"testing"
	"time"

	"github.com/StarCitizenTools/wiki-tools/scripts/internal/httpx"
	"github.com/StarCitizenTools/wiki-tools/scripts/internal/mediawiki"
)

// testWeb is an httpx client with no pacing and no retries.
func testWeb(t *testing.T) *httpx.Client {
	t.Helper()
	c := httpx.New(httpx.Options{Interval: time.Millisecond, UserAgent: "test", MaxTries: 1})
	t.Cleanup(c.Close)
	return c
}

// testWiki is a mediawiki client whose action API answers from handler.
func testWiki(t *testing.T, handler func(form url.Values) string) *mediawiki.Client {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		form, err := url.ParseQuery(string(body))
		if err != nil {
			t.Fatalf("parsing form: %v", err)
		}
		io.WriteString(w, handler(form))
	}))
	t.Cleanup(srv.Close)
	c, err := mediawiki.New(mediawiki.Config{Endpoint: srv.URL, UserAgent: "test", Interval: time.Millisecond})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(c.Close)
	return c
}
