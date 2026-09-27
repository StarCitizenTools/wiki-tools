package commlink

import (
	"reflect"
	"testing"
)

func TestMissing(t *testing.T) {
	page := "{{CommLink\n| title = X\n}}\n\n'''Greetings Citizens!'''\n\n== AI (Content) ==\n\n" +
		"The [[Gladius]] got &#91;new&#93; ''parts'' at [https://x the studio].\n\n" +
		"[[File:A - 01.png|thumb|center|image by [https://y RUSTEC_Urhu]]]\n"
	api := "Greetings Citizens!\n" +
		"AI (Content)The Gladius got [new] parts at the studio.\n" +
		"RUSTEC_Urhu image by\n" +
		"A line that is not there.\n" +
		"Banner placeholder\n\n"
	got := Missing(api, page, nil, func(l string) bool { return l == "Banner placeholder" })
	if want := []string{"A line that is not there."}; !reflect.DeepEqual(got, want) {
		t.Errorf("Missing = %q", got)
	}
}

func TestMissingShortLineNotInFileCaption(t *testing.T) {
	page := "Image by RUSTEC_Urhu.\n\n" +
		"[[File:Photo.png|thumb|center|Other photographer's work]]\n"
	api := "RUSTEC_Urhu image by\n"
	got := Missing(api, page, nil, func(l string) bool { return false })
	if want := []string{"RUSTEC_Urhu image by"}; !reflect.DeepEqual(got, want) {
		t.Errorf("Missing = %q, want %q", got, want)
	}
}

func TestMissingCountsTemplateText(t *testing.T) {
	page := "{{CommLink\n| title = Squadron 42 Monthly Report: April 2024\n| url = https://x\n}}\n\nBody text.\n"
	api := "Squadron 42 Monthly Report\nApril 2024\nBody text.\n"
	if got := Missing(api, page, nil, func(string) bool { return false }); len(got) != 0 {
		t.Errorf("Missing = %q, want none: the infobox title is on the page", got)
	}
}

// The API glues a paragraph to the text after it when RSI has an element in
// between that the API leaves out: the "Conclusion" title before the sign-off,
// or an image and a studio title.
func TestMissingGluedAcrossBlocks(t *testing.T) {
	page := "Weapons got nose guns.\n\n[[File:X - 15.png|thumb|center]]\n\n== Conclusion ==\n\n'''WE’LL SEE YOU NEXT MONTH…'''\n\n" +
		"Seen in the future.\n\n[[File:X - 16.png|thumb|center]]\n\n== Austin ==\n\n[[File:X - 17.png|thumb|center]]\n\n=== Design ===\n\nThe design team met.\n"
	api := "Weapons got nose guns. WE’LL SEE YOU NEXT MONTH…\n" +
		"Seen in the future. AUSTIN DESIGN The design team\n" +
		"Weapons got nose guns. A dropped sentence.\n" +
		"Seen in the future. design team met.\n"
	got := Missing(api, page, nil, func(string) bool { return false })
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
	got := Missing(api, page, nil, func(string) bool { return false })
	if want := []string{"Features (Gameplay)"}; !reflect.DeepEqual(got, want) {
		t.Errorf("Missing = %q, want %q", got, want)
	}
}

// The API collects illustration credits into lines of their own, the name and
// the intro of one credit, or the names of several, glued with no space.
func TestMissingGluedCredits(t *testing.T) {
	page := "Text.\n\n[[File:A.png|thumb|center|Image by [https://x/1 MaKizaR]]]\n\n" +
		"[[File:B.png|thumb|center|Overall graph view]]\n\n[[File:C.png|thumb|center|Image by yoyoMeg]]\n\n" +
		"[[File:D.png|thumb|center|Bar Citizen Beijing]]\n\n[[File:E.png|thumb|center]]\n"
	api := "MaKizaROverall graph viewImage by\n" +
		"yoyoMegBar Citizen Beijing\n" +
		"MaKizaR image by\n" +
		"daftdigitImage by\n" +
		"graphImage by\n" +
		"800pxImage by\n"
	got := Missing(api, page, nil, func(string) bool { return false })
	want := []string{"daftdigitImage by", "graphImage by", "800pxImage by"}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("Missing = %q, want %q", got, want)
	}
}

