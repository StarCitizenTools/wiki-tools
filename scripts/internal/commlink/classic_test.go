package commlink

import (
	"fmt"
	"os"
	"reflect"
	"strings"
	"testing"
)

// dump renders blocks compactly so expected output reads like the page.
func dump(blocks []Block) []string {
	var out []string
	for _, b := range blocks {
		switch b.Kind {
		case Heading:
			out = append(out, fmt.Sprintf("H%d %s", b.Level, b.Text))
		case Paragraph:
			out = append(out, "P "+b.Text)
		case Quote:
			out = append(out, "Q "+b.Text)
		case List:
			out = append(out, "LIST "+strings.Join(b.Items, " / "))
		case Image:
			s := "IMG " + b.Src
			if b.Caption != "" {
				s += " | " + b.Caption
			}
			out = append(out, s)
		case Video:
			out = append(out, fmt.Sprintf("VID %s %s%s", b.VideoKind, b.VideoID, b.Src))
		case Gallery:
			var slides []string
			for _, s := range b.Images {
				slides = append(slides, strings.TrimPrefix(dump([]Block{s})[0], "IMG "))
			}
			out = append(out, "GALLERY "+strings.Join(slides, " / "))
		}
	}
	return out
}

func parseFixture(t *testing.T, name, title string) []string {
	t.Helper()
	shell, err := os.ReadFile("testdata/" + name)
	if err != nil {
		t.Fatal(err)
	}
	blocks, _, err := ParseClassic(shell, title, testConfig(t))
	if err != nil {
		t.Fatal(err)
	}
	return dump(blocks)
}

func check(t *testing.T, got, want []string) {
	t.Helper()
	if !reflect.DeepEqual(got, want) {
		t.Errorf("blocks:\n got %q\nwant %q", got, want)
	}
}

func TestParseClassicStudio(t *testing.T) {
	check(t, parseFixture(t, "classic_studio.html", "Monthly Studio Report: April 2017"), []string{
		"P '''Greetings Citizens!'''",
		"P Welcome to our April Monthly Report!",
		"H2 CIG Los Angeles",
		"IMG https://robertsspaceindustries.com/media/utuvor88kjammr/source/Heavy_armor.png",
		"H3 ENGINEERING",
		"IMG https://robertsspaceindustries.com/media/3axlriz1esgfnr/source/Liveworks.jpg",
		"P Soon, all new ships will have a '''Heat''' and ''Power'' component. See [https://robertsspaceindustries.com/comm-link/engineering/1 the post].",
		"LIST First item / Second item",
		"VID youtube 8sZ5Zb48EiA",
	})
}

func TestParseClassicTeam(t *testing.T) {
	check(t, parseFixture(t, "classic_team.html", "Star Citizen Monthly Report: May 2021"), []string{
		"P In the month of May, Star Citizen welcomed the fleet.",
		"H2 AI (Content)",
		"P The AI Content Team focused on tech.",
		"P Bare text run one.",
		"P Bare text run two.",
		"H3 600i",
		"P The 600i got love.",
		"H2 Conclusion",
		"P '''WE'LL SEE YOU NEXT MONTH'''",
	})
}

func TestParseClassic2014(t *testing.T) {
	check(t, parseFixture(t, "classic_2014.html", "Monthly Report: September 2014"), []string{
		"P '''Greetings Citizens,'''",
		"P It has been a busy month!",
		"H2 CLOUD IMPERIUM SANTA MONICA",
		"H3 Ship Pipeline",
		"IMG https://robertsspaceindustries.com/media/jsypy77iz1tw8r/source/Shippipe.png | How an idea becomes a ship.",
		"P In addition, we have been improving our pipeline.",
	})
}

// An intro heading holding several paragraphs split by <br><br>.
func TestParseClassicIntroBreaks(t *testing.T) {
	shell := []byte(`<html><body><div id="contentbody"><div id="post"><div class="wrapper">
<div class="content-block1 rsi-markup"><div class="segment"><div class="content"><div class="variant-block">
<h3 class="no-margin">Welcome to September.
<br />
<br />

<em>A second paragraph.</em>
<br />
<br />
<br />
</h3></div></div></div></div>
<div class="content-block4"><div class="content"><h1>Star Citizen Monthly Report: September 2018</h1></div></div>
</div><div class="two-line-separator"></div></div></div></body></html>`)
	blocks, _, err := ParseClassic(shell, "Star Citizen Monthly Report: September 2018", testConfig(t))
	if err != nil {
		t.Fatal(err)
	}
	check(t, dump(blocks), []string{
		"P Welcome to September.",
		"P ''A second paragraph.''",
	})
}

