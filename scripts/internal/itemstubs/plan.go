package itemstubs

import (
	"context"
	"fmt"
	"sort"
	"strings"
	"time"
	"unicode"
	"unicode/utf8"

	"github.com/StarCitizenTools/wiki-tools/scripts/internal/mediawiki"
)

// Meta stamps a plan with its provenance. A plan is a snapshot of live wiki
// state plus one dump revision; its age and sources are part of reading it.
type Meta struct {
	Generated time.Time `json:"generated"`
	Build     string    `json:"build"`
	Source    string    `json:"source"`
	WikiUUIDs int       `json:"wikiUuids"`
	Items     int       `json:"items"`
}

// CreateEntry is one stub page ready to create mechanically.
type CreateEntry struct {
	Title        string `json:"title"`
	UUID         string `json:"uuid"`
	Type         string `json:"type"`
	Kind         string `json:"kind"`
	Manufacturer string `json:"manufacturer"`
	// MismatchFromClass is non-empty when the item's class name implies a
	// different manufacturer than Manufacturer (see Mismatch). It means this
	// entry needs checking against the class name before it is published,
	// not applied verbatim.
	MismatchFromClass string `json:"mismatchFromClass,omitempty"`
	Summary           string `json:"summary"`
	Wikitext          string `json:"wikitext"`
}

// ConflictEntry is an item the tool refuses to decide: the applying agent
// resolves it with context the tool does not have.
type ConflictEntry struct {
	Reason   string   `json:"reason"`
	Title    string   `json:"title"`
	UUID     string   `json:"uuid,omitempty"`
	UUIDs    []string `json:"uuids,omitempty"`
	Note     string   `json:"note,omitempty"`
	Wikitext string   `json:"wikitext,omitempty"`
	// OnPageUUID is the uuid the existing page already documents, with that
	// item's class name and whether its description is identical to this
	// one's. A match is the fingerprint of a name CIG reused for an
	// unimplemented item — evidence for the reviewer, never grounds for the
	// tool to drop the item, because the page sometimes holds the placeholder
	// and the flagged item is the real one.
	OnPageUUID      string `json:"onPageUuid,omitempty"`
	OnPageClass     string `json:"onPageClass,omitempty"`
	SameDescription bool   `json:"sameDescription,omitempty"`
}

// Skipped summarises everything filtered out, by reason.
type Skipped struct {
	Exists   int            `json:"exists"`
	Blocked  map[string]int `json:"blocked"`
	Excluded int            `json:"excluded"`
	Unusable int            `json:"unusable"`
}

// UnmappedType is a type with page-candidates that nobody has decided on —
// the config-drift report, printed every run until each is allowlisted or
// skip-listed.
type UnmappedType struct {
	Type   string `json:"type"`
	Count  int    `json:"count"`
	Sample string `json:"sample"`
}

// Mismatch is a disagreement between the manufacturer the dump states and
// the one its class name implies. It is advisory: the item is still planned,
// because either side can be the wrong one, and only a human reading both
// can say which.
type Mismatch struct {
	Title     string `json:"title"`
	UUID      string `json:"uuid"`
	Resolved  string `json:"resolved"`
	FromClass string `json:"fromClass"`
	ClassName string `json:"className"`
}

// Plan is the document an agent applies via the MCP server.
type Plan struct {
	Meta       Meta            `json:"meta"`
	Create     []CreateEntry   `json:"create"`
	Conflicts  []ConflictEntry `json:"conflicts"`
	Skipped    Skipped         `json:"skipped"`
	Unmapped   []UnmappedType  `json:"unmappedTypes"`
	Mismatches []Mismatch      `json:"manufacturerMismatches"`
}

// Drift reports whether anything is pending — creates or conflicts both mean
// somebody has work to do.
func (p *Plan) Drift() bool { return len(p.Create)+len(p.Conflicts) > 0 }

// invalidTitleChars are rejected locally. Most of these MediaWiki genuinely
// cannot host in a title; "_" is actually legal there (MediaWiki treats it as
// equivalent to a space), but this tool declines to guess how to normalise it
// rather than silently collapsing it itself. "|" or "#" would additionally
// corrupt the batched existence query.
const invalidTitleChars = "#<>[]|{}_"

func invalidTitle(title string) bool {
	return strings.ContainsAny(title, invalidTitleChars) || title != strings.TrimSpace(title)
}

