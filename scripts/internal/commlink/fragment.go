package commlink

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"regexp"
	"strings"
	"time"

	"golang.org/x/net/html"
	"golang.org/x/net/html/atom"
)

// ParseFragment converts a fragment-layout body into blocks. The prose lives in
// component attributes: g-introduction's :info JSON, g-article's body HTML and
// a g-banner-advanced's paragraph; g-illustration and g-slideshow carry
// images, g-trailer a YouTube video and g-author the signature. The parser
// decodes each attribute once, and the body is then parsed as HTML, which also
// decodes the double-escaped entities of the earliest fragments. Q&As from
// 2021 on add question lists (g-faq), section headers and a disclaimer (see
// faq, component and slotted).
//
// The body's Labels are the page furniture the API's text carries as lines of
// their own or runs into a neighbouring line without a space: the
// introduction's overline, title and subtitle and a header's first title,
// which restate the report's title the infobox shows; a legacy banner's text
// slots; a disclaimer's title; and each question of a list as the API numbers
// it. Its Date is the day the page's header article shows in its byline
// ("05/18/2022 - 1:00 PM"), as written: the byline names no time zone, and
// read as Pacific time one letter's would fall after its first Wayback
// capture.
func ParseFragment(frag []byte, cfg *Config) (Body, error) {
	doc, err := html.Parse(bytes.NewReader(frag))
	if err != nil {
		return Body{}, err
	}
	p := &fragment{cfg: cfg}
	for _, a := range findAll(doc, tagIs("g-article")) {
		if strings.TrimSpace(attr(a, "body")) != "" {
			p.last = a
		}
	}
	p.walk(doc)
	if p.err != nil {
		return Body{}, p.err
	}
	if len(p.blocks) == 0 {
		return Body{}, errors.New("fragment has no content")
	}
	return Body{Blocks: splitPseudoHeadings(tidyRules(p.blocks), cfg), Labels: p.labels, Date: p.date}, nil
}

// bylineDate is the day a byline shows ("05/18/2022 - 1:00 PM" is
// 2022-05-18), or "" for any other text.
var bylineDate = regexp.MustCompile(`^(\d{2}/\d{2}/\d{4})\s*-\s*\d{1,2}:\d{2}\s*[AP]M$`)

func parseByline(s string) string {
	m := bylineDate.FindStringSubmatch(strings.TrimSpace(s))
	if m == nil {
		return ""
	}
	t, err := time.Parse("01/02/2006", m[1])
	if err != nil {
		return ""
	}
	return t.Format("2006-01-02")
}

type fragment struct {
	cfg    *Config
	blocks []Block
	labels []string
	date   string // the first byline's day
	err    error
	// last is the last article with a body. An emphasis article there is the
	// report's closing block; an earlier one is a section RSI draws in a box
	// (a letter's), converted as any other article.
	last *html.Node
	// section is set once a section title (a header, a later introduction)
	// has opened a section; the questions of a later list sit one level
	// below it.
	section    bool
	introduced bool // an introduction has titled the page
}

// label keeps s, markup that a component shows as text, as page furniture (see
// ParseFragment).
func (p *fragment) label(s string) {
	if s = htmlText(s); s != "" {
		p.labels = append(p.labels, s)
	}
}

// htmlText is the text a component shows for a JSON string: RSI renders the
// string as HTML, and some titles carry markup (<font size=5>).
func htmlText(s string) string {
	ctx := &html.Node{Type: html.ElementNode, Data: "div", DataAtom: atom.Div}
	nodes, err := html.ParseFragment(strings.NewReader(s), ctx)
	if err != nil {
		return strings.TrimSpace(wsRun.ReplaceAllString(normalizeChars(s), " "))
	}
	for _, n := range nodes {
		ctx.AppendChild(n)
	}
	return PlainText(ctx)
}

