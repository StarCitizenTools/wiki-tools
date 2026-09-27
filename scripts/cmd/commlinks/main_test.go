package main

import (
	"os"
	"path/filepath"
	"reflect"
	"slices"
	"sort"
	"strings"
	"testing"

	"github.com/StarCitizenTools/wiki-tools/scripts/internal/mediawiki"
)

func TestDefaultOut(t *testing.T) {
	for config, want := range map[string]string{
		"cmd/commlinks/config.json":                    "out/commlinks",
		"cmd/commlinks/config.chairman.json":           "out/commlinks-chairman",
		"chairman.json":                                "out/commlinks-chairman",
		"cmd/commlinks/config.serialized-fiction.json": "out/commlinks-serialized-fiction",
	} {
		if got := defaultOut(config); got != want {
			t.Errorf("defaultOut(%q) = %q, want %q", config, got, want)
		}
	}
}

// Every config beside the one in use names a series whose full plan -only
// must not replace.
func TestSeriesOuts(t *testing.T) {
	dir := t.TempDir()
	for _, f := range []string{"config.json", "config.chairman.json", "notes.json", "README.md"} {
		if err := os.WriteFile(filepath.Join(dir, f), []byte("{}"), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	got, err := seriesOuts(filepath.Join(dir, "config.json"))
	if err != nil {
		t.Fatal(err)
	}
	sort.Strings(got)
	if want := []string{"out/commlinks", "out/commlinks", "out/commlinks-chairman"}; !reflect.DeepEqual(got, want) {
		t.Errorf("seriesOuts = %q, want %q", got, want)
	}
	if got, _ := seriesOuts("config.json"); !slices.Contains(got, "out/commlinks-chairman") {
		t.Errorf("seriesOuts of the repository's config = %q, want the chairman default among them", got)
	}
}

func TestValidateOnlyRefresh(t *testing.T) {
	const defaultOut = "out/commlinks"
	outs := []string{defaultOut, "out/commlinks-chairman"}
	for _, c := range []struct {
		name    string
		only    string
		refresh bool
		out     string
		wantErr bool
	}{
		{"neither flag, default out", "", false, defaultOut, false},
		{"only with a scratch out", "16000", false, "out/scratch", false},
		{"only with the default out", "16000", false, defaultOut, true},
		{"refresh needs only", "", true, "out/scratch", true},
		{"refresh with only and a scratch out", "16000", true, "out/scratch", false},
		{"refresh with only but the default out", "16000", true, defaultOut, true},
		{"only with the default out, spelled differently", "16000", false, "out/commlinks/", true},
		{"only with another series' default out", "16000", false, "out/commlinks-chairman", true},
		{"refresh with only and another series' default out", "16000", true, "./out/commlinks-chairman", true},
	} {
		err := validateOnlyRefresh(c.only, c.refresh, c.out, outs)
		if (err != nil) != c.wantErr {
			t.Errorf("%s: validateOnlyRefresh(%q, %v, %q) = %v, want error %v", c.name, c.only, c.refresh, c.out, err, c.wantErr)
		}
	}
}

func TestWanted(t *testing.T) {
	existing := map[int]string{1: "Comm-Link:A"}
	for _, c := range []struct {
		name    string
		id      int
		only    map[int]bool
		refresh bool
		want    bool
	}{
		{"missing report, full run", 2, nil, false, true},
		{"stored report, full run", 1, nil, false, false},
		{"missing report outside -only", 2, map[int]bool{3: true}, false, false},
		{"missing report in -only", 2, map[int]bool{2: true}, false, true},
		{"stored report in -only", 1, map[int]bool{1: true}, false, false},
		{"stored report in -only under -refresh", 1, map[int]bool{1: true}, true, true},
		{"stored report outside -only under -refresh", 1, map[int]bool{2: true}, true, false},
	} {
		if got := wanted(c.id, existing, c.only, c.refresh); got != c.want {
			t.Errorf("%s: wanted = %v, want %v", c.name, got, c.want)
		}
	}
}

func TestTitleConflict(t *testing.T) {
	const title = "Comm-Link:Monthly Report - May 2021"
	for _, c := range []struct {
		name      string
		stored    string
		taken     bool
		claimedBy int
		want      string // "" for none, else a substring of the detail
	}{
		{"free title", "", false, 0, ""},
		{"title taken by another report", "", true, 0, "no page stores RSI number 7"},
		{"refresh of the report's own page", title, true, 0, ""},
		{"refresh with the report stored under another title, this one free", "Comm-Link:Old name", false, 0, "stores RSI number 7 on Comm-Link:Old name"},
		{"refresh with the report stored under another title, this one taken", "Comm-Link:Old name", true, 0, "stores RSI number 7 on Comm-Link:Old name"},
		{"title planned by an earlier report of this run", "", false, 5, "RSI number 5 in this run"},
	} {
		got := titleConflict(7, title, c.stored, c.taken, c.claimedBy)
		if (c.want == "") != (got == "") || !strings.Contains(got, c.want) {
			t.Errorf("%s: titleConflict = %q, want %q", c.name, got, c.want)
		}
	}
}

// A report coveredElsewhere counts as present unless a Comm-Link page already
// stores it, so it is planned only when -refresh and -only name it, and its
// title check then names the page that holds it.
func TestAddCovered(t *testing.T) {
	existing := map[int]string{13239: "Comm-Link:Star Citizen Patch 1"}
	addCovered(existing, map[int]string{13239: "Update:Star Citizen Patch 1", 13246: "Update:Star Citizen Patch 2"})
	want := map[int]string{13239: "Comm-Link:Star Citizen Patch 1", 13246: "Update:Star Citizen Patch 2"}
	if !reflect.DeepEqual(existing, want) {
		t.Errorf("existing = %v, want %v", existing, want)
	}
	if wanted(13246, existing, nil, false) {
		t.Error("a covered report is planned")
	}
	if !wanted(13246, existing, map[int]bool{13246: true}, true) {
		t.Error("a covered report named by -only under -refresh is not planned")
	}
	if got := titleConflict(13246, "Comm-Link:Star Citizen Patch 2", existing[13246], false, 0); !strings.Contains(got, "Update:Star Citizen Patch 2") {
		t.Errorf("titleConflict = %q, want one naming the page that holds the report", got)
	}
}

// A page name MediaWiki would reject goes to review whatever the wiki says,
// and so does one the wiki answers as invalid.
func TestTitleProblem(t *testing.T) {
	for _, c := range []struct {
		page   string
		status mediawiki.TitleStatus
		want   string
	}{
		{"Q&A - DefenseCon 2956 New Ships", mediawiki.TitleMissing, ""},
		{"Q&A - DefenseCon 2956 New Ships", "", ""},
		{"DefenseCon 2956 Ship Q&A | Star Citizen", "", `"|"`},
		{"Q&A - Odd", mediawiki.TitleInvalid, "the wiki rejects Comm-Link:Q&A - Odd"},
	} {
		got := titleProblem(c.page, c.status)
		if (c.want == "") != (got == "") || !strings.Contains(got, c.want) {
			t.Errorf("titleProblem(%q, %q) = %q, want %q", c.page, c.status, got, c.want)
		}
	}
}
