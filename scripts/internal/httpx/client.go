// Package httpx provides a polite HTTP client: every request passes through a
// shared rate limiter, and transient upstream failures are retried with backoff
// up to a bounded number of attempts.
//
// The bound matters. The TypeScript generator this replaces retried 502/504 by
// recursing into itself with no attempt ceiling, so a sustained upstream outage
// became an unbounded loop rather than an error.
package httpx

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

// Client is a rate-limited, retrying HTTP client. It is safe for concurrent use:
// the limiter channel serialises the pacing of every in-flight goroutine.
type Client struct {
	http      *http.Client
	userAgent string
	limiter   <-chan time.Time
	ticker    *time.Ticker
	maxTries  int
}

// Options configures a Client.
type Options struct {
	// Interval is the minimum spacing between the start of any two requests.
	Interval time.Duration
	// UserAgent identifies us to the upstream host. Include contact details.
	UserAgent string
	// MaxTries bounds attempts per request, including the first. Minimum 1.
	MaxTries int
	// Timeout is the per-request timeout.
	Timeout time.Duration
}

// New builds a Client. Call Close when finished to release the ticker.
func New(opts Options) *Client {
	if opts.Interval <= 0 {
		opts.Interval = time.Second
	}
	if opts.MaxTries < 1 {
		opts.MaxTries = 4
	}
	if opts.Timeout <= 0 {
		opts.Timeout = 60 * time.Second
	}
	t := time.NewTicker(opts.Interval)
	return &Client{
		http:      &http.Client{Timeout: opts.Timeout},
		userAgent: opts.UserAgent,
		limiter:   t.C,
		ticker:    t,
		maxTries:  opts.MaxTries,
	}
}

// Close releases the rate limiter.
func (c *Client) Close() { c.ticker.Stop() }

// retryable reports whether a status code is worth another attempt. These are
// the codes that indicate a transient upstream or edge problem rather than a
// request we got wrong.
func retryable(status int) bool {
	switch status {
	case http.StatusTooManyRequests,
		http.StatusInternalServerError,
		http.StatusBadGateway,
		http.StatusServiceUnavailable,
		http.StatusGatewayTimeout:
		return true
	}
	return false
}

// Do issues a request, waiting for a rate-limiter tick before each attempt and
// backing off between retries. The response body is read fully and returned, so
// callers do not need to close anything.
func (c *Client) Do(ctx context.Context, method, url string, body string) ([]byte, error) {
	var lastErr error

	for attempt := 1; attempt <= c.maxTries; attempt++ {
		// Pace every attempt, including retries.
		select {
		case <-c.limiter:
		case <-ctx.Done():
			return nil, ctx.Err()
		}

		var reader io.Reader
		if body != "" {
			reader = strings.NewReader(body)
		}
		req, err := http.NewRequestWithContext(ctx, method, url, reader)
		if err != nil {
			return nil, err // Malformed request; retrying cannot help.
		}
		req.Header.Set("User-Agent", c.userAgent)
		if body != "" {
			req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
		}

		resp, err := c.http.Do(req)
		if err != nil {
			lastErr = err
		} else {
			data, readErr := io.ReadAll(resp.Body)
			resp.Body.Close()
			switch {
			case readErr != nil:
				lastErr = readErr
			case resp.StatusCode == http.StatusOK:
				return data, nil
			case retryable(resp.StatusCode):
				lastErr = fmt.Errorf("http %d %s", resp.StatusCode, resp.Status)
			default:
				// 4xx and anything else: the request itself is wrong, so stop.
				return nil, fmt.Errorf("http %d %s: %s", resp.StatusCode, resp.Status, snippet(data))
			}
		}

		if attempt < c.maxTries {
			backoff := time.Duration(1<<uint(attempt-1)) * time.Second
			select {
			case <-time.After(backoff):
			case <-ctx.Done():
				return nil, ctx.Err()
			}
		}
	}

	return nil, fmt.Errorf("giving up after %d attempts: %w", c.maxTries, lastErr)
}

// snippet trims a response body for inclusion in an error message.
func snippet(b []byte) string {
	const max = 200
	s := strings.TrimSpace(string(b))
	if len(s) > max {
		return s[:max] + "…"
	}
	return s
}