func (p *fragment) walk(n *html.Node) {
	for c := n.FirstChild; c != nil && p.err == nil; c = c.NextSibling {
		if c.Type != html.ElementNode {
			continue
		}
		switch {
		case c.Data == "g-banner-advanced":
			var content bannerContent
			if err := json.Unmarshal([]byte(attr(c, ":content")), &content); err != nil {
				p.err = fmt.Errorf("g-banner-advanced :content: %w", err)
				return
			}
			p.banner(content)
		case c.Data == "g-banner":
			// Decoration; its text slots can hold placeholder copy.
			for _, t := range findAll(c, tagIs("template")) {
				p.label(PlainText(t))
			}
		case dropTags[c.Data]:
		case attr(c, "id") == "aria-skin-info":
		case c.Data == "g-introduction":
			var info struct {
				Overline string   `json:"overline"`
				Title    string   `json:"title"`
				Subtitle string   `json:"subtitle"`
				Contents []string `json:"contents"`
			}
			if err := json.Unmarshal([]byte(attr(c, ":info")), &info); err != nil {
				p.err = fmt.Errorf("g-introduction :info: %w", err)
				return
			}
			// The first introduction titles the page; a later one titles a
			// section (About the Golem OX).
			p.label(info.Overline)
			p.label(info.Subtitle)
			if title := htmlText(info.Title); p.introduced && title != "" {
				p.blocks = append(p.blocks, Block{Kind: Heading, Level: 2, Text: title})
				p.section = true
			} else {
				p.label(info.Title)
			}
			p.introduced = true
			for _, h := range info.Contents {
				p.flowHTML(h, false)
			}
		case c.Data == "g-faq":
			var list []faqItem
			if err := json.Unmarshal([]byte(attr(c, ":question-list")), &list); err != nil {
				p.err = fmt.Errorf("g-faq :question-list: %w", err)
				return
			}
			p.faq(list)
		case c.Data == "g-platform-client-component":
			p.component(c)
		case c.Data == "g-header":
			// The first header, before any body, titles the page.
			title, content := slotted(c)
			if len(p.blocks) == 0 {
				p.label(title)
			} else if title != "" {
				p.blocks = append(p.blocks, Block{Kind: Heading, Level: 2, Text: title})
				p.section = true
			}
			if content != nil {
				p.flowNode(content, false)
			}
		case c.Data == "g-disclaimer":
			title, content := slotted(c)
			if title != "" {
				p.label(title)
				p.blocks = append(p.blocks, Block{Kind: Heading, Level: 2, Text: title})
			}
			if content != nil {
				p.flowNode(content, false)
			}
		case c.Data == "g-article":
			if p.date == "" {
				p.date = parseByline(attr(c, "byline"))
			}
			if body := attr(c, "body"); strings.TrimSpace(body) != "" {
				p.flowHTML(body, attr(c, ":show-emphasis") == "true" && c == p.last)
			}
		case c.Data == "g-illustration":
			p.illustration(c)
		case c.Data == "g-slideshow":
			p.slideshow(c)
		case c.Data == "g-trailer":
			if id := attr(c, "video-id"); id != "" {
				p.blocks = append(p.blocks, Block{Kind: Video, VideoKind: "youtube", VideoID: id})
			}
		case c.Data == "g-author":
			if name := strings.TrimSpace(attr(c, "author-name")); name != "" {
				text := escapeText(name)
				if desc := strings.TrimSpace(attr(c, "author-desc")); desc != "" {
					text += "<br />" + escapeText(desc)
				}
				p.blocks = append(p.blocks, Block{Kind: Paragraph, Text: text})
			}
		default:
			p.walk(c)
		}
	}
}

// flowHTML converts one article body or intro entry. Its single heading level
// is a top-level section: h2 in the earliest fragments, then, from a change
// during 2022, h4 for Star Citizen and h3 for Squadron 42. With noSections a
// heading is bold text.
func (p *fragment) flowHTML(src string, emphasis bool) {
	ctx := &html.Node{Type: html.ElementNode, Data: "div", DataAtom: atom.Div}
	nodes, err := html.ParseFragment(strings.NewReader(src), ctx)
	if err != nil {
		p.err = err
		return
	}
	for _, n := range nodes {
		ctx.AppendChild(n)
	}
	p.flowNode(ctx, emphasis)
}

