package commlink

import (
	"context"
	"html"
	"io"
	"net/http"
	"net/http/httptest"
	"reflect"
	"strings"
	"testing"
)

const fragmentFixture = `<div class="turbo-anchor" data-plugin_key="plugin_trblt_banner"></div>
<g-banner-advanced :content="{&quot;text&quot;:{&quot;displayed&quot;:false}}"></g-banner-advanced>
<g-introduction :info="{&quot;title&quot;:&quot;Squadron 42 Monthly Report&quot;,&quot;subtitle&quot;:&quot;April 2024&quot;,&quot;contents&quot;:[&quot;<p><strong>TO: SQUADRON 42 RECRUITS</strong></p><p>Welcome to April’s report.</p>&quot;]}" img-url="/logo.png"></g-introduction>
<g-narrative-group v-cloak=""><g-article :show-emphasis="false" body="<h3><strong>AI (</strong>Content<strong>)</strong></h3><p>April saw the <a href=&quot;https://robertsspaceindustries.com/x&quot;>AI Content</a> team&amp;nbsp;at work.</p>"></g-article>
<g-illustration sign-link-href="https://example.com/thread" sign-name="RUSTEC_Urhu" sign-intro="image by" :simple-image="{&quot;originalFormat&quot;:{&quot;max&quot;:&quot;/i/abc/def/tavern-upload-large-1.png&quot;}}"></g-illustration>
<g-article :show-emphasis="false" body="<p>Continued text.</p>"></g-article>
<g-article :show-emphasis="false" body=""></g-article>
<g-illustration :simple-image="{}" :image="{}"></g-illustration>
<g-badge-condition><g-article :show-emphasis="true" body="<p>See you <strong>next</strong> month!</p>"></g-article></g-badge-condition>
</g-narrative-group><style>.x{}</style><div id="aria-skin-info">skin</div>`

func TestParseFragment(t *testing.T) {
	body, err := ParseFragment([]byte(fragmentFixture), testConfig(t))
	if err != nil {
		t.Fatal(err)
	}
	check(t, dump(body.Blocks), []string{
		"P '''TO: SQUADRON 42 RECRUITS'''",
		"P Welcome to April’s report.",
		"H2 AI (Content)",
		"P April saw the [https://robertsspaceindustries.com/x AI Content] team at work.",
		"IMG https://robertsspaceindustries.com/i/abc/def/tavern-upload-large-1.png | image by [https://example.com/thread RUSTEC_Urhu]",
		"P Continued text.",
		"P '''See you next month!'''",
	})
}

// A closing sign-off sent as headings, not paragraphs: an emphasis article
// turns every heading bold, and a heading matching the "see you next month"
// sign-off turns bold even without emphasis.
func TestParseFragmentSignOff(t *testing.T) {
	body, err := ParseFragment([]byte(`<g-article :show-emphasis="true" body="<h3>WE'LL SEE YOU NEXT MONTH...</h3><h3>// END TRANSMISSION</h3>"></g-article>`), testConfig(t))
	if err != nil {
		t.Fatal(err)
	}
	check(t, dump(body.Blocks), []string{
		"P '''WE'LL SEE YOU NEXT MONTH...'''",
		"P '''// END TRANSMISSION'''",
	})

	body, err = ParseFragment([]byte(`<g-article :show-emphasis="false" body="<h4>We'll see you next month!</h4>"></g-article>`), testConfig(t))
	if err != nil {
		t.Fatal(err)
	}
	check(t, dump(body.Blocks), []string{"P '''We'll see you next month!'''"})

	// An emphasis article's lines are never read as bold subsection titles.
	body, err = ParseFragment([]byte(`<g-article :show-emphasis="true" body="<p>Thanks for reading</p><p>// END TRANSMISSION</p>"></g-article>`), testConfig(t))
	if err != nil {
		t.Fatal(err)
	}
	check(t, dump(body.Blocks), []string{"P '''Thanks for reading'''", "P '''// END TRANSMISSION'''"})

	// Without emphasis, a heading after the sign-off is still part of it.
	body, err = ParseFragment([]byte(`<g-article :show-emphasis="false" body="<h3><strong>WE'LL SEE YOU NEXT MONTH...</strong></h3><h3><strong>// END TRANSMISSION</strong></h3>"></g-article>`), testConfig(t))
	if err != nil {
		t.Fatal(err)
	}
	check(t, dump(body.Blocks), []string{
		"P '''WE'LL SEE YOU NEXT MONTH...'''",
		"P '''// END TRANSMISSION'''",
	})
}

