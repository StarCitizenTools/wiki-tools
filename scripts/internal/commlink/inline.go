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
		appendMarkup(b, escapeText(n.Data))
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
		appendMarkup(b, s)
		return
	}
	i := strings.Index(s, core)
	for _, part := range []string{s[:i], open, core, close, s[i+len(core):]} {
		appendMarkup(b, part)
	}
}

// quoteSep is what must go between left and right so that the apostrophes
// where they meet are not read as one run of quote marks: a nowiki tag, unless
// one side has none there, or the two are an italic and a bold marker (two
// marks and three), a run of five that MediaWiki reads as both. Escaped text
// ends in at most one apostrophe (escapeText entity-encodes a doubled one), so
// a single apostrophe of text meeting a marker is separated too.
func quoteSep(left, right string) string {
	l := len(left) - len(strings.TrimRight(left, "'"))
	r := len(right) - len(strings.TrimLeft(right, "'"))
	if l == 0 || r == 0 || (l == 2 && r == 3) || (l == 3 && r == 2) {
		return ""
	}
	return "<nowiki />"
}

// appendMarkup appends s to b, separated by quoteSep.
func appendMarkup(b *strings.Builder, s string) {
	b.WriteString(quoteSep(b.String(), s))
	b.WriteString(s)
}

// joinMarkup concatenates parts, each separated from the next by quoteSep.
func joinMarkup(parts ...string) string {
	var b strings.Builder
	for _, p := range parts {
		appendMarkup(&b, p)
	}
	return b.String()
}

// link renders an anchor as an external link, keeping any space at the edges
// of its text outside the brackets, where it still separates words.
func link(b *strings.Builder, n *html.Node) {
	var inner strings.Builder
	inlineChildren(&inner, n)
	s := inner.String()
	text := strings.TrimSpace(s)
	if text == "" {
		return
	}
	href := strings.TrimSpace(attr(n, "href"))
	lower := strings.ToLower(href)
	if href == "" || strings.HasPrefix(href, "#") || strings.HasPrefix(lower, "javascript:") || strings.HasPrefix(lower, "mailto:") {
		appendMarkup(b, s)
		return
	}
	i := strings.Index(s, text)
	fmt.Fprintf(b, "%s[%s %s]%s", s[:i], absURL(href), text, s[i+len(text):])
}

// mergeSplitLinks moves each anchor's run of directly following anchors with
// the same href into it, so a link RSI split mid-word renders as one.
func mergeSplitLinks(n *html.Node) {
	for c := n.FirstChild; c != nil; c = c.NextSibling {
		if isPlainLink(c) {
			for next := c.NextSibling; isPlainLink(next) && attr(next, "href") == attr(c, "href"); next = c.NextSibling {
				for ch := next.FirstChild; ch != nil; ch = next.FirstChild {
					next.RemoveChild(ch)
					c.AppendChild(ch)
				}
				n.RemoveChild(next)
			}
		}
		mergeSplitLinks(c)
	}
}

func isPlainLink(n *html.Node) bool {
	return n != nil && n.Type == html.ElementNode && n.Data == "a" && attr(n, "href") != "" &&
		attr(n, "data-source_url") == "" && !hasClass(n, "js-video") && !hasClass(n, "js-open-in-slideshow")
}

// lineSafe stops a paragraph's first character from being read as list,
// indent, definition or heading markup.
func lineSafe(s string) string {
	if s != "" && strings.ContainsRune("*#:;=", rune(s[0])) {
		return "<nowiki />" + s
	}
	return s
}
