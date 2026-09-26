package commlink

import (
	"fmt"
	"net/url"
	"regexp"
	"strings"
	"unicode"

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

// normalizeInvisibles maps every Unicode space separator (general category
// Zs: NBSP, narrow no-break space, ideographic space, ...) other than U+0020
// to a plain space, and drops soft hyphen (U+00AD) and the zero-width marks
// (U+200B, U+2060, U+FEFF) RSI's HTML carries. It runs before wsRun, so a
// mapped space landing next to a plain one is left as an ordinary run for
// wsRun to collapse; wsRun itself is `\s+`, which Go's regexp resolves as
// ASCII-only and so would not touch an unmapped Zs character.
func normalizeInvisibles(s string) string {
	return strings.Map(func(r rune) rune {
		switch r {
		case 0x00AD, 0x200B, 0x2060, 0xFEFF: // soft hyphen, zero width space, word joiner, BOM
			return -1
		case ' ':
			return r
		}
		if unicode.Is(unicode.Zs, r) {
			return ' '
		}
		return r
	}, s)
}

// PlainText is an element's text with markup dropped, invisible characters
// normalized (see normalizeInvisibles), and whitespace collapsed. A Heading
// block stores this result directly, ahead of the escapeText call that
// renders it, so this is where that text is normalized.
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
	return strings.TrimSpace(wsRun.ReplaceAllString(normalizeInvisibles(b.String()), " "))
}

// urlUnsafeASCII is the ASCII set that would break wikitext link markup: quote
// marks, angle brackets, and the wiki-markup delimiters.
const urlUnsafeASCII = `"'<>[]{|}`

// escapeURLChars percent-encodes the characters that would end or break a URL
// inside a wikitext external link, or open markup there: every Unicode space
// separator (general category Zs, which includes U+0020; MediaWiki's
// external-link syntax ends the URL at any of them, not only U+0020) and
// urlUnsafeASCII.
func escapeURLChars(s string) string {
	var b strings.Builder
	for _, r := range s {
		if !unicode.Is(unicode.Zs, r) && !strings.ContainsRune(urlUnsafeASCII, r) {
			b.WriteRune(r)
			continue
		}
		for _, by := range []byte(string(r)) {
			fmt.Fprintf(&b, "%%%02X", by)
		}
	}
	return b.String()
}

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
	return escapeURLChars(out)
}

var foldRe = regexp.MustCompile(`[^\pL\pN]+`)

// fold is a comparison key: lower case, punctuation and spacing collapsed.
func fold(s string) string {
	return strings.TrimSpace(foldRe.ReplaceAllString(strings.ToLower(s), " "))
}