// A link's text keeps its own markup (an underlined link).
func TestMissingMarkupInLinkText(t *testing.T) {
	page := "Planning for this year's [https://x <u>CitizenCon</u>] in Manchester is underway.\n"
	api := "Planning for this year's CitizenCon in Manchester is underway.\n"
	if got := Missing(api, page, nil, func(string) bool { return false }); len(got) != 0 {
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
	if got := Missing(api, page, nil, func(string) bool { return false }); len(got) != 0 {
		t.Errorf("Missing = %q, want none", got)
	}
}

// An API text under half the body's words is short: the API has not finished
// scraping the report. Media lines are not body words.
func TestAPITextWords(t *testing.T) {
	body := "One two three four five six seven eight.\n\n[[File:A - 01.png|thumb|center|a long caption of many words here]]\n\n{{#ev:youtube|abc}}\n"
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

// The API runs a row of captioned images into the paragraph after them; each
// captioned image's block is its caption. Out of page order, the line is still
// missing.
func TestMissingGluedCaptions(t *testing.T) {
	page := "Intro.\n\n[[File:A - 01.jpg|thumb|center|Stanton III - Casaba Outlet]]\n\n" +
		"[[File:A - 02.jpg|thumb|center|Stanton III - Dumper's Depot]]\n\n[[File:A - 03.jpg|thumb|center]]\n\n" +
		"The $48 million stretch goal was the commercial.\n"
	api := "Stanton III - Casaba Outlet Stanton III - Dumper's Depot The $48 million stretch goal\n" +
		"Stanton III - Dumper's Depot Stanton III - Casaba Outlet The $48 million stretch goal\n"
	got := Missing(api, page, nil, func(string) bool { return false })
	if want := []string{"Stanton III - Dumper's Depot Stanton III - Casaba Outlet The $48 million stretch goal"}; !reflect.DeepEqual(got, want) {
		t.Errorf("Missing = %q, want %q", got, want)
	}
}

// A gallery's text is its captions, the gallery's own and each slide's: they
// are page text, a block for the glued-line check and pieces of a credit, and
// none counts toward the body's words.
func TestMissingGalleryCaptions(t *testing.T) {
	page := "Intro.\n\n<gallery caption=\"Manchester, &quot;England&quot;\">\nFile:A - 01.jpg\nFile:A - 02.jpg\n</gallery>\n\n" +
		"<gallery>\nFile:A - 03.jpg|Gladiator - Original\nFile:A - 04.jpg|image by [https://y RUSTEC_Urhu]\n</gallery>\n\n" +
		"The team moved offices.\n"
	api := "Manchester, \"England\"\n" +
		"Gladiator - Original\n" +
		"Gladiator - Original image by RUSTEC_Urhu The team moved offices.\n" +
		"RUSTEC_Urhu image by\n" +
		"A01 jpg\n"
	got := Missing(api, page, nil, func(string) bool { return false })
	if want := []string{"A01 jpg"}; !reflect.DeepEqual(got, want) {
		t.Errorf("Missing = %q, want %q", got, want)
	}
	if _, words, _ := APITextWords("", page); words != 5 {
		t.Errorf("APITextWords page words = %d, want 5: galleries are not body text", words)
	}
}

// The API drops "$" and up to two digits of a dollar amount.
func TestMissingDollarAmounts(t *testing.T) {
	page := "2019 was a record year, with $48 million in sales, and our first $100 million+ year.\n"
	api := "2019 was a record year, with million in sales, and our first 0 million+ year.\n" +
		"2019 was a record year, with $48 million in sales, and our first $100 million+ year.\n" +
		"2019 was a record year, with 49 million in sales\n"
	got := Missing(api, page, nil, func(string) bool { return false })
	if want := []string{"2019 was a record year, with 49 million in sales"}; !reflect.DeepEqual(got, want) {
		t.Errorf("Missing = %q, want %q", got, want)
	}
}

// A line that fails is checked again without the page's labels: the API runs
// a disclaimer's title into its text, an introduction's title into the line
// before it, and a banner's slots into each other, and numbers a list's
// questions. A label never hides a line whose rest is not on the page.
func TestMissingLabels(t *testing.T) {
	page := "{{CommLink\n| title = Q&A: Origin 400i\n}}\n\nNow that the 400i has been revealed, here are the answers.\n\n" +
		"== Is it big? ==\n\nYes.\n\n== Disclaimer ==\n\nThe answers reflect intentions.\n"
	labels := []string{"Origin 400i Q&A", "Magnificent deepening", "Jeffrey's tube", "1. Is it big?", "DISCLAIMER"}
	api := "Now that the 400i has been revealed, here are the answers.Origin 400i Q&A\n" +
		"Magnificent deepeningJeffrey's tube\n" +
		"1. Is it big?\n" +
		"DISCLAIMERThe answers reflect intentions.\n" +
		"DISCLAIMERThe answers were dropped.\n" +
		"2. Is it small?\n"
	got := Missing(api, page, labels, func(string) bool { return false })
	want := []string{"DISCLAIMERThe answers were dropped.", "2. Is it small?"}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("Missing = %q, want %q", got, want)
	}
}

// A table's markup is no text: its cells read in row order, so an API line
// that runs from the paragraph before a table into its cells is on the page.
func TestMissingTable(t *testing.T) {
	page := "Both, yeah?\n\n{| class=\"wikitable\"\n|-\n! Ship Type\n! colspan=\"2\" | Missiles\n|-\n| Gladius\n| rowspan=\"2\" | 4x S2\n|}\n"
	api := "Both, yeah? Ship Type Missiles Gladius 4x S2\nShip Type colspan Missiles\n"
	got := Missing(api, page, nil, func(string) bool { return false })
	if want := []string{"Ship Type colspan Missiles"}; !reflect.DeepEqual(got, want) {
		t.Errorf("Missing = %q, want %q", got, want)
	}
}
