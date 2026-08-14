// Package systemmap builds Module:SystemMap/systems.json — the orbit-rail model
// behind {{System map}} — from the ARK Starmap mirror plus a hand-owned overlay
// of editorial corrections.
//
// The split is the point. Upstream data goes stale and gets refetched; editorial
// judgement (which page a body links to, where a belt sits, which planet is
// really a moon) must survive that refetch. Before this package both lived in
// the same hand-edited file, so a refetch would have overwritten the judgement.
//
// Struct field order is significant: encoding/json emits fields in declaration
// order, and that order is the key order of the committed page. Do not reorder
// fields without intending to rewrite the file.
package systemmap

import (
	"bytes"
	"encoding/json"
	"fmt"
)

// Tier marks a body that is not what its position in the file would otherwise
// say. Module:SystemMap infers "planet" from the absence of the key at the top
// level, and "moon" from the absence of it inside a planet's `moons` array.
//
// `belt` marks a region on the planet rail. `ring` marks a planetary ring, which
// nests where a moon nests — the rail has exactly one level of nesting and a
// ring wants that one — while carrying its own glyph kind, because a ring is not
// a body and must not be drawn as one.
//
// A third value reaches the top level: `moon`, for the one body upstream parents
// to the star rather than to a planet, which therefore has no planet to nest
// under and holds a top-level slot while being a moon. Its constant is tierMoon,
// declared in extents.go with the tiers that scale, because it is the same tier —
// the marker exists precisely so that the body is measured, coloured and counted
// there rather than at the tier its position implies.
const (
	tierBelt = "belt"
	tierRing = "ring"
)

// Body is one rendered body: a star, a planet, a belt, a moon, or a planet's
// rings.
//
// Every optional field is omitted rather than emitted as null, because
// Module:SystemMap/Data.lua reads them with `type(x) == 'string'`-style guards
// and mw.loadJsonData freezes what it loads — an explicit null buys nothing and
// costs bytes on a page that is re-parsed on every render of every article that
// embeds a map.
type Body struct {
	Page        string `json:"page"`
	Label       string `json:"label"`
	Designation string `json:"designation,omitempty"`
	Subtype     string `json:"subtype,omitempty"`
	Class       string `json:"class,omitempty"`
	Tier        string `json:"tier,omitempty"`
	// Moons is a pointer so that "planet with no moons" (an empty array, which
	// the committed file writes) stays distinguishable from "cannot have moons"
	// (a belt or a moon, which omit the key entirely).
	Moons *[]Body `json:"moons,omitempty"`
	// KM is a radius for stars and a diameter for everything else. See the
	// %doc in systems.json: the disc scale is rank-preserving within a tier and
	// never compares across tiers, so the mixed quantity is harmless — but it
	// is a quantity, not a unit, so it must not be described as one.
	KM        *float64 `json:"km,omitempty"`
	Icon      string   `json:"icon,omitempty"`
	IconRatio float64  `json:"iconRatio,omitempty"`
}

// Shapes a system's second star can be drawn in. Both are real arrangements
// upstream describes, and drawing one as the other would be the inconsistency:
// see resolveStars for how the shape is derived.
const (
	// shapeNested is a companion that orbits the primary — upstream parents it
	// to the other star (Tyrol B, Kyuk'ya B). It is drawn where a moon is drawn,
	// nested under the primary, because that is what it does.
	shapeNested = "nested"
	// shapePaired is a co-orbiting pair — neither star is parented to the other,
	// and upstream puts both at the same distance from the barycentre (Bacchus,
	// Baker, Goss). Both share the head slot and the planets orbit the pair.
	shapePaired = "paired"
)

// System is one star system: its own article, its star or stars, and everything
// orbiting them in orbital order — planets and belts interleaved.
//
// Star, Companion and CompanionShape are all optional, and all three are omitted
// rather than emitted empty, which is what keeps this shape backward compatible:
// the 83 single-star systems write `page`, `star`, `bodies` and nothing else,
// exactly as they did before a second star was representable.
//
// Star is a pointer because one upstream system, Min, has no star at all. It
// carries a planet and four moons and is perfectly renderable without a head, so
// the model must not assume one — a value type here would have made "no star"
// unrepresentable and pushed the problem into whichever code first dereferenced
// it. (Tamsa files no STAR either, but is not renderable headless and never
// reaches this type: see typeBlackHole.)
type System struct {
	Page string `json:"page"`
	Star *Body  `json:"star,omitempty"`
	// Companion is the system's second star. Five systems have one; none has a
	// third. It is a sibling key rather than an entry in Bodies because it is
	// not on the planet rail, and rather than an array of stars because turning
	// `star` into `stars` would have rewritten all 145 published pages to say
	// something none of them needed to say.
	Companion *Body `json:"companion,omitempty"`
	// CompanionShape is how the two stars relate: shapeNested or shapePaired.
	// It is meaningless without a companion and is never written without one.
	CompanionShape string `json:"companionShape,omitempty"`
	Bodies         []Body `json:"bodies"`
}

// Extent is one tier's smallest and largest `km`, in the units Body.KM stores.
type Extent struct {
	Min float64 `json:"min"`
	Max float64 `json:"max"`
}

