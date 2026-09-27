// Package commlink plans wiki pages for RSI Comm-Links: it finds the reports
// of a series the wiki is missing, converts RSI's HTML into wikitext, and plans
// their images, dates and links. It never writes to the wiki.
package commlink

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"regexp"
	"slices"
	"strconv"
	"strings"
	"time"
)

// Rename rewrites an RSI title before the ": " to " - " rule applies.
type Rename struct {
	Pattern string `json:"pattern"`
	Replace string `json:"replace"`
}

// SeriesRule gives Series to the reports it matches: Title, a pattern over the
// RSI title, and Label, an exact API series label, are each optional, and both
// must match when both are given.
type SeriesRule struct {
	Title  string `json:"title"`
	Label  string `json:"label"`
	Series string `json:"series"`
}

// Config is the editorial input to the importer, read from
// cmd/commlinks/config.json.
type Config struct {
	// Series and Channel are RSI hub slugs; RSI's listing is read by the one
	// that is set.
	Series  string `json:"series"`
	Channel string `json:"channel"`
	// APIChannel is the API's name for a channel. When it is set, API
	// discovery reads every comm-link the API files under it, and titleQuery
	// and titlePattern are not needed; otherwise it reads the titles that
	// contain titleQuery and match titlePattern.
	APIChannel   string `json:"apiChannel"`
	TitleQuery   string `json:"titleQuery"`
	TitlePattern string `json:"titlePattern"`
	// GreetingPattern and SignOffPattern match a report's opening greeting and
	// closing sign-off; an empty pattern matches nothing. A bold line matching
	// either is never a pseudo-heading, and a classic heading matching either
	// (only an intro heading, with introHeadings), or a fragment heading
	// matching the sign-off, renders as bold text.
	GreetingPattern string `json:"greetingPattern"`
	SignOffPattern  string `json:"signOffPattern"`
	// StudioSections reads a classic page with a section-title block other
	// than its own title and "Conclusion" as one section per studio, whose
	// prose opens with the studio's name as an h1 (the monthly reports, 2014 to
	// August 2018). Without it, a prose h1 that does not repeat its section's
	// title is text.
	StudioSections bool `json:"studioSections"`
	// IntroHeadings marks a classic page's intro with headings (the monthly
	// reports): an h1 or a heading inside div.variant-block is intro text, and
	// only such a heading is read as a greeting or sign-off. Without it,
	// div.variant-block is only styling, and a heading at any level matching
	// greetingPattern or signOffPattern is bold text.
	IntroHeadings bool `json:"introHeadings"`
	// NoSections reads a body with no sections, a story: each heading, which
	// RSI uses for styling (a writer's note, a script's scene heading, THE
	// END), is bold text, and no bold line is a subsection title.
	NoSections bool `json:"noSections"`
	// SceneBreaks keeps a horizontal rule in the prose, a story's scene break,
	// as a wikitext rule; without it a rule is dropped.
	SceneBreaks bool `json:"sceneBreaks"`
	// Byline opens a classic body with its page header's subtitle when that
	// names the author ("By: Autumn Kalquist"); a fragment carries its byline
	// in the body.
	Byline bool `json:"byline"`
	// H1Headings reads a classic page's prose h1 that does not repeat its
	// section's title, and does not end as a sentence does, as a subsection
	// heading, one level below the section's; without it (and without
	// StudioSections) such an h1 is text.
	H1Headings bool `json:"h1Headings"`
	// Tables converts an HTML table into a wikitable; without it each cell
	// is a paragraph of its own.
	Tables  bool     `json:"tables"`
	Renames []Rename `json:"renames"`
	// DatedTitlePattern matches a page name, after renames, that several
	// reports share (a bare "Letter from the Chairman"); such a name takes
	// " - " and the report's publication date.
	DatedTitlePattern string `json:"datedTitlePattern"`
	InfoboxType       string `json:"infoboxType"`
	// InfoboxSeries is every report's infobox series, unless SeriesFromReport
	// takes each report's own (see ReportSeries).
	InfoboxSeries    string `json:"infoboxSeries"`
	SeriesFromReport bool   `json:"seriesFromReport"`
	// StandaloneSeries are API series labels that name no story arc ("News
	// Update", "None"), and SeriesRename corrects the labels that name one
	// differently from the wiki.
	StandaloneSeries []string          `json:"standaloneSeries"`
	SeriesRename     map[string]string `json:"seriesRename"`
	// SeriesRules, tried in order before the API label, give a series by title
	// or label to a channel whose labels don't name its families (Engineering
	// files most of its posts under "None").
	SeriesRules []SeriesRule `json:"seriesRules"`
	// CoveredElsewhere maps an RSI number to the wiki page outside the
	// Comm-Link namespace that already holds that report (a patch note's
	// Update: page); the report counts as present.
	CoveredElsewhere map[string]string `json:"coveredElsewhere"`
	ImageCategory    string            `json:"imageCategory"`
	ImageAuthor      string            `json:"imageAuthor"`
	LinkCategories   []string          `json:"linkCategories"`
	Aliases          map[string]string `json:"aliases"`
	Stoplist         []string          `json:"stoplist"`
	// NoLink lists phrases inside which no term is linked: a name used in
	// another sense.
	NoLink         []string `json:"noLink"`
	FidelityIgnore []string `json:"fidelityIgnore"`
	KnownReview    []int    `json:"knownReview"`
	// APITextAccepted are reports whose short API text a person has read
	// against RSI's page; the api-text check passes them.
	APITextAccepted []int `json:"apiTextAccepted"`
	// APIIngestDates are YYYY-MM-DD days the API imported reports in bulk; a
	// created_at on one of them is not a publication date.
	APIIngestDates []string `json:"apiIngestDates"`

	titleRe, greetingRe, signOffRe, datedRe *regexp.Regexp
	renameRe, ignoreRe, seriesRuleRe        []*regexp.Regexp
	covered                                 map[int]string
}

