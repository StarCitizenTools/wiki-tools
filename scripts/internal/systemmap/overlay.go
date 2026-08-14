package systemmap

import (
	"bytes"
	"encoding/json"
	"fmt"
	"strings"
)

// Correction is what a human knows that the starmap does not.
//
// Every field overrides something the generator would otherwise derive, and each
// one corresponds to a correction that already existed in the hand-written file:
//
//	page       the derived title is wrong or ambiguous ("ArcCorp (planet)")
//	label      the display name differs from the upstream name
//	icon       a wiki file exists for the body's render (in-game systems only)
//	iconRatio  that file is wider than tall, because the body has rings
//	after      position a body upstream cannot order: belts, and Delamar
//	moonOf     reparent a body as a moon of another (Pyro IV under Pyro V)
//	km         the derived size is wrong
//
// An empty field is not an override — there is no way to blank a derived value,
// because nothing has needed one.
type Correction struct {
	Page      string   `json:"page,omitempty"`
	Label     string   `json:"label,omitempty"`
	Icon      string   `json:"icon,omitempty"`
	IconRatio float64  `json:"iconRatio,omitempty"`
	After     string   `json:"after,omitempty"`
	MoonOf    string   `json:"moonOf,omitempty"`
	KM        *float64 `json:"km,omitempty"`
}

// SystemOverlay holds the corrections for one system.
type SystemOverlay struct {
	// Star corrects the system's star. `after` and `moonOf` are meaningless on
	// the one body nothing orbits, and supplying either is an error rather than
	// a no-op. Every other key applies: `page` (Terra's star is Terra Nova),
	// `label`, `icon`, `iconRatio`, and `km` — which for a star is its radius,
	// the quantity Data.lua scales the disc by.
	Star Correction
	// Bodies is keyed by upstream body name, falling back to the upstream
	// designation when the name is null — the same identity the generator uses
	// for a body's label, so what an editor sees on the rail is what they key.
	Bodies map[string]Correction
	// BodyOrder is the order the keys were written in, which decides the
	// relative position of two bodies inserted after the same anchor.
	BodyOrder []string
}

// Overlay is the whole hand-owned input file.
type Overlay struct {
	Doc string
	// Order is the order systems were written in, and therefore the order they
	// appear in systems.json. It is also the roster: a system enters the output
	// by being listed here.
	Order   []string
	Systems map[string]*SystemOverlay
	// Exclude drops bodies whose key matches, in any system. `*` is the only
	// wildcard.
	Exclude []string
}

// LoadOverlay parses the overlay file.
//
// Unknown keys are rejected at every level. A misspelled correction key is the
// same failure as a misspelled body name — a correction that silently stops
// applying — and encoding/json's default is to ignore it.
func LoadOverlay(b []byte) (*Overlay, error) {
	keys, raw, err := decodeOrderedObject(b)
	if err != nil {
		return nil, fmt.Errorf("overlay: %w", err)
	}

	out := &Overlay{Systems: map[string]*SystemOverlay{}}
	for _, k := range keys {
		switch k {
		case "%doc":
			if err := json.Unmarshal(raw[k], &out.Doc); err != nil {
				return nil, fmt.Errorf("overlay: %%doc: %w", err)
			}
		case "exclude":
			if err := json.Unmarshal(raw[k], &out.Exclude); err != nil {
				return nil, fmt.Errorf("overlay: exclude: %w", err)
			}
		case "systems":
			if err := out.loadSystems(raw[k]); err != nil {
				return nil, err
			}
		default:
			return nil, fmt.Errorf("overlay: unknown top-level key %q "+
				"(expected %%doc, systems or exclude)", k)
		}
	}
	return out, nil
}

func (o *Overlay) loadSystems(raw json.RawMessage) error {
	names, bySystem, err := decodeOrderedObject(raw)
	if err != nil {
		return fmt.Errorf("overlay: systems: %w", err)
	}
	for _, name := range names {
		sys, err := loadSystemOverlay(bySystem[name])
		if err != nil {
			return fmt.Errorf("overlay: system %s: %w", name, err)
		}
		if _, seen := o.Systems[name]; !seen {
			o.Order = append(o.Order, name)
		}
		o.Systems[name] = sys
	}
	return nil
}

func loadSystemOverlay(raw json.RawMessage) (*SystemOverlay, error) {
	keys, parts, err := decodeOrderedObject(raw)
	if err != nil {
		return nil, err
	}
	sys := &SystemOverlay{Bodies: map[string]Correction{}}
	for _, k := range keys {
		switch k {
		case "star":
			c, err := decodeCorrection(parts[k])
			if err != nil {
				return nil, fmt.Errorf("star: %w", err)
			}
			if c.After != "" || c.MoonOf != "" {
				return nil, fmt.Errorf("star: `after` and `moonOf` do not apply to a star")
			}
			sys.Star = c
		case "bodies":
			names, byName, err := decodeOrderedObject(parts[k])
			if err != nil {
				return nil, fmt.Errorf("bodies: %w", err)
			}
			for _, name := range names {
				c, err := decodeCorrection(byName[name])
				if err != nil {
					return nil, fmt.Errorf("body %s: %w", name, err)
				}
				if c.After != "" && c.MoonOf != "" {
					return nil, fmt.Errorf("body %s: `after` orders a body on the "+
						"planet rail and `moonOf` moves it off the rail; use one", name)
				}
				sys.Bodies[name] = c
				sys.BodyOrder = append(sys.BodyOrder, name)
			}
		default:
			return nil, fmt.Errorf("unknown key %q (expected star or bodies)", k)
		}
	}
	return sys, nil
}

func decodeCorrection(raw json.RawMessage) (Correction, error) {
	dec := json.NewDecoder(bytes.NewReader(raw))
	dec.DisallowUnknownFields()
	var c Correction
	if err := dec.Decode(&c); err != nil {
		return Correction{}, err
	}
	return c, nil
}

// excludes reports whether a body key matches any exclusion pattern.
func (o *Overlay) excludes(key string) bool {
	for _, pattern := range o.Exclude {
		if globMatch(pattern, key) {
			return true
		}
	}
	return false
}

// globMatch matches a pattern in which `*` stands for any run of characters and
// every other character is literal.
//
// path.Match is not used on purpose: it also honours ?, character classes and
// backslash escapes, and body names are free text from an upstream that has
// already shipped one typo ("Protoplentary Disk 4"). A pattern language with one
// operator cannot surprise anybody.
func globMatch(pattern, s string) bool {
	parts := strings.Split(pattern, "*")
	if len(parts) == 1 {
		return pattern == s
	}
	if !strings.HasPrefix(s, parts[0]) {
		return false
	}
	s = s[len(parts[0]):]
	last := parts[len(parts)-1]
	for _, part := range parts[1 : len(parts)-1] {
		i := strings.Index(s, part)
		if i < 0 {
			return false
		}
		s = s[i+len(part):]
	}
	return strings.HasSuffix(s, last)
}
