package commlink

import (
	"strings"
	"testing"
)

func TestDrift(t *testing.T) {
	if (&Plan{}).Drift(nil) {
		t.Error("an empty plan drifts")
	}
	if !(&Plan{Create: []PageEntry{{ID: 1}}}).Drift(nil) {
		t.Error("a page to create does not drift")
	}
	p := &Plan{Review: []ReviewEntry{{ID: 18078}}}
	if p.Drift([]int{18078}) {
		t.Error("a known review entry drifts")
	}
	if !p.Drift(nil) {
		t.Error("an unknown review entry does not drift")
	}
}

func TestReport(t *testing.T) {
	p := &Plan{
		Create: []PageEntry{
			{ID: 1, DateSource: DateWayback, Images: []ImagePlan{{Action: "upload"}, {Action: "reuse"}}},
			{ID: 2, DateSource: DateRSI}, {ID: 3, DateSource: DateRSI}, {ID: 4, DateSource: DateAPI},
		},
		Review:        []ReviewEntry{{ID: 18078, Page: "Squadron 42 Monthly Report - March 2021", Reason: ReasonFetch}},
		Disagreements: []Disagreement{{ID: 18078, Title: "Squadron 42 Monthly Report: March 2021", FoundBy: FoundByTitle}},
	}
	got := strings.Join(p.Report(), "\n")
	for _, want := range []string{
		"create: 4 pages (1 images to upload, 1 reused; dated by rsi 2, api 1, wayback 1)",
		"review: 1",
		"18078 Squadron 42 Monthly Report - March 2021: fetch-or-parse",
		"found only by api-title: 18078 Squadron 42 Monthly Report: March 2021",
	} {
		if !strings.Contains(got, want) {
			t.Errorf("report lacks %q:\n%s", want, got)
		}
	}
}
