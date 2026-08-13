// Package uuidindex reconciles the UUID: namespace against the UUID values
// annotated on wiki pages.
//
// The namespace is a lookup index: UUID:<uuid> is a redirect to the page that
// holds that uuid, so tools can resolve a game uuid to a wiki page with one
// request. This package scans both sides — the Uuid property values in
// Semantic MediaWiki and the pages of the UUID: namespace — and computes the
// plan that brings the namespace back in step: redirects to create, redirects
// whose target moved, and redirects whose uuid no longer exists anywhere.
//
// It is read-only. Applying the plan goes through the MediaWiki MCP server,
// where an agent can resolve conflicts and make editorial judgements.
package uuidindex

import (
	"fmt"
	"regexp"
	"sort"
	"strings"
)

// Namespace is the id of the UUID: namespace on starcitizen.tools.
const Namespace = 69420

// PlaceholderUUID marks "uuid unknown" on pages that have not been resolved
// against the game data. It never gets a redirect: the namespace holds a
// hand-written note page at this title instead.
const PlaceholderUUID = "00000000-0000-0000-0000-000000000000"

// Properties are the SMW properties that carry uuid annotations. "Uuid" is
// what {{Entity}} stores; "UUID" is its predecessor, still emitted by a
// handful of unmigrated infobox pages. Both feed the index so those pages
// stay resolvable until they are migrated.
var Properties = []string{"Uuid", "UUID"}

// LegacyProperty is the deprecated member of Properties, worth calling out in
// reports because every page still using it is migration debt.
const LegacyProperty = "UUID"

