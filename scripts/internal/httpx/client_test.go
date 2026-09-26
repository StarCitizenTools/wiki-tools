package httpx

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestDoContentType(t *testing.T) {
	var gotType, gotBody string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotType = r.Header.Get("Content-Type")
		b, _ := io.ReadAll(r.Body)
		gotBody = string(b)
		io.WriteString(w, "ok")
	}))
	defer srv.Close()
	c := New(Options{Interval: time.Millisecond, UserAgent: "test"})
	defer c.Close()

	body, err := c.DoContentType(context.Background(), http.MethodPost, srv.URL, `{"a":1}`, "application/json")
	if err != nil || string(body) != "ok" {
		t.Fatalf("DoContentType = %q, %v", body, err)
	}
	if gotType != "application/json" || gotBody != `{"a":1}` {
		t.Errorf("server saw type %q body %q", gotType, gotBody)
	}

	if _, err := c.Do(context.Background(), http.MethodPost, srv.URL, "a=1"); err != nil {
		t.Fatal(err)
	}
	if gotType != "application/x-www-form-urlencoded" {
		t.Errorf("Do sent type %q, want form encoding", gotType)
	}
}
