package commlink

import (
	"regexp"
	"strings"
	"unicode"
	"unicode/utf8"

	"golang.org/x/net/html"
)

// flow turns a run of mixed inline and block content into blocks. Inline
// content collects into the open paragraph; a block-level element closes it.
// Both layouts use it; heading decides what a heading element becomes.
type flow struct {
	blocks  []Block
	buf     strings.Builder
	brs     int // consecutive <br> since the last visible text
	heading func(f *flow, n *html.Node)
}

var inlineTags = map[string]bool{
	"strong": true, "b": true, "em": true, "i": true, "u": true, "span": true, "a": true,
	"sup": true, "sub": true, "small": true, "font": true, "code": true, "abbr": true,
	"cite": true, "mark": true, "s": true, "strike": true, "label": true,
}

var blockTags = map[string]bool{
	"img": true, "iframe": true, "video": true, "p": true, "div": true, "ul": true, "ol": true,
	"blockquote": true, "table": true, "h1": true, "h2": true, "h3": true, "h4": true, "h5": true, "h6": true,
}

var dropTags = map[string]bool{"script": true, "style": true, "template": true, "noscript": true}

func (f *flow) run(n *html.Node) {
	for c := n.FirstChild; c != nil; c = c.NextSibling {
		f.node(c)
	}
}

func (f *flow) emit(b Block) {
	f.flush()
	f.blocks = append(f.blocks, b)
}

func (f *flow) flush() {
	text := trimBreaks(multiSpace.ReplaceAllString(f.buf.String(), " "))
	f.buf.Reset()
	f.brs = 0
	if text != "" {
		f.blocks = append(f.blocks, Block{Kind: Paragraph, Text: text})
	}
}

// trimBreaks strips spaces and <br /> from both ends of a paragraph.
func trimBreaks(s string) string {
	for {
		t := strings.TrimSpace(s)
		t = strings.TrimSpace(strings.TrimPrefix(t, "<br />"))
		t = strings.TrimSpace(strings.TrimSuffix(t, "<br />"))
		if t == s {
			return t
		}
		s = t
	}
}

func (f *flow) node(n *html.Node) {
	switch n.Type {
	case html.TextNode:
		if strings.TrimSpace(n.Data) != "" {
			f.brs = 0
		}
		appendMarkup(&f.buf, escapeText(n.Data))
		return
	case html.ElementNode:
	default:
		return
	}
	switch {
	case dropTags[n.Data]:
	case n.Data == "br":
		f.brs++
		if f.brs >= 2 {
			f.flush()
		} else {
			f.buf.WriteString("<br />")
		}
	case isHeading(n):
		f.flush()
		f.heading(f, n)
	case n.Data == "a" && hasClass(n, "js-video") && attr(n, "data-distant-source") == "vimeo":
		f.emit(Block{Kind: Video, VideoKind: "vimeo", VideoID: attr(n, "data-distant-id")})
	case n.Data == "a" && (attr(n, "data-source_url") != "" || hasClass(n, "js-open-in-slideshow")):
		f.image(n)
	case n.Data == "img":
		if src := sourceURL(attr(n, "src")); src != "" {
			f.emit(Block{Kind: Image, Src: src})
		}
	case n.Data == "iframe":
		id := youtubeID(attr(n, "data-src"))
		if id == "" {
			id = youtubeID(attr(n, "src"))
		}
		if id != "" {
			f.emit(Block{Kind: Video, VideoKind: "youtube", VideoID: id})
		}
	case n.Data == "video":
		src := attr(n, "src")
		if s := findFirst(n, tagIs("source")); src == "" && s != nil {
			src = attr(s, "src")
		}
		if src != "" {
			f.emit(Block{Kind: Video, VideoKind: "file", Src: absURL(src)})
		}
	case n.Data == "ul" || n.Data == "ol":
		f.list(n)
	case n.Data == "blockquote":
		if t := Inline(n); t != "" {
			f.emit(Block{Kind: Quote, Text: t})
		}
	case n.Data == "hr":
		f.flush()
	case inlineTags[n.Data] && !hasBlockContent(n):
		var b strings.Builder
		inlineNode(&b, n)
		if PlainText(n) != "" {
			f.brs = 0
		}
		appendMarkup(&f.buf, b.String())
	default:
		// p, div, and anything unrecognised (dic, no-marin): a block container.
		f.flush()
		f.run(n)
		f.flush()
	}
}

func hasBlockContent(n *html.Node) bool {
	return findFirst(n, func(c *html.Node) bool {
		return c.Type == html.ElementNode && (blockTags[c.Data] || attr(c, "data-source_url") != "")
	}) != nil
}

