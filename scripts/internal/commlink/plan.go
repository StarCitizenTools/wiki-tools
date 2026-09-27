package commlink

import (
	"encoding/json"
	"fmt"
	"time"
)

// Why a report went to review rather than to pages/.
const (
	ReasonFetch       = "fetch-or-parse"
	ReasonTitleExists = "title-exists"
	ReasonNoDate      = "no-date"
	ReasonImages      = "images"
	ReasonAPIText     = "api-text"
	ReasonFidelity    = "fidelity"
)

// Plan is the importer's output: pages to create, and reports it would not
// decide on its own.
type Plan struct {
	Generated     time.Time      `json:"generated"`
	Create        []PageEntry    `json:"create"`
	Review        []ReviewEntry  `json:"review"`
	Disagreements []Disagreement `json:"discoveryDisagreements"`
}

// PageEntry is one page to create. Wikitext is the page's file, relative to the
// plan.
type PageEntry struct {
	ID         int         `json:"id"`
	RSITitle   string      `json:"rsiTitle"`
	Page       string      `json:"page"`
	URL        string      `json:"url"`
	Date       string      `json:"date"`
	DateSource string      `json:"dateSource"`
	Wikitext   string      `json:"wikitext"`
	Images     []ImagePlan `json:"images"`
	Links      []LinkEntry `json:"links"`
	// MissingImages are body image sources RSI answers with 404, left out
	// of the page.
	MissingImages []string `json:"missingImages,omitempty"`
	// Refresh marks an entry planned by -refresh: the wiki already has this
	// page, under this title, storing this RSI number, so a publisher should
	// update it rather than create it.
	Refresh bool `json:"refresh,omitempty"`
}

// MarshalJSON writes an empty list, never null, for a plan with no entries of
// a kind.
func (p Plan) MarshalJSON() ([]byte, error) {
	type plain Plan
	q := plain(p)
	q.Create, q.Review, q.Disagreements = orEmpty(q.Create), orEmpty(q.Review), orEmpty(q.Disagreements)
	return json.Marshal(q)
}

// MarshalJSON writes an empty list, never null, for a page with no images or
// no links.
func (e PageEntry) MarshalJSON() ([]byte, error) {
	type plain PageEntry
	q := plain(e)
	q.Images, q.Links = orEmpty(q.Images), orEmpty(q.Links)
	return json.Marshal(q)
}

func orEmpty[T any](s []T) []T {
	if s == nil {
		return []T{}
	}
	return s
}

// ReviewEntry is a report held back, with the reason and its evidence.
type ReviewEntry struct {
	ID       int      `json:"id"`
	RSITitle string   `json:"rsiTitle"`
	Page     string   `json:"page"`
	Reason   string   `json:"reason"`
	Detail   []string `json:"detail,omitempty"`
}

// Drift reports whether the plan holds work: a page to create, or a review
// entry not yet accepted in the config's knownReview.
func (p *Plan) Drift(known []int) bool {
	if len(p.Create) > 0 {
		return true
	}
	k := map[int]bool{}
	for _, id := range known {
		k[id] = true
	}
	for _, r := range p.Review {
		if !k[r.ID] {
			return true
		}
	}
	return false
}

// CreateLines lists the pages the plan creates, one "id page" line each.
func (p *Plan) CreateLines() []string {
	lines := make([]string, len(p.Create))
	for i, e := range p.Create {
		lines[i] = fmt.Sprintf("%d %s", e.ID, e.Page)
	}
	return lines
}

// Report summarises the plan for the terminal.
func (p *Plan) Report() []string {
	uploads, reuses := 0, 0
	dated := map[string]int{}
	for _, e := range p.Create {
		dated[e.DateSource]++
		for _, im := range e.Images {
			if im.Action == "upload" {
				uploads++
			} else {
				reuses++
			}
		}
	}
	lines := []string{
		fmt.Sprintf("create: %d pages (%d images to upload, %d reused; dated by rsi %d, api %d, wayback %d)",
			len(p.Create), uploads, reuses, dated[DateRSI], dated[DateAPI], dated[DateWayback]),
		fmt.Sprintf("review: %d", len(p.Review)),
	}
	for _, r := range p.Review {
		lines = append(lines, fmt.Sprintf("  %d %s: %s", r.ID, orUnknown(r.Page), r.Reason))
	}
	for _, d := range p.Disagreements {
		lines = append(lines, fmt.Sprintf("found only by %s: %d %s", d.FoundBy, d.ID, orUnknown(d.Title)))
	}
	return lines
}

// orUnknown stands in for the title of a report the API has no record of.
func orUnknown(s string) string {
	if s == "" {
		return "(title unknown)"
	}
	return s
}
