package systemmap

import (
	"strings"
	"testing"
)

// TestCompareReportsAChangeToEitherOfTwoBodiesSharingALabel guards the -diff
// report against the same ambiguity the overlay keys had.
//
// Two bodies can share a label, because upstream leaves some unnamed and the
// designation stands in: Ellis has two called "Ellis XI". Indexing the report on
// the label alone let the second overwrite the first, so a change to either
// printed "no differences" — a diff that lies about drift is worse than no diff,
// because it is the thing the exit code is trusted on.
func TestCompareReportsAChangeToEitherOfTwoBodiesSharingALabel(t *testing.T) {
	twins := func(firstPage string) *Document {
		doc := &Document{Doc: "doc"}
		doc.Systems.Set("Ellis", &System{
			Page: "Ellis system",
			Star: Body{Page: "Ellis (star)", Label: "Ellis"},
			Bodies: []Body{
				{Page: firstPage, Label: "Ellis XI", Tier: tierBelt},
				{Page: "Ellis XI", Label: "Ellis XI", Moons: &[]Body{}},
			},
		})
		return doc
	}

	got := strings.Join(Compare(twins("Ellis XI"), twins("Ellis XI (cluster)")), "\n")
	if strings.Contains(got, "no differences") {
		t.Fatalf("a changed page on the first of two same-labelled bodies went unreported:\n%s", got)
	}
	if !strings.Contains(got, "Ellis XI (cluster)") {
		t.Errorf("the report should name the new value:\n%s", got)
	}

	if got := strings.Join(Compare(twins("Ellis XI"), twins("Ellis XI")), "\n"); got != "no differences" {
		t.Errorf("two identical documents should compare clean, got:\n%s", got)
	}
}