func (f *flow) image(n *html.Node) {
	src := attr(n, "data-source_url")
	if src == "" {
		if img := findFirst(n, tagIs("img")); img != nil {
			src = attr(img, "src")
		}
	}
	src = sourceURL(src)
	if src == "" {
		return
	}
	caption := ""
	if c := findFirst(n, classIs("caption")); c != nil {
		caption = escapeText(PlainText(c))
	}
	f.emit(Block{Kind: Image, Src: src, Caption: caption})
}

func (f *flow) list(n *html.Node) {
	var items []string
	for c := n.FirstChild; c != nil; c = c.NextSibling {
		if c.Type == html.ElementNode && c.Data == "li" {
			if t := Inline(c); t != "" {
				items = append(items, t)
			}
		}
	}
	if len(items) > 0 {
		f.emit(Block{Kind: List, Items: items, Ordered: n.Data == "ol"})
	}
}

var mediaVariant = regexp.MustCompile(`^(https?://[^/]+)/media/([a-z0-9]+)/([a-z_]+)/(.+)$`)

// sourceURL is the absolute URL of an image's original. An RSI /media/ path
// names a size variant (post, tavern_upload_large, post_section_header, ...);
// "source" is the original.
func sourceURL(src string) string {
	src = strings.TrimSpace(src)
	if src == "" || strings.HasPrefix(src, "data:") {
		return ""
	}
	abs := absURL(src)
	if m := mediaVariant.FindStringSubmatch(abs); m != nil && m[3] != "source" {
		return m[1] + "/media/" + m[2] + "/source/" + m[4]
	}
	return abs
}

var ytEmbed = regexp.MustCompile(`youtube(?:-nocookie)?\.com/embed/([A-Za-z0-9_-]{6,})`)

func youtubeID(src string) string {
	if m := ytEmbed.FindStringSubmatch(src); m != nil {
		return m[1]
	}
	return ""
}

// pseudoHeading is a line that is only one short bold run. A link or tag
// inside it rules it out: a heading never carries one.
var pseudoHeading = regexp.MustCompile(`^'''([^'<\[\n]{1,60})'''$`)

// pseudoHeadingText is the text of a line that reads as a subsection title:
// one short bold run that opens with a letter or digit, ends without terminal
// punctuation, and is not a greeting or sign-off.
func pseudoHeadingText(line string) (string, bool) {
	m := pseudoHeading.FindStringSubmatch(strings.TrimSpace(line))
	if m == nil {
		return "", false
	}
	t := m[1]
	first, _ := utf8.DecodeRuneInString(t)
	if (!unicode.IsLetter(first) && !unicode.IsDigit(first)) || strings.ContainsAny(t[len(t)-1:], ".,!?:;") ||
		greeting.MatchString(t) || signOff.MatchString(t) {
		return "", false
	}
	return t, true
}

// textFollows reports whether the first block from blocks[i] on that is not an
// image or video is text.
func textFollows(blocks []Block, i int) bool {
	for ; i < len(blocks); i++ {
		switch blocks[i].Kind {
		case Image, Video:
			continue
		case Paragraph, List, Quote:
			return true
		}
		return false
	}
	return false
}

// splitPseudoHeadings turns a bold subsection title into a heading one level
// below the latest real heading, the level its siblings get. The title is a
// paragraph of its own (<div><strong>AI (Ships)</strong></div>) or a line of
// one between breaks (<br/><strong>600i</strong><br/>), and text must follow
// it, past any images: a bold line before the next heading is a signature
// (UEE Naval High Command), not a title.
func splitPseudoHeadings(blocks []Block) []Block {
	var out []Block
	level := 2
	for i, b := range blocks {
		if b.Kind == Heading {
			level = b.Level
		}
		if b.Kind != Paragraph {
			out = append(out, b)
			continue
		}
		parts := strings.Split(b.Text, "<br />")
		var cur []string
		flushCur := func() {
			if t := trimBreaks(strings.Join(cur, "<br />")); t != "" {
				out = append(out, Block{Kind: Paragraph, Text: t})
			}
			cur = nil
		}
		for j, part := range parts {
			if t, ok := pseudoHeadingText(part); ok &&
				(strings.TrimSpace(strings.Join(parts[j+1:], "")) != "" || textFollows(blocks, i+1)) {
				flushCur()
				out = append(out, Block{Kind: Heading, Level: level + 1, Text: t})
				continue
			}
			cur = append(cur, part)
		}
		flushCur()
	}
	return out
}
