package commlink

import "testing"

func TestInfobox(t *testing.T) {
	for _, c := range []struct {
		m    PageMeta
		want string
	}{
		{
			PageMeta{
				RSITitle: "Star Citizen Monthly Report: May 2021",
				URL:      "https://robertsspaceindustries.com/comm-link/transmission/18167-Star-Citizen-Monthly-Report-May-2021",
				Series:   "Monthly Reports", Type: "Transmission", Date: "2021-06-02",
			},
			"{{CommLink\n| title = Star Citizen Monthly Report: May 2021\n| url = https://robertsspaceindustries.com/comm-link/transmission/18167-Star-Citizen-Monthly-Report-May-2021\n| image =\n| series = Monthly Reports\n| type = Transmission\n| publicationdate = 2021-06-02\n}}\n",
		},
		{
			PageMeta{RSITitle: "A | B {{x}}", URL: "https://example.com", Series: "Series", Type: "Type", Date: "2021-01-01"},
			"{{CommLink\n| title = A &#124; B &#123;&#123;x&#125;&#125;\n| url = https://example.com\n| image =\n| series = Series\n| type = Type\n| publicationdate = 2021-01-01\n}}\n",
		},
	} {
		if got := Infobox(c.m); got != c.want {
			t.Errorf("Infobox:\n%s\nwant:\n%s", got, c.want)
		}
	}
}

func TestRenderBody(t *testing.T) {
	blocks := []Block{
		{Kind: Paragraph, Text: "'''Greetings Citizens!'''"},
		{Kind: Heading, Level: 2, Text: "ENGINEERING"},
		{Kind: Image, Src: "https://x/a.jpg"},
		{Kind: Paragraph, Text: "* starts like a list"},
		{Kind: List, Items: []string{"one", "two"}, Ordered: true},
		{Kind: List, Items: []string{"three", "four"}},
		{Kind: Quote, Text: "Quoted"},
		{Kind: Image, Src: "https://x/b.png", Caption: "image by [https://y Name] | credit"},
		{Kind: Video, VideoKind: "youtube", VideoID: "abc"},
		{Kind: Video, VideoKind: "vimeo", VideoID: "123"},
		{Kind: Video, VideoKind: "file", Src: "https://x/v.mp4"},
		{Kind: Image, Src: "https://x/unplanned.jpg"},
	}
	files := map[string]string{"https://x/a.jpg": "R - 01.jpg", "https://x/b.png": "R - 02.png"}
	got := RenderBody(blocks, NewHeadCaser(nil, ""), func(src string) string { return files[src] })
	want := "'''Greetings Citizens!'''\n\n" +
		"== Engineering ==\n\n" +
		"[[File:R - 01.jpg|thumb|center]]\n\n" +
		"<nowiki />* starts like a list\n\n" +
		"# one\n# two\n\n" +
		"* three\n* four\n\n" +
		"<blockquote>Quoted</blockquote>\n\n" +
		"[[File:R - 02.png|thumb|center|image by [https://y Name] &#124; credit]]\n\n" +
		"{{#ev:youtube|abc}}\n\n" +
		"{{#ev:vimeo|123}}\n\n" +
		"[https://x/v.mp4 Watch the video]\n"
	if got != want {
		t.Errorf("RenderBody:\n%s\nwant:\n%s", got, want)
	}
}

// A slideshow is one <gallery>. A caption all its slides share is the
// gallery's, given once and escaped for the attribute; otherwise each slide
// keeps its own. A slide without a file is left out, and a gallery without
// any renders nothing. A lone image stays a thumb.
func TestRenderGallery(t *testing.T) {
	slide := func(src, caption string) Block { return Block{Kind: Image, Src: "https://x/" + src, Caption: caption} }
	files := map[string]string{"https://x/a.jpg": "R - 01.jpg", "https://x/b.jpg": "R - 02.jpg", "https://x/c.jpg": "R - 03.jpg"}
	blocks := []Block{
		{Kind: Gallery, Images: []Block{slide("a.jpg", `Manchester, "England" | UK`), slide("b.jpg", `Manchester, "England" | UK`)}},
		{Kind: Gallery, Images: []Block{slide("a.jpg", "Gladiator - Original"), slide("b.jpg", "Turret | Variant"), slide("unplanned.jpg", "Gone"), slide("c.jpg", "")}},
		{Kind: Gallery, Images: []Block{slide("a.jpg", ""), slide("b.jpg", "")}},
		{Kind: Gallery, Images: []Block{slide("unplanned.jpg", "Gone")}},
		{Kind: Image, Src: "https://x/c.jpg", Caption: "Alone"},
	}
	got := RenderBody(blocks, NewHeadCaser(nil, ""), func(src string) string { return files[src] })
	want := "<gallery caption=\"Manchester, &quot;England&quot; &#124; UK\">\nFile:R - 01.jpg\nFile:R - 02.jpg\n</gallery>\n\n" +
		"<gallery>\nFile:R - 01.jpg|Gladiator - Original\nFile:R - 02.jpg|Turret &#124; Variant\nFile:R - 03.jpg\n</gallery>\n\n" +
		"<gallery>\nFile:R - 01.jpg\nFile:R - 02.jpg\n</gallery>\n\n" +
		"[[File:R - 03.jpg|thumb|center|Alone]]\n"
	if got != want {
		t.Errorf("RenderBody:\n%s\nwant:\n%s", got, want)
	}
}

// A slideshow that shows one image, alone or after its other slides are left
// out, is a thumb with that slide's caption, never a one-image gallery.
func TestRenderGallerySingleSlide(t *testing.T) {
	slide := func(src, caption string) Block { return Block{Kind: Image, Src: "https://x/" + src, Caption: caption} }
	files := map[string]string{"https://x/a.jpg": "R - 01.jpg", "https://x/b.jpg": "R - 02.jpg"}
	blocks := []Block{
		{Kind: Gallery, Images: []Block{slide("a.jpg", "")}},
		{Kind: Gallery, Images: []Block{slide("unplanned.jpg", "Gone"), slide("b.jpg", "Road | to PES")}},
	}
	got := RenderBody(blocks, NewHeadCaser(nil, ""), func(src string) string { return files[src] })
	want := "[[File:R - 01.jpg|thumb|center]]\n\n[[File:R - 02.jpg|thumb|center|Road &#124; to PES]]\n"
	if got != want {
		t.Errorf("RenderBody:\n%s\nwant:\n%s", got, want)
	}
}

func TestRenderBodyInvalidVideoIDs(t *testing.T) {
	blocks := []Block{
		{Kind: Video, VideoKind: "vimeo", VideoID: "12a|b}}"},
		{Kind: Video, VideoKind: "youtube", VideoID: "invalid|id"},
	}
	got := RenderBody(blocks, NewHeadCaser(nil, ""), func(src string) string { return "" })
	want := "\n"
	if got != want {
		t.Errorf("RenderBody with invalid video IDs should render nothing:\n%s\nwant:\n%s", got, want)
	}
}

func TestRenderRule(t *testing.T) {
	blocks := []Block{{Kind: Paragraph, Text: "One."}, {Kind: Rule}, {Kind: Paragraph, Text: "Two."}}
	got := RenderBody(blocks, NewHeadCaser(nil, ""), func(string) string { return "" })
	if want := "One.\n\n----\n\nTwo.\n"; got != want {
		t.Errorf("RenderBody = %q, want %q", got, want)
	}
}