func TestFetchBlocks(t *testing.T) {
	var srv *httptest.Server
	srv = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/en/comm-link/transmission/19956-X":
			io.WriteString(w, `<html><script>const s3Url = '`+srv.URL+`/frag';</script></html>`)
		case "/frag":
			io.WriteString(w, `<g-article body="<h4>Tech</h4><p>Text.</p>"></g-article>`)
		default:
			http.NotFound(w, r)
		}
	}))
	defer srv.Close()
	body, err := FetchBlocks(context.Background(), testWeb(t), testConfig(t), Candidate{ID: 19956, Title: "X", RSIURL: srv.URL + "/en/comm-link/transmission/19956-X"})
	if err != nil {
		t.Fatal(err)
	}
	check(t, dump(body.Blocks), []string{"H2 Tech", "P Text."})
	if body.Title != "" {
		t.Errorf("FetchBlocks title = %q, want none from a fragment", body.Title)
	}
}

// RSI can split one link into anchors with the same href, the last one
// starting with the space between two words.
func TestParseFragmentSplitLink(t *testing.T) {
	body, err := ParseFragment([]byte(`<g-article :show-emphasis="false" body="<p>An episode of <a href=&quot;https://youtu.be/x&quot;>Insid</a><a href=&quot;https://youtu.be/x&quot; target=&quot;_blank&quot;>e</a><a href=&quot;https://youtu.be/x&quot;> Star Citizen</a>. Then <a href=&quot;https://a.test/1&quot;>one</a><a href=&quot;https://a.test/2&quot;>two</a>.</p>"></g-article>`), testConfig(t))
	if err != nil {
		t.Fatal(err)
	}
	check(t, dump(body.Blocks), []string{
		"P An episode of [https://youtu.be/x Inside Star Citizen]. Then [https://a.test/1 one][https://a.test/2 two].",
	})
}

// A break at the end of a list item is dropped: the list marker already ends
// the line.
func TestParseFragmentListItemBreaks(t *testing.T) {
	body, err := ParseFragment([]byte(`<g-article :show-emphasis="false" body="<ul><li>One<br></li><li>Two<br><br></li><li>Three<br>four</li></ul>"></g-article>`), testConfig(t))
	if err != nil {
		t.Fatal(err)
	}
	check(t, dump(body.Blocks), []string{"LIST One / Two / Three<br />four"})
}

// A letter's fragment: a banner's pull-quote paragraph, a slideshow captioned
// with its title, a trailer and the signature. A banner that shows only a
// title is decoration.
func TestParseFragmentLetterComponents(t *testing.T) {
	body, err := ParseFragment([]byte(`<g-banner-advanced :content="{&quot;displayed&quot;:true,&quot;text&quot;:{&quot;displayed&quot;:true,&quot;title&quot;:&quot;LETTER FROM THE CHAIRMAN&quot;,&quot;paragraph&quot;:&quot;&quot;}}"></g-banner-advanced>
<g-article :show-emphasis="false" body="<p>Opening.</p>"></g-article>
<g-banner-advanced :content="{&quot;displayed&quot;:true,&quot;text&quot;:{&quot;displayed&quot;:true,&quot;paragraph&quot;:&quot;<p>“<em>A quote.</em></p><p>- Benoit Beausejour, CTO</p>&quot;}}"></g-banner-advanced>
<g-banner-advanced :content="{&quot;displayed&quot;:false,&quot;text&quot;:{&quot;displayed&quot;:true,&quot;paragraph&quot;:&quot;<p>Hidden.</p>&quot;}}"></g-banner-advanced>
<g-slideshow :images="[&quot;/media/40yh807r62gyjr/source/Building_Out.png&quot;,&quot;/media/x7ywvbjfc8umgr/source/AZ8A4441.jpg&quot;]" :title="&quot;Manchester, England&quot;" :subtitle="&quot;&quot;"></g-slideshow>
<g-trailer arrangement="arrangementB" video-id="zxlci1YJCDA"></g-trailer>
<g-author author-desc="Founder &amp; CEO" author-name="Chris Roberts"></g-author>`), chairmanConfig(t))
	if err != nil {
		t.Fatal(err)
	}
	check(t, dump(body.Blocks), []string{
		"P Opening.",
		"P “''A quote.''",
		"P - Benoit Beausejour, CTO",
		"GALLERY https://robertsspaceindustries.com/media/40yh807r62gyjr/source/Building_Out.png | Manchester, England / https://robertsspaceindustries.com/media/x7ywvbjfc8umgr/source/AZ8A4441.jpg | Manchester, England",
		"VID youtube zxlci1YJCDA",
		"P Chris Roberts<br />Founder & CEO",
	})
}

