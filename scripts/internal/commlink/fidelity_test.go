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
