package commlink

import "testing"

func TestInfobox(t *testing.T) {
	got := Infobox(PageMeta{
		RSITitle: "Star Citizen Monthly Report: May 2021",
		URL:      "https://robertsspaceindustries.com/comm-link/transmission/18167-Star-Citizen-Monthly-Report-May-2021",
		Series:   "Monthly Reports", Type: "Transmission", Date: "2021-06-02",
	})
	want := "{{CommLink\n| title = Star Citizen Monthly Report: May 2021\n| url = https://robertsspaceindustries.com/comm-link/transmission/18167-Star-Citizen-Monthly-Report-May-2021\n| image =\n| series = Monthly Reports\n| type = Transmission\n| publicationdate = 2021-06-02\n}}\n"
	if got != want {
		t.Errorf("Infobox:\n%s\nwant:\n%s", got, want)
	}
}

func TestRenderBody(t *testing.T) {
	blocks := []Block{
		{Kind: Paragraph, Text: "'''Greetings Citizens!'''"},
		{Kind: Heading, Level: 2, Text: "ENGINEERING"},
		{Kind: Image, Src: "https://x/a.jpg"},
		{Kind: Paragraph, Text: "* starts like a list"},
		{Kind: List, Items: []string{"one", "two"}, Ordered: true},
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
		"[[File:R - 01.jpg|center|frameless|800px]]\n\n" +
		"<nowiki />* starts like a list\n\n" +
		"# one\n# two\n\n" +
		"<blockquote>Quoted</blockquote>\n\n" +
		"[[File:R - 02.png|thumb|center|image by [https://y Name] &#124; credit]]\n\n" +
		"{{#ev:youtube|abc}}\n\n" +
		"{{#ev:vimeo|123}}\n\n" +
		"[https://x/v.mp4 Watch the video]\n"
	if got != want {
		t.Errorf("RenderBody:\n%s\nwant:\n%s", got, want)
	}
}
