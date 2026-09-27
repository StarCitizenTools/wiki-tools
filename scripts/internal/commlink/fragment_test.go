package commlink

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
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
	blocks, err := ParseFragment([]byte(fragmentFixture), testConfig(t))
	if err != nil {
		t.Fatal(err)
	}
	check(t, dump(blocks), []string{
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
	blocks, err := ParseFragment([]byte(`<g-article :show-emphasis="true" body="<h3>WE'LL SEE YOU NEXT MONTH...</h3><h3>// END TRANSMISSION</h3>"></g-article>`), testConfig(t))
	if err != nil {
		t.Fatal(err)
	}
	check(t, dump(blocks), []string{
		"P '''WE'LL SEE YOU NEXT MONTH...'''",
		"P '''// END TRANSMISSION'''",
	})

	blocks, err = ParseFragment([]byte(`<g-article :show-emphasis="false" body="<h4>We'll see you next month!</h4>"></g-article>`), testConfig(t))
	if err != nil {
		t.Fatal(err)
	}
	check(t, dump(blocks), []string{"P '''We'll see you next month!'''"})

	// An emphasis article's lines are never read as bold subsection titles.
	blocks, err = ParseFragment([]byte(`<g-article :show-emphasis="true" body="<p>Thanks for reading</p><p>// END TRANSMISSION</p>"></g-article>`), testConfig(t))
	if err != nil {
		t.Fatal(err)
	}
	check(t, dump(blocks), []string{"P '''Thanks for reading'''", "P '''// END TRANSMISSION'''"})

	// Without emphasis, a heading after the sign-off is still part of it.
	blocks, err = ParseFragment([]byte(`<g-article :show-emphasis="false" body="<h3><strong>WE'LL SEE YOU NEXT MONTH...</strong></h3><h3><strong>// END TRANSMISSION</strong></h3>"></g-article>`), testConfig(t))
	if err != nil {
		t.Fatal(err)
	}
	check(t, dump(blocks), []string{
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
	blocks, title, err := FetchBlocks(context.Background(), testWeb(t), testConfig(t), Candidate{ID: 19956, Title: "X", RSIURL: srv.URL + "/en/comm-link/transmission/19956-X"})
	if err != nil {
		t.Fatal(err)
	}
	check(t, dump(blocks), []string{"H2 Tech", "P Text."})
	if title != "" {
		t.Errorf("FetchBlocks title = %q, want none from a fragment", title)
	}
}

// RSI can split one link into anchors with the same href, the last one
// starting with the space between two words.
func TestParseFragmentSplitLink(t *testing.T) {
	blocks, err := ParseFragment([]byte(`<g-article :show-emphasis="false" body="<p>An episode of <a href=&quot;https://youtu.be/x&quot;>Insid</a><a href=&quot;https://youtu.be/x&quot; target=&quot;_blank&quot;>e</a><a href=&quot;https://youtu.be/x&quot;> Star Citizen</a>. Then <a href=&quot;https://a.test/1&quot;>one</a><a href=&quot;https://a.test/2&quot;>two</a>.</p>"></g-article>`), testConfig(t))
	if err != nil {
		t.Fatal(err)
	}
	check(t, dump(blocks), []string{
		"P An episode of [https://youtu.be/x Inside Star Citizen]. Then [https://a.test/1 one][https://a.test/2 two].",
	})
}

// A break at the end of a list item is dropped: the list marker already ends
// the line.
func TestParseFragmentListItemBreaks(t *testing.T) {
	blocks, err := ParseFragment([]byte(`<g-article :show-emphasis="false" body="<ul><li>One<br></li><li>Two<br><br></li><li>Three<br>four</li></ul>"></g-article>`), testConfig(t))
	if err != nil {
		t.Fatal(err)
	}
	check(t, dump(blocks), []string{"LIST One / Two / Three<br />four"})
}

// A letter's fragment: a banner's pull-quote paragraph, a slideshow captioned
// with its title, a trailer and the signature. A banner that shows only a
// title is decoration.
func TestParseFragmentLetterComponents(t *testing.T) {
	blocks, err := ParseFragment([]byte(`<g-banner-advanced :content="{&quot;displayed&quot;:true,&quot;text&quot;:{&quot;displayed&quot;:true,&quot;title&quot;:&quot;LETTER FROM THE CHAIRMAN&quot;,&quot;paragraph&quot;:&quot;&quot;}}"></g-banner-advanced>
<g-article :show-emphasis="false" body="<p>Opening.</p>"></g-article>
<g-banner-advanced :content="{&quot;displayed&quot;:true,&quot;text&quot;:{&quot;displayed&quot;:true,&quot;paragraph&quot;:&quot;<p>“<em>A quote.</em></p><p>- Benoit Beausejour, CTO</p>&quot;}}"></g-banner-advanced>
<g-banner-advanced :content="{&quot;displayed&quot;:false,&quot;text&quot;:{&quot;displayed&quot;:true,&quot;paragraph&quot;:&quot;<p>Hidden.</p>&quot;}}"></g-banner-advanced>
<g-slideshow :images="[&quot;/media/40yh807r62gyjr/source/Building_Out.png&quot;,&quot;/media/x7ywvbjfc8umgr/source/AZ8A4441.jpg&quot;]" :title="&quot;Manchester, England&quot;" :subtitle="&quot;&quot;"></g-slideshow>
<g-trailer arrangement="arrangementB" video-id="zxlci1YJCDA"></g-trailer>
<g-author author-desc="Founder &amp; CEO" author-name="Chris Roberts"></g-author>`), chairmanConfig(t))
	if err != nil {
		t.Fatal(err)
	}
	check(t, dump(blocks), []string{
		"P Opening.",
		"P “''A quote.''",
		"P - Benoit Beausejour, CTO",
		"IMG https://robertsspaceindustries.com/media/40yh807r62gyjr/source/Building_Out.png | Manchester, England",
		"IMG https://robertsspaceindustries.com/media/x7ywvbjfc8umgr/source/AZ8A4441.jpg | Manchester, England",
		"VID youtube zxlci1YJCDA",
		"P Chris Roberts<br />Founder & CEO",
	})
}

// Only the last article is a closing block when emphasised; an emphasised
// article before it is a boxed section, converted as any other.
func TestParseFragmentEmphasisBeforeLastArticle(t *testing.T) {
	blocks, err := ParseFragment([]byte(`<g-article :show-emphasis="true" body="<h2><strong>Building for Longevity</strong></h2><p>We are building offices.</p>"></g-article>
<g-article :show-emphasis="false" body="<h2>Final Thoughts</h2><p>Thank you.</p>"></g-article>
<g-article :show-emphasis="true" body="<p>See you in the verse.</p>"></g-article>
<g-article :show-emphasis="false" body=""></g-article>`), chairmanConfig(t))
	if err != nil {
		t.Fatal(err)
	}
	check(t, dump(blocks), []string{
		"H2 Building for Longevity",
		"P We are building offices.",
		"H2 Final Thoughts",
		"P Thank you.",
		"P '''See you in the verse.'''",
	})
}