// flowNode converts the content of ctx as flowHTML does.
func (p *fragment) flowNode(ctx *html.Node, emphasis bool) {
	mergeSplitLinks(ctx)
	// closing: the article is the sign-off, or reached it; every heading
	// from there on (// END TRANSMISSION) belongs to it.
	closing := emphasis
	f := &flow{rules: p.cfg.SceneBreaks, tables: p.cfg.Tables, heading: func(f *flow, h *html.Node) {
		t := PlainText(h)
		if t == "" {
			return
		}
		if p.cfg.NoSections {
			f.emit(Block{Kind: Paragraph, Text: bold(trimBreaks(Inline(h)))})
			return
		}
		closing = closing || p.cfg.MatchesSignOff(t)
		if closing {
			f.emit(Block{Kind: Paragraph, Text: joinMarkup("'''", escapeText(t), "'''")})
			return
		}
		f.emit(Block{Kind: Heading, Level: 2, Text: t})
	}}
	f.run(ctx)
	f.flush()
	if emphasis {
		for i := range f.blocks {
			if f.blocks[i].Kind == Paragraph {
				f.blocks[i].Text = bold(f.blocks[i].Text)
				f.blocks[i].Emphasis = true
			}
		}
	}
	p.blocks = append(p.blocks, f.blocks...)
}

// bannerContent is an advanced banner's content: g-banner-advanced's :content,
// or an ArtemisBannerAdvanced's content.
type bannerContent struct {
	Displayed bool `json:"displayed"`
	Text      struct {
		Displayed bool   `json:"displayed"`
		Paragraph string `json:"paragraph"`
	} `json:"text"`
}

// banner converts an advanced banner's paragraph, when it shows one (a
// pull-quote). Its title is decoration, such as the report's name.
func (p *fragment) banner(content bannerContent) {
	if content.Displayed && content.Text.Displayed && strings.TrimSpace(content.Text.Paragraph) != "" {
		p.flowHTML(content.Text.Paragraph, false)
	}
}

// faqItem is one question of a question list, its answer HTML.
type faqItem struct {
	Title   string `json:"title"`
	Content string `json:"content"`
}

// faq converts a question list: each question a heading, one level below an
// open section, then its answer. The API numbers the questions of each list
// from 1, which RSI's page does not, so each numbered question is a label.
func (p *fragment) faq(list []faqItem) {
	level := 2
	if p.section {
		level = 3
	}
	for i, q := range list {
		title := htmlText(q.Title)
		if title == "" {
			continue
		}
		p.blocks = append(p.blocks, Block{Kind: Heading, Level: level, Text: title})
		p.label(fmt.Sprintf("%d. %s", i+1, title))
		p.flowHTML(q.Content, false)
	}
}

