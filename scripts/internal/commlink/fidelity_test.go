package commlink

import (
	"reflect"
	"testing"
)

func TestMissing(t *testing.T) {
	page := "{{CommLink\n| title = X\n}}\n\n'''Greetings Citizens!'''\n\n== AI (Content) ==\n\n" +
		"The [[Gladius]] got &#91;new&#93; ''parts'' at [https://x the studio].\n\n" +
		"[[File:A - 01.png|thumb|center|800px|image by [https://y RUSTEC_Urhu]]]\n"
	api := "Greetings Citizens!\n" +
		"AI (Content)The Gladius got [new] parts at the studio.\n" +
		"RUSTEC_Urhu image by\n" +
		"A line that is not there.\n" +
		"Banner placeholder\n\n"
	got := Missing(api, page, func(l string) bool { return l == "Banner placeholder" })
	if want := []string{"A line that is not there."}; !reflect.DeepEqual(got, want) {
		t.Errorf("Missing = %q", got)
	}
}

func TestMissingShortLineNoCaption(t *testing.T) {
	page := "Thanks for the help. Your support is great. Now we proceed.\n"
	api := "Thanks for your support now!\n"
	got := Missing(api, page, func(l string) bool { return false })
	if want := []string{"Thanks for your support now!"}; !reflect.DeepEqual(got, want) {
		t.Errorf("Missing = %q, want %q", got, want)
	}
}

func TestMissingShortLineNotInFileCaption(t *testing.T) {
	page := "Image by RUSTEC_Urhu.\n\n" +
		"[[File:Photo.png|thumb|center|800px|Other photographer's work]]\n"
	api := "RUSTEC_Urhu image by\n"
	got := Missing(api, page, func(l string) bool { return false })
	if want := []string{"RUSTEC_Urhu image by"}; !reflect.DeepEqual(got, want) {
		t.Errorf("Missing = %q, want %q", got, want)
	}
}

func TestMissingCountsTemplateText(t *testing.T) {
	page := "{{CommLink\n| title = Squadron 42 Monthly Report: April 2024\n| url = https://x\n}}\n\nBody text.\n"
	api := "Squadron 42 Monthly Report\nApril 2024\nBody text.\n"
	if got := Missing(api, page, func(string) bool { return false }); len(got) != 0 {
		t.Errorf("Missing = %q, want none: the infobox title is on the page", got)
	}
}

// The API glues a paragraph to the text after it when RSI has an element in
// between that the API leaves out: the "Conclusion" title before the sign-off,
// or an image and a studio title.
func TestMissingGluedAcrossBlocks(t *testing.T) {
	page := "Weapons got nose guns.\n\n[[File:X - 15.png|thumb|center|800px]]\n\n== Conclusion ==\n\n'''WE’LL SEE YOU NEXT MONTH…'''\n\n" +
		"Seen in the future.\n\n[[File:X - 16.png|thumb|center|800px]]\n\n== Austin ==\n\n[[File:X - 17.png|thumb|center|800px]]\n\n=== Design ===\n\nThe design team met.\n"
	api := "Weapons got nose guns. WE’LL SEE YOU NEXT MONTH…\n" +
		"Seen in the future. AUSTIN DESIGN The design team\n" +
		"Weapons got nose guns. A dropped sentence.\n" +
		"Seen in the future. design team met.\n"
	got := Missing(api, page, func(string) bool { return false })
	want := []string{"Weapons got nose guns. A dropped sentence.", "Seen in the future. design team met."}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("Missing = %q, want %q", got, want)
	}
}

// A dropped short heading must not pass as a glue of one-word block edges: a
// block that ends with the heading's first word and a later one that starts
// with its last.
func TestMissingHeadingOnOneWordEdges(t *testing.T) {
	page := "The team shipped new features\n\n== Audio ==\n\nGameplay sounds were recorded.\n"
	api := "Features (Gameplay)\nThe team shipped new features\n"
	got := Missing(api, page, func(string) bool { return false })
	if want := []string{"Features (Gameplay)"}; !reflect.DeepEqual(got, want) {
		t.Errorf("Missing = %q, want %q", got, want)
	}
}