// A studio-era section title is repeated in capitals as the first h1 of its
// prose. Where the repeat names the studio more fully ("CLOUD IMPERIUM: LOS
// ANGELES" under "CIG Los Angeles") it becomes the heading; a repeat that only
// differs in case, says less, or names something else is dropped.
func TestParseClassicStudioRepeat(t *testing.T) {
	section := func(title, repeat, rest string) string {
		return `<div class="wrapper"><div class="content-block4"><div class="content"><h1>` + title + `</h1></div></div>
<div class="content-block1 rsi-markup"><div class="segment"><div class="content">
<h1 class="no-margin">` + repeat + `</h2><div class="clearfix"></div><br><br>` + rest + `
</div></div></div></div>`
	}
	shell := []byte(`<html><body><div id="contentbody"><div id="post">` +
		section("CIG Los Angeles", `<span class="caps">CLOUD</span> <span class="caps">IMPERIUM</span>: <span class="caps">LOS</span> <span class="caps">ANGELES</span>`, `<p>LA text.</p>`) +
		section("Foundry 42 UK", `<span class="caps">FOUNDRY</span> 42: <span class="caps">UK</span>`, `<p>UK text.</p>`) +
		section("Platform: Turbulent", `<span class="caps">SPECTRUM</span>`, `<h2 class="no-margin"><span class="caps">SPECTRUM</span></h2><hr/><p>Spectrum text.</p>`) +
		section("Community", `<span class="caps">CITIZENCON AND GAMESCOM</span>`, `<p>Community text.</p>`) +
		`<div class="two-line-separator"></div></div></div></body></html>`)
	blocks, _, err := ParseClassic(shell, "Monthly Studio Report: April 2017", testConfig(t))
	if err != nil {
		t.Fatal(err)
	}
	check(t, dump(blocks), []string{
		"H2 CLOUD IMPERIUM: LOS ANGELES",
		"P LA text.",
		"H2 Foundry 42 UK",
		"P UK text.",
		"H2 Platform: Turbulent",
		"H3 SPECTRUM",
		"P Spectrum text.",
		"H2 Community",
		"P Community text.",
	})
}

// A first title block that names two months where the report's title names
// one is still the page title, not a studio section.
func TestParseClassicPageTitleVariant(t *testing.T) {
	shell := []byte(`<html><body><div id="contentbody"><div id="post"><div class="wrapper">
<div class="content-block4"><div class="content"><h1>Star Citizen Monthly Report: December 2018 - January 2019</h1></div></div>
<div class="content-block1 rsi-markup"><div class="segment"><div class="content">
<h2 class="no-margin">AI</h2><hr/><p>AI text.</p>
</div></div></div>
<div class="content-block4"><div class="content"><h1>Conclusion</h1></div></div>
</div><div class="two-line-separator"></div></div></div></body></html>`)
	blocks, _, err := ParseClassic(shell, "Star Citizen Monthly Report: January 2019", testConfig(t))
	if err != nil {
		t.Fatal(err)
	}
	check(t, dump(blocks), []string{"H2 AI", "P AI text.", "H2 Conclusion"})
}

// Adjacent anchors with one href are one link in the classic layout too.
func TestParseClassicSplitLink(t *testing.T) {
	shell := []byte(`<html><body><div id="contentbody"><div id="post"><div class="wrapper">
<div class="content-block1 rsi-markup"><div class="segment"><div class="content">
<p>See <a href="/comm-link/x/1-Y">Insid</a><a href="/comm-link/x/1-Y" target="_blank">e</a><a href="/comm-link/x/1-Y"> Star Citizen</a> now.</p>
</div></div></div>
</div><div class="two-line-separator"></div></div></div></body></html>`)
	blocks, _, err := ParseClassic(shell, "Star Citizen Monthly Report: July 2020", testConfig(t))
	if err != nil {
		t.Fatal(err)
	}
	check(t, dump(blocks), []string{"P See [https://robertsspaceindustries.com/comm-link/x/1-Y Inside Star Citizen] now."})
}

func TestDetect(t *testing.T) {
	shell := []byte(`<html><script>const s3Url = 'https://robertsspaceindustries.com/alexandria/html/fromHeap/x/19956/abc-default.html';</script></html>`)
	frag, err := Detect(shell)
	if err != nil || frag != "https://robertsspaceindustries.com/alexandria/html/fromHeap/x/19956/abc-default.html" {
		t.Errorf("fragment shell: %q %v", frag, err)
	}
	classic, _ := os.ReadFile("testdata/classic_team.html")
	if frag, err := Detect(classic); err != nil || frag != "" {
		t.Errorf("classic page: %q %v", frag, err)
	}
	if _, err := Detect([]byte(`<html><body><p>x</p></body></html>`)); err == nil {
		t.Error("an unknown page was accepted")
	}
}

