package commlink

import (
	"fmt"
	"regexp"
	"strings"

	"golang.org/x/net/html"
)

var wikiEscaper = strings.NewReplacer(
	"[", "&#91;", "]", "&#93;", "{", "&#123;", "}", "&#125;",
	"<", "&lt;", ">", "&gt;", "''", "&#39;&#39;", "~", "&#126;",
)

// escapeText makes RSI text inert as wikitext: brackets, braces, angle brackets,
// doubled apostrophes and tildes become entities (every tilde, not just runs of
// three, since Replacer's single left-to-right scan would otherwise leave a
// shorter tilde run behind a matched one, and MediaWiki reads any run of 3+ as
// a signature), NBSP becomes a space, and whitespace runs collapse.
func escapeText(s string) string {
	s = strings.ReplaceAll(s, " ", " ")
	s = wsRun.ReplaceAllString(s, " ")
	return wikiEscaper.Replace(s)
}

var multiSpace = regexp.MustCompile(` {2,}`)

// Inline renders an element's children as one line of wikitext. Bold, italic,
// underline, line breaks and links survive; any other element contributes only
// its text.
func Inline(n *html.Node) string {
	var b strings.Builder
	inlineChildren(&b, n)
	return strings.TrimSpace(multiSpace.ReplaceAllString(b.String(), " "))
}

func inlineChildren(b *strings.Builder, n *html.Node) {
	for c := n.FirstChild; c != nil; c = c.NextSibling {
		inlineNode(b, c)
	}
}

func inlineNode(b *strings.Builder, n *html.Node) {
	switch n.Type {
	case html.TextNode:
		b.WriteString(escapeText(n.Data))
	case html.ElementNode:
		switch n.Data {
		case "strong", "b":
			wrap(b, n, "'''", "'''")
		case "em", "i":
			wrap(b, n, "''", "''")
		case "u":
			wrap(b, n, "<u>", "</u>")
		case "span":
			if hasClass(n, "italic") {
				wrap(b, n, "''", "''")
			} else {
				inlineChildren(b, n)
			}
		case "a":
			link(b, n)
		case "br":
			b.WriteString("<br />")
		case "img", "iframe", "video", "script", "style", "template", "noscript":
		default:
			inlineChildren(b, n)
		}
	}
}

// wrap puts markers around an element's content, but keeps any leading or
// trailing space in that content outside the markers rather than inside them.
// gofmt's doc-comment formatter converts a doubled quote mark into a single
// curly one, so this comment must not spell the wikitext markers literally.
func wrap(b *strings.Builder, n *html.Node, open, close string) {
	var inner strings.Builder
	inlineChildren(&inner, n)
	s := inner.String()
	core := strings.TrimSpace(s)
	if core == "" {
		b.WriteString(s)
		return
	}
	i := strings.Index(s, core)
	b.WriteString(s[:i] + open + core + close + s[i+len(core):])
}

func link(b *strings.Builder, n *html.Node) {
	var inner strings.Builder
	inlineChildren(&inner, n)
	text := strings.TrimSpace(inner.String())
	if text == "" {
		return
	}
	href := strings.TrimSpace(attr(n, "href"))
	lower := strings.ToLower(href)
	if href == "" || strings.HasPrefix(href, "#") || strings.HasPrefix(lower, "javascript:") || strings.HasPrefix(lower, "mailto:") {
		b.WriteString(inner.String())
		return
	}
	fmt.Fprintf(b, "[%s %s]", absURL(href), text)
}

// lineSafe stops a paragraph's first character from being read as list,
// indent, definition or heading markup.
func lineSafe(s string) string {
	if s != "" && strings.ContainsRune("*#:;=", rune(s[0])) {
		return "<nowiki />" + s
	}
	return s
}
