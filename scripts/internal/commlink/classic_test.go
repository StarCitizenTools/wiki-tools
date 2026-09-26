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

// An intro heading holding several paragraphs split by <br><br> (16743, 16790).
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
