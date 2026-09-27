package commlink

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	"golang.org/x/net/html"
	"golang.org/x/net/html/atom"
)

// ParseFragment converts a fragment-layout body into blocks. The prose lives in
// component attributes: g-introduction's :info JSON, g-article's body HTML and
// a g-banner-advanced's paragraph; g-illustration and g-slideshow carry
// images, g-trailer a YouTube video and g-author the signature. The parser
// decodes each attribute once, and the body is then parsed as HTML, which also
// decodes the double-escaped entities of the earliest fragments.
func ParseFragment(frag []byte, cfg *Config) ([]Block, error) {
	doc, err := html.Parse(bytes.NewReader(frag))
	if err != nil {
		return nil, err
	}
	p := &fragment{cfg: cfg}
	for _, a := range findAll(doc, tagIs("g-article")) {
		if strings.TrimSpace(attr(a, "body")) != "" {
			p.last = a
		}
	}
	p.walk(doc)
	if p.err != nil {
		return nil, p.err
	}
	if len(p.blocks) == 0 {
		return nil, errors.New("fragment has no content")
	}
	return splitPseudoHeadings(tidyRules(p.blocks), cfg), nil
}

type fragment struct {
	cfg    *Config
	blocks []Block
	err    error
	// last is the last article with a body. An emphasis article there is the
	// report's closing block; an earlier one is a section RSI draws in a box
	// (a letter's), converted as any other article.
	last *html.Node
}

func (p *fragment) walk(n *html.Node) {
	for c := n.FirstChild; c != nil && p.err == nil; c = c.NextSibling {
		if c.Type != html.ElementNode {
			continue
		}
		switch {
		case c.Data == "g-banner-advanced":
			p.banner(c)
		case c.Data == "g-banner" || dropTags[c.Data]:
		case attr(c, "id") == "aria-skin-info":
		case c.Data == "g-introduction":
			var info struct {
				Contents []string `json:"contents"`
			}
			if err := json.Unmarshal([]byte(attr(c, ":info")), &info); err != nil {
				p.err = fmt.Errorf("g-introduction :info: %w", err)
				return
			}
			for _, h := range info.Contents {
				p.flowHTML(h, false)
			}
		case c.Data == "g-article":
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
	mergeSplitLinks(ctx)
	// closing: the article is the sign-off, or reached it; every heading
	// from there on (// END TRANSMISSION) belongs to it.
	closing := emphasis
	f := &flow{rules: p.cfg.SceneBreaks, heading: func(f *flow, h *html.Node) {
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

// banner converts a g-banner-advanced's paragraph, when it shows one (a
// pull-quote). Its title is decoration, such as the report's name.
func (p *fragment) banner(n *html.Node) {
	var content struct {
		Displayed bool `json:"displayed"`
		Text      struct {
			Displayed bool   `json:"displayed"`
			Paragraph string `json:"paragraph"`
		} `json:"text"`
	}
	if err := json.Unmarshal([]byte(attr(n, ":content")), &content); err != nil {
		p.err = fmt.Errorf("g-banner-advanced :content: %w", err)
		return
	}
	if content.Displayed && content.Text.Displayed && strings.TrimSpace(content.Text.Paragraph) != "" {
		p.flowHTML(content.Text.Paragraph, false)
	}
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
