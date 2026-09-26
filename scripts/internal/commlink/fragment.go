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

// ParseFragment converts a fragment-layout body (from late 2021) into blocks.
// The prose lives in component attributes: g-introduction's :info JSON and
// g-article's body HTML; g-illustration carries an image. The parser decodes
// each attribute once, and the body is then parsed as HTML, which also decodes
// the double-escaped entities of the earliest fragments.
func ParseFragment(frag []byte) ([]Block, error) {
	doc, err := html.Parse(bytes.NewReader(frag))
	if err != nil {
		return nil, err
	}
	p := &fragment{}
	p.walk(doc)
	if p.err != nil {
		return nil, p.err
	}
	if len(p.blocks) == 0 {
		return nil, errors.New("fragment has no content")
	}
	return splitPseudoHeadings(p.blocks), nil
}

type fragment struct {
	blocks []Block
	err    error
}

func (p *fragment) walk(n *html.Node) {
	for c := n.FirstChild; c != nil && p.err == nil; c = c.NextSibling {
		if c.Type != html.ElementNode {
			continue
		}
		switch {
		case c.Data == "g-banner" || c.Data == "g-banner-advanced" || dropTags[c.Data]:
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
				p.flowHTML(body, attr(c, ":show-emphasis") == "true")
			}
		case c.Data == "g-illustration":
			p.illustration(c)
		default:
			p.walk(c)
		}
	}
}

// flowHTML converts one article body or intro entry. Its single heading level
// is a top-level section: h2 in the earliest fragments, then, from a change
// during 2022, h4 for Star Citizen and h3 for Squadron 42.
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
	f := &flow{heading: func(f *flow, h *html.Node) {
		t := PlainText(h)
		if t == "" {
			return
		}
		closing = closing || signOff.MatchString(t)
		if closing {
			f.emit(Block{Kind: Paragraph, Text: "'''" + escapeText(t) + "'''"})
			return
		}
		f.emit(Block{Kind: Heading, Level: 2, Text: t})
	}}
	f.run(ctx)
	f.flush()
	if emphasis {
		for i := range f.blocks {
			if f.blocks[i].Kind == Paragraph {
				f.blocks[i].Text = "'''" + strings.ReplaceAll(f.blocks[i].Text, "'''", "") + "'''"
			}
		}
	}
	p.blocks = append(p.blocks, f.blocks...)
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
