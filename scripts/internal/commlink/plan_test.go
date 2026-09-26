package commlink

import (
	"encoding/json"
	"reflect"
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

func TestCreateLines(t *testing.T) {
	p := &Plan{Create: []PageEntry{{ID: 16294, Page: "Monthly Report - November 2017"}, {ID: 16363, Page: "Monthly Report - December 2017"}}}
	want := []string{"16294 Monthly Report - November 2017", "16363 Monthly Report - December 2017"}
	if got := p.CreateLines(); !reflect.DeepEqual(got, want) {
		t.Errorf("CreateLines = %q", got)
	}
}

// Lists a plan or a page lacks are written as [], never null.
func TestPlanJSONEmptyLists(t *testing.T) {
	data, err := json.Marshal(&Plan{Create: []PageEntry{{ID: 1}}})
	if err != nil {
		t.Fatal(err)
	}
	var got struct {
		Create []map[string]json.RawMessage `json:"create"`
		Review json.RawMessage              `json:"review"`
		Dis    json.RawMessage              `json:"discoveryDisagreements"`
	}
	if err := json.Unmarshal(data, &got); err != nil {
		t.Fatal(err)
	}
	if string(got.Review) != "[]" || string(got.Dis) != "[]" ||
		string(got.Create[0]["images"]) != "[]" || string(got.Create[0]["links"]) != "[]" {
		t.Errorf("plan JSON = %s", data)
	}
	if _, ok := got.Create[0]["missingImages"]; ok {
		t.Errorf("missingImages written for a page with none: %s", data)
	}
}