// LoadConfig reads and validates the config.
func LoadConfig(path string) (*Config, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var c Config
	dec := json.NewDecoder(bytes.NewReader(data))
	dec.DisallowUnknownFields()
	if err := dec.Decode(&c); err != nil {
		return nil, fmt.Errorf("%s: %w", path, err)
	}
	if (c.Series == "") == (c.Channel == "") {
		return nil, fmt.Errorf("%s: one of series and channel is required", path)
	}
	if c.APIChannel == "" && (c.TitleQuery == "" || c.TitlePattern == "") {
		return nil, fmt.Errorf("%s: titleQuery and titlePattern are required without apiChannel", path)
	}
	if c.SeriesFromReport && c.InfoboxSeries != "" {
		return nil, fmt.Errorf("%s: infoboxSeries and seriesFromReport exclude each other", path)
	}
	if !c.SeriesFromReport && (len(c.StandaloneSeries) > 0 || len(c.SeriesRename) > 0 || len(c.SeriesRules) > 0) {
		return nil, fmt.Errorf("%s: standaloneSeries, seriesRename and seriesRules need seriesFromReport", path)
	}
	for _, r := range c.SeriesRules {
		if strings.TrimSpace(r.Series) == "" || (r.Title == "" && r.Label == "") {
			return nil, fmt.Errorf("%s: seriesRules: a rule needs a series and a title or label", path)
		}
		var re *regexp.Regexp
		if r.Title != "" {
			if re, err = regexp.Compile(r.Title); err != nil {
				return nil, fmt.Errorf("%s: seriesRules %q: %w", path, r.Title, err)
			}
		}
		c.seriesRuleRe = append(c.seriesRuleRe, re)
	}
	c.covered = map[int]string{}
	for k, page := range c.CoveredElsewhere {
		id, err := strconv.Atoi(k)
		if err != nil || id <= 0 || strings.TrimSpace(page) == "" {
			return nil, fmt.Errorf("%s: coveredElsewhere %q: needs an RSI number and a page", path, k)
		}
		c.covered[id] = page
	}
	if !c.NoSections && (c.GreetingPattern == "" || c.SignOffPattern == "") {
		return nil, fmt.Errorf("%s: greetingPattern and signOffPattern are required without noSections", path)
	}
	for _, p := range []struct {
		key, pattern string
		re           **regexp.Regexp
	}{
		{"titlePattern", c.TitlePattern, &c.titleRe},
		{"greetingPattern", c.GreetingPattern, &c.greetingRe},
		{"signOffPattern", c.SignOffPattern, &c.signOffRe},
	} {
		if p.pattern == "" {
			continue
		}
		if *p.re, err = regexp.Compile(p.pattern); err != nil {
			return nil, fmt.Errorf("%s: %s: %w", path, p.key, err)
		}
	}
	if c.DatedTitlePattern != "" {
		if c.datedRe, err = regexp.Compile(c.DatedTitlePattern); err != nil {
			return nil, fmt.Errorf("%s: datedTitlePattern: %w", path, err)
		}
	}
	for _, r := range c.Renames {
		re, err := regexp.Compile(r.Pattern)
		if err != nil {
			return nil, fmt.Errorf("%s: rename %q: %w", path, r.Pattern, err)
		}
		c.renameRe = append(c.renameRe, re)
	}
	for k := range c.Aliases {
		if strings.TrimSpace(k) == "" {
			return nil, fmt.Errorf("%s: aliases has an empty term", path)
		}
	}
	for _, p := range c.NoLink {
		if strings.TrimSpace(p) == "" {
			return nil, fmt.Errorf("%s: noLink has an empty phrase", path)
		}
	}
	for _, d := range c.APIIngestDates {
		if _, err := time.Parse("2006-01-02", d); err != nil {
			return nil, fmt.Errorf("%s: apiIngestDates %q: %w", path, d, err)
		}
	}
	for _, p := range c.FidelityIgnore {
		re, err := regexp.Compile(p)
		if err != nil {
			return nil, fmt.Errorf("%s: fidelityIgnore %q: %w", path, p, err)
		}
		c.ignoreRe = append(c.ignoreRe, re)
	}
	return &c, nil
}