// A bold subsection title becomes a heading below the section's, whether it
// stands between breaks before an image or in a div of its own. A bold line
// that ends in punctuation, carries a link, or is followed by no text before
// the next heading stays bold.
func TestParseClassicPseudoHeadings(t *testing.T) {
	img := func(name string) string {
		return `<a class="image  js-open-in-slideshow" data-source_url="/media/x/source/` + name + `" rel="post"><img src="/media/x/tavern_upload_square/` + name + `" alt="" /></a>`
	}
	shell := []byte(`<html><body><div id="contentbody"><div id="post"><div class="wrapper">
<div class="content-block1 rsi-markup"><div class="segment"><div class="content">
<div class="no-margin"><strong>Attention Recruits,</strong></div><br />
<div class="no-margin">Read on.</div><br />
<div class="no-margin"><strong>UEE Naval High Command</strong></div>
` + img("Banner.jpg") + `
<h2 class="no-margin"><span class="caps">SHIPS</span></h2><hr/>
  <strong>Hammerhead</strong>
  <br />
` + img("Hammerhead.jpg") + `
  The Hammerhead made progress.
  <br />
<br />
  <strong>600i</strong>
  <br />
` + img("600i.jpg") + img("600i_2.jpg") + `
  The 600i got corridors.
<br /><br />
<strong><a href="/x">Linked</a></strong><br />Linked text.
<h2 class="no-margin">AI</h2><hr/>
<div class="no-margin"><strong>AI (Ships)</strong></div>
<br />
<div class="no-margin">Ship AI flew.</div>
</div></div></div>
</div><div class="two-line-separator"></div></div></div></body></html>`)
	blocks, _, err := ParseClassic(shell, "Star Citizen Monthly Report: November 2017", testConfig(t))
	if err != nil {
		t.Fatal(err)
	}
	check(t, dump(blocks), []string{
		"P '''Attention Recruits,'''",
		"P Read on.",
		"P '''UEE Naval High Command'''",
		"IMG https://robertsspaceindustries.com/media/x/source/Banner.jpg",
		"H2 SHIPS",
		"H3 Hammerhead",
		"IMG https://robertsspaceindustries.com/media/x/source/Hammerhead.jpg",
		"P The Hammerhead made progress.",
		"H3 600i",
		"IMG https://robertsspaceindustries.com/media/x/source/600i.jpg",
		"IMG https://robertsspaceindustries.com/media/x/source/600i_2.jpg",
		"P The 600i got corridors.",
		"P '''[https://robertsspaceindustries.com/x Linked]'''<br />Linked text.",
		"H2 AI",
		"H3 AI (Ships)",
		"P Ship AI flew.",
	})
}

func parseLetter(t *testing.T, shell, title string) []string {
	t.Helper()
	blocks, _, err := ParseClassic([]byte(shell), title, chairmanConfig(t))
	if err != nil {
		t.Fatal(err)
	}
	return dump(blocks)
}

// A letter marks no intro and has no studios: a greeting is bold at any
// heading level, a heading in div.variant-block is a section heading, and a
// prose h1 that does not repeat its section's title is text.
func TestParseClassicLetterHeadings(t *testing.T) {
	check(t, parseLetter(t, `<html><body><div id="contentbody"><div id="post"><div class="wrapper">
<div class="content-block4"><div class="content"><h1>Letter from the Chairman</h1></div></div>
<div class="content-block1 rsi-markup"><div class="segment"><div class="content"><div class="variant-block">
<h2>Hi everyone,</h2><p>Opening words.</p>
<h2>A Grand Tour</h2><p>Tour text.</p>
<h2>Greetings Citizens,</h2><p>A second greeting.</p>
</div><p>&#8212; Chris Roberts</p></div></div></div>
<div class="content-block4"><div class="content"><h1>Oculus &amp; Facebook</h1></div></div>
<div class="content-block1 rsi-markup"><div class="segment"><div class="content">
<h1>Oculus &amp; Facebook</h1><h1>Like many of you, </h1><p>I was surprised.</p>
</div></div></div>
</div><div class="two-line-separator"></div></div></div></body></html>`, "Letter from the Chairman"), []string{
		"P '''Hi everyone,'''",
		"P Opening words.",
		"H2 A Grand Tour",
		"P Tour text.",
		"P '''Greetings Citizens,'''",
		"P A second greeting.",
		"P — Chris Roberts",
		"H2 Oculus & Facebook",
		"P Like many of you,",
		"P I was surprised.",
	})
}

