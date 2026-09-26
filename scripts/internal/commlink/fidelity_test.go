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
		"[[File:Photo.png|thumb|center|Other photographer's work]]\n"
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
// between that the API leaves out: the "Conclusion" title before the sign-off
// (16999), or an image and a studio title (16551).
func TestMissingGluedAcrossBlocks(t *testing.T) {
	page := "Weapons got nose guns.\n\n[[File:X - 15.png|center|frameless|800px]]\n\n== Conclusion ==\n\n'''WE’LL SEE YOU NEXT MONTH…'''\n\n" +
		"Seen in the future.\n\n[[File:X - 16.png|center|frameless|800px]]\n\n== Austin ==\n\n[[File:X - 17.png|center|frameless|800px]]\n\n=== Design ===\n\nThe design team met.\n"
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

// The API collects illustration credits into lines of their own, the name and
// the intro of one credit, or the names of several, glued with no space
// (19317, 20220, 20620).
func TestMissingGluedCredits(t *testing.T) {
	page := "Text.\n\n[[File:A.png|thumb|center|Image by [https://x/1 MaKizaR]]]\n\n" +
		"[[File:B.png|thumb|center|Overall graph view]]\n\n[[File:C.png|thumb|center|Image by yoyoMeg]]\n\n" +
		"[[File:D.png|thumb|center|Bar Citizen Beijing]]\n\n[[File:E.png|center|frameless|800px]]\n"
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
