// Package commlink plans wiki pages for RSI Comm-Links: it finds the reports
// of a series the wiki is missing, converts RSI's HTML into wikitext, and plans
// their images, dates and links. It never writes to the wiki.
package commlink

import (
	"encoding/json"
	"fmt"
	"os"
	"regexp"
	"slices"
	"strings"
	"time"
)

// Rename rewrites an RSI title before the ": " to " - " rule applies.
type Rename struct {
	Pattern string `json:"pattern"`
	Replace string `json:"replace"`
}

// Config is the editorial input to the importer, read from
// cmd/commlinks/config.json.
type Config struct {
	Series       string `json:"series"`
	TitleQuery   string `json:"titleQuery"`
	TitlePattern string `json:"titlePattern"`
	// GreetingPattern and SignOffPattern match a report's opening greeting and
	// closing sign-off. A bold line matching either is never a pseudo-heading,
	// and a classic heading matching either (only an intro heading, with
	// introHeadings), or a fragment heading matching the sign-off, renders as
	// bold text.
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
	IntroHeadings bool     `json:"introHeadings"`
	Renames       []Rename `json:"renames"`
	// DatedTitlePattern matches a page name, after renames, that several
	// reports share (a bare "Letter from the Chairman"); such a name takes
	// " - " and the report's publication date.
	DatedTitlePattern string            `json:"datedTitlePattern"`
	InfoboxType       string            `json:"infoboxType"`
	InfoboxSeries     string            `json:"infoboxSeries"`
	ImageCategory     string            `json:"imageCategory"`
	ImageAuthor       string            `json:"imageAuthor"`
	LinkCategories    []string          `json:"linkCategories"`
	Aliases           map[string]string `json:"aliases"`
	Stoplist          []string          `json:"stoplist"`
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
	renameRe, ignoreRe                      []*regexp.Regexp
}

// LoadConfig reads and validates the config.
func LoadConfig(path string) (*Config, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var c Config
	if err := json.Unmarshal(data, &c); err != nil {
		return nil, fmt.Errorf("%s: %w", path, err)
	}
	if c.Series == "" || c.TitleQuery == "" || c.TitlePattern == "" || c.GreetingPattern == "" || c.SignOffPattern == "" {
		return nil, fmt.Errorf("%s: series, titleQuery, titlePattern, greetingPattern and signOffPattern are required", path)
	}
	if c.titleRe, err = regexp.Compile(c.TitlePattern); err != nil {
		return nil, fmt.Errorf("%s: titlePattern: %w", path, err)
	}
	if c.greetingRe, err = regexp.Compile(c.GreetingPattern); err != nil {
		return nil, fmt.Errorf("%s: greetingPattern: %w", path, err)
	}
	if c.signOffRe, err = regexp.Compile(c.SignOffPattern); err != nil {
		return nil, fmt.Errorf("%s: signOffPattern: %w", path, err)
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
func (c *Config) MatchesTitle(title string) bool { return c.titleRe.MatchString(title) }

// MatchesGreeting reports whether text opens a report.
func (c *Config) MatchesGreeting(text string) bool { return c.greetingRe.MatchString(text) }

// MatchesSignOff reports whether text is a report's sign-off.
func (c *Config) MatchesSignOff(text string) bool { return c.signOffRe.MatchString(text) }

// PageName is the page title, without namespace, for an RSI title published
// on date (YYYY-MM-DD): the first matching rename, then ": " becomes " - ",
// the rule existing Comm-Link pages follow, then " - " and date when
// datedTitlePattern matches the result. complete is false when the name takes
// the date and date is "": the name is not final.
func (c *Config) PageName(rsiTitle, date string) (name string, complete bool) {
	name = strings.TrimSpace(rsiTitle)
	for i, re := range c.renameRe {
		if re.MatchString(name) {
			name = re.ReplaceAllString(name, c.Renames[i].Replace)
			break
		}
	}
	name = strings.ReplaceAll(name, ": ", " - ")
	if c.datedRe == nil || !c.datedRe.MatchString(name) {
		return name, true
	}
	if date == "" {
		return name, false
	}
	return name + " - " + date, true
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
