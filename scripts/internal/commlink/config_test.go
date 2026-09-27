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
		if got, complete := c.PageName(in, "2019-12-20"); got != want || !complete {
			t.Errorf("PageName(%q) = %q, %v, want %q, true", in, got, complete, want)
		}
	}
}

func chairmanConfig(t *testing.T) *Config {
	t.Helper()
	c, err := LoadConfig("../../cmd/commlinks/config.chairman.json")
	if err != nil {
		t.Fatal(err)
	}
	return c
}

// A bare letter title, in any capitalisation, takes the publication date; a
// titled one does not.
func TestPageNameDated(t *testing.T) {
	c := chairmanConfig(t)
	for _, tc := range []struct{ in, date, want string }{
		{"Letter from the Chairman", "2014-12-06", "Letter from the Chairman - 2014-12-06"},
		{"Letter From The Chairman", "2026-08-27", "Letter from the Chairman - 2026-08-27"},
		{"Letter From the Chairman", "2023-11-24", "Letter from the Chairman - 2023-11-24"},
		{"Note from the Chairman", "2015-03-03", "Note from the Chairman - 2015-03-03"},
		{"Note from the Chairman: EVERSPACE", "2015-09-01", "Note from the Chairman - EVERSPACE"},
		{"Letter from the Chairman: $23 Million!", "2013-10-17", "Letter from the Chairman - $23 Million!"},
		{"$10 Million!", "2013-06-10", "$10 Million!"},
	} {
		if got, complete := c.PageName(tc.in, tc.date); got != tc.want || !complete {
			t.Errorf("PageName(%q, %q) = %q, %v, want %q, true", tc.in, tc.date, got, complete, tc.want)
		}
	}
	if got, complete := c.PageName("Letter From The Chairman", ""); complete {
		t.Errorf("PageName of a bare title with no date = %q, complete; want incomplete", got)
	}
	if got, complete := c.PageName("Letter from the Chairman: $48 Million", ""); !complete || got != "Letter from the Chairman - $48 Million" {
		t.Errorf("PageName of a titled letter with no date = %q, %v; want its name, complete", got, complete)
	}
}

func TestMatchesTitleChairman(t *testing.T) {
	c := chairmanConfig(t)
	for title, want := range map[string]bool{
		"Letter from the Chairman":                  true,
		"Letter From The Chairman":                  true,
		"Letter From the Chairman":                  true,
		"Note from the Chairman: EVERSPACE":         true,
		"Letter from the Chairman: $23 Million!":    true,
		"10 for the Chairman":                       false,
		"Star Citizen: 10 for the Chairman":         false,
		"Chairman's Response to The Escapist - RSI": false,
	} {
		if got := c.MatchesTitle(title); got != want {
			t.Errorf("MatchesTitle(%q) = %v, want %v", title, got, want)
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
		`{` + base + `,"datedTitlePattern":"("}`:                                                        "datedTitlePattern",
		`{` + base + `}`:                                                                                "",
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
