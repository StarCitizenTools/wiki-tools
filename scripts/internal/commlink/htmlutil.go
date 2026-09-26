package commlink

import (
	"net/url"
	"regexp"
	"strings"

	"golang.org/x/net/html"
)

// RSIRoot resolves RSI's relative links and image paths.
const RSIRoot = "https://robertsspaceindustries.com"

func attr(n *html.Node, key string) string {
	for _, a := range n.Attr {
		if a.Key == key {
			return a.Val
		}
	}
	return ""
}

func hasClass(n *html.Node, class string) bool {
	if n == nil || n.Type != html.ElementNode {
		return false
	}
	for _, c := range strings.Fields(attr(n, "class")) {
		if c == class {
			return true
		}
	}
	return false
}

func tagIs(tag string) func(*html.Node) bool {
	return func(n *html.Node) bool { return n.Type == html.ElementNode && n.Data == tag }
}

func classIs(class string) func(*html.Node) bool {
	return func(n *html.Node) bool { return hasClass(n, class) }
}

// findFirst returns the first descendant of n, in document order, that matches.
func findFirst(n *html.Node, match func(*html.Node) bool) *html.Node {
	for c := n.FirstChild; c != nil; c = c.NextSibling {
		if match(c) {
			return c
		}
		if f := findFirst(c, match); f != nil {
			return f
		}
	}
	return nil
}

// findAll returns every descendant of n that matches, in document order.
func findAll(n *html.Node, match func(*html.Node) bool) []*html.Node {
	var out []*html.Node
	var walk func(*html.Node)
	walk = func(n *html.Node) {
		for c := n.FirstChild; c != nil; c = c.NextSibling {
			if match(c) {
				out = append(out, c)
			}
			walk(c)
		}
	}
	walk(n)
	return out
}

func findByID(n *html.Node, id string) *html.Node {
	return findFirst(n, func(c *html.Node) bool { return c.Type == html.ElementNode && attr(c, "id") == id })
}

func hasAncestorClass(n *html.Node, class string) bool {
	for p := n.Parent; p != nil; p = p.Parent {
		if hasClass(p, class) {
			return true
		}
	}
	return false
}

func isHeading(n *html.Node) bool {
	return n.Type == html.ElementNode && len(n.Data) == 2 && n.Data[0] == 'h' && n.Data[1] >= '1' && n.Data[1] <= '6'
}

var wsRun = regexp.MustCompile(`\s+`)

// PlainText is an element's text with markup dropped and whitespace collapsed.
func PlainText(n *html.Node) string {
	var b strings.Builder
	var walk func(*html.Node)
	walk = func(n *html.Node) {
		if n.Type == html.TextNode {
			b.WriteString(n.Data)
		}
		for c := n.FirstChild; c != nil; c = c.NextSibling {
			walk(c)
		}
	}
	walk(n)
	return strings.TrimSpace(wsRun.ReplaceAllString(strings.ReplaceAll(b.String(), " ", " "), " "))
}

// urlUnsafe percent-encodes the characters that would end or break a URL
// inside a wikitext external link, or open markup there.
var urlUnsafe = strings.NewReplacer(
	" ", "%20", `"`, "%22", "'", "%27", "<", "%3C", ">", "%3E",
	"[", "%5B", "]", "%5D", "{", "%7B", "|", "%7C", "}", "%7D",
)

// absURL resolves an RSI href or src to an absolute URL safe inside a wikitext
// external link.
func absURL(ref string) string {
	ref = strings.TrimSpace(ref)
	if strings.HasPrefix(ref, "//") {
		ref = "https:" + ref
	}
	out := ref
	if u, err := url.Parse(ref); err == nil && !u.IsAbs() {
		base, _ := url.Parse(RSIRoot + "/")
		out = base.ResolveReference(u).String()
	}
	return urlUnsafe.Replace(out)
}

var foldRe = regexp.MustCompile(`[^\pL\pN]+`)

// fold is a comparison key: lower case, punctuation and spacing collapsed.
func fold(s string) string {
	return strings.TrimSpace(foldRe.ReplaceAllString(strings.ToLower(s), " "))
}