// Extents is the disc scale, recorded rather than inferred.
//
// Module:SystemMap/Data.lua maps a body's km onto a pixel diameter by where it
// falls between its tier's smallest and largest. Computing those bounds from
// the file's own contents — which is what Data.lua did, and still does when this
// key is absent — makes every disc on every already-published page a function of
// which systems happen to have been rolled out. Adding Terra and Castra alone
// moved Nyx's star from 30.0px to 24.3px.
//
// So the generator anchors the bounds to the whole upstream dataset once, and
// they stop moving: a later batch adds systems without resizing anything already
// on the wiki.
//
// Belts have no entry. They render as a fixed band, carry no km, and have no
// meaningful diameter to scale.
type Extents struct {
	Star   *Extent `json:"star,omitempty"`
	Planet *Extent `json:"planet,omitempty"`
	Moon   *Extent `json:"moon,omitempty"`
}

// Document is the file written to Module:SystemMap/systems.json.
type Document struct {
	Doc string `json:"%doc"`
	// Extents is a pointer so that its absence stays representable: the page as
	// it stood before this key existed still decodes, and Data.lua's fallback is
	// tested against a document without one.
	Extents *Extents `json:"extents,omitempty"`
	Systems Systems  `json:"systems"`
}

// Systems is an insertion-ordered map of system name to system.
//
// A plain map[string]*System would encode in sorted key order (Nyx, Pyro,
// Stanton), which is neither the order the file is in nor an order anybody
// chose. The overlay's key order is the authored order, and preserving it is
// what lets the generator reproduce the committed file byte for byte.
type Systems struct {
	keys  []string
	byKey map[string]*System
}

// Set appends a system, or replaces one already present without moving it.
func (s *Systems) Set(key string, sys *System) {
	if s.byKey == nil {
		s.byKey = map[string]*System{}
	}
	if _, seen := s.byKey[key]; !seen {
		s.keys = append(s.keys, key)
	}
	s.byKey[key] = sys
}

// Get returns a system by name.
func (s *Systems) Get(key string) (*System, bool) {
	sys, ok := s.byKey[key]
	return sys, ok
}

// Keys returns the system names in file order.
func (s *Systems) Keys() []string { return s.keys }

// Len returns how many systems the document holds.
func (s *Systems) Len() int { return len(s.keys) }

// MarshalJSON writes the systems in insertion order.
//
// The compact form is deliberate: json.MarshalIndent marshals first and indents
// afterwards, so a custom marshaller only has to produce valid compact JSON for
// the tab indentation to come out right.
func (s Systems) MarshalJSON() ([]byte, error) {
	var buf bytes.Buffer
	buf.WriteByte('{')
	for i, k := range s.keys {
		if i > 0 {
			buf.WriteByte(',')
		}
		key, err := json.Marshal(k)
		if err != nil {
			return nil, err
		}
		buf.Write(key)
		buf.WriteByte(':')
		val, err := json.Marshal(s.byKey[k])
		if err != nil {
			return nil, fmt.Errorf("system %s: %w", k, err)
		}
		buf.Write(val)
	}
	buf.WriteByte('}')
	return buf.Bytes(), nil
}

// UnmarshalJSON reads the systems, keeping the order they appear in.
func (s *Systems) UnmarshalJSON(b []byte) error {
	keys, raw, err := decodeOrderedObject(b)
	if err != nil {
		return err
	}
	*s = Systems{}
	for _, k := range keys {
		var sys System
		if err := json.Unmarshal(raw[k], &sys); err != nil {
			return fmt.Errorf("system %s: %w", k, err)
		}
		s.Set(k, &sys)
	}
	return nil
}

// decodeOrderedObject reads a JSON object and returns its keys in document
// order alongside their raw values. encoding/json's map decoding discards that
// order, and both the overlay and the output depend on it.
func decodeOrderedObject(b []byte) ([]string, map[string]json.RawMessage, error) {
	dec := json.NewDecoder(bytes.NewReader(b))
	tok, err := dec.Token()
	if err != nil {
		return nil, nil, err
	}
	if delim, ok := tok.(json.Delim); !ok || delim != '{' {
		return nil, nil, fmt.Errorf("expected a JSON object, got %v", tok)
	}

	var keys []string
	values := map[string]json.RawMessage{}
	for dec.More() {
		tok, err := dec.Token()
		if err != nil {
			return nil, nil, err
		}
		key, ok := tok.(string)
		if !ok {
			return nil, nil, fmt.Errorf("expected an object key, got %v", tok)
		}
		var raw json.RawMessage
		if err := dec.Decode(&raw); err != nil {
			return nil, nil, fmt.Errorf("key %s: %w", key, err)
		}
		if _, seen := values[key]; !seen {
			keys = append(keys, key)
		}
		values[key] = raw
	}
	if _, err := dec.Token(); err != nil { // closing brace
		return nil, nil, err
	}
	return keys, values, nil
}

// Encode renders the document exactly as the committed page stores it: tab
// indented, one trailing newline.
//
// Go's encoding/json escapes &, < and > — the same set MediaWiki's JSON content
// model escapes — and leaves apostrophes alone, as MediaWiki does, so these
// bytes are what the wiki will store. TestEncodeRoundTripsCommittedFile pins it.
func Encode(doc *Document) ([]byte, error) {
	b, err := json.MarshalIndent(doc, "", "\t")
	if err != nil {
		return nil, err
	}
	return append(b, '\n'), nil
}

// Decode parses a systems document, preserving system order.
func Decode(b []byte) (*Document, error) {
	var doc Document
	if err := json.Unmarshal(b, &doc); err != nil {
		return nil, err
	}
	return &doc, nil
}
