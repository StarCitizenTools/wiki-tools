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
	"strconv"
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
	// Interval is the minimum spacing between requests. Zero means 250ms.
	Interval time.Duration
}

// New builds a Client. No network traffic happens until a request is made.
func New(cfg Config) (*Client, error) {
	if cfg.Endpoint == "" {
		return nil, fmt.Errorf("mediawiki: endpoint is required")
	}
	if cfg.UserAgent == "" {
		return nil, fmt.Errorf("mediawiki: user agent is required")
	}
	if cfg.Interval <= 0 {
		cfg.Interval = 250 * time.Millisecond
	}
	return &Client{
		endpoint: cfg.Endpoint,
		http: httpx.New(httpx.Options{
			Interval:  cfg.Interval,
			UserAgent: cfg.UserAgent,
			MaxTries:  4,
			Timeout:   120 * time.Second,
		}),
	}, nil
}

// Close releases underlying resources.
func (c *Client) Close() { c.http.Close() }

// APIError is an error the action API reports in the response body. These
// arrive with HTTP 200, so they are invisible to the transport and have to be
// read out of the payload.
type APIError struct {
	Code string `json:"code"`
	Info string `json:"info"`
}

func (e *APIError) Error() string {
	return fmt.Sprintf("mediawiki api error %s: %s", e.Code, e.Info)
}

// Response is embedded by every decoded action-API response. Embedding it lets
// Request surface API errors from the same pass that decodes the payload,
// rather than unmarshalling a possibly multi-megabyte body twice.
type Response struct {
	Error *APIError `json:"error"`
}

func (r *Response) apiError() *APIError { return r.Error }

// envelope is satisfied by anything embedding Response.
type envelope interface{ apiError() *APIError }

// Request issues one action-API call and decodes it into out, which must embed
// Response. The query is POSTed so that long parameters (title batches, ask
// queries) cannot run into a URL-length limit.
//
// Every read this package performs goes through here, so that tools do not each
// grow their own subtly different request path.
func (c *Client) Request(ctx context.Context, form url.Values, out envelope) error {
	body, err := c.http.Do(ctx, http.MethodPost, c.endpoint, form.Encode())
	if err != nil {
		return err
	}
	if err := json.Unmarshal(body, out); err != nil {
		return fmt.Errorf("mediawiki: decoding response: %w", err)
	}
	if apiErr := out.apiError(); apiErr != nil {
		return apiErr
	}
	return nil
}

// NamespaceCase reports how a namespace normalises the first letter of its
// titles: "first-letter" or "case-sensitive".
func (c *Client) NamespaceCase(ctx context.Context, id int) (string, error) {
	var res struct {
		Response
		Query struct {
			Namespaces map[string]struct {
				Case string `json:"case"`
			} `json:"namespaces"`
		} `json:"query"`
	}
	form := url.Values{
		"action":        {"query"},
		"meta":          {"siteinfo"},
		"siprop":        {"namespaces"},
		"format":        {"json"},
		"formatversion": {"2"},
	}
	if err := c.Request(ctx, form, &res); err != nil {
		return "", err
	}
	ns, ok := res.Query.Namespaces[strconv.Itoa(id)]
	if !ok {
		return "", fmt.Errorf("mediawiki: no namespace %d on this wiki", id)
	}
	return ns.Case, nil
}

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

	var res struct {
		Response
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
	if err := c.Request(ctx, form, &res); err != nil {
		return nil, err
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
