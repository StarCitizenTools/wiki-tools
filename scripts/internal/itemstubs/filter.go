package itemstubs

import (
	"slices"
	"sort"
	"strings"
)

// Dispositions order the filter chain: the first matching one wins, and every
// non-create outcome is recorded in the plan's skip summary or conflicts.
const (
	DispExists   = "exists"   // uuid already annotated on the wiki
	DispBlocked  = "blocked"  // blocklist heuristics (placeholder, test item…)
	DispUnmapped = "unmapped" // type nobody has decided on yet → drift report
	DispExcluded = "excluded" // type decided: no pages (skip: true)
	DispReview   = "review"   // detectable-but-contextual → plan conflict
	DispCreate   = "create"   // stub page to plan
)

// Filtered is one item's classification.
type Filtered struct {
	Item        Item
	Disposition string
	// RuleID names the blocklist/review rule that fired.
	RuleID string
	// Rule is the type's allowlist entry, set for review and create.
	Rule TypeRule
}

// unnamed is built-in rather than config: a nameless item is structurally
// unusable (its name IS the page title), not an editorial judgment.
func unnamed(it Item) bool {
	return it.Name == "" || it.Name == it.ClassName
}

// placeholderUUID is the all-zeros uuid. uuidindex's scan deliberately never
// indexes it (it is not a real annotation), so an item carrying it would
// never match wiki[...] and would be planned as a create — with a
// placeholder uuid baked into {{Entity}} — on every single run. Block it
// explicitly instead of letting it fail open.
const placeholderUUID = "00000000-0000-0000-0000-000000000000"

// Classify runs one item through the filter chain from design §05.
func Classify(it Item, wiki map[string]bool, cfg *Config) Filtered {
	f := Filtered{Item: it}
	switch {
	case it.UUID == placeholderUUID:
		f.Disposition, f.RuleID = DispBlocked, "placeholder-uuid"
		return f
	case wiki[it.UUID]:
		f.Disposition = DispExists
		return f
	case unnamed(it):
		f.Disposition, f.RuleID = DispBlocked, "unnamed"
		return f
	}
	for _, rule := range cfg.Blocklist {
		if rule.Matches(it.Name, it.ClassName, it.Description) {
			f.Disposition, f.RuleID = DispBlocked, rule.ID
			return f
		}
	}
	rule, known := cfg.Types[it.Type]
	switch {
	case !known:
		f.Disposition = DispUnmapped
		return f
	case rule.Skip:
		f.Disposition = DispExcluded
		return f
	}
	f.Rule = rule
	for _, rev := range cfg.Review {
		if rev.Matches(it.Name, it.ClassName, it.Description) {
			f.Disposition, f.RuleID = DispReview, rev.ID
			return f
		}
	}
	f.Disposition = DispCreate
	return f
}

// ResolveManufacturer turns an item's manufacturer data into a code and the
// wiki article to link. ok=false means no code could be determined at all —
// a plan conflict. An empty page with ok=true means "known but not an
// article-worthy maker": the lead's manufacturer clause and navplate are
// omitted (OmitInLead codes, or a code with no name anywhere).
func ResolveManufacturer(it Item, m Manufacturers) (code, page string, ok bool) {
	lowerClass := strings.ToLower(it.ClassName)
	for _, prefix := range sortedMapKeys(m.ByPrefix) {
		if strings.HasPrefix(lowerClass, prefix) {
			code = m.ByPrefix[prefix]
			break
		}
	}
	if code == "" {
		code = it.Manufacturer.Code
		if override, hit := m.ByName[it.Manufacturer.Name]; hit {
			code = override
		}
		if renamed, hit := m.Renames[code]; hit {
			code = renamed
		}
	}
	if code == "" {
		return "", "", false
	}
	if slices.Contains(m.OmitInLead, code) {
		return code, "", true
	}
	page = m.Names[code]
	if page == "" {
		page = it.Manufacturer.Name
	}
	return code, page, true
}

// ClassManufacturer returns the manufacturer code a class name claims, or ""
// when it claims none.
//
// Only the leading token counts. A maker-prefixed class name asserts who made
// the item ("kegr_fire_extinguisher_01", "cds_combat_superheavy_suit_01"), but
// a code further in names the ship the part belongs to, not its maker:
// Controller_Flight_ANVL_Hornet is the blade for Anvil's Hornet, and whoever
// built it is a separate fact. Reading those as manufacturer claims made 135
// of 143 findings false — every flight blade in the game disagreeing with
// itself — so the position is the whole signal.
func ClassManufacturer(className string, known map[string]bool) string {
	head, _, _ := strings.Cut(className, "_")
	if len(head) < 2 {
		return ""
	}
	upper := strings.ToUpper(head)
	if known[upper] {
		return upper
	}
	return ""
}

func sortedMapKeys(m map[string]string) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}