// A banner or slideshow whose JSON does not parse sends the report to review
// rather than losing its content; a slideshow with no title has no caption.
func TestParseFragmentBadComponentJSON(t *testing.T) {
	for _, c := range []struct{ frag, want string }{
		{`<g-banner-advanced :content="{not json"></g-banner-advanced>`, "g-banner-advanced :content"},
		{`<g-slideshow :images="[&quot;/media/a/source/A.jpg&quot;"></g-slideshow>`, "g-slideshow :images"},
		{`<g-slideshow :images="[&quot;/media/a/source/A.jpg&quot;]" :title="Manchester"></g-slideshow>`, "g-slideshow :title"},
	} {
		if _, err := ParseFragment([]byte(c.frag), chairmanConfig(t)); err == nil || !strings.Contains(err.Error(), c.want) {
			t.Errorf("ParseFragment(%s) = %v, want an error naming %q", c.frag, err, c.want)
		}
	}
	body, err := ParseFragment([]byte(`<g-slideshow :images="[&quot;/media/a/source/A.jpg&quot;]"></g-slideshow>`), chairmanConfig(t))
	if err != nil {
		t.Fatal(err)
	}
	check(t, dump(body.Blocks), []string{"GALLERY https://robertsspaceindustries.com/media/a/source/A.jpg"})
}

// Only the last article is a closing block when emphasised; an emphasised
// article before it is a boxed section, converted as any other.
func TestParseFragmentEmphasisBeforeLastArticle(t *testing.T) {
	body, err := ParseFragment([]byte(`<g-article :show-emphasis="true" body="<h2><strong>Building for Longevity</strong></h2><p>We are building offices.</p>"></g-article>
<g-article :show-emphasis="false" body="<h2>Final Thoughts</h2><p>Thank you.</p>"></g-article>
<g-article :show-emphasis="true" body="<p>See you in the verse.</p>"></g-article>
<g-article :show-emphasis="false" body=""></g-article>`), chairmanConfig(t))
	if err != nil {
		t.Fatal(err)
	}
	check(t, dump(body.Blocks), []string{
		"H2 Building for Longevity",
		"P We are building offices.",
		"H2 Final Thoughts",
		"P Thank you.",
		"P '''See you in the verse.'''",
	})
}

// A fragment story's headings are bold text, links and italics kept, and its
// bold byline stays a paragraph.
func TestParseFragmentStory(t *testing.T) {
	body, err := ParseFragment([]byte(`<g-article v-cloak="" headline="A Gift for Baba" byline="04/13/2021 - 5:00 PM"></g-article>`+
		`<g-article :show-emphasis="false" body="<p><i><strong>By: Will Weissbaum</strong></i></p>`+
		`<h2>Writer's Note: <em>A Gift for Baba</em>. Read <a href=&quot;https://robertsspaceindustries.com/x&quot;>Part One</a>.</h2>`+
		`<h2>Part Two</h2><p>Text.</p><hr><p>More.</p><h2>To be continued<br><br></h2>"></g-article>`), storyConfig(t))
	if err != nil {
		t.Fatal(err)
	}
	check(t, dump(body.Blocks), []string{
		"P '''''By: Will Weissbaum'''''",
		"P '''Writer's Note: ''A Gift for Baba''. Read [https://robertsspaceindustries.com/x Part One].'''",
		"P '''Part Two'''",
		"P Text.",
		"RULE",
		"P More.",
		"P '''To be continued'''",
	})
}

