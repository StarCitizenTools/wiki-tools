// Package mediawiki is a minimal, read-only action-API client.
//
// It reads pages so tools can compare generated output against what is live.
// It deliberately cannot write: deployment goes through the MediaWiki MCP
// server, where an agent can resolve conflicts and make editorial judgements
// that a batch script should not be making on its own. Keeping a second write
// path here would only give the two ways to drift apart.
package mediawiki

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"time"

	"github.com/StarCitizenTools/wiki-tools/scripts/internal/httpx"
)

// Client reads pages from one wiki. No credentials are involved: everything it
// does is available anonymously.
type Client struct {
	endpoint string
	http     *httpx.Client
}

// Config configures a Client.
type Config struct {
	// Endpoint is the full action API URL, e.g. https://starcitizen.tools/api.php
	Endpoint string
	// UserAgent identifies the tool. The wiki's WAF rejects some defaults, so
	// always send something descriptive.
	UserAgent string
}

// New builds a Client. No network traffic happens until a page is fetched.
func New(cfg Config) (*Client, error) {
	if cfg.Endpoint == "" {
		return nil, fmt.Errorf("mediawiki: endpoint is required")
	}
	if cfg.UserAgent == "" {
		return nil, fmt.Errorf("mediawiki: user agent is required")
	}
	return &Client{
		endpoint: cfg.Endpoint,
		http: httpx.New(httpx.Options{
			Interval:  250 * time.Millisecond,
			UserAgent: cfg.UserAgent,
			MaxTries:  4,
			Timeout:   120 * time.Second,
		}),
	}, nil
}

// Close releases underlying resources.
func (c *Client) Close() { c.http.Close() }

// Page is the current state of a wiki page.
type Page struct {
	Title      string
	Exists     bool
	RevisionID int64
	Content    string
}

// Fetch reads a page's newest revision, including its content.
func (c *Client) Fetch(ctx context.Context, title string) (*Page, error) {
	form := url.Values{
		"action":        {"query"},
		"prop":          {"revisions"},
		"titles":        {title},
		"rvprop":        {"ids|content"},
		"rvslots":       {"main"},
		"rvlimit":       {"1"},
		"format":        {"json"},
		"formatversion": {"2"},
	}

	// A page can be large (the starmap is about a megabyte), so POST the query
	// rather than risk a URL-length limit on a GET.
	body, err := c.http.Do(ctx, http.MethodPost, c.endpoint, form.Encode())
	if err != nil {
		return nil, err
	}

	var res struct {
		Error *struct {
			Code string `json:"code"`
			Info string `json:"info"`
		} `json:"error"`
		Query struct {
			Pages []struct {
				Title     string `json:"title"`
				Missing   bool   `json:"missing"`
				Revisions []struct {
					RevID int64 `json:"revid"`
					Slots struct {
						Main struct {
							Content string `json:"content"`
						} `json:"main"`
					} `json:"slots"`
				} `json:"revisions"`
			} `json:"pages"`
		} `json:"query"`
	}
	if err := json.Unmarshal(body, &res); err != nil {
		return nil, fmt.Errorf("mediawiki: decoding response: %w", err)
	}
	// API-level errors arrive with HTTP 200.
	if res.Error != nil {
		return nil, fmt.Errorf("mediawiki api error %s: %s", res.Error.Code, res.Error.Info)
	}
	if len(res.Query.Pages) == 0 {
		return nil, fmt.Errorf("mediawiki: no page returned for %q", title)
	}

	p := res.Query.Pages[0]
	page := &Page{Title: p.Title, Exists: !p.Missing}
	if len(p.Revisions) > 0 {
		page.RevisionID = p.Revisions[0].RevID
		page.Content = p.Revisions[0].Slots.Main.Content
	}
	return page, nil
}
