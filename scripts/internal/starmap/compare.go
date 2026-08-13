package starmap

import (
	"encoding/json"
	"fmt"
	"sort"
)

// Decode parses a starmap document.
func Decode(b []byte) (*Document, error) {
	var doc Document
	if err := json.Unmarshal(b, &doc); err != nil {
		return nil, err
	}
	return &doc, nil
}

// fieldMap renders a record as its JSON fields, so any two records can be
// compared field by field without hand-writing a comparison per struct.
// Encoding is canonical, so a byte comparison per field is exact.
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

// diffRecords compares two id-keyed collections and returns a summary.
func diffRecords[T any](
	label string,
	oldByID, newByID map[int]T,
	name func(T) string,
) []string {
	var added, removed []string
	changedFields := map[string]int{}
	changedRecords := 0

	for id, n := range newByID {
		if _, ok := oldByID[id]; !ok {
			added = append(added, fmt.Sprintf("%s [%d]", name(n), id))
		}
	}
	for id, o := range oldByID {
		if _, ok := newByID[id]; !ok {
			removed = append(removed, fmt.Sprintf("%s [%d]", name(o), id))
		}
	}

	for id, o := range oldByID {
		n, ok := newByID[id]
		if !ok {
			continue
		}
		om, err1 := fieldMap(o)
		nm, err2 := fieldMap(n)
		if err1 != nil || err2 != nil {
			continue
		}
		touched := false
		for k, ov := range om {
			nv, present := nm[k]
			if !present || string(ov) != string(nv) {
				changedFields[k]++
				touched = true
			}
		}
		if touched {
			changedRecords++
		}
	}

	sort.Strings(added)
	sort.Strings(removed)

	lines := []string{fmt.Sprintf("%s: %d -> %d  (+%d added, -%d removed, %d changed)",
		label, len(oldByID), len(newByID), len(added), len(removed), changedRecords)}

	for _, a := range capped(added, 10) {
		lines = append(lines, "  + "+a)
	}
	for _, r := range capped(removed, 10) {
		lines = append(lines, "  - "+r)
	}
	if len(changedFields) > 0 {
		type fc struct {
			field string
			n     int
		}
		var fcs []fc
		for f, n := range changedFields {
			fcs = append(fcs, fc{f, n})
		}
		sort.Slice(fcs, func(i, j int) bool {
			if fcs[i].n != fcs[j].n {
				return fcs[i].n > fcs[j].n
			}
			return fcs[i].field < fcs[j].field
		})
		for _, f := range fcs {
			lines = append(lines, fmt.Sprintf("    %5dx %s", f.n, f.field))
		}
	}
	return lines
}

// capped truncates a list for display, noting how many were elided.
func capped(items []string, max int) []string {
	if len(items) <= max {
		return items
	}
	out := append([]string{}, items[:max]...)
	return append(out, fmt.Sprintf("… and %d more", len(items)-max))
}

// Compare summarises the difference between two starmap documents, keyed on
// record id. The output is a field-level tally rather than a textual diff,
// because the two files are a megabyte of JSON and a line diff is unreadable.
func Compare(oldDoc, newDoc *Document) []string {
	oldSys := make(map[int]System, len(oldDoc.Systems))
	for _, s := range oldDoc.Systems {
		oldSys[s.ID] = s
	}
	newSys := make(map[int]System, len(newDoc.Systems))
	for _, s := range newDoc.Systems {
		newSys[s.ID] = s
	}

	oldObj := make(map[int]Object, len(oldDoc.Objects))
	for _, o := range oldDoc.Objects {
		oldObj[o.ID] = o
	}
	newObj := make(map[int]Object, len(newDoc.Objects))
	for _, o := range newDoc.Objects {
		newObj[o.ID] = o
	}

	lines := diffRecords("systems", oldSys, newSys, func(s System) string {
		return fmt.Sprintf("%s (%s)", s.Name, s.Code)
	})
	lines = append(lines, diffRecords("objects", oldObj, newObj, func(o Object) string {
		n := "<unnamed>"
		if o.Name != nil {
			n = *o.Name
		}
		return fmt.Sprintf("%s [%s] (%s)", n, o.Type, o.Code)
	})...)
	return lines
}
