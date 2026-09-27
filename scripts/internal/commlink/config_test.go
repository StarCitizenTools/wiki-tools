package commlink

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func testConfig(t *testing.T) *Config {
	t.Helper()
	c, err := LoadConfig("../../cmd/commlinks/config.json")
	if err != nil {
		t.Fatal(err)
	}
	return c
}

func TestPageName(t *testing.T) {
	c := testConfig(t)
	for in, want := range map[string]string{
		"Monthly Studio Report: April 2017":                    "Monthly Report - April 2017",
		"Monthly Report: September 2014":                       "Monthly Report - September 2014",
		"Star Citizen Monthly Report: May 2021":                "Star Citizen Monthly Report - May 2021",
		"Squadron 42 Monthly Report: November & December 2019": "Squadron 42 Monthly Report - November & December 2019",
	} {
		if got := c.PageName(in); got != want {
			t.Errorf("PageName(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestMatchesTitle(t *testing.T) {
	c := testConfig(t)
	for title, want := range map[string]bool{
		"Star Citizen Monthly Report: August 2026": true,
		"Squadron 42 Monthly Report: April 2024":   true,
		"Monthly Studio Report: April 2017":        true,
		"Monthly Store Bundle 2026":                false,
	} {
		if got := c.MatchesTitle(title); got != want {
			t.Errorf("MatchesTitle(%q) = %v, want %v", title, got, want)
		}
	}
}

func TestInfoboxURL(t *testing.T) {
	in := "https://robertsspaceindustries.com/en/comm-link/transmission/15833-Monthly-Studio-Report-March-2017"
	want := "https://robertsspaceindustries.com/comm-link/transmission/15833-Monthly-Studio-Report-March-2017"
	if got := InfoboxURL(in); got != want {
		t.Errorf("InfoboxURL = %q", got)
	}
	if got := InfoboxURL(want); got != want {
		t.Errorf("InfoboxURL changed a locale-free url: %q", got)
	}
}

// Each broken config fails on its own key; the valid base loads.
func TestLoadConfigRejects(t *testing.T) {
	dir := t.TempDir()
	const base = `"series":"s","titleQuery":"M","titlePattern":"m","greetingPattern":"g","signOffPattern":"o"`
	for body, want := range map[string]string{
		`{"titleQuery":"M","titlePattern":"m","greetingPattern":"g","signOffPattern":"o"}`:              "required",
		`{"series":"s","titleQuery":"M","titlePattern":"m","greetingPattern":"g"}`:                      "required",
		`{"series":"s","titleQuery":"M","titlePattern":"(","greetingPattern":"g","signOffPattern":"o"}`: "titlePattern",
		`{"series":"s","titleQuery":"M","titlePattern":"m","greetingPattern":"(","signOffPattern":"o"}`: "greetingPattern",
		`{"series":"s","titleQuery":"M","titlePattern":"m","greetingPattern":"g","signOffPattern":"("}`: "signOffPattern",
		`{` + base + `,"aliases":{" ":"Target"}}`:                                                       "aliases",
		`{` + base + `,"noLink":["Vulcan (G12)",""]}`:                                                   "noLink",
		`{` + base + `}`: "",
	} {
		p := filepath.Join(dir, "config.json")
		os.WriteFile(p, []byte(body), 0o644)
		_, err := LoadConfig(p)
		if want == "" {
			if err != nil {
				t.Errorf("%s: LoadConfig = %v, want no error", body, err)
			}
		} else if err == nil || !strings.Contains(err.Error(), want) {
			t.Errorf("%s: LoadConfig = %v, want an error naming %q", body, err, want)
		}
	}
}
