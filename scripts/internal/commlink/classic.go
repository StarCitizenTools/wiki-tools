package commlink

import (
	"bytes"
	"errors"
	"regexp"

	"golang.org/x/net/html"
)

var (
	greeting = regexp.MustCompile(`(?i)^greetings`)
	signOff  = regexp.MustCompile(`(?i)see you next month`)
	// reportTitle matches a first title block that names the report, though
	// not always as the RSI title does (16963 names two months).
	reportTitle = regexp.MustCompile(`(?i)\bmonthly (studio )?report\b`)
)

// isPageTitle reports whether the first title block's text is the page title.
func isPageTitle(text, foldedTitle string) bool {
	return fold(text) == foldedTitle || reportTitle.MatchString(text)
}

// ParseClassic converts a classic-layout page into blocks. The body is the run
// of content-block4 (section title), content-block2 (header image) and
// content-block1 (prose) blocks inside div#post, up to the first
// div.two-line-separator; the channel banner and comments follow it.
func ParseClassic(shell []byte, rsiTitle string) ([]Block, error) {
	doc, err := html.Parse(bytes.NewReader(shell))
	if err != nil {
		return nil, err
	}
	post := findByID(doc, "post")
	if post == nil {
		return nil, errors.New("classic page has no div#post")
	}
	mergeSplitLinks(post)
	c := &classic{title: fold(rsiTitle)}
	c.studios = countStudioBlocks(post, c.title) > 0
	c.walk(post)
	if len(c.blocks) == 0 {
		return nil, errors.New("classic page has no body blocks")
	}
	return splitPseudoHeadings(c.blocks), nil
}

type classic struct {
	title      string // folded page title
	studios    bool   // one title block per studio (2014 to August 2018)
	sawTitle   bool
	lastTitle  string // folded text of the latest section-title block
	titleAt    int    // index in blocks of that block's heading
	repeatOpen bool   // no h1 has followed that block yet
	stopped    bool
	blocks     []Block
}

func (c *classic) walk(n *html.Node) {
	for ch := n.FirstChild; ch != nil && !c.stopped; ch = ch.NextSibling {
		c.visit(ch)
	}
}

func (c *classic) visit(n *html.Node) {
	if n.Type != html.ElementNode || dropTags[n.Data] {
		return
	}
	switch {
	case hasClass(n, "two-line-separator"):
		c.stopped = true
	case hasClass(n, "content-block4"):
		c.titleBlock(n)
	case hasClass(n, "content-block2"):
		for _, img := range findAll(n, tagIs("img")) {
			if src := sourceURL(attr(img, "src")); src != "" {
				c.blocks = append(c.blocks, Block{Kind: Image, Src: src})
			}
		}
	case hasClass(n, "content-block1"):
		c.prose(n)
	default:
		c.walk(n)
	}
}

// titleBlock turns a content-block4 into a section heading. The first one is
// the page title when its text matches the report's title.
func (c *classic) titleBlock(n *html.Node) {
	h := findFirst(n, tagIs("h1"))
	if h == nil {
		return
	}
	text := PlainText(h)
	if text == "" {
		return
	}
	if !c.sawTitle {
		c.sawTitle = true
		if isPageTitle(text, c.title) {
			return
		}
	}
	c.lastTitle = fold(text)
	c.titleAt, c.repeatOpen = len(c.blocks), true
	c.blocks = append(c.blocks, Block{Kind: Heading, Level: 2, Text: text})
}

// prose converts a content-block1's segment > content. Any other child is
// visited as a block of its own: a missing </div> in four reports nests the
// following blocks here, beside div.segment.
func (c *classic) prose(n *html.Node) {
	for ch := n.FirstChild; ch != nil && !c.stopped; ch = ch.NextSibling {
		if ch.Type != html.ElementNode {
			continue
		}
		if !hasClass(ch, "segment") {
			c.visit(ch)
			continue
		}
		for content := ch.FirstChild; content != nil; content = content.NextSibling {
			if hasClass(content, "content") {
				f := &flow{heading: c.heading}
				f.run(content)
				f.flush()
				c.blocks = append(c.blocks, f.blocks...)
			}
		}
	}
}

func (c *classic) heading(f *flow, n *html.Node) {
	text := PlainText(n)
	if text == "" {
		return
	}
	if n.Data == "h1" || hasAncestorClass(n, "variant-block") {
		switch {
		case greeting.MatchString(text) || signOff.MatchString(text):
			f.emit(Block{Kind: Paragraph, Text: "'''" + Inline(n) + "'''"})
		case n.Data == "h1" && (c.studios || fold(text) == c.lastTitle):
			// The studio name, repeated in capitals under its title block.
			// A repeat naming the studio more fully (CLOUD IMPERIUM: LOS
			// ANGELES under CIG Los Angeles) replaces the title's text.
			if c.repeatOpen && len(fold(text)) > len(c.lastTitle) {
				c.blocks[c.titleAt].Text = text
				c.lastTitle = fold(text)
			}
			c.repeatOpen = false
		default:
			// An intro h3.no-margin can hold several paragraphs split by <br><br>.
			f.run(n)
			f.flush()
		}
		return
	}
	level := 2
	if c.studios {
		level = 3
	}
	if n.Data != "h2" {
		level++
	}
	f.emit(Block{Kind: Heading, Level: level, Text: text})
}

// countStudioBlocks counts the section-title blocks other than the page title
// and "Conclusion", up to the separator. Studio-era pages have one per studio.
func countStudioBlocks(post *html.Node, title string) int {
	count, first, stop := 0, true, false
	var walk func(*html.Node)
	walk = func(n *html.Node) {
		for ch := n.FirstChild; ch != nil && !stop; ch = ch.NextSibling {
			if hasClass(ch, "two-line-separator") {
				stop = true
				return
			}
			if hasClass(ch, "content-block4") {
				if h := findFirst(ch, tagIs("h1")); h != nil {
					text := PlainText(h)
					t := fold(text)
					if !(first && isPageTitle(text, title)) && t != "" && t != "conclusion" {
						count++
					}
					first = false
				}
				continue
			}
			walk(ch)
		}
	}
	walk(post)
	return count
}
