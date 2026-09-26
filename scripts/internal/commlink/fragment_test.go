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
<g-introduction :info="{&quot;title&quot;:&quot;Squadron 42 Monthly Report&quot;,&quot;subtitle&quot;:&quot;April 2024&quot;,&quot;contents&quot;:[&quot;<p>TO: SQUADRON 42 RECRUITS</p><p>Welcome to April’s report.</p>&quot;]}" img-url="/logo.png"></g-introduction>
<g-narrative-group v-cloak=""><g-article :show-emphasis="false" body="<h3><strong>AI (</strong>Content<strong>)</strong></h3><p>April saw the <a href=&quot;https://robertsspaceindustries.com/x&quot;>AI Content</a> team&amp;nbsp;at work.</p>"></g-article>
<g-illustration sign-link-href="https://example.com/thread" sign-name="RUSTEC_Urhu" sign-intro="image by" :simple-image="{&quot;originalFormat&quot;:{&quot;max&quot;:&quot;/i/abc/def/tavern-upload-large-1.png&quot;}}"></g-illustration>
<g-article :show-emphasis="false" body="<p>Continued text.</p>"></g-article>
<g-article :show-emphasis="false" body=""></g-article>
<g-illustration :simple-image="{}" :image="{}"></g-illustration>
<g-badge-condition><g-article :show-emphasis="true" body="<p>See you <strong>next</strong> month!</p>"></g-article></g-badge-condition>
</g-narrative-group><style>.x{}</style><div id="aria-skin-info">skin</div>`

func TestParseFragment(t *testing.T) {
	blocks, err := ParseFragment([]byte(fragmentFixture))
	if err != nil {
		t.Fatal(err)
	}
	check(t, dump(blocks), []string{
		"P TO: SQUADRON 42 RECRUITS",
		"P Welcome to April’s report.",
		"H2 AI (Content)",
		"P April saw the [https://robertsspaceindustries.com/x AI Content] team at work.",
		"IMG https://robertsspaceindustries.com/i/abc/def/tavern-upload-large-1.png | image by [https://example.com/thread RUSTEC_Urhu]",
		"P Continued text.",
		"P '''See you next month!'''",
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
	blocks, err := FetchBlocks(context.Background(), testWeb(t), Candidate{ID: 19956, Title: "X", RSIURL: srv.URL + "/en/comm-link/transmission/19956-X"})
	if err != nil {
		t.Fatal(err)
	}
	check(t, dump(blocks), []string{"H2 Tech", "P Text."})
}