// titleKey is the wiki page title an item's name would produce: internal
// whitespace runs collapse to a single space and the first rune is
// upper-cased (MediaWiki's first-letter title normalisation). Duplicate
// detection groups on this key rather than the dump's raw string, so "cup"
// and "Cup" (or a name with a stray double space) are recognised as the same
// page instead of producing two creates for one title. Underscores and edge
// whitespace are left to invalidTitle.
func titleKey(name string) string {
	key := strings.Join(strings.Fields(name), " ")
	if key == "" {
		return key
	}
	r, size := utf8.DecodeRuneInString(key)
	return string(unicode.ToUpper(r)) + key[size:]
}

// BuildPlan classifies every item, renders stubs, checks titles against the
// live wiki through statuses (injected so tests stay offline), and assembles
// the plan. Meta's WikiUUIDs/Items are filled here from the inputs.
func BuildPlan(ctx context.Context, items []Item, wiki map[string]bool, wikiByPage map[string]string, cfg *Config, reg *Registry,
	meta Meta, statuses func(context.Context, []string) (map[string]mediawiki.TitleStatus, error)) (*Plan, error) {

	plan := &Plan{
		Meta:       meta,
		Create:     []CreateEntry{},
		Conflicts:  []ConflictEntry{},
		Unmapped:   []UnmappedType{},
		Mismatches: []Mismatch{},
		Skipped:    Skipped{Blocked: map[string]int{}},
	}
	plan.Meta.WikiUUIDs = len(wiki)
	plan.Meta.Items = len(items)

	version, ok := Version(meta.Build)
	if !ok {
		return nil, fmt.Errorf("itemstubs: %q is not a build id; pass -build", meta.Build)
	}
	date := meta.Generated.UTC().Format("2006-01-02")

	known := make(map[string]bool, len(reg.Manufacturers))
	for code := range reg.Manufacturers {
		known[strings.ToUpper(code)] = true
	}

	// itemsByUUID resolves a title-exists conflict's on-page uuid to the dump
	// item it names, so the conflict can carry that item's class name and a
	// description comparison — evidence for the reviewer, built once here
	// rather than per-conflict.
	itemsByUUID := make(map[string]Item, len(items))
	for _, it := range items {
		itemsByUUID[it.UUID] = it
	}

	type candidate struct {
		filtered Filtered
		code     string
		wikitext string
		// mismatchFromClass mirrors Mismatch.FromClass for this item, carried
		// alongside the candidate so a resulting CreateEntry can surface it
		// too — see BuildPlan's Mismatches handling below.
		mismatchFromClass string
	}
	candidateUUIDs := func(cands []candidate) []string {
		uuids := make([]string, len(cands))
		for i, c := range cands {
			uuids[i] = c.filtered.Item.UUID
		}
		sort.Strings(uuids)
		return uuids
	}

	byTitle := map[string][]candidate{}
	unmappedCount := map[string]int{}
	unmappedSample := map[string]string{}

	for _, it := range items {
		f := Classify(it, wiki, cfg)
		switch f.Disposition {
		case DispExists:
			plan.Skipped.Exists++
		case DispBlocked:
			plan.Skipped.Blocked[f.RuleID]++
		case DispExcluded:
			plan.Skipped.Excluded++
		case DispUnmapped:
			unmappedCount[it.Type]++
			if unmappedSample[it.Type] == "" {
				unmappedSample[it.Type] = it.Name
			}
		case DispReview, DispCreate:
			code, page, ok := ResolveManufacturer(it, cfg.Manufacturers, reg)
			if !ok {
				plan.Conflicts = append(plan.Conflicts, ConflictEntry{
					Reason: "no-manufacturer", Title: it.Name, UUID: it.UUID,
					Note: fmt.Sprintf("class %s: no manufacturer in dump and no prefix rule", it.ClassName),
				})
				continue
			}
			var mismatchFromClass string
			if fromClass := ClassManufacturer(it.ClassName, known); fromClass != "" && fromClass != code &&
				cfg.Manufacturers.Aliases[fromClass] != code {
				mismatchFromClass = fromClass
				plan.Mismatches = append(plan.Mismatches, Mismatch{
					Title: it.Name, UUID: it.UUID, Resolved: code,
					FromClass: fromClass, ClassName: it.ClassName,
				})
			}
			kind := cfg.Kinds[f.Rule.Kind]
			wikitext := RenderStub(StubData{
				Name: it.Name, UUID: it.UUID,
				MfrCode: code, MfrPage: page,
				Label: cfg.LabelFor(it.Type, reg), LabelLink: f.Rule.LabelLink, NoLabelLink: f.Rule.NoLabelLink, Navplate: f.Rule.Navplate,
				Sections: kind.Sections, LeadSize: kind.LeadSize, Size: it.Size,
				Version: version, Date: date,
			})
			key := titleKey(it.Name)
			byTitle[key] = append(byTitle[key], candidate{f, code, wikitext, mismatchFromClass})
		}
	}

	// Local title validation and duplicate grouping happen before the wiki is
	// asked anything: invalid titles would corrupt the batch, and duplicates
	// are conflicts regardless of what exists.
	var toCheck []string
	for title, cands := range byTitle {
		switch {
		case invalidTitle(title):
			entry := ConflictEntry{
				Reason: "invalid-title", Title: title,
				Note: "name cannot be a wiki title as-is; needs a hand-picked title",
			}
			if len(cands) == 1 {
				entry.UUID = cands[0].filtered.Item.UUID
			} else {
				entry.UUIDs = candidateUUIDs(cands)
			}
			plan.Conflicts = append(plan.Conflicts, entry)
			delete(byTitle, title)
		case len(cands) > 1:
			plan.Conflicts = append(plan.Conflicts, ConflictEntry{
				Reason: "duplicate-name", Title: title, UUIDs: candidateUUIDs(cands),
				Note: "several missing items share this name; needs disambiguation",
			})
			delete(byTitle, title)
		default:
			toCheck = append(toCheck, title)
		}
	}
	sort.Strings(toCheck)

	var existing map[string]mediawiki.TitleStatus
	if len(toCheck) > 0 {
		var err error
		if existing, err = statuses(ctx, toCheck); err != nil {
			return nil, fmt.Errorf("itemstubs: checking titles: %w", err)
		}
	}

	for _, title := range toCheck {
		c := byTitle[title][0]
		it := c.filtered.Item
		status, ok := existing[title]
		if !ok {
			// The API can answer a title outside query.pages entirely (e.g.
			// interwiki or namespace resolution quirks); a title absent from
			// the statuses map is not proof it's free, so it must not fall
			// through to create.
			plan.Conflicts = append(plan.Conflicts, ConflictEntry{
				Reason: "unknown-title-status", Title: title, UUID: it.UUID,
				Note: "the wiki's answer for this title could not be classified; resolve by hand",
			})
			continue
		}
		switch {
		case status == mediawiki.TitleExists:
			entry := ConflictEntry{
				Reason: "title-exists", Title: title, UUID: it.UUID, Wikitext: c.wikitext,
				Note: "page exists without this uuid; disambiguate or merge",
			}
			if onPageUUID, hit := wikiByPage[title]; hit {
				entry.OnPageUUID = onPageUUID
				if onPageItem, found := itemsByUUID[onPageUUID]; found {
					entry.OnPageClass = onPageItem.ClassName
					desc, onPageDesc := strings.TrimSpace(it.Description), strings.TrimSpace(onPageItem.Description)
					entry.SameDescription = desc != "" && onPageDesc != "" && desc == onPageDesc
				}
			}
			plan.Conflicts = append(plan.Conflicts, entry)
		case status == mediawiki.TitleInvalid:
			plan.Conflicts = append(plan.Conflicts, ConflictEntry{
				Reason: "invalid-title", Title: title, UUID: it.UUID,
				Note: "the API rejects this title; needs a hand-picked title",
			})
		case c.filtered.Disposition == DispReview:
			plan.Conflicts = append(plan.Conflicts, ConflictEntry{
				Reason: "review:" + c.filtered.RuleID, Title: title, UUID: it.UUID, Wikitext: c.wikitext,
				Note: fmt.Sprintf("flagged by review rule %q (class %s); create only if it deserves a page", c.filtered.RuleID, it.ClassName),
			})
		default:
			plan.Create = append(plan.Create, CreateEntry{
				Title: title, UUID: it.UUID, Type: it.Type, Kind: c.filtered.Rule.Kind,
				Manufacturer:      c.code,
				MismatchFromClass: c.mismatchFromClass,
				Summary:           fmt.Sprintf("Create item stub from Alpha %s datamine", version),
				Wikitext:          c.wikitext,
			})
		}
	}

	for typ, count := range unmappedCount {
		plan.Unmapped = append(plan.Unmapped, UnmappedType{typ, count, unmappedSample[typ]})
	}
	sort.Slice(plan.Unmapped, func(i, j int) bool {
		if plan.Unmapped[i].Count != plan.Unmapped[j].Count {
			return plan.Unmapped[i].Count > plan.Unmapped[j].Count
		}
		return plan.Unmapped[i].Type < plan.Unmapped[j].Type
	})
	sort.Slice(plan.Create, func(i, j int) bool { return plan.Create[i].Title < plan.Create[j].Title })
	sort.Slice(plan.Mismatches, func(i, j int) bool { return plan.Mismatches[i].Title < plan.Mismatches[j].Title })
	sort.Slice(plan.Conflicts, func(i, j int) bool {
		a, b := plan.Conflicts[i], plan.Conflicts[j]
		if a.Reason != b.Reason {
			return a.Reason < b.Reason
		}
		if a.Title != b.Title {
			return a.Title < b.Title
		}
		return a.UUID < b.UUID
	})
	return plan, nil
}

