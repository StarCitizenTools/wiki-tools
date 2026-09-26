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
