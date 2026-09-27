// Package bucketschemas turns the Entity, Company and WearableSet property
// manifests into Bucket schema pages. A bucket page is a JSON object keyed by
// field name; each value carries type, index and repeated exactly as
// Extension:Bucket reads them.
package bucketschemas

import (
	"bytes"
	"encoding/json"
	"fmt"
	"sort"
	"strings"
)

// Field is one Bucket column.
type Field struct {
	Type     string `json:"type"`
	Index    bool   `json:"index"`
	Repeated bool   `json:"repeated"`
}

// Schema is one bucket: field name -> column.
type Schema map[string]Field

type manifestEntry struct {
	Type     string `json:"type"`
	Bucket   string `json:"bucket"`
	Field    string `json:"field"`
	Index    bool   `json:"index"`
	Repeated bool   `json:"repeated"`
	// MigrateTo names the table a property is moving to; the column is built
	// there too, since the writer fills both while readers still read Bucket.
	MigrateTo string `json:"migrateTo"`
}

// Build reads one manifest and returns every bucket it defines. A property is
// placed in its bucket, and one with migrateTo in that table as well.
func Build(manifest []byte) (map[string]Schema, error) {
	var raw map[string]json.RawMessage
	if err := json.Unmarshal(manifest, &raw); err != nil {
		return nil, fmt.Errorf("manifest: %w", err)
	}
	out := map[string]Schema{}
	place := func(bucket, field string, f Field) error {
		if out[bucket] == nil {
			out[bucket] = Schema{}
		}
		if prev, ok := out[bucket][field]; ok && prev != f {
			return fmt.Errorf("bucket %s field %s defined twice with different shapes", bucket, field)
		}
		out[bucket][field] = f
		return nil
	}
	for name, msg := range raw {
		if strings.HasPrefix(name, "%") {
			continue
		}
		var e manifestEntry
		if err := json.Unmarshal(msg, &e); err != nil {
			return nil, fmt.Errorf("%s: %w", name, err)
		}
		if e.Field == "" || e.Type == "" || e.Bucket == "" {
			return nil, fmt.Errorf("%s: missing bucket, field or type", name)
		}
		f := Field{Type: e.Type, Index: e.Index, Repeated: e.Repeated}
		if e.MigrateTo != "" {
			if err := place(e.MigrateTo, e.Field, f); err != nil {
				return nil, err
			}
		}
		if err := place(e.Bucket, e.Field, f); err != nil {
			return nil, err
		}
	}
	return out, nil
}

// Render serialises one schema with fields in alphabetical order, tab-indented,
// trailing newline, so the file is byte-stable across runs.
func Render(s Schema) ([]byte, error) {
	names := make([]string, 0, len(s))
	for n := range s {
		names = append(names, n)
	}
	sort.Strings(names)
	var buf bytes.Buffer
	buf.WriteString("{\n")
	for i, n := range names {
		v, err := json.Marshal(s[n])
		if err != nil {
			return nil, err
		}
		var pretty bytes.Buffer
		if err := json.Indent(&pretty, v, "\t", "\t"); err != nil {
			return nil, err
		}
		fmt.Fprintf(&buf, "\t%q: %s", n, pretty.String())
		if i < len(names)-1 {
			buf.WriteString(",")
		}
		buf.WriteString("\n")
	}
	buf.WriteString("}\n")
	return buf.Bytes(), nil
}

// Merge adds src's fields to dst. A field both define must have the same shape.
func Merge(bucket string, dst, src Schema) error {
	for field, f := range src {
		if prev, ok := dst[field]; ok && prev != f {
			return fmt.Errorf("bucket %s field %s differs between manifests", bucket, field)
		}
		dst[field] = f
	}
	return nil
}

// PageTitle is the Bucket: page name for a bucket: Bucket lowercases and
// underscores the title, so "Vehicle stats" is queried as vehicle_stats.
func PageTitle(bucket string) string {
	s := strings.ReplaceAll(bucket, "_", " ")
	return strings.ToUpper(s[:1]) + s[1:]
}
