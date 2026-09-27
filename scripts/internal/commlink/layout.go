package commlink

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"net/http"
	"regexp"

	"github.com/StarCitizenTools/wiki-tools/scripts/internal/httpx"
	"golang.org/x/net/html"
)

// s3URL names the fragment in every fragment shell, across all three of its URL
// forms (alexandria/html/fromHeap/..., fromHeap/<hex>/..., <hex>/<hex>/...-en).
var s3URL = regexp.MustCompile(`const s3Url\s*=\s*'([^']+)'`)

// Detect tells RSI's two layouts apart: it returns the fragment URL of a Vue
// shell, whose body is a separate HTML fragment, or "" for the classic
// server-rendered body (to October 2021). Fragment shells embed
// text/x-jsmart-tmpl templates with classic class names, so the classic test
// looks inside div#contentbody rather than grepping the page.
func Detect(shell []byte) (fragURL string, err error) {
	if m := s3URL.FindSubmatch(shell); m != nil {
		return string(m[1]), nil
	}
	doc, err := html.Parse(bytes.NewReader(shell))
	if err != nil {
		return "", err
	}
	if body := findByID(doc, "contentbody"); body != nil && findFirst(body, func(n *html.Node) bool {
		return hasClass(n, "content-block1") && hasClass(n, "rsi-markup")
	}) != nil {
		return "", nil
	}
	return "", errors.New("the page has neither an s3Url fragment nor a classic body")
}

// FetchBlocks downloads a comm-link's page, and its fragment for the newer
// layout, and converts the body into blocks.
func FetchBlocks(ctx context.Context, web *httpx.Client, cfg *Config, c Candidate) ([]Block, error) {
	shell, err := web.Do(ctx, http.MethodGet, c.RSIURL, "")
	if err != nil {
		return nil, fmt.Errorf("fetching %s: %w", c.RSIURL, err)
	}
	fragURL, err := Detect(shell)
	if err != nil {
		return nil, err
	}
	if fragURL == "" {
		return ParseClassic(shell, c.Title, cfg)
	}
	frag, err := web.Do(ctx, http.MethodGet, fragURL, "")
	if err != nil {
		return nil, fmt.Errorf("fetching fragment %s: %w", fragURL, err)
	}
	return ParseFragment(frag, cfg)
}