var uuidRe = regexp.MustCompile(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`)

// Valid reports whether s is a well-formed lowercase uuid.
func Valid(s string) bool { return uuidRe.MatchString(s) }

// TitleFor returns the canonical page title indexing a uuid. The namespace is
// first-letter case-insensitive, so MediaWiki stores "a03…" as "UUID:A03…";
// returning the stored form keeps titles comparable with API responses.
func TitleFor(uuid string) string {
	return "UUID:" + strings.ToUpper(uuid[:1]) + uuid[1:]
}

// UUIDFromTitle extracts the uuid a namespace page title indexes. The second
// return is false when the title does not parse as a uuid.
func UUIDFromTitle(title string) (string, bool) {
	rest, ok := strings.CutPrefix(title, "UUID:")
	if !ok {
		return "", false
	}
	uuid := strings.ToLower(rest)
	return uuid, Valid(uuid)
}

// Holder is a page annotating a uuid value.
type Holder struct {
	Page string `json:"page"`
	// Property that carried the annotation; LegacyProperty means the page
	// has not been migrated to {{Entity}} yet.
	Property string `json:"property"`
}

// InvalidValue is a property value that is not a well-formed uuid. The fix
// belongs on the holding page, not in the UUID namespace.
type InvalidValue struct {
	Page     string `json:"page"`
	Property string `json:"property"`
	Value    string `json:"value"`
}

// IgnoredValue is a property value deliberately left out of the index.
type IgnoredValue struct {
	Page     string `json:"page"`
	Property string `json:"property"`
	Value    string `json:"value"`
	Reason   string `json:"reason"`
}

// PropertyScan accumulates the SMW side of the reconciliation.
type PropertyScan struct {
	// Holders maps each lowercase uuid to the pages annotating it. One entry
	// per page: a uuid held by more than one page is a conflict.
	Holders map[string][]Holder
	Invalid []InvalidValue
	Ignored []IgnoredValue
}

// NewPropertyScan returns an empty scan.
func NewPropertyScan() *PropertyScan {
	return &PropertyScan{Holders: map[string][]Holder{}}
}

// Add records one property value from a subject page. Values outside the main
// namespace are ignored (sandboxes and drafts must not own index entries), as
// is the placeholder uuid.
func (s *PropertyScan) Add(page string, namespace int, property, value string) {
	// Subobject subjects arrive as "Page#fragment"; the page owns the value.
	if i := strings.IndexByte(page, '#'); i >= 0 {
		page = page[:i]
	}
	uuid := strings.ToLower(strings.TrimSpace(value))
	switch {
	case namespace != 0:
		s.Ignored = append(s.Ignored, IgnoredValue{page, property, uuid, "outside the main namespace"})
	case uuid == PlaceholderUUID:
		s.Ignored = append(s.Ignored, IgnoredValue{page, property, uuid, "placeholder uuid"})
	case !Valid(uuid):
		s.Invalid = append(s.Invalid, InvalidValue{page, property, uuid})
	default:
		for i, h := range s.Holders[uuid] {
			if h.Page == page {
				// Same page via both properties: keep the modern label.
				if h.Property == LegacyProperty {
					s.Holders[uuid][i].Property = property
				}
				return
			}
		}
		s.Holders[uuid] = append(s.Holders[uuid], Holder{page, property})
	}
}

// NSPage is one page of the UUID: namespace.
type NSPage struct {
	Title    string
	Redirect bool
	// Target is where the redirect points (empty for non-redirects, and for
	// redirects the API could not resolve, e.g. interwiki).
	Target string
	// TargetMissing reports a redirect whose target page does not exist.
	TargetMissing bool
}

// ScanResult is everything a reconciliation needs, as read from the wiki.
type ScanResult struct {
	Properties *PropertyScan
	Pages      []NSPage
	// Requests counts API calls made.
	Requests int
}

// Create is a missing index entry: no page in the namespace serves this uuid.
type Create struct {
	UUID   string `json:"uuid"`
	Title  string `json:"title"`
	Target string `json:"target"`
}

// Retarget is an index entry pointing somewhere other than the page that
// holds its uuid — typically left behind by a page move.
type Retarget struct {
	UUID  string `json:"uuid"`
	Title string `json:"title"`
	From  string `json:"from"`
	To    string `json:"to"`
}

// Delete is an index entry whose uuid no longer appears on any page.
type Delete struct {
	Title  string `json:"title"`
	Target string `json:"target"`
}

// Conflict is a uuid annotated by more than one page. The index cannot pick a
// winner; the duplication has to be fixed on the pages themselves.
type Conflict struct {
	UUID  string   `json:"uuid"`
	Pages []string `json:"pages"`
}

// Review is a namespace page the plan deliberately leaves alone, with the
// reason a human (or agent) should look at it.
type Review struct {
	Title string `json:"title"`
	Note  string `json:"note"`
}

// Plan is the reconciliation: what to change, what to leave, what to flag.
type Plan struct {
	Endpoint string `json:"endpoint"`
	// UUIDs is how many distinct uuids are annotated; Pages how many pages
	// the UUID: namespace holds; InSync how many index entries are correct.
	UUIDs  int `json:"uuids"`
	Pages  int `json:"pages"`
	InSync int `json:"in_sync"`

	Create   []Create   `json:"create"`
	Retarget []Retarget `json:"retarget"`
	Delete   []Delete   `json:"delete"`

	Conflicts []Conflict     `json:"conflicts"`
	Invalid   []InvalidValue `json:"invalid_values"`
	Review    []Review       `json:"review"`

	// LegacyPages annotate uuids via the deprecated property — migration debt.
	LegacyPages []string `json:"legacy_property_pages"`
}

// Drift reports whether the namespace needs mechanical changes. Conflicts and
// invalid values are excluded on purpose: they are data problems on ordinary
// pages, reported every run but not fixable from inside the namespace.
func (p *Plan) Drift() bool {
	return len(p.Create)+len(p.Retarget)+len(p.Delete) > 0
}

// Reconcile computes the plan that brings the namespace in step with the
// property annotations. It is pure: both sides come from the scan.
func Reconcile(scan *ScanResult, endpoint string) *Plan {
	plan := &Plan{
		Endpoint: endpoint,
		UUIDs:    len(scan.Properties.Holders),
		Pages:    len(scan.Pages),
		Invalid:  append([]InvalidValue{}, scan.Properties.Invalid...),
	}

	// Group namespace pages by the uuid their title indexes. First-letter
	// case-insensitivity means distinct titles can index the same uuid.
	byUUID := map[string][]NSPage{}
	var unparsable []NSPage
	for _, p := range scan.Pages {
		if uuid, ok := UUIDFromTitle(p.Title); ok {
			byUUID[uuid] = append(byUUID[uuid], p)
		} else {
			unparsable = append(unparsable, p)
		}
	}

	legacy := map[string]struct{}{}
	for _, uuid := range sortedKeys(scan.Properties.Holders) {
		holders := scan.Properties.Holders[uuid]
		for _, h := range holders {
			if h.Property == LegacyProperty {
				legacy[h.Page] = struct{}{}
			}
		}
		if len(holders) > 1 {
			pages := make([]string, len(holders))
			for i, h := range holders {
				pages[i] = h.Page
			}
			sort.Strings(pages)
			plan.Conflicts = append(plan.Conflicts, Conflict{uuid, pages})
			continue // no winner; leave any existing entry untouched
		}
		target := holders[0].Page

		existing := byUUID[uuid]
		switch {
		case len(existing) == 0:
			plan.Create = append(plan.Create, Create{uuid, TitleFor(uuid), target})
		case len(existing) > 1:
			for _, p := range existing {
				plan.Review = append(plan.Review, Review{p.Title,
					fmt.Sprintf("one of %d case-variant titles indexing uuid %s", len(existing), uuid)})
			}
		case !existing[0].Redirect:
			plan.Review = append(plan.Review, Review{existing[0].Title,
				fmt.Sprintf("not a redirect, but %q holds its uuid", target)})
		case existing[0].Target != target:
			plan.Retarget = append(plan.Retarget, Retarget{uuid, existing[0].Title, existing[0].Target, target})
		default:
			plan.InSync++
		}
	}

	// Namespace pages whose uuid nothing annotates any more.
	for _, uuid := range sortedKeys(byUUID) {
		if _, held := scan.Properties.Holders[uuid]; held {
			continue
		}
		for _, p := range byUUID[uuid] {
			if p.Redirect {
				plan.Delete = append(plan.Delete, Delete{p.Title, p.Target})
			} else {
				plan.Review = append(plan.Review, Review{p.Title,
					"no page holds this uuid, but it is not a redirect; left alone"})
			}
		}
	}

	// Titles that do not parse as a uuid index nothing, but deleting on a
	// parse failure would be trigger-happy — flag them instead.
	for _, p := range unparsable {
		plan.Review = append(plan.Review, Review{p.Title, "title is not a well-formed uuid; left alone"})
	}

	plan.LegacyPages = sortedKeys(legacy)
	sort.Slice(plan.Review, func(i, j int) bool { return plan.Review[i].Title < plan.Review[j].Title })
	return plan
}

func sortedKeys[V any](m map[string]V) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}

// Report renders the plan as human-readable lines, counts first, then a
// sample of each pending category.
func Report(p *Plan) []string {
	lines := []string{
		fmt.Sprintf("uuids      %d annotated (%d via the legacy %s property)", p.UUIDs, len(p.LegacyPages), LegacyProperty),
		fmt.Sprintf("uuid pages %d", p.Pages),
		fmt.Sprintf("in sync    %d", p.InSync),
	}
	sample := func(n int, format string, line func(i int) string) {
		if n == 0 {
			return
		}
		lines = append(lines, fmt.Sprintf(format, n))
		const max = 8
		for i := 0; i < n && i < max; i++ {
			lines = append(lines, "  "+line(i))
		}
		if n > max {
			lines = append(lines, fmt.Sprintf("  … and %d more", n-max))
		}
	}
	sample(len(p.Create), "create     %d", func(i int) string {
		c := p.Create[i]
		return fmt.Sprintf("%s -> %s", c.Title, c.Target)
	})
	sample(len(p.Retarget), "retarget   %d", func(i int) string {
		r := p.Retarget[i]
		return fmt.Sprintf("%s: %s -> %s", r.Title, orDash(r.From), r.To)
	})
	sample(len(p.Delete), "delete     %d", func(i int) string {
		d := p.Delete[i]
		return fmt.Sprintf("%s (pointed at %s)", d.Title, orDash(d.Target))
	})
	sample(len(p.Conflicts), "conflicts  %d uuids held by more than one page", func(i int) string {
		c := p.Conflicts[i]
		return fmt.Sprintf("%s: %s", c.UUID, strings.Join(c.Pages, ", "))
	})
	sample(len(p.Invalid), "invalid    %d property values that are not uuids", func(i int) string {
		v := p.Invalid[i]
		return fmt.Sprintf("%s = %q on %s", v.Property, v.Value, v.Page)
	})
	sample(len(p.Review), "review     %d pages left alone", func(i int) string {
		r := p.Review[i]
		return fmt.Sprintf("%s: %s", r.Title, r.Note)
	})
	return lines
}

func orDash(s string) string {
	if s == "" {
		return "(unresolved)"
	}
	return s
}
