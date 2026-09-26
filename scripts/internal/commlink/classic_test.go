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
	blocks, err := ParseClassic(shell, title)
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
	blocks, err := ParseClassic(shell, "Star Citizen Monthly Report: September 2018")
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
	blocks, err := ParseClassic(shell, "Monthly Studio Report: April 2017")
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
	blocks, err := ParseClassic(shell, "Star Citizen Monthly Report: January 2019")
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
	blocks, err := ParseClassic(shell, "Star Citizen Monthly Report: July 2020")
	if err != nil {
		t.Fatal(err)
	}
	check(t, dump(blocks), []string{"P See [https://robertsspaceindustries.com/comm-link/x/1-Y Inside Star Citizen] now."})
}

func TestDetect(t *testing.T) {
	shell := []byte(`<html><script>const s3Url = 'https://robertsspaceindustries.com/alexandria/html/fromHeap/x/19956/abc-default.html';</script></html>`)
	layout, frag, err := Detect(shell)
	if err != nil || layout != LayoutFragment || frag != "https://robertsspaceindustries.com/alexandria/html/fromHeap/x/19956/abc-default.html" {
		t.Errorf("fragment shell: %v %q %v", layout, frag, err)
	}
	classic, _ := os.ReadFile("testdata/classic_team.html")
	if layout, _, err := Detect(classic); err != nil || layout != LayoutClassic {
		t.Errorf("classic page: %v %v", layout, err)
	}
	if _, _, err := Detect([]byte(`<html><body><p>x</p></body></html>`)); err == nil {
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
	blocks, err := ParseClassic(shell, "Star Citizen Monthly Report: November 2017")
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
