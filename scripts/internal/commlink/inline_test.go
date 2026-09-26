package commlink

import (
	"strings"
	"testing"

	"golang.org/x/net/html"
	"golang.org/x/net/html/atom"
)

// fragmentNode parses src as the content of a <div> and returns that div.
func fragmentNode(t *testing.T, src string) *html.Node {
	t.Helper()
	div := &html.Node{Type: html.ElementNode, Data: "div", DataAtom: atom.Div}
	nodes, err := html.ParseFragment(strings.NewReader(src), div)
	if err != nil {
		t.Fatal(err)
	}
	for _, n := range nodes {
		div.AppendChild(n)
	}
	return div
}

func TestInline(t *testing.T) {
	cases := map[string]string{
		`<span class="initial">S</span>oon, all ships`:                   `Soon, all ships`,
		`a <strong>Heat </strong>and <em>Power</em> part`:                `a '''Heat''' and ''Power'' part`,
		`<span class="italic">slanted</span> and <u>under</u>`:           `''slanted'' and <u>under</u>`,
		`See <a href="/comm-link/engineering/1">the post</a>.`:           `See [https://robertsspaceindustries.com/comm-link/engineering/1 the post].`,
		`<a href="//www.youtube.com/watch?v=x">video</a>`:                `[https://www.youtube.com/watch?v=x video]`,
		`<a href="#top">up</a> <a href="mailto:a@b">mail</a>`:            `up mail`,
		"one&nbsp;two\n   three<br>four":                                 `one two three<br />four`,
		`[[not a link]] {{not a template}} <b>x</b> ''quoted'' a &lt; b`: `&#91;&#91;not a link&#93;&#93; &#123;&#123;not a template&#125;&#125; '''x''' &#39;&#39;quoted&#39;&#39; a &lt; b`,
		`<a href="https://example.com"><strong>bold</strong> link</a>`:   `[https://example.com '''bold''' link]`,
		`<img src="x.png"> text <script>alert(1)</script>`:               `text`,
		`a ~~~~ b ~ c`: `a &#126;&#126;&#126;&#126; b &#126; c`,
		`additional<a href="https://x"> Galactapedia Entries</a>.`: `additional [https://x Galactapedia Entries].`,
	}
	for src, want := range cases {
		if got := Inline(fragmentNode(t, src)); got != want {
			t.Errorf("Inline(%q)\n got %q\nwant %q", src, got, want)
		}
	}
}

// Quote markers that meet another marker or an apostrophe of text are
// separated, except an italic and a bold marker, which MediaWiki reads as a
// run of five.
func TestInlineQuoteJoins(t *testing.T) {
	cases := map[string]string{
		`<em>a</em><em>b</em>`:                          `''a''<nowiki />''b''`,
		`<strong><em>X</em></strong><em>!</em>`:         `'''''X'''''<nowiki />''!''`,
		`<em>the players'</em> turn`:                    `''the players'<nowiki />'' turn`,
		`<em>Kraken</em>'s hull`:                        `''Kraken''<nowiki />'s hull`,
		`rock'<em>n</em>`:                               `rock'<nowiki />''n''`,
		`<em><em>X</em></em>`:                           `''<nowiki />''X''<nowiki />''`,
		`<strong><em>X</em></strong>`:                   `'''''X'''''`,
		`<em>a</em><strong>b</strong>`:                  `''a'''''b'''`,
		`<a href="#x">'s</a> after <em>Y</em><a>'s</a>`: `'s after ''Y''<nowiki />'s`,
	}
	for src, want := range cases {
		if got := Inline(fragmentNode(t, src)); got != want {
			t.Errorf("Inline(%q)\n got %q\nwant %q", src, got, want)
		}
	}
}

// A paragraph's inline elements join in the flow's buffer, not through
// Inline, so the separation applies there too.
func TestParseFragmentQuoteJoins(t *testing.T) {
	blocks, err := ParseFragment([]byte(`<g-article :show-emphasis="false" body="<p><em>with you on</em> <strong><em>October 21 and 22</em></strong><em>! Keep</em></p>"></g-article>`))
	if err != nil {
		t.Fatal(err)
	}
	check(t, dump(blocks), []string{`P ''with you on'' '''''October 21 and 22'''''<nowiki />''! Keep''`})
}

func TestPlainText(t *testing.T) {
	n := fragmentNode(t, `<h3><strong>AI (</strong>Content<strong>)</strong></h3>`)
	if got := PlainText(n); got != "AI (Content)" {
		t.Errorf("PlainText = %q", got)
	}
}

func TestLineSafe(t *testing.T) {
	for in, want := range map[string]string{
		"* not a list": "<nowiki />* not a list",
		"= not a head": "<nowiki />= not a head",
		"Plain text":   "Plain text",
	} {
		if got := lineSafe(in); got != want {
			t.Errorf("lineSafe(%q) = %q", in, got)
		}
	}
}