// A Q&A from 2021 on: the introduction titles the page (its overline, title
// and subtitle are labels); a question list is one heading per question, at
// level 2 until a component header opens a section and one below it after;
// a later introduction titles a section; a disclaimer is a section. The API's
// numbered questions and a legacy banner's text slots are labels, a separator
// is decoration, and a title's markup is read as text.
func TestParseFragmentQandA(t *testing.T) {
	body, err := ParseFragment([]byte(`<g-banner><template slot="main-pretitle">Magnificent deepening</template><template slot="main-title">Jeffrey's tube</template></g-banner>
<g-introduction :info="{&quot;overline&quot;:&quot;Q&amp;A&quot;,&quot;title&quot;:&quot;Golem&quot;,&quot;subtitle&quot;:&quot;By Drake&quot;,&quot;contents&quot;:[&quot;<p>We asked the team.</p>&quot;]}"></g-introduction>
<g-faq :question-list="[{&quot;title&quot;:&quot;<font size=5>Is it tough?</font>&quot;,&quot;content&quot;:&quot;<p>Yes.</p>&quot;,&quot;visual&quot;:{&quot;displayed&quot;:true}},{&quot;title&quot;:&quot; &quot;,&quot;content&quot;:&quot;<p>Orphan.</p>&quot;}]"></g-faq>
<g-introduction :info="{&quot;overline&quot;:&quot;About the&quot;,&quot;title&quot;:&quot;Golem OX&quot;,&quot;subtitle&quot;:&quot;By Drake&quot;,&quot;contents&quot;:[&quot;<p>The OX.</p>&quot;]}"></g-introduction>
<g-platform-client-component :properties="{&quot;componentId&quot;:&quot;Separator&quot;,&quot;componentProps&quot;:{&quot;variant&quot;:&quot;outline&quot;}}"></g-platform-client-component>
<g-faq :question-list="[{&quot;title&quot;:&quot;Does it fit?&quot;,&quot;content&quot;:&quot;<p>No.</p>&quot;}]"></g-faq>
<g-disclaimer><template slot="title">DISCLAIMER</template><template slot="content"><p>Answers may change.</p></template></g-disclaimer>`), engineeringConfig(t))
	if err != nil {
		t.Fatal(err)
	}
	check(t, dump(body.Blocks), []string{
		"P We asked the team.",
		"H2 Is it tough?",
		"P Yes.",
		"H2 Golem OX",
		"P The OX.",
		"H3 Does it fit?",
		"P No.",
		"H2 DISCLAIMER",
		"P Answers may change.",
	})
	want := []string{"Magnificent deepening", "Jeffrey's tube", "Q&A", "By Drake", "Golem", "1. Is it tough?", "About the", "By Drake", "1. Does it fit?", "DISCLAIMER"}
	if !reflect.DeepEqual(body.Labels, want) {
		t.Errorf("labels = %q, want %q", body.Labels, want)
	}
}

// The platform components of the newest Q&As: a header opens a section with
// its title and text, a question list, an advanced banner's paragraph and a
// trailer convert as their g- counterparts do. A first g-header titles the
// page; a later one opens a section. A component whose JSON does not parse
// sends the report to review.
func TestParseFragmentPlatformComponents(t *testing.T) {
	prop := func(id, props string) string {
		return `<g-platform-client-component :properties="` + html.EscapeString(`{"componentId":"`+id+`","componentProps":`+props+`}`) + `"></g-platform-client-component>`
	}
	body, err := ParseFragment([]byte(`<g-header><template slot="title"><p>Q&amp;A: Paladin</p></template><template slot="content"><p>Intro.</p></template></g-header>
<g-header><template slot="title"><p>Anvil Paladin</p></template></g-header>`+
		prop("ArtemisHeader", `{"overline":"","title":"ORIGIN M80","subtitle":"","content":"<p>A fighter.</p>"}`)+
		prop("ArtemisFaq", `{"questionList":[{"title":"Why?","content":"<p>Because.</p>","visual":{"displayed":false}}]}`)+
		prop("ArtemisBannerAdvanced", `{"content":{"displayed":true,"text":{"displayed":true,"paragraph":"<p>A quote.</p>"}}}`)+
		prop("ArtemisTrailer", `{"title":"","videoId":"CFoQp6wRjPo"}`)+
		prop("Background", `{"layers":[]}`)), engineeringConfig(t))
	if err != nil {
		t.Fatal(err)
	}
	check(t, dump(body.Blocks), []string{
		"P Intro.",
		"H2 Anvil Paladin",
		"H2 ORIGIN M80",
		"P A fighter.",
		"H3 Why?",
		"P Because.",
		"P A quote.",
		"VID youtube CFoQp6wRjPo",
	})
	if want := []string{"Q&A: Paladin", "1. Why?"}; !reflect.DeepEqual(body.Labels, want) {
		t.Errorf("labels = %q, want %q", body.Labels, want)
	}
	for _, frag := range []string{
		`<g-faq :question-list="[{"></g-faq>`,
		`<g-platform-client-component :properties="{"></g-platform-client-component>`,
		prop("ArtemisFaq", `{"questionList":"x"}`),
	} {
		if _, err := ParseFragment([]byte(frag), engineeringConfig(t)); err == nil {
			t.Errorf("ParseFragment(%s) accepted bad JSON", frag)
		}
	}
}