// MatchesTitle reports whether an API title, or a classic page's first title
// block, names a report of this series.
func (c *Config) MatchesTitle(title string) bool { return matches(c.titleRe, title) }

// MatchesGreeting reports whether text opens a report.
func (c *Config) MatchesGreeting(text string) bool { return matches(c.greetingRe, text) }

// MatchesSignOff reports whether text is a report's sign-off.
func (c *Config) MatchesSignOff(text string) bool { return matches(c.signOffRe, text) }

// matches is re.MatchString, false for a pattern the config leaves empty.
func matches(re *regexp.Regexp, s string) bool { return re != nil && re.MatchString(s) }

// renamed is an RSI title after the first matching rename, with ": " turned
// into " - " and each run of spaces made one, as MediaWiki stores a title
// ("Orion Vault : A Loan" is "Orion Vault - A Loan").
func (c *Config) renamed(rsiTitle string) string {
	name := strings.TrimSpace(rsiTitle)
	for i, re := range c.renameRe {
		if re.MatchString(name) {
			name = re.ReplaceAllString(name, c.Renames[i].Replace)
			break
		}
	}
	return strings.Join(strings.Fields(strings.ReplaceAll(name, ": ", " - ")), " ")
}

// PageName is the page title, without namespace, for an RSI title published
// on date (YYYY-MM-DD): the first matching rename, then ": " becomes " - ",
// the rule existing Comm-Link pages follow, then " - " and date when
// datedTitlePattern matches the result. complete is false when the name takes
// the date and date is "": the name is not final.
func (c *Config) PageName(rsiTitle, date string) (name string, complete bool) {
	name = c.renamed(rsiTitle)
	if c.datedRe == nil || !c.datedRe.MatchString(name) {
		return name, true
	}
	if date == "" {
		return name, false
	}
	return name + " - " + date, true
}

// sharedName reports whether an RSI title's name is one datedTitlePattern
// matches, a name several reports share.
func (c *Config) sharedName(rsiTitle string) bool {
	return c.datedRe != nil && c.datedRe.MatchString(c.renamed(rsiTitle))
}

// ReportTitle is a report's title: the page's own title block when it names a
// subject the listed title lacks, that is when datedTitlePattern matches the
// listed title's name but not the block's ("Note from the Chairman: Dual
// Universe" over "Note from the Chairman"), else the listed title.
func (c *Config) ReportTitle(listed, titleBlock string) string {
	titleBlock = strings.TrimSpace(titleBlock)
	if c.datedRe == nil || titleBlock == "" {
		return listed
	}
	if !c.sharedName(listed) || c.sharedName(titleBlock) {
		return listed
	}
	return titleBlock
}

// partMarker is a title's closing part marker: "(Part 1)", ": Part One" or
// "Act 1". An act takes a number, so "Balancing Act II" keeps its "Act".
var partMarker = regexp.MustCompile(`(?i)(?:\s*\(\s*part\s+[^()]+\)|\s*:\s*part\s+\S+|\s+act\s+\d+)\s*$`)

// ReportSeries is a report's infobox series: infoboxSeries, or with
// seriesFromReport the first of seriesRules to match, else the report's API
// series label after seriesRename. A label
// in standaloneSeries names no arc, so the report takes its series from its
// title instead: the title without a closing part marker ("A Gift for Baba
// (Part 1)" is in "A Gift for Baba"), or the whole title for a story in one
// part.
func (c *Config) ReportSeries(title, apiSeries string) string {
	if !c.SeriesFromReport {
		return c.InfoboxSeries
	}
	for i, r := range c.SeriesRules {
		if (r.Label == "" || r.Label == apiSeries) && (c.seriesRuleRe[i] == nil || c.seriesRuleRe[i].MatchString(title)) {
			return r.Series
		}
	}
	if !slices.Contains(c.StandaloneSeries, apiSeries) {
		if renamed, ok := c.SeriesRename[apiSeries]; ok {
			return renamed
		}
		return apiSeries
	}
	title = strings.TrimSpace(title)
	if arc := partMarker.ReplaceAllString(title, ""); arc != "" {
		return arc
	}
	return title
}

// IgnoredLine reports whether an API text line is a known artefact that the
// fidelity check must not count as missing.
func (c *Config) IgnoredLine(line string) bool {
	for _, re := range c.ignoreRe {
		if re.MatchString(line) {
			return true
		}
	}
	return false
}

// AcceptsAPIText reports whether id is in apiTextAccepted.
func (c *Config) AcceptsAPIText(id int) bool { return slices.Contains(c.APITextAccepted, id) }

// InfoboxURL drops RSI's locale segment, matching the url the existing pages
// carry.
func InfoboxURL(rsiURL string) string {
	return strings.Replace(rsiURL, "robertsspaceindustries.com/en/", "robertsspaceindustries.com/", 1)
}

// Covered is the RSI numbers coveredElsewhere lists, each with its page.
func (c *Config) Covered() map[int]string { return c.covered }
