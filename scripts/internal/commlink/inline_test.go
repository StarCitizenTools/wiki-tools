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
		// Stray Unicode spacing maps to a plain space and collapses with its
		// neighbours; soft hyphens and zero-width marks are dropped.
		"word\u202f<a href=\"https://x\">link</a>\u202fword": `word [https://x link] word`,
		"a \u202fb co\u00adop\u200ber\u2060at\ufeffion":      `a b cooperation`,
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
	blocks, _, err := ParseFragment([]byte(`<g-article :show-emphasis="false" body="<p><em>with you on</em> <strong><em>October 21 and 22</em></strong><em>! Keep</em></p>"></g-article>`), testConfig(t))
	if err != nil {
		t.Fatal(err)
	}
	check(t, dump(blocks), []string{`P ''with you on'' '''''October 21 and 22'''''<nowiki />''! Keep''`})
}

func TestPlainText(t *testing.T) {
	for _, src := range []string{
		`<h3><strong>AI (</strong>Content<strong>)</strong></h3>`,
		"<h3>AI\u202f(Co\u00adntent)</h3>",
	} {
		if got, want := PlainText(fragmentNode(t, src)), "AI (Content)"; got != want {
			t.Errorf("PlainText(%q) = %q, want %q", src, got, want)
		}
	}
}

// Every Unicode space separator (general category Zs) other than U+0020 maps
// to a plain space; soft hyphen and the zero-width marks are dropped, and
// ligatures are spelled out.
func TestNormalizeChars(t *testing.T) {
	for _, r := range []rune{0x00A0, 0x1680, 0x2000, 0x200A, 0x202F, 0x205F, 0x3000} {
		if got := normalizeChars("a" + string(r) + "b"); got != "a b" {
			t.Errorf("normalizeChars(a U+%04X b) = %q, want %q", r, got, "a b")
		}
	}
	for _, r := range []rune{0x00AD, 0x200B, 0x2060, 0xFEFF} {
		if got := normalizeChars("a" + string(r) + "b"); got != "ab" {
			t.Errorf("normalizeChars(a U+%04X b) = %q, want %q", r, got, "ab")
		}
	}
	if got := normalizeChars("\uFB01re \uFB02ow e\uFB03cient"); got != "fire flow efficient" {
		t.Errorf("normalizeChars left a ligature: %q", got)
	}
	if got := normalizeChars("a  b\tc"); got != "a  b\tc" {
		t.Errorf("normalizeChars changed ASCII spacing: %q", got)
	}
}

// escapeText must normalise before it collapses whitespace, or a mapped space
// beside an ASCII one survives as a double space in text nothing re-collapses.
func TestEscapeTextCollapsesMappedSpace(t *testing.T) {
	if got := escapeText("a" + string(rune(0x202F)) + " b"); got != "a b" {
		t.Errorf("escapeText(a U+202F space b) = %q, want %q", got, "a b")
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

func TestAbsURL(t *testing.T) {
	for in, want := range map[string]string{
		"/media/x/source/a b.jpg":           "https://robertsspaceindustries.com/media/x/source/a%20b.jpg",
		"//www.youtube.com/watch?v=x":       "https://www.youtube.com/watch?v=x",
		`https://x.test/a[1]{2}|'3'<4>"5"`:  "https://x.test/a%5B1%5D%7B2%7D%7C%273%27%3C4%3E%225%22",
		"https://x.test/q?a=1&b=%20already": "https://x.test/q?a=1&b=%20already",
		// MediaWiki's external-link syntax ends the URL at any Unicode space
		// separator, not only U+0020.
		"https://x.test/a\u00a0b\u202fc": "https://x.test/a%C2%A0b%E2%80%AFc",
	} {
		if got := absURL(in); got != want {
			t.Errorf("absURL(%q) = %q, want %q", in, got, want)
		}
	}
}

// bold drops the bold runs inside its text, which would otherwise close it.
func TestBold(t *testing.T) {
	for in, want := range map[string]string{
		"THE END":            "'''THE END'''",
		"'''EXT.''' PAD":     "'''EXT. PAD'''",
		"''Said.'' (to him)": "'''''Said.'' (to him)'''",
		"'''''Both'''''":     "'''''Both'''''",
	} {
		if got := bold(in); got != want {
			t.Errorf("bold(%q) = %q, want %q", in, got, want)
		}
	}
}