// A header article's byline dates the page by the day it shows; a byline in
// any other form, or a later one, is ignored.
func TestParseFragmentBylineDate(t *testing.T) {
	for frag, want := range map[string]string{
		`<g-article byline="12/30/2022 - 12:57 AM" headline="Letter From the Chairman" v-cloak=""></g-article><g-article body="<p>Text.</p>"></g-article>`:                     "2022-12-30",
		`<g-article v-cloak="" headline="A Gift for Baba" byline="04/13/2021 - 5:00 PM"></g-article><g-article byline="05/11/2021 - 5:00 PM" body="<p>Text.</p>"></g-article>`: "2021-04-13",
		`<g-article byline="Yesterday" headline="X"></g-article><g-article body="<p>Text.</p>"></g-article>`:                                                                   "",
		`<g-article byline="13/45/2022 - 1:00 PM" headline="X"></g-article><g-article body="<p>Text.</p>"></g-article>`:                                                        "",
		`<g-article body="<p>Text.</p>"></g-article>`: "",
	} {
		body, err := ParseFragment([]byte(frag), chairmanConfig(t))
		if err != nil {
			t.Fatal(err)
		}
		if body.Date != want {
			t.Errorf("ParseFragment(%s).Date = %q, want %q", frag, body.Date, want)
		}
	}
}

// With bannerImages an advanced banner that shows no text is its background
// picture, in place; one showing a paragraph stays text. Without it a
// text-less banner is dropped.
func TestParseFragmentBannerImages(t *testing.T) {
	media := func(name string) string {
		return html.EscapeString(`{"background":{"picture":{"originalFormat":{"desktop":"/i/a/resize(3000)/` + name + `","max":"/i/b/key/` + name + `"}},"video":{}}}`)
	}
	frag := `<g-banner-advanced :content="{&quot;displayed&quot;:false}" :media="` + media("hero.jpg") + `"></g-banner-advanced>
<g-introduction :info="{&quot;title&quot;:&quot;Golem&quot;,&quot;contents&quot;:[&quot;<p>We asked.</p>&quot;]}"></g-introduction>
<g-banner-advanced :content="{&quot;displayed&quot;:true,&quot;text&quot;:{&quot;displayed&quot;:true,&quot;paragraph&quot;:&quot;<p>A quote.</p>&quot;}}" :media="` + media("quote.jpg") + `"></g-banner-advanced>
<g-platform-client-component :properties="` + html.EscapeString(`{"componentId":"ArtemisBannerAdvanced","componentProps":{"content":{"displayed":true,"text":{"displayed":false}},"media":{"background":{"picture":{"originalFormat":{"max":"/i/c/key/section.jpg"}}}}}}`) + `"></g-platform-client-component>`
	body, err := ParseFragment([]byte(frag), engineeringConfig(t))
	if err != nil {
		t.Fatal(err)
	}
	check(t, dump(body.Blocks), []string{
		"IMG https://robertsspaceindustries.com/i/b/key/hero.jpg",
		"P We asked.",
		"P A quote.",
		"IMG https://robertsspaceindustries.com/i/c/key/section.jpg",
	})
	body, err = ParseFragment([]byte(frag), chairmanConfig(t))
	if err != nil {
		t.Fatal(err)
	}
	check(t, dump(body.Blocks), []string{"P We asked.", "P A quote."})
	if _, err := ParseFragment([]byte(`<g-banner-advanced :content="{}" :media="{bad"></g-banner-advanced><g-article body="<p>x</p>"></g-article>`), engineeringConfig(t)); err == nil || !strings.Contains(err.Error(), ":media") {
		t.Errorf("a banner whose media does not parse = %v, want an error", err)
	}
}

// An unknown platform component sends the report to review; a separator and
// a page background are decoration.
func TestParseFragmentUnknownComponent(t *testing.T) {
	prop := func(id string) string {
		return `<g-platform-client-component :properties="` + html.EscapeString(`{"componentId":"`+id+`","componentProps":{}}`) + `"></g-platform-client-component>`
	}
	body, err := ParseFragment([]byte(prop("Separator")+prop("Background")+`<g-article body="<p>Text.</p>"></g-article>`), engineeringConfig(t))
	if err != nil {
		t.Fatal(err)
	}
	check(t, dump(body.Blocks), []string{"P Text."})
	if _, err := ParseFragment([]byte(prop("ArtemisCarousel")+`<g-article body="<p>Text.</p>"></g-article>`), engineeringConfig(t)); err == nil || !strings.Contains(err.Error(), `"ArtemisCarousel"`) {
		t.Errorf("an unknown component = %v, want an error naming it", err)
	}
}
