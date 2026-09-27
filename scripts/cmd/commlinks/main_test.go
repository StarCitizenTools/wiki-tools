package main

import (
	"strings"
	"testing"
)

func TestValidateOnlyRefresh(t *testing.T) {
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
	} {
		err := validateOnlyRefresh(c.only, c.refresh, c.out)
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
