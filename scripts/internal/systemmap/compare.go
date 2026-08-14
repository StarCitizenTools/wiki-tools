package systemmap

import (
	"encoding/json"
	"fmt"
	"sort"
	"strings"
)

// Compare summarises how one document differs from another, for the -diff
// report. The file is small enough to eyeball, but a line diff of pretty-printed
// JSON hides the two changes that actually matter — a body moving on the rail,
// and a correction disappearing — inside a wall of re-indented context.
func Compare(oldDoc, newDoc *Document) []string {
	var out []string
	if oldDoc.Doc != newDoc.Doc {
		out = append(out, "%doc: changed")
	}
	// A moved extent resizes every disc on all 42 pages while changing no body,
	// so it would otherwise be the one difference this report does not mention.
	if before, after := oldDoc.Extents.summarise(), newDoc.Extents.summarise(); before != after {
		out = append(out, fmt.Sprintf("%s -> %s", before, after))
	}

	oldKeys, newKeys := oldDoc.Systems.Keys(), newDoc.Systems.Keys()
	added, removed, common := partition(oldKeys, newKeys)
	for _, k := range added {
		sys, _ := newDoc.Systems.Get(k)
		out = append(out, fmt.Sprintf("+ %s (%d bodies)", k, len(sys.Bodies)))
	}
	for _, k := range removed {
		out = append(out, fmt.Sprintf("- %s", k))
	}
	if strings.Join(oldKeys, "\x00") != strings.Join(newKeys, "\x00") && len(added)+len(removed) == 0 {
		out = append(out, fmt.Sprintf("system order: %s -> %s", strings.Join(oldKeys, ", "), strings.Join(newKeys, ", ")))
	}

	for _, k := range common {
		oldSys, _ := oldDoc.Systems.Get(k)
		newSys, _ := newDoc.Systems.Get(k)
		out = append(out, prefix(k, compareSystem(oldSys, newSys))...)
	}

	if len(out) == 0 {
		out = append(out, "no differences")
	}
	return out
}

func compareSystem(oldSys, newSys *System) []string {
	var out []string
	if oldSys.Page != newSys.Page {
		out = append(out, fmt.Sprintf("page: %s -> %s", oldSys.Page, newSys.Page))
	}
	out = append(out, prefix("star", compareBody(oldSys.Star, newSys.Star))...)

	oldBodies, oldOrder := flatten(oldSys.Bodies)
	newBodies, newOrder := flatten(newSys.Bodies)
	added, removed, common := partition(oldOrder, newOrder)
	for _, k := range added {
		out = append(out, "+ "+k)
	}
	for _, k := range removed {
		out = append(out, "- "+k)
	}
	if len(added)+len(removed) == 0 && strings.Join(oldOrder, "\x00") != strings.Join(newOrder, "\x00") {
		out = append(out, fmt.Sprintf("order: %s -> %s", strings.Join(oldOrder, ", "), strings.Join(newOrder, ", ")))
	}
	for _, k := range common {
		out = append(out, prefix(k, compareBody(oldBodies[k], newBodies[k]))...)
	}
	return out
}

// compareBody reports field-level changes, comparing the encoded form so that
// an omitted key and an empty one are the same thing here as on the page.
func compareBody(oldBody, newBody Body) []string {
	oldFields, err := fieldMap(oldBody)
	if err != nil {
		return []string{"(could not encode)"}
	}
	newFields, err := fieldMap(newBody)
	if err != nil {
		return []string{"(could not encode)"}
	}
	// moons are compared as their own entries by flatten(); comparing them here
	// too would print the whole subtree for a one-field change.
	delete(oldFields, "moons")
	delete(newFields, "moons")

	var names []string
	seen := map[string]bool{}
	for k := range oldFields {
		names, seen[k] = append(names, k), true
	}
	for k := range newFields {
		if !seen[k] {
			names = append(names, k)
		}
	}
	sort.Strings(names)

	var out []string
	for _, k := range names {
		before, after := string(oldFields[k]), string(newFields[k])
		if before == after {
			continue
		}
		out = append(out, fmt.Sprintf("%s: %s -> %s", k, orNone(before), orNone(after)))
	}
	return out
}

// flatten indexes a system's bodies by label, moons included as "Planet / Moon",
// and returns the rail order alongside.
//
// A label is not unique. Upstream leaves bodies unnamed, so the designation
// stands in, and Ellis has two called "Ellis XI". Indexing on the label alone
// would let the second overwrite the first, and the report would then be unable
// to show a change to either — the one thing a diff must never do quietly. A
// repeat is therefore suffixed with its rail position within the label.
func flatten(bodies []Body) (map[string]Body, []string) {
	index := map[string]Body{}
	order := make([]string, 0, len(bodies))
	add := func(label string, b Body) {
		key := label
		for n := 2; ; n++ {
			if _, taken := index[key]; !taken {
				break
			}
			key = fmt.Sprintf("%s [%d]", label, n)
		}
		index[key] = b
		order = append(order, key)
	}
	for _, b := range bodies {
		add(b.Label, b)
		if b.Moons == nil {
			continue
		}
		for _, m := range *b.Moons {
			add(b.Label+" / "+m.Label, m)
		}
	}
	return index, order
}

func fieldMap(v any) (map[string]json.RawMessage, error) {
	b, err := json.Marshal(v)
	if err != nil {
		return nil, err
	}
	var m map[string]json.RawMessage
	if err := json.Unmarshal(b, &m); err != nil {
		return nil, err
	}
	return m, nil
}

// partition splits two ordered key lists into added, removed and common, each in
// the order they appear in the newer list where possible.
func partition(oldKeys, newKeys []string) (added, removed, common []string) {
	inOld := map[string]bool{}
	for _, k := range oldKeys {
		inOld[k] = true
	}
	inNew := map[string]bool{}
	for _, k := range newKeys {
		inNew[k] = true
	}
	for _, k := range newKeys {
		if inOld[k] {
			common = append(common, k)
		} else {
			added = append(added, k)
		}
	}
	for _, k := range oldKeys {
		if !inNew[k] {
			removed = append(removed, k)
		}
	}
	return added, removed, common
}

func prefix(label string, lines []string) []string {
	out := make([]string, 0, len(lines))
	for _, l := range lines {
		out = append(out, label+" "+l)
	}
	return out
}

func orNone(s string) string {
	if s == "" {
		return "(none)"
	}
	return s
}