// Some pages draw a two-line-separator inside div.title-section, above the
// body; the body still runs to the separator after it.
func TestParseClassicTitleSectionSeparator(t *testing.T) {
	check(t, parseLetter(t, `<html><body><div id="contentbody"><div id="post">
<div class="title-section"><h1></h1><h3>ID:</h3><p>13391</p><div class="two-line-separator"></div>
<div class="small-title-container"><div class="title">Letter from the Chairman: $30 Million!</div></div></div>
<div class="wrapper"><div class="content-block1 rsi-markup"><div class="segment"><div class="content"><p>Body.</p></div></div></div></div>
<div class="two-line-separator"></div><div class="content-block1 rsi-markup"><div class="segment"><div class="content"><p>Comments.</p></div></div></div>
</div></div></body></html>`, "Letter from the Chairman: $30 Million!"), []string{"P Body."})
}

// A header slideshow keeps each slide's source and caption; a poll keeps its
// options with their shares and the vote count, and its question only when it
// is not its section's title.
func TestParseClassicSlideshowAndPoll(t *testing.T) {
	poll := func(q string) string {
		return `<div class="poll content-block2"><div class="voted atom-special-block poll-holder"><h1>` + q + `</h1><div class="options">
<label class="radio option first"><div class="label"><div class="value">a</div><div class="text">Combat</div></div>
<div class="bars"><div class="bar-item"><div class="label">a</div><div class="value">5%</div></div></div></label>
<label class="radio option"><div class="label"><div class="value">b</div><div class="text">Mining</div></div>
<div class="bars"><div class="bar-item"><div class="label">b</div><div class="value">28%</div></div></div></label>
</div><div class="total">Total Votes: 27857</div></div></div>`
	}
	check(t, parseLetter(t, `<html><body><div id="contentbody"><div id="post"><div class="wrapper">
<div class="content-block2"><div class="atom-special-block"><div class="atom-slideshow"><div class="carousel">
<div data-source_url="/media/cnp6015ubsw1kr/source/Gladiator_Top.png" rel="vault-items"><div class="media"><img data-srcset="/media/cnp6015ubsw1kr/slideshow_pager/Gladiator_Top.png" alt="Gladiator - Original"></div>
<div class="text"><a href="/media/cnp6015ubsw1kr/source/Gladiator_Top.png" class="download"></a><div class="caption">Gladiator - Original</div></div></div>
<div data-source_url="/media/54h3op9oi9v92r/source/Gladiator_Rev1.png" rel="vault-items"><div class="text"><div class="caption">Gladiator - Turret Variant 1</div></div></div>
</div></div></div></div>
<div class="content-block4"><div class="content"><h1>What role would you like to see?</h1></div></div>
<div class="content-block1 rsi-markup">`+poll("What role would you like to see?")+poll("Another question?")+`</div>
</div><div class="two-line-separator"></div></div></div></body></html>`, "Letter from the Chairman"), []string{
		"GALLERY https://robertsspaceindustries.com/media/cnp6015ubsw1kr/source/Gladiator_Top.png | Gladiator - Original / https://robertsspaceindustries.com/media/54h3op9oi9v92r/source/Gladiator_Rev1.png | Gladiator - Turret Variant 1",
		"H2 What role would you like to see?",
		"LIST Combat (5%) / Mining (28%)",
		"P Total Votes: 27857",
		"P '''Another question?'''",
		"LIST Combat (5%) / Mining (28%)",
		"P Total Votes: 27857",
	})
}

// The page's own title block comes back as the title, even when it names more
// than the listed title; a first title block that is a section gives none.
func TestParseClassicTitleBlock(t *testing.T) {
	page := func(first string) []byte {
		return []byte(`<html><body><div id="contentbody"><div id="post"><div class="wrapper">
<div class="content-block4"><div class="content"><h1>` + first + `</h1></div></div>
<div class="content-block1 rsi-markup"><div class="segment"><div class="content"><p>Body.</p></div></div></div>
</div><div class="two-line-separator"></div></div></div></body></html>`)
	}
	for _, c := range []struct {
		listed, first, want string
		blocks              []string
	}{
		{"Note from the Chairman", "Note from the Chairman: Dual Universe", "Note from the Chairman: Dual Universe", []string{"P Body."}},
		{"Letter from the Chairman", "Letter from the Chairman", "Letter from the Chairman", []string{"P Body."}},
		{"Letter from the Chairman", "The Best of Times, the Worst of Times", "", []string{"H2 The Best of Times, the Worst of Times", "P Body."}},
	} {
		blocks, title, err := ParseClassic(page(c.first), c.listed, chairmanConfig(t))
		if err != nil {
			t.Fatal(err)
		}
		if title != c.want {
			t.Errorf("ParseClassic(%q) title = %q, want %q", c.first, title, c.want)
		}
		check(t, dump(blocks), c.blocks)
	}
}
