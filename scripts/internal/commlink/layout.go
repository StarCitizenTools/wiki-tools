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
// server-rendered body. The layout follows the page, not its date: the reports
// moved to fragments in October 2021, the stories kept the classic body into
// 2024. Fragment shells embed text/x-jsmart-tmpl templates with classic class
// names, so the classic test looks inside div#contentbody rather than grepping
// the page. A classic body is prose (content-block1), a header block alone (a
// gallery post's content-block2), or segments standing in div#post (see
// ParseClassic). A post RSI keeps for Subscribers answers with its restricted
// area page, whose message the error carries.
func Detect(shell []byte) (fragURL string, err error) {
	if m := s3URL.FindSubmatch(shell); m != nil {
		return string(m[1]), nil
	}
	doc, err := html.Parse(bytes.NewReader(shell))
	if err != nil {
		return "", err
	}
	body := findByID(doc, "contentbody")
	if body != nil && findFirst(body, classicBody) != nil {
		return "", nil
	}
	if body != nil {
		if msg := findFirst(body, classIs("c-error-messages")); msg != nil && findFirst(body, classIs("c-error-tech--403")) != nil {
			return "", errors.New("RSI shows its restricted area page instead of the post: " + PlainText(msg))
		}
	}
	return "", errors.New("the page has neither an s3Url fragment nor a classic body")
}

// classicBody matches a block of a classic body: prose, a header block inside
// div#post, or a segment standing in div#post.
func classicBody(n *html.Node) bool {
	switch {
	case hasClass(n, "content-block1") && hasClass(n, "rsi-markup"):
		return true
	case hasClass(n, "content-block2"):
		return hasAncestorID(n, "post")
	}
	return isPostSegment(n)
}

// isPostSegment reports whether n is a div.segment that is a child of div#post.
func isPostSegment(n *html.Node) bool {
	return hasClass(n, "segment") && n.Parent != nil && attr(n.Parent, "id") == "post"
}

// Body is a converted report body.
type Body struct {
	Blocks []Block
	// Title is a classic page's own title block (see ParseClassic); a
	// fragment gives none.
	Title string
	// Labels are a fragment's furniture (see ParseFragment); a classic page
	// gives none.
	Labels []string
	// Date is the YYYY-MM-DD day a fragment's byline shows, or "". A classic
	// page's header Date field is not read: it can show the day the page is
	// fetched.
	Date string
}

// FetchBlocks downloads a comm-link's page, and its fragment for the newer
// layout, and converts the body.
func FetchBlocks(ctx context.Context, web *httpx.Client, cfg *Config, c Candidate) (Body, error) {
	shell, err := web.Do(ctx, http.MethodGet, c.RSIURL, "")
	if err != nil {
		return Body{}, fmt.Errorf("fetching %s: %w", c.RSIURL, err)
	}
	fragURL, err := Detect(shell)
	if err != nil {
		return Body{}, err
	}
	if fragURL == "" {
		blocks, title, err := ParseClassic(shell, c.Title, cfg)
		return Body{Blocks: blocks, Title: title}, err
	}
	frag, err := web.Do(ctx, http.MethodGet, fragURL, "")
	if err != nil {
		return Body{}, fmt.Errorf("fetching fragment %s: %w", fragURL, err)
	}
	return ParseFragment(frag, cfg)
}