// component converts a g-platform-client-component by its componentId: a
// header (a section title, level 2, and its text), a question list, an
// advanced banner or a trailer. Any other (a separator, a page background) is
// decoration.
func (p *fragment) component(n *html.Node) {
	var props struct {
		ComponentID    string          `json:"componentId"`
		ComponentProps json.RawMessage `json:"componentProps"`
	}
	if err := json.Unmarshal([]byte(attr(n, ":properties")), &props); err != nil {
		p.err = fmt.Errorf("g-platform-client-component :properties: %w", err)
		return
	}
	decode := func(v any) bool {
		if err := json.Unmarshal(props.ComponentProps, v); err != nil {
			p.err = fmt.Errorf("%s componentProps: %w", props.ComponentID, err)
			return false
		}
		return true
	}
	switch props.ComponentID {
	case "ArtemisHeader":
		var h struct {
			Overline string `json:"overline"`
			Title    string `json:"title"`
			Subtitle string `json:"subtitle"`
			Content  string `json:"content"`
		}
		if !decode(&h) {
			return
		}
		p.label(h.Overline)
		p.label(h.Subtitle)
		if title := htmlText(h.Title); title != "" {
			p.blocks = append(p.blocks, Block{Kind: Heading, Level: 2, Text: title})
			p.section = true
		}
		if strings.TrimSpace(h.Content) != "" {
			p.flowHTML(h.Content, false)
		}
	case "ArtemisFaq":
		var f struct {
			QuestionList []faqItem `json:"questionList"`
		}
		if decode(&f) {
			p.faq(f.QuestionList)
		}
	case "ArtemisBannerAdvanced":
		var b struct {
			Content bannerContent `json:"content"`
		}
		if decode(&b) {
			p.banner(b.Content)
		}
	case "ArtemisTrailer":
		var t struct {
			VideoID string `json:"videoId"`
		}
		if decode(&t) && strings.TrimSpace(t.VideoID) != "" {
			p.blocks = append(p.blocks, Block{Kind: Video, VideoKind: "youtube", VideoID: strings.TrimSpace(t.VideoID)})
		}
	}
}

// slotted is a component's title slot text and its content slot.
func slotted(n *html.Node) (title string, content *html.Node) {
	for c := n.FirstChild; c != nil; c = c.NextSibling {
		if c.Type != html.ElementNode || c.Data != "template" {
			continue
		}
		switch attr(c, "slot") {
		case "title":
			title = PlainText(c)
		case "content":
			content = c
		}
	}
	return title, content
}

// slideshow converts a g-slideshow into one gallery of its images, in order,
// each captioned with the slideshow's title. Each slide's alt is an internal
// label.
func (p *fragment) slideshow(n *html.Node) {
	var images []string
	if err := json.Unmarshal([]byte(attr(n, ":images")), &images); err != nil {
		p.err = fmt.Errorf("g-slideshow :images: %w", err)
		return
	}
	var title string
	if raw := attr(n, ":title"); raw != "" {
		if err := json.Unmarshal([]byte(raw), &title); err != nil {
			p.err = fmt.Errorf("g-slideshow :title: %w", err)
			return
		}
	}
	caption := escapeText(strings.TrimSpace(title))
	g := Block{Kind: Gallery}
	for _, src := range images {
		if src = strings.TrimSpace(src); src != "" {
			g.Images = append(g.Images, Block{Kind: Image, Src: absURL(src), Caption: caption})
		}
	}
	if len(g.Images) > 0 {
		p.blocks = append(p.blocks, g)
	}
}

func (p *fragment) illustration(n *html.Node) {
	var simple struct {
		OriginalFormat struct {
			Max string `json:"max"`
		} `json:"originalFormat"`
	}
	var image struct {
		Source string `json:"source"`
	}
	src := ""
	if json.Unmarshal([]byte(attr(n, ":simple-image")), &simple) == nil && simple.OriginalFormat.Max != "" {
		src = absURL(simple.OriginalFormat.Max)
	} else if json.Unmarshal([]byte(attr(n, ":image")), &image) == nil && image.Source != "" {
		src = absURL(image.Source)
	}
	if src == "" {
		return
	}
	p.blocks = append(p.blocks, Block{Kind: Image, Src: src, Caption: credit(attr(n, "sign-intro"), attr(n, "sign-name"), attr(n, "sign-link-href"))})
}

// credit builds an illustration's caption from its sign attributes. Some
// values are a lone space; alt is an internal label and never a caption.
func credit(intro, name, href string) string {
	intro, name, href = strings.TrimSpace(intro), strings.TrimSpace(name), strings.TrimSpace(href)
	if name == "" {
		return ""
	}
	who := escapeText(name)
	if href != "" {
		who = "[" + absURL(href) + " " + who + "]"
	}
	if intro == "" {
		return who
	}
	return escapeText(intro) + " " + who
}
