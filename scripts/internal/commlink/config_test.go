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

// A bare letter takes its title block's subject; a titled letter, a bare
// block, a missing block and every monthly report keep the listed title.
func TestReportTitle(t *testing.T) {
	chairman, monthly := chairmanConfig(t), testConfig(t)
	for _, tc := range []struct {
		cfg                 *Config
		listed, block, want string
	}{
		{chairman, "Note from the Chairman", "Note from the Chairman: Dual Universe", "Note from the Chairman: Dual Universe"},
		{chairman, "Letter From The Chairman", "Letter from the Chairman: Happy New Year", "Letter from the Chairman: Happy New Year"},
		{chairman, "Letter from the Chairman", "Letter from the Chairman", "Letter from the Chairman"},
		{chairman, "Letter from the Chairman", "", "Letter from the Chairman"},
		{chairman, "Letter from the Chairman: $29 Million! Squadron 42!", "Letter from the Chairman", "Letter from the Chairman: $29 Million! Squadron 42!"},
		{chairman, "Note from the Chairman: EVERSPACE", "Note from the Chairman: EVERSPACE", "Note from the Chairman: EVERSPACE"},
		{monthly, "Star Citizen Monthly Report: January 2019", "Star Citizen Monthly Report: December 2018 - January 2019", "Star Citizen Monthly Report: January 2019"},
	} {
		if got := tc.cfg.ReportTitle(tc.listed, tc.block); got != tc.want {
			t.Errorf("ReportTitle(%q, %q) = %q, want %q", tc.listed, tc.block, got, tc.want)
		}
	}
	if got, complete := chairman.PageName(chairman.ReportTitle("Note from the Chairman", "Note from the Chairman: Dual Universe"), "2016-09-15"); got != "Note from the Chairman - Dual Universe" || !complete {
		t.Errorf("PageName of a subject title = %q, %v; want it undated", got, complete)
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
		`{"series":"s","channel":"c","apiChannel":"C"}`:                                                 "series and channel",
		`{"series":"s","titlePattern":"m"}`:                                                             "titleQuery",
		`{"channel":"c","apiChannel":"C","seriesFromReport":true,"infoboxSeries":"X"}`:                  "infoboxSeries",
		`{"channel":"c","apiChannel":"C","standaloneSeries":["None"]}`:                                  "seriesFromReport",
		`{"channel":"c","apiChannel":"C","seriesRename":{"A":"B"}}`:                                     "seriesFromReport",
		`{"channel":"c","apiChannel":"C","noSections":true}`:                                            "",
		`{"channel":"c","apiChannel":"C"}`:                                                              "greetingPattern",
		`{"series":"s","titleQuery":"M","titlePattern":"m","greetingPattern":"g"}`:                      "signOffPattern",
		`{` + base + `,"signOffPatern":"o"}`:                                                            "signOffPatern",
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

func storyConfig(t *testing.T) *Config {
	t.Helper()
	c, err := LoadConfig("../../cmd/commlinks/config.serialized-fiction.json")
	if err != nil {
		t.Fatal(err)
	}
	return c
}

// Every story title shape takes the dash form; the subtitle a title carries
// before its part marker stays.
func TestPageNameStory(t *testing.T) {
	c := storyConfig(t)
	for in, want := range map[string]string{
		"The Cup: Part One":                                 "The Cup - Part One",
		"Phantom Bounty: Part Three":                        "Phantom Bounty - Part Three",
		"Instrument of Surrender (Part One)":                "Instrument of Surrender - Part One",
		"The Second Run: A Sorri Lyrax Delivery (Part One)": "The Second Run - A Sorri Lyrax Delivery - Part One",
		`Lost Squad: "Before the Fall" Act 1`:               `Lost Squad - "Before the Fall" Act 1`,
		"A Gift for Baba (Part 1)":                          "A Gift for Baba - Part 1",
		"The Payout":                                        "The Payout",
	} {
		if got, complete := c.PageName(in, "2021-08-04"); got != want || !complete {
			t.Errorf("PageName(%q) = %q, %v, want %q, true", in, got, complete, want)
		}
	}
}

// A story's series is its API label, renamed where the wiki names the arc
// differently; a label that names no arc takes the title without its part
// marker.
func TestReportSeries(t *testing.T) {
	c := storyConfig(t)
	for _, tc := range []struct {
		title, api, want string
	}{
		{"The Cup: Part One", "The Cup", "The Cup"},
		{"The Second Run: A Sorri Lyrax Delivery (Part One)", "Second Run", "The Second Run"},
		{`Lost Squad: "Before the Fall" Act 1`, `Lost Squad: "Before the Fall"`, `Lost Squad: "Before the Fall"`},
		{"The Payout", "News Update", "The Payout"},
		{"The Meltdown", "None", "The Meltdown"},
		{"Untitled", "", "Untitled"},
		{"Dying Star: Part Two", "News Update", "Dying Star"},
		{"Night Shift Act 2", "None", "Night Shift"},
		{"Balancing Act II", "None", "Balancing Act II"},
		{"A Gift for Baba (Part 1)", "None", "A Gift for Baba"},
	} {
		if got := c.ReportSeries(tc.title, tc.api); got != tc.want {
			t.Errorf("ReportSeries(%q, %q) = %q, want %q", tc.title, tc.api, got, tc.want)
		}
	}
	if got := testConfig(t).ReportSeries("Star Citizen Monthly Report: May 2021", "Monthly Report"); got != "Monthly Reports" {
		t.Errorf("monthly ReportSeries = %q, want the fixed infoboxSeries", got)
	}
}

// An empty greeting or sign-off pattern matches nothing.
func TestEmptyPatternsMatchNothing(t *testing.T) {
	c := storyConfig(t)
	for _, s := range []string{"Greetings Citizens,", "Chris", "", "THE END"} {
		if c.MatchesGreeting(s) || c.MatchesSignOff(s) || c.MatchesTitle(s) {
			t.Errorf("%q matched an empty pattern", s)
		}
	}
}
