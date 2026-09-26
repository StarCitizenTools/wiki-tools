package commlink

import (
	"fmt"
	"time"
)

// Why a report went to review rather than to pages/.
const (
	ReasonFetch       = "fetch-or-parse"
	ReasonTitleExists = "title-exists"
	ReasonNoDate      = "no-wayback-capture"
	ReasonImages      = "images"
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

// Report summarises the plan for the terminal.
func (p *Plan) Report() []string {
	uploads, reuses, wayback := 0, 0, 0
	for _, e := range p.Create {
		if e.DateSource == DateWayback {
			wayback++
		}
		for _, im := range e.Images {
			if im.Action == "upload" {
				uploads++
			} else {
				reuses++
			}
		}
	}
	lines := []string{
		fmt.Sprintf("create: %d pages (%d images to upload, %d reused; %d dated by the Wayback Machine)", len(p.Create), uploads, reuses, wayback),
		fmt.Sprintf("review: %d", len(p.Review)),
	}
	for _, r := range p.Review {
		lines = append(lines, fmt.Sprintf("  %d %s: %s", r.ID, r.Page, r.Reason))
	}
	for _, d := range p.Disagreements {
		lines = append(lines, fmt.Sprintf("found only by %s: %d %s", d.FoundBy, d.ID, d.Title))
	}
	return lines
}