// Report renders the plan as human-readable lines, counts first, then samples
// of each pending category — the same shape as uuidindex.Report.
func Report(p *Plan) []string {
	blocked := 0
	for _, n := range p.Skipped.Blocked {
		blocked += n
	}
	lines := []string{
		fmt.Sprintf("dump       %d usable items (%s)", p.Meta.Items, p.Meta.Build),
		fmt.Sprintf("wiki       %d annotated uuids", p.Meta.WikiUUIDs),
		fmt.Sprintf("skipped    %d on wiki, %d blocked, %d excluded types, %d unusable",
			p.Skipped.Exists, blocked, p.Skipped.Excluded, p.Skipped.Unusable),
	}
	if len(p.Skipped.Blocked) > 0 {
		var ruleIDs []string
		for id := range p.Skipped.Blocked {
			ruleIDs = append(ruleIDs, id)
		}
		sort.Strings(ruleIDs)
		lines = append(lines, fmt.Sprintf("blocked    %d by heuristic rule", blocked))
		for _, id := range ruleIDs {
			lines = append(lines, fmt.Sprintf("  %5d  %s", p.Skipped.Blocked[id], id))
		}
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
	sample(len(p.Create), "create     %d stub pages", func(i int) string {
		c := p.Create[i]
		return fmt.Sprintf("%s (%s, %s)", c.Title, c.Kind, c.Type)
	})
	// Conflicts are sampled per reason rather than off the top of the sorted
	// list: they sort by reason, so a flat sample only ever shows whichever
	// reason happens to sort first and says nothing about the rest.
	if n := len(p.Conflicts); n > 0 {
		lines = append(lines, fmt.Sprintf("conflicts  %d for agent judgment", n))
		byReason := map[string][]ConflictEntry{}
		var order []string
		for _, c := range p.Conflicts {
			if _, seen := byReason[c.Reason]; !seen {
				order = append(order, c.Reason)
			}
			byReason[c.Reason] = append(byReason[c.Reason], c)
		}
		sort.Strings(order)
		for _, reason := range order {
			group := byReason[reason]
			noise := 0
			for _, c := range group {
				if c.SameDescription {
					noise++
				}
			}
			head := fmt.Sprintf("  %5d  %s", len(group), reason)
			if noise > 0 {
				head += fmt.Sprintf("  (%d share the description of the item already on the page)", noise)
			}
			lines = append(lines, head)
			const per = 3
			for i := 0; i < len(group) && i < per; i++ {
				lines = append(lines, "         "+group[i].Title)
			}
			if len(group) > per {
				lines = append(lines, fmt.Sprintf("         … and %d more", len(group)-per))
			}
		}
	}
	sample(len(p.Unmapped), "unmapped   %d types nobody has decided on", func(i int) string {
		u := p.Unmapped[i]
		return fmt.Sprintf("%5d  %s (e.g. %q)", u.Count, u.Type, u.Sample)
	})
	sample(len(p.Mismatches), "mismatch   %d manufacturers disagree with the class name", func(i int) string {
		m := p.Mismatches[i]
		return fmt.Sprintf("%s: dump %s, class says %s (%s)", m.Title, m.Resolved, m.FromClass, m.ClassName)
	})
	return lines
}
