package commlink

import (
	"errors"
	"regexp"
	"strconv"
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
	// headingTag reports whether an element is a heading, for heading to
	// convert; nil means h1 to h6.
	headingTag func(n *html.Node) bool
	rules      bool // an <hr> is a Rule block (sceneBreaks), not only a break
	tables     bool // a <table> is a Table block (tables), not a run of paragraphs
	err        error
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
	case f.isHeading(n):
		f.flush()
		f.heading(f, n)
	case n.Data == "a" && hasClass(n, "js-video") && attr(n, "data-distant-source") == "vimeo":
		f.emit(Block{Kind: Video, VideoKind: "vimeo", VideoID: attr(n, "data-distant-id")})
	case n.Data == "a" && hasClass(n, "js-video") && attr(n, "data-distant-source") == "youtube":
		f.emit(Block{Kind: Video, VideoKind: "youtube", VideoID: attr(n, "data-distant-id")})
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
		} else if doc := scribdDocument(attr(n, "src")); doc != "" {
			f.emit(Block{Kind: Paragraph, Text: "[" + doc + " Read the document on Scribd]"})
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
	case n.Data == "table" && f.tables:
		f.table(n)
	case n.Data == "div" && f.tables && divTable.MatchString(attr(n, "id")):
		f.divTable(n)
	case n.Data == "blockquote":
		if t := Inline(n); t != "" {
			f.emit(Block{Kind: Quote, Text: t})
		}
	case n.Data == "hr" && f.rules:
		f.emit(Block{Kind: Rule})
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

func (f *flow) isHeading(n *html.Node) bool {
	if f.headingTag != nil {
		return f.headingTag(n)
	}
	return isHeading(n)
}

// table converts a table into a Table block: its rows in order, a th cell
// marked as a header and a spanning cell keeping its span. A row with no cells
// is left out. A table inside a table, or an image in a cell, is more than a
// wikitable of text cells holds, so it sends the report to review.
func (f *flow) table(n *html.Node) {
	if findFirst(n, tagIs("table")) != nil {
		f.fail(errors.New("a table holds a nested table"))
		return
	}
	var rows [][]Cell
	for _, tr := range findAll(n, tagIs("tr")) {
		var row []Cell
		for c := tr.FirstChild; c != nil; c = c.NextSibling {
			if c.Type != html.ElementNode || (c.Data != "td" && c.Data != "th") {
				continue
			}
			if findFirst(c, func(m *html.Node) bool { return tagIs("img")(m) || attr(m, "data-source_url") != "" }) != nil {
				f.fail(errors.New("a table cell holds an image"))
				return
			}
			row = append(row, Cell{Text: trimBreaks(Inline(c)), Header: c.Data == "th",
				Colspan: span(attr(c, "colspan")), Rowspan: span(attr(c, "rowspan"))})
		}
		if len(row) > 0 {
			rows = append(rows, row)
		}
	}
	if len(rows) > 0 {
		f.emit(Block{Kind: Table, Rows: rows})
	}
}

// span is a colspan or rowspan attribute's value, 0 for none or one that does
// not parse.
func span(v string) int {
	n, err := strconv.Atoi(strings.TrimSpace(v))
	if err != nil || n < 2 {
		return 0
	}
	return n
}

// fail keeps the first error the flow meets.
func (f *flow) fail(err error) {
	if f.err == nil {
		f.err = err
	}
}

// divTable is the id of a table The Shipyard draws with divs
// (#jaredtable-table2): a header block, a row of header cells, then rows each
// opened by a left cell, and a footer.
var (
	divTable     = regexp.MustCompile(`^jaredtable-table\d*$`)
	divTablePart = regexp.MustCompile(`^jaredtable-([a-z]+)\d*$`)
)

// divTable converts a div-drawn table: its header block and footer as
// paragraphs around a Table block. An empty header cell widens the header
// cell before it, as the drawn table does.
func (f *flow) divTable(n *html.Node) {
	byID := func(part string) *html.Node {
		return findFirst(n, func(m *html.Node) bool {
			p := divTablePart.FindStringSubmatch(attr(m, "id"))
			return m.Type == html.ElementNode && p != nil && p[1] == part
		})
	}
	cellsOf := func(parent *html.Node) []*html.Node {
		var out []*html.Node
		for c := parent.FirstChild; c != nil; c = c.NextSibling {
			if c.Type == html.ElementNode && c.Data == "div" {
				out = append(out, c)
			}
		}
		return out
	}
	if h := byID("header"); h != nil {
		f.flush()
		f.run(h)
		f.flush()
	}
	var rows [][]Cell
	if top := byID("top"); top != nil {
		var row []Cell
		for _, c := range cellsOf(top) {
			text := trimBreaks(Inline(c))
			if text == "" && len(row) > 0 {
				row[len(row)-1].Colspan = max(row[len(row)-1].Colspan, 1) + 1
				continue
			}
			row = append(row, Cell{Text: text, Header: true})
		}
		rows = append(rows, row)
	}
	if mid := byID("middle"); mid != nil {
		var row []Cell
		for _, c := range cellsOf(mid) {
			if strings.HasPrefix(attr(c, "class"), "jaredtable-left") && len(row) > 0 {
				rows = append(rows, row)
				row = nil
			}
			row = append(row, Cell{Text: trimBreaks(Inline(c))})
		}
		if len(row) > 0 {
			rows = append(rows, row)
		}
	}
	if len(rows) > 0 {
		f.emit(Block{Kind: Table, Rows: rows})
	}
	if foot := byID("footer"); foot != nil {
		f.flush()
		f.run(foot)
		f.flush()
	}
}

var scribdEmbed = regexp.MustCompile(`^(?:https?:)?//(?:www\.)?scribd\.com/embeds/(\d+)/`)

// scribdDocument is the Scribd page of an embedded Scribd document, or "".
func scribdDocument(src string) string {
	if m := scribdEmbed.FindStringSubmatch(strings.TrimSpace(src)); m != nil {
		return "https://www.scribd.com/document/" + m[1]
	}
	return ""
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
			if t := trimBreaks(Inline(c)); t != "" {
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
// punctuation, holds no colon (an addressee line: TO: SQUADRON 42 RECRUITS),
// and is not a greeting or sign-off.
func pseudoHeadingText(line string, cfg *Config) (string, bool) {
	m := pseudoHeading.FindStringSubmatch(strings.TrimSpace(line))
	if m == nil {
		return "", false
	}
	t := m[1]
	first, _ := utf8.DecodeRuneInString(t)
	if (!unicode.IsLetter(first) && !unicode.IsDigit(first)) || strings.ContainsAny(t[len(t)-1:], ".,!?;") ||
		strings.Contains(t, ":") || cfg.MatchesGreeting(t) || cfg.MatchesSignOff(t) {
		return "", false
	}
	return t, true
}

// tidyRules drops a rule that opens or closes the body or follows another: a
// scene break separates two runs of content.
func tidyRules(blocks []Block) []Block {
	var out []Block
	for _, b := range blocks {
		if b.Kind == Rule && (len(out) == 0 || out[len(out)-1].Kind == Rule) {
			continue
		}
		out = append(out, b)
	}
	for len(out) > 0 && out[len(out)-1].Kind == Rule {
		out = out[:len(out)-1]
	}
	return out
}

// textFollows reports whether the first block from blocks[i] on that is not an
// image, gallery or video is text.
func textFollows(blocks []Block, i int) bool {
	for ; i < len(blocks); i++ {
		switch blocks[i].Kind {
		case Image, Gallery, Video:
			continue
		case Paragraph, List, Quote, Table:
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
// (UEE Naval High Command), not a title. An emphasis article is bold
// throughout, so none of its lines is a title, and a body with noSections has
// no titles at all.
func splitPseudoHeadings(blocks []Block, cfg *Config) []Block {
	if cfg.NoSections {
		return blocks
	}
	var out []Block
	level := 2
	for i, b := range blocks {
		if b.Kind == Heading {
			level = b.Level
		}
		if b.Kind != Paragraph || b.Emphasis {
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
			if t, ok := pseudoHeadingText(part, cfg); ok &&
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
