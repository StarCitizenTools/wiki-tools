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

// Layout is how an RSI comm-link page carries its body.
type Layout int

const (
	LayoutUnknown  Layout = iota
	LayoutClassic         // server-rendered body, to October 2021
	LayoutFragment        // Vue shell; the body is a separate HTML fragment
)

// s3URL names the fragment in every fragment shell, across all three of its URL
// forms (alexandria/html/fromHeap/..., fromHeap/<hex>/..., <hex>/<hex>/...-en).
var s3URL = regexp.MustCompile(`const s3Url\s*=\s*'([^']+)'`)

// Detect tells the layouts apart. Fragment shells embed text/x-jsmart-tmpl
// templates with classic class names, so the classic test looks inside
// div#contentbody rather than grepping the page.
func Detect(shell []byte) (Layout, string, error) {
	if m := s3URL.FindSubmatch(shell); m != nil {
		return LayoutFragment, string(m[1]), nil
	}
	doc, err := html.Parse(bytes.NewReader(shell))
	if err != nil {
		return LayoutUnknown, "", err
	}
	if body := findByID(doc, "contentbody"); body != nil && findFirst(body, func(n *html.Node) bool {
		return hasClass(n, "content-block1") && hasClass(n, "rsi-markup")
	}) != nil {
		return LayoutClassic, "", nil
	}
	return LayoutUnknown, "", errors.New("the page has neither an s3Url fragment nor a classic body")
}

// FetchBlocks downloads a comm-link's page, and its fragment for the newer
// layout, and converts the body into blocks.
func FetchBlocks(ctx context.Context, web *httpx.Client, c Candidate) ([]Block, error) {
	shell, err := web.Do(ctx, http.MethodGet, c.RSIURL, "")
	if err != nil {
		return nil, fmt.Errorf("fetching %s: %w", c.RSIURL, err)
	}
	layout, fragURL, err := Detect(shell)
	if err != nil {
		return nil, err
	}
	if layout == LayoutClassic {
		return ParseClassic(shell, c.Title)
	}
	frag, err := web.Do(ctx, http.MethodGet, fragURL, "")
	if err != nil {
		return nil, fmt.Errorf("fetching fragment %s: %w", fragURL, err)
	}
	return ParseFragment(frag)
}

// ParseFragment is implemented in Task 9.
func ParseFragment(frag []byte) ([]Block, error) { return nil, errors.New("not implemented") }
