package systemmap

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"testing"

	"github.com/StarCitizenTools/wiki-tools/scripts/internal/starmap"
)

// The Lua half of the vocabulary. systems.json is the wire between them: this
// package writes `subtype` strings into it, and Data.lua looks them up.
var (
	dataLua   = filepath.Join("..", "..", "..", "pages", "module", "SystemMap", "Data.lua")
	stylesCSS = filepath.Join("..", "..", "..", "pages", "module", "SystemMap", "styles.css")
)

// TestPlanetSubtypesMatchDataLua is the guard on the one seam in this design
// that fails silently.
//
// A subtype this package emits that SUBTYPE_KIND does not hold renders as the
// neutral 'unknown' disc: no error, no failing assertion on either side, just a
// wrong-coloured body on a live page. Both halves have their own tests pinning
// their own strings, and both would still pass while disagreeing with each
// other — the tables were derived separately from the same upstream vocabulary
// and only happen to have landed identically. This is what checks they still do.
//
// The direction matters in both senses. An emitted subtype with no kind is the
// silent bug; a kind with no emitter is dead weight that outlives whatever
// upstream string it was written for.
func TestPlanetSubtypesMatchDataLua(t *testing.T) {
	kinds, err := subtypeKind()
	if err != nil {
		t.Fatal(err)
	}

	emitted := map[string]bool{}
	for upstream, display := range planetSubtypes {
		if _, ok := kinds[display]; !ok {
			t.Errorf("this package writes subtype %q (from upstream %q), which SUBTYPE_KIND in %s "+
				"has no key for: the body would render the neutral 'unknown' disc",
				display, upstream, dataLua)
		}
		emitted[display] = true
	}

	for display := range kinds {
		if !emitted[display] {
			t.Errorf("SUBTYPE_KIND in %s keys on %q, which this package never writes: "+
				"either planetSubtypes lost an entry or the key is stale",
				dataLua, display)
		}
	}
}

// TestEveryGlyphKindIsStyled checks the far end of the same wire. A kind with no
// rule in styles.css falls through to the base disc, which is the same neutral
// grey an unmapped subtype gets — so a missing colour looks exactly like a
// missing mapping, and neither shows up in a test that only reads Lua.
//
// Star kinds are included because they are assembled, not looked up: Data.lua
// builds 'star-' .. lower(class) from whatever class string this package writes,
// so a typo here produces a plausible-looking kind that no rule matches. The
// generic 'star', 'moon', 'belt' and 'unknown' are deliberately absent — those
// ARE the fallbacks, drawn by the base disc and the --belt modifier.
func TestEveryGlyphKindIsStyled(t *testing.T) {
	css, err := os.ReadFile(stylesCSS)
	if err != nil {
		t.Fatal(err)
	}
	styled := map[string]bool{}
	for _, m := range regexp.MustCompile(`\[data-kind='([^']+)'\]`).FindAllStringSubmatch(string(css), -1) {
		styled[m[1]] = true
	}

	kinds, err := subtypeKind()
	if err != nil {
		t.Fatal(err)
	}
	want := map[string]string{}
	for subtype, kind := range kinds {
		want[kind] = "subtype " + subtype
	}
	for upstream, star := range starSubtypes {
		if star.class == "" {
			continue // Variable and Subgiant: the generic disc, on purpose
		}
		want["star-"+strings.ToLower(star.class)] = "star subtype " + upstream
	}

	for _, kind := range sortedKeys(want) {
		if !styled[kind] {
			t.Errorf("%s yields glyph kind %q, which %s has no rule for: "+
				"it would render the neutral base disc, indistinguishable from an unmapped body",
				want[kind], kind, stylesCSS)
		}
	}
}

// TestStarOnlySystemEmitsAnEmptyBodiesArray covers the other way this file can
// be unreadable to Lua: shape rather than vocabulary.
//
// Fifteen upstream systems are a star and nothing else. A nil Go slice encodes
// as `null`, and Data.lua walks `system.bodies` with ipairs() — once in
// buildModel, and once in tierExtents, which reads EVERY system in the file to
// scale the discs. So a single null does not degrade one map: it raises
// "bad argument #1 to 'ipairs' (table expected, got nil)" on every page the
// component renders. `moons` already had this handled; `bodies` did not.
func TestStarOnlySystemEmitsAnEmptyBodiesArray(t *testing.T) {
	name := "Vector"
	doc := &starmap.Document{
		Systems: []starmap.System{{ID: 1, Name: name}},
		Objects: []starmap.Object{{ID: 10, StarSystemID: 1, Type: typeStar, Name: &name}},
	}
	overlay, err := LoadOverlay([]byte(`{"systems": {"Vector": {}}}`))
	if err != nil {
		t.Fatal(err)
	}
	res, err := Build(Options{Starmap: doc, Overlay: overlay})
	if err != nil {
		t.Fatal(err)
	}
	sys, ok := res.Document.Systems.Get(name)
	if !ok {
		t.Fatal("the star-only system was not built")
	}
	if sys.Bodies == nil {
		t.Error("Bodies is a nil slice, which encodes as null")
	}

	out, err := Encode(res.Document)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(out), `"bodies": null`) {
		t.Errorf("emitted `\"bodies\": null`, which Data.lua cannot ipairs():\n%s", out)
	}
	if !strings.Contains(string(out), `"bodies": []`) {
		t.Errorf("expected an empty bodies array, got:\n%s", out)
	}
}

// subtypeKind reads the SUBTYPE_KIND table out of Data.lua.
//
// Parsing the Lua is the point: importing a copy of the table would only pin the
// copy. It is brittle by design — reformatting SUBTYPE_KIND breaks this test
// rather than letting it quietly stop checking anything, which is the failure
// mode that matters for a cross-language assertion.
func subtypeKind() (map[string]string, error) {
	src, err := os.ReadFile(dataLua)
	if err != nil {
		return nil, err
	}
	const open = "local SUBTYPE_KIND = {"
	_, rest, ok := strings.Cut(string(src), open)
	if !ok {
		return nil, fmt.Errorf("%s: no %q; the table was renamed or reformatted, and this test "+
			"stopped checking the vocabulary seam", dataLua, open)
	}
	body, _, ok := strings.Cut(rest, "\n}")
	if !ok {
		return nil, fmt.Errorf("%s: SUBTYPE_KIND is not closed by a line-leading '}'", dataLua)
	}

	out := map[string]string{}
	for _, m := range regexp.MustCompile(`\['([^']+)'\]\s*=\s*'([^']+)'`).FindAllStringSubmatch(body, -1) {
		out[m[1]] = m[2]
	}
	if len(out) == 0 {
		return nil, fmt.Errorf("%s: parsed no entries out of SUBTYPE_KIND", dataLua)
	}
	return out, nil
}

func sortedKeys(m map[string]string) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}
