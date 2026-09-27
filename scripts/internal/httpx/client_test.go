package httpx

import (
	"context"
	"errors"
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

func TestDoStatusError(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, "gone", http.StatusNotFound)
	}))
	defer srv.Close()
	c := New(Options{Interval: time.Millisecond, UserAgent: "test", MaxTries: 1})
	defer c.Close()

	_, err := c.Do(context.Background(), http.MethodGet, srv.URL, "")
	var se *StatusError
	if !errors.As(err, &se) || se.Code != http.StatusNotFound {
		t.Fatalf("Do error = %v, want a *StatusError with code 404", err)
	}
	if want := "http 404 404 Not Found: gone"; err.Error() != want {
		t.Errorf("error text = %q, want %q", err.Error(), want)
	}
}