// The API collects illustration credits into lines of their own, the name and
// the intro of one credit, or the names of several, glued with no space.
func TestMissingGluedCredits(t *testing.T) {
	page := "Text.\n\n[[File:A.png|thumb|center|800px|Image by [https://x/1 MaKizaR]]]\n\n" +
		"[[File:B.png|thumb|center|800px|Overall graph view]]\n\n[[File:C.png|thumb|center|800px|Image by yoyoMeg]]\n\n" +
		"[[File:D.png|thumb|center|800px|Bar Citizen Beijing]]\n\n[[File:E.png|thumb|center|800px]]\n"
	api := "MaKizaROverall graph viewImage by\n" +
		"yoyoMegBar Citizen Beijing\n" +
		"MaKizaR image by\n" +
		"daftdigitImage by\n" +
		"graphImage by\n" +
		"800pxImage by\n"
	got := Missing(api, page, func(string) bool { return false })
	want := []string{"daftdigitImage by", "graphImage by", "800pxImage by"}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("Missing = %q, want %q", got, want)
	}
}

// A link's text keeps its own markup (an underlined link).
func TestMissingMarkupInLinkText(t *testing.T) {
	page := "Planning for this year's [https://x <u>CitizenCon</u>] in Manchester is underway.\n"
	api := "Planning for this year's CitizenCon in Manchester is underway.\n"
	if got := Missing(api, page, func(string) bool { return false }); len(got) != 0 {
		t.Errorf("Missing = %q, want none", got)
	}
}

// The API text is fetched independently of the page and never passes through
// escapeText, so a narrow no-break space it carries must still match the
// plain space the page rendering mapped it to.
func TestMissingNarrowNoBreakSpaceInAPIText(t *testing.T) {
	nnbsp := string(rune(0x202F))
	page := "Check out the new ship on display at the show.\n"
	api := "Check out the new ship" + nnbsp + "on display at the show.\n"
	if got := Missing(api, page, func(string) bool { return false }); len(got) != 0 {
		t.Errorf("Missing = %q, want none", got)
	}
}

// escapeText drops a soft hyphen from the page rather than spacing it, so the
// gate must drop it from the API text too, or the API's line splits into two
// words where the page has one and reads as missing.
func TestMissingSoftHyphenInAPIText(t *testing.T) {
	softHyphen := string(rune(0x00AD))
	page := "The cooperation agreement was signed today.\n"
	api := "The co" + softHyphen + "operation agreement was signed today.\n"
	if got := Missing(api, page, func(string) bool { return false }); len(got) != 0 {
		t.Errorf("Missing = %q, want none", got)
	}
}

// An API text under half the body's words is short: the API has not finished
// scraping the report. Media lines are not body words.
func TestAPITextWords(t *testing.T) {
	body := "One two three four five six seven eight.\n\n[[File:A - 01.png|thumb|center|800px|a long caption of many words here]]\n\n{{#ev:youtube|abc}}\n"
	for _, c := range []struct {
		api         string
		apiN, pageN int
		short       bool
	}{
		{"", 0, 8, true},
		{"One two three", 3, 8, true},
		{"One two three four", 4, 8, false},
		{"One two three four five six seven eight.", 8, 8, false},
	} {
		api, page, short := APITextWords(c.api, body)
		if api != c.apiN || page != c.pageN || short != c.short {
			t.Errorf("APITextWords(%q) = %d, %d, %v; want %d, %d, %v", c.api, api, page, short, c.apiN, c.pageN, c.short)
		}
	}
	if _, _, short := APITextWords("", ""); short {
		t.Error("an empty page with empty API text is short")
	}
}
