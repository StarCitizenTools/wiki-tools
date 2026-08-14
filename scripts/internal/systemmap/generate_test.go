package systemmap

import (
	"os"
	"strings"
	"testing"

	"github.com/StarCitizenTools/wiki-tools/scripts/internal/starmap"
)

// loadFixture reads testdata/starmap.json: the six systems this package is
// tested against, taken verbatim from a real cmd/starmap run. See
// testdata/README.md for how it was cut and how to refresh it.
func loadFixture(t *testing.T) *starmap.Document {
	t.Helper()
	b, err := os.ReadFile("testdata/starmap.json")
	if err != nil {
		t.Fatal(err)
	}
	doc, err := starmap.Decode(b)
	if err != nil {
		t.Fatal(err)
	}
	return doc
}

// build runs the whole pipe — overlay parsing included — so a test exercises the
// same path the command does.
func build(t *testing.T, overlayJSON string) *Document {
	t.Helper()
	res, err := buildOrErr(t, overlayJSON)
	if err != nil {
		t.Fatal(err)
	}
	return res.Document
}

func buildOrErr(t *testing.T, overlayJSON string) (*Result, error) {
	t.Helper()
	overlay, err := LoadOverlay([]byte(overlayJSON))
	if err != nil {
		return nil, err
	}
	return Build(Options{Starmap: loadFixture(t), Overlay: overlay})
}

// rail is the labels of a system's bodies in order, with moons in parentheses.
func rail(t *testing.T, doc *Document, system string) []string {
	t.Helper()
	sys, ok := doc.Systems.Get(system)
	if !ok {
		t.Fatalf("no system %q in the output", system)
	}
	out := make([]string, 0, len(sys.Bodies))
	for _, b := range sys.Bodies {
		label := b.Label
		if b.Moons != nil && len(*b.Moons) > 0 {
			moons := make([]string, 0, len(*b.Moons))
			for _, m := range *b.Moons {
				moons = append(moons, m.Label)
			}
			label += " (" + strings.Join(moons, ", ") + ")"
		}
		out = append(out, label)
	}
	return out
}

func find(t *testing.T, doc *Document, system, label string) Body {
	t.Helper()
	sys, ok := doc.Systems.Get(system)
	if !ok {
		t.Fatalf("no system %q in the output", system)
	}
	for _, b := range sys.Bodies {
		if b.Label == label {
			return b
		}
		if b.Moons == nil {
			continue
		}
		for _, m := range *b.Moons {
			if m.Label == label {
				return m
			}
		}
	}
	t.Fatalf("no body %q in %s", label, system)
	return Body{}
}

func TestBuildOrdersPlanetsByRomanNumeral(t *testing.T) {
	// With no overlay at all, the numeral alone has to reproduce the order the
	// live page shows. orbit_period is null for every Stanton moon and for 195
	// of upstream's 326 planets, so it is not a fallback.
	doc := build(t, `{"systems": {"Stanton": {}}}`)
	// Aaron Halo has no numeral and no `after` here, so it falls to the end.
	want := "Hurston (Arial, Aberdeen, Magda, Ita), Crusader (Cellin, Daymar, Yela), " +
		"ArcCorp (Lyria, Wala), microTech (Calliope, Clio, Euterpe), Aaron Halo"
	if got := strings.Join(rail(t, doc, "Stanton"), ", "); got != want {
		t.Errorf("rail:\n got %s\nwant %s", got, want)
	}
}

func TestBuildPlacesUnnumberedBodiesWithAfter(t *testing.T) {
	// A belt has no numeral, so upstream cannot say where it sits. Without
	// `after` it lands at the end; with it, between the planets the wiki's own
	// prose puts it between.
	doc := build(t, `{"systems": {"Stanton": {}}}`)
	if got := rail(t, doc, "Stanton"); got[len(got)-1] != "Aaron Halo" {
		t.Errorf("an unplaceable body should fall to the end, got %v", got)
	}

	doc = build(t, `{"systems": {"Stanton": {"bodies": {"Aaron Halo": {"after": "Crusader"}}}}}`)
	got := rail(t, doc, "Stanton")
	if got[2] != "Aaron Halo" {
		t.Errorf("Aaron Halo should follow Crusader, got %v", got)
	}
}

func TestBuildChainsAfterOntoAnotherAfter(t *testing.T) {
	// Nyx is the awkward one: Glaciem Ring is placed after Nyx II, and Delamar
	// — a planet with no numeral — after the belt. The second insert has to see
	// the first one's position, not upstream's.
	doc := build(t, `{"systems": {"Nyx": {"bodies": {
		"Glaciem Ring": {"after": "Nyx II"},
		"Delamar": {"after": "Glaciem Ring"},
		"Keeger Belt": {"after": "Nyx III"}
	}}}}`)
	want := "Nyx I, Nyx II, Glaciem Ring, Delamar, Nyx III, Keeger Belt"
	if got := strings.Join(rail(t, doc, "Nyx"), ", "); got != want {
		t.Errorf("rail:\n got %s\nwant %s", got, want)
	}
}

func TestBuildOrdersTwoBodiesAnchoredToTheSameBodyByOverlayOrder(t *testing.T) {
	doc := build(t, `{"systems": {"Nyx": {"bodies": {
		"Keeger Belt": {"after": "Nyx I"},
		"Glaciem Ring": {"after": "Nyx I"}
	}}}}`)
	got := strings.Join(rail(t, doc, "Nyx"), ", ")
	if !strings.HasPrefix(got, "Nyx I, Keeger Belt, Glaciem Ring") {
		t.Errorf("two bodies after the same anchor should keep overlay order, got %s", got)
	}
}

func TestBuildReparentsWithMoonOf(t *testing.T) {
	doc := build(t, `{"systems": {"Pyro": {"bodies": {"Pyro IV": {"moonOf": "Pyro V"}}}}}`)
	got := strings.Join(rail(t, doc, "Pyro"), ", ")
	want := "Pyro I, Monox, Bloom, Pyro V (Ignis, Vatra, Adir, Fairo, Fuego, Vuur, Pyro IV), Terminus, Akiro Cluster"
	if got != want {
		t.Errorf("rail:\n got %s\nwant %s", got, want)
	}

	// It keeps a planet's size rule and a planet's subtype, because upstream
	// still types it a planet. Only its position changed.
	pyroIV := find(t, doc, "Pyro", "Pyro IV")
	if pyroIV.KM == nil || *pyroIV.KM != 3214 {
		t.Errorf("Pyro IV km = %v, want 3214 (planet scale, not moon scale)", pyroIV.KM)
	}
	if pyroIV.Subtype != "Terrestrial rocky" {
		t.Errorf("Pyro IV subtype = %q, want Terrestrial rocky", pyroIV.Subtype)
	}
	if pyroIV.Moons != nil {
		t.Error("a body at the moon tier must not carry a moons array")
	}

	// A real moon of the same planet is still thousands of km.
	if ignis := find(t, doc, "Pyro", "Ignis"); ignis.KM == nil || *ignis.KM != 500 {
		t.Errorf("Ignis km = %v, want 500", ignis.KM)
	}
}

func TestBuildAppliesEveryCorrectionKey(t *testing.T) {
	doc := build(t, `{"systems": {"Stanton": {
		"star": {"page": "Stanton the star"},
		"bodies": {
			"ArcCorp": {"page": "ArcCorp (planet)", "icon": "ArcCorp Icon.png"},
			"microTech": {"label": "MicroTech"},
			"Crusader": {"icon": "Crusader-Icon.png", "iconRatio": 2.1},
			"Hurston": {"km": 12000}
		}
	}}}`)

	sys, _ := doc.Systems.Get("Stanton")
	if sys.Star.Page != "Stanton the star" {
		t.Errorf("star page = %q", sys.Star.Page)
	}
	if got := find(t, doc, "Stanton", "ArcCorp"); got.Page != "ArcCorp (planet)" || got.Icon != "ArcCorp Icon.png" {
		t.Errorf("ArcCorp = %+v", got)
	}
	// A corrected label carries the derived page with it, so a rename needs one
	// key rather than two.
	if got := find(t, doc, "Stanton", "MicroTech"); got.Page != "MicroTech" {
		t.Errorf("page should follow a corrected label, got %q", got.Page)
	}
	if got := find(t, doc, "Stanton", "Crusader"); got.IconRatio != 2.1 {
		t.Errorf("iconRatio = %v", got.IconRatio)
	}
	if got := find(t, doc, "Stanton", "Hurston"); got.KM == nil || *got.KM != 12000 {
		t.Errorf("km override = %v, want 12000", got.KM)
	}
}

// TestBuildAppliesEveryStarCorrectionKeyExceptPosition pins which keys reach a
// star, because the Go doc said one thing and the code did another: `km` on a
// star was documented as an error and is in fact an applied override. It is the
// only way to correct a star's size, so the comment was what was wrong — and an
// editor who believed it would have gone looking for a code change instead.
func TestBuildAppliesEveryStarCorrectionKeyExceptPosition(t *testing.T) {
	doc := build(t, `{"systems": {"Terra": {"star": {
		"page": "Terra Nova", "label": "Terra Nova I", "km": 123456,
		"icon": "TerraNova.png", "iconRatio": 1.5
	}}}}`)
	sys, _ := doc.Systems.Get("Terra")
	if sys.Star.Page != "Terra Nova" || sys.Star.Label != "Terra Nova I" {
		t.Errorf("star page/label = %q / %q", sys.Star.Page, sys.Star.Label)
	}
	if sys.Star.KM == nil || *sys.Star.KM != 123456 {
		t.Errorf("star km = %v, want the override 123456 (derived is 715236)", sys.Star.KM)
	}
	if sys.Star.Icon != "TerraNova.png" || sys.Star.IconRatio != 1.5 {
		t.Errorf("star icon = %q / %v", sys.Star.Icon, sys.Star.IconRatio)
	}

	// The two that genuinely have no meaning: a star holds no position on a rail
	// it is the origin of. Both are refused at load, not silently ignored.
	for _, key := range []string{"after", "moonOf"} {
		if _, err := LoadOverlay([]byte(
			`{"systems": {"Terra": {"star": {"` + key + `": "Terra"}}}}`)); err == nil {
			t.Errorf("`%s` on a star should be an error", key)
		}
	}
}

// TestBuildFailsOnCorrectionThatMatchesNothing is the guarantee the whole
// two-file design rests on. A correction that stops matching — because upstream
// renamed the body, or because somebody mistyped it — must stop the build. If it
// were ignored, the next refetch would quietly ship a map with a missing icon,
// a wrong link, or a body in the wrong orbit, and nothing would say so.
func TestBuildFailsOnCorrectionThatMatchesNothing(t *testing.T) {
	cases := map[string]string{
		"misspelled body": `{"systems": {"Stanton": {"bodies": {"Arccorp": {"page": "ArcCorp (planet)"}}}}}`,
		"unknown after":   `{"systems": {"Stanton": {"bodies": {"Aaron Halo": {"after": "Crusadar"}}}}}`,
		"unknown moonOf":  `{"systems": {"Pyro": {"bodies": {"Pyro IV": {"moonOf": "Pyro VII"}}}}}`,
		"unknown system":  `{"systems": {"Terra Prime": {}}}`,
		"excluded body": `{"systems": {"Stanton": {"bodies": {"Aaron Halo": {"icon": "x.png"}}},` +
			`"exclude": ["Aaron*"]}`,
	}
	for name, overlay := range cases {
		t.Run(name, func(t *testing.T) {
			if _, err := buildOrErr(t, overlay); err == nil {
				t.Fatal("expected the build to fail")
			} else {
				t.Log(err)
			}
		})
	}
}

// TestBuildFailsWhenAMoonHangsOffAMoon is the `moonOf` half of the invariant
// TestBuildFailsWhenAfterTargetsABodyOffTheRail covers for `after`.
//
// The rail nests one level, so a body parented onto something that is itself a
// moon has nowhere to be drawn — and it has left the planet rail, so it is not
// drawn there either. It used to be written nowhere at all: exit 0, a cheerful
// "built 1 systems", and one fewer body than went in. That is the silent loss
// the two-file design exists to prevent, and it is reachable from the shipped
// overlay: `Pyro IV: {moonOf: Pyro V}` deletes Pyro IV the day upstream
// reclassifies Pyro V as a satellite.
func TestBuildFailsWhenAMoonHangsOffAMoon(t *testing.T) {
	cases := map[string]string{
		// Cellin is already a moon of Crusader upstream.
		"chained onto an upstream moon": `{"systems": {"Stanton": {"bodies": {"Yela": {"moonOf": "Cellin"}}}}}`,
		// Neither can be the parent, because each is waiting on the other.
		"pointing at each other": `{"systems": {"Nyx": {"bodies": {
			"Nyx II": {"moonOf": "Nyx III"},
			"Nyx III": {"moonOf": "Nyx II"}
		}}}}`,
		// The same off-rail target `after` already refuses.
		"onto a moon of another planet": `{"systems": {"Stanton": {"bodies": {"Aaron Halo": {"moonOf": "Yela"}}}}}`,
	}
	for name, overlay := range cases {
		t.Run(name, func(t *testing.T) {
			_, err := buildOrErr(t, overlay)
			if err == nil {
				t.Fatal("a body with nowhere to be drawn must not vanish silently")
			}
			if !strings.Contains(err.Error(), "nests one level") {
				t.Errorf("error should say why: %v", err)
			}
			t.Log(err)
		})
	}
}

func TestBuildFailsWhenAfterTargetsABodyOffTheRail(t *testing.T) {
	// Yela is a moon, so nothing can be placed after it on the planet rail.
	_, err := buildOrErr(t, `{"systems": {"Stanton": {"bodies": {"Aaron Halo": {"after": "Yela"}}}}}`)
	if err == nil {
		t.Fatal("expected the build to fail")
	}
	if !strings.Contains(err.Error(), "planet rail") {
		t.Errorf("error should say why: %v", err)
	}
}

func TestBuildFailsOnMutuallyAnchoredBodies(t *testing.T) {
	_, err := buildOrErr(t, `{"systems": {"Nyx": {"bodies": {
		"Glaciem Ring": {"after": "Keeger Belt"},
		"Keeger Belt": {"after": "Glaciem Ring"}
	}}}}`)
	if err == nil {
		t.Fatal("two bodies waiting on each other must not silently vanish from the rail")
	}
}

func TestBuildDropsWhatIsNotOnTheRail(t *testing.T) {
	doc := build(t, `{"systems": {"Stanton": {}}}`)
	sys, _ := doc.Systems.Get("Stanton")
	// Stanton's payload also holds four jump points, four landing zones, six
	// stations and the unnamed Ring of Yela.
	if len(sys.Bodies) != 5 {
		t.Fatalf("Stanton has %d rail bodies, want 5 (4 planets + Aaron Halo)", len(sys.Bodies))
	}
	for _, b := range sys.Bodies {
		if strings.Contains(b.Label, "Yela") && b.Tier == tierBelt {
			t.Error("Ring of Yela is unnamed upstream and has no article; it must not render")
		}
	}
	for _, b := range sys.Bodies {
		if b.Label == "Lorville" || b.Label == "Port Olisar" {
			t.Errorf("%q is not a celestial body", b.Label)
		}
	}
}

// TestBuildDisambiguatesTwoBodiesSharingAKey covers the one system upstream has
// left genuinely ambiguous.
//
// Ellis' eleventh planet collided with its moon, and upstream records the
// wreckage as two objects: an asteroid cluster and a protoplanet, both unnamed,
// both designated "Ellis XI". The key falls back to the designation, so they
// collide — two identical discs linking to one article, at most one of which is
// right. Neither could be corrected and neither could be excluded alone, which
// made shipping Ellis a code change rather than the data task the design
// promises. The type-qualified key is the handle.
func TestBuildDisambiguatesTwoBodiesSharingAKey(t *testing.T) {
	t.Run("the plain key is refused, and names the forms that work", func(t *testing.T) {
		_, err := buildOrErr(t, `{"systems": {"Ellis": {"bodies": {"Ellis XI": {"page": "x"}}}}}`)
		if err == nil {
			t.Fatal("an ambiguous key must not silently correct one of the two")
		}
		for _, want := range []string{`"Ellis XI (PLANET)"`, `"Ellis XI (ASTEROID_FIELD)"`} {
			if !strings.Contains(err.Error(), want) {
				t.Errorf("error should offer %s: %v", want, err)
			}
		}
	})

	t.Run("each is correctable on its own", func(t *testing.T) {
		doc := build(t, `{"systems": {"Ellis": {"bodies": {
			"Ellis XI (PLANET)": {"page": "Ellis XI (planet)"},
			"Ellis XI (ASTEROID_FIELD)": {"label": "Ellis XI cluster", "page": "Ellis XI cluster"}
		}}}}`)
		if got := find(t, doc, "Ellis", "Ellis XI"); got.Page != "Ellis XI (planet)" {
			t.Errorf("the protoplanet's page = %q, want Ellis XI (planet)", got.Page)
		}
		if got := find(t, doc, "Ellis", "Ellis XI cluster"); got.Tier != tierBelt {
			t.Errorf("the cluster should still be a belt, got %+v", got)
		}
	})

	t.Run("one can be excluded without the other", func(t *testing.T) {
		doc := build(t, `{"systems": {"Ellis": {}}, "exclude": ["Ellis XI (ASTEROID_FIELD)"]}`)
		got := rail(t, doc, "Ellis")
		if n := strings.Count(strings.Join(got, "\x00"), "Ellis XI"); n != 1 {
			t.Errorf("want one Ellis XI left on the rail, got %d in %v", n, got)
		}

		// A plain key still means both, which is what an editor writing a bare
		// name is asking for.
		doc = build(t, `{"systems": {"Ellis": {}}, "exclude": ["Ellis XI"]}`)
		if got := rail(t, doc, "Ellis"); strings.Contains(strings.Join(got, "\x00"), "Ellis XI") {
			t.Errorf("the plain pattern should drop both, got %v", got)
		}
	})

	t.Run("a key that is not shared keeps its plain form", func(t *testing.T) {
		// Only the colliding key is promoted; the qualified form is not a second
		// way to address every body, which would be two spellings for one thing.
		if _, err := buildOrErr(t, `{"systems": {"Ellis": {"bodies": {"Green (PLANET)": {"page": "x"}}}}}`); err == nil {
			t.Error("expected the qualified form of an unshared key to match nothing")
		}
		doc := build(t, `{"systems": {"Ellis": {"bodies": {"Green": {"page": "Green (planet)"}}}}}`)
		if got := find(t, doc, "Ellis", "Green"); got.Page != "Green (planet)" {
			t.Errorf("Green page = %q", got.Page)
		}
	})
}

// TestBuildNestsAPlanetsRingsWhereItsMoonsGo is the ring rule.
//
// A ring orbits a planet, so it belongs under that planet — and the rail nests
// exactly one level, which is the level the moons occupy. It shares the array
// and nothing else: `tier: ring` is what stops Data.lua drawing it as one of the
// bodies beside it.
func TestBuildNestsAPlanetsRingsWhereItsMoonsGo(t *testing.T) {
	doc := build(t, `{"systems": {"Sol": {}, "Ellis": {}}, "exclude": ["Ellis XI (PLANET)"]}`)

	jupiter := find(t, doc, "Sol", "Jupiter")
	if jupiter.Moons == nil {
		t.Fatal("Jupiter has no moons array at all")
	}
	var labels []string
	for _, m := range *jupiter.Moons {
		labels = append(labels, m.Label)
	}
	// The ring comes first and the Galilean moons keep their lettered order
	// behind it: the column is distance from the planet, and the ring is inside
	// all four of them.
	if got := strings.Join(labels, ", "); got != "Jovian Rings, Io, Europa, Ganymede, Callisto" {
		t.Errorf("Jupiter's moons = %s", got)
	}

	ring := (*jupiter.Moons)[0]
	if ring.Tier != tierRing {
		t.Errorf("ring tier = %q, want %q: without it the rail draws a moon", ring.Tier, tierRing)
	}
	if ring.KM != nil {
		t.Errorf("a ring is a region and carries no km, got %v", *ring.KM)
	}
	if ring.Subtype != "" {
		t.Errorf(`a ring's subtype ("Planetary Ring") only restates its tier, got %q`, ring.Subtype)
	}
	if ring.Moons != nil {
		t.Error("a ring cannot have moons and must omit the key")
	}
	// Unnamed upstream, so label and page are the designation — and the belt
	// house-style rule does not touch it: "Jovian Rings" does not start with the
	// system name, and "Rings of Ellis VII" names the planet it circles.
	if ring.Page != "Jovian Rings" || ring.Designation != "Jovian Rings" {
		t.Errorf("ring page/designation = %q / %q, want Jovian Rings", ring.Page, ring.Designation)
	}

	// The same holds in a system where the ring is the planet's only child, which
	// is the shape that has no moon to hide behind.
	ellisVII := find(t, doc, "Ellis", "Ellis VII")
	if ellisVII.Moons == nil || len(*ellisVII.Moons) != 1 {
		t.Fatalf("Ellis VII moons = %v, want just its ring", ellisVII.Moons)
	}
	if got := (*ellisVII.Moons)[0]; got.Page != "Rings of Ellis VII" || got.Tier != tierRing {
		t.Errorf("Ellis VII's ring = %+v", got)
	}
}

// TestBuildDropsARingThatOrbitsAMoon is the half that stays dropped, and it is
// the one live on the wiki: Stanton is on 57 pages, and Yela's ring appearing
// there would be a regression a reader sees.
//
// The rail nests one level. A ring of a moon needs a second, for one body in all
// 90 systems — and that body has no article under any title, so there would be
// nothing to link even with somewhere to put it.
func TestBuildDropsARingThatOrbitsAMoon(t *testing.T) {
	res, err := buildOrErr(t, `{"systems": {"Stanton": {}}}`)
	if err != nil {
		t.Fatal(err)
	}
	sys, _ := res.Document.Systems.Get("Stanton")
	for _, b := range sys.Bodies {
		if strings.Contains(b.Label, "Ring") {
			t.Errorf("%q reached the planet rail", b.Label)
		}
		if b.Moons == nil {
			continue
		}
		for _, m := range *b.Moons {
			if m.Tier == tierRing || strings.Contains(m.Label, "Ring") {
				t.Errorf("%q reached %q's moons; Yela is a moon, so its ring has nowhere to nest",
					m.Label, b.Label)
			}
		}
	}
	// And it is reported rather than vanishing quietly.
	var noted bool
	for _, note := range res.Notes {
		if strings.Contains(note, "rings that orbit a moon") {
			noted = true
		}
	}
	if !noted {
		t.Errorf("dropping a body should be reported, got %v", res.Notes)
	}
}

// TestBuildFailsWhenARingsPlanetIsExcluded covers the one way a kept ring can
// end up parentless. Rendering it loose on the planet rail would put a ring in
// an orbital slot where a world belongs, and dropping it silently is the failure
// this whole design exists to prevent.
func TestBuildFailsWhenARingsPlanetIsExcluded(t *testing.T) {
	_, err := buildOrErr(t, `{"systems": {"Sol": {}}, "exclude": ["Jupiter"]}`)
	if err == nil {
		t.Fatal("a ring whose planet is gone must not be placed by guesswork")
	}
	if !strings.Contains(err.Error(), "ring of a body that is not in the output") {
		t.Errorf("error should say why: %v", err)
	}
	t.Log(err)

	// Excluding both is the fix the error asks for, and it builds.
	doc := build(t, `{"systems": {"Sol": {}}, "exclude": ["Jupiter", "Jovian Rings"]}`)
	for _, label := range rail(t, doc, "Sol") {
		if strings.HasPrefix(label, "Jupiter") || strings.Contains(label, "Jovian") {
			t.Errorf("%q should have been excluded", label)
		}
	}
}

// TestBuildKeepsARingsSizeOutOfTheFileEvenWhenUpstreamReportsOne is why the km
// test is on the ROLE rather than on what sizeKM happens to return.
//
// All eleven rings upstream report 0 or null today, so nothing in the real data
// distinguishes "a ring has no diameter" from "this field is empty". A ring with
// a size would otherwise be written at the moon tier and drag the moon extents
// with it, resizing every moon on every published page.
//
// The synthetic ring below is typed SATELLITE, which no real one is. That is
// deliberate: upstream types all eleven ASTEROID_BELT, and sizeKM returns nil for
// that type whatever the size says — so a belt-typed ring cannot show whether the
// size was dropped because it is a ring or merely because of its type. What makes
// a body a ring here is its SUBTYPE, so the size rule has to hang off the role
// that subtype produces, and this is the fixture that proves it does.
func TestBuildKeepsARingsSizeOutOfTheFileEvenWhenUpstreamReportsOne(t *testing.T) {
	str := func(s string) *string { return &s }
	num := func(v int) *int { return &v }
	size := func(v float64) *starmap.Number {
		n := starmap.Number(v)
		return &n
	}
	upstream := &starmap.Document{
		Systems: []starmap.System{{ID: 1, Name: "Vector"}},
		Objects: []starmap.Object{
			{ID: 1, StarSystemID: 1, Type: typeStar, Designation: str("Vector"), Size: size(1.2),
				Subtype: &starmap.Subtype{Name: "Main Sequence-Dwarf-G"}},
			{ID: 2, StarSystemID: 1, Type: typePlanet, Designation: str("Vector I"), Size: size(11853),
				Subtype: &starmap.Subtype{Name: "Terrestrial Rocky"}},
			{ID: 3, StarSystemID: 1, Type: typeMoon, Designation: str("Vector 1a"), Size: size(0.7),
				Subtype: &starmap.Subtype{Name: "Planetary Moon"}, ParentID: num(2)},
			// Upstream names this one, and gives it a size in the units its type
			// would imply. Both are ignored where they should be: the name is a
			// proper noun and is kept, the size is not a diameter and is dropped.
			{ID: 4, StarSystemID: 1, Type: typeMoon, Name: str("Halo of Vector"),
				Designation: str("Rings of Vector I"), Size: size(99999),
				Subtype: &starmap.Subtype{Name: subtypePlanetaryRing}, ParentID: num(2)},
		},
	}
	overlay, err := LoadOverlay([]byte(`{"systems": {"Vector": {}}}`))
	if err != nil {
		t.Fatal(err)
	}
	res, err := Build(Options{Starmap: upstream, Overlay: overlay})
	if err != nil {
		t.Fatal(err)
	}

	planet := find(t, res.Document, "Vector", "Vector I")
	if planet.Moons == nil || len(*planet.Moons) != 2 {
		t.Fatalf("Vector I moons = %v, want its moon and its ring", planet.Moons)
	}
	ring := (*planet.Moons)[0]
	if ring.Tier != tierRing {
		t.Fatalf("expected the ring first, got %+v", ring)
	}
	if ring.KM != nil {
		t.Errorf("ring km = %v, want none: a ring has no diameter whatever upstream reports", *ring.KM)
	}
	if ring.Label != "Halo of Vector" || ring.Page != "Halo of Vector" {
		t.Errorf("ring label/page = %q / %q, want the upstream name verbatim", ring.Label, ring.Page)
	}
	if ring.Designation != "Rings of Vector I" {
		t.Errorf("ring designation = %q", ring.Designation)
	}

	// The extents are the point: the moon tier still stops at the real moon.
	ext := res.Document.Extents
	if ext == nil || ext.Moon == nil {
		t.Fatalf("no moon extent recorded: %+v", ext)
	}
	if ext.Moon.Max != 700 {
		t.Errorf("moon maximum is %g, want 700: the ring's 99999 must not reach the scale", ext.Moon.Max)
	}
}

func TestBuildExcludesByPattern(t *testing.T) {
	// Gurzil is nine placeholder "Protoplanetary Disk N" belts (two of them
	// misspelled upstream) alongside one real belt.
	doc := build(t, `{"systems": {"Gurzil": {}}}`)
	if sys, _ := doc.Systems.Get("Gurzil"); len(sys.Bodies) != 10 {
		t.Fatalf("without exclusions Gurzil has %d bodies, want 10", len(sys.Bodies))
	}

	doc = build(t, `{"systems": {"Gurzil": {}}, "exclude": ["Protoplanetary Disk*", "Protoplentary Disk*"]}`)
	sys, _ := doc.Systems.Get("Gurzil")
	// The label is house-styled — upstream designates it "Gurzil Belt Alpha" and
	// names it nothing — while the exclusion patterns above still match on the
	// upstream key. See TestBuildKeysTheOverlayByUpstreamCaseNotTheHouseStyledLabel.
	if len(sys.Bodies) != 1 || sys.Bodies[0].Label != "Gurzil belt alpha" {
		t.Fatalf("with exclusions Gurzil has %v, want just Gurzil belt alpha", rail(t, doc, "Gurzil"))
	}
}

func TestBuildNotesAnExclusionThatMatchedNothing(t *testing.T) {
	// Not an error: the patterns are global while the output is only the
	// systems the overlay lists. It is still worth saying, because the other
	// reason a pattern stops matching is that upstream renamed what it hid.
	res, err := buildOrErr(t, `{"systems": {"Stanton": {}}, "exclude": ["Accretion Disk*"]}`)
	if err != nil {
		t.Fatal(err)
	}
	var found bool
	for _, note := range res.Notes {
		if strings.Contains(note, "Accretion Disk*") {
			found = true
		}
	}
	if !found {
		t.Errorf("expected a note about the unmatched pattern, got %v", res.Notes)
	}
}

func TestBuildDerivesPagesAndSystemTitles(t *testing.T) {
	doc := build(t, `{"systems": {"Castra": {}, "Terra": {"star": {"page": "Terra Nova"}}}}`)

	castra, _ := doc.Systems.Get("Castra")
	if castra.Page != "Castra system" {
		t.Errorf("system page = %q, want Castra system", castra.Page)
	}
	if castra.Star.Page != "Castra (star)" {
		t.Errorf("star page = %q, want the derived Castra (star)", castra.Star.Page)
	}
	if castra.Star.Label != "Castra" {
		t.Errorf("star label = %q; upstream gives it no name, so the designation is the label", castra.Star.Label)
	}

	// Terra breaks the convention: "Terra (star)" does not exist, and the star
	// is Terra Nova. It is an override rather than a derivation from the
	// upstream name, because four of the five systems have no star name at all.
	terra, _ := doc.Systems.Get("Terra")
	if terra.Star.Page != "Terra Nova" || terra.Star.Label != "Terra Nova" {
		t.Errorf("Terra star = %q / %q, want Terra Nova", terra.Star.Page, terra.Star.Label)
	}
	// A star carries no designation: it is the thing the others are numbered
	// against.
	if terra.Star.Designation != "" {
		t.Errorf("star designation = %q, want none", terra.Star.Designation)
	}
}

func TestBuildEmitsOnlyTheSystemsTheOverlayLists(t *testing.T) {
	doc := build(t, `{"systems": {"Pyro": {}, "Stanton": {}}}`)
	if got := strings.Join(doc.Systems.Keys(), ","); got != "Pyro,Stanton" {
		t.Errorf("systems = %q, want Pyro,Stanton in overlay order", got)
	}
}

func TestBuildShapesEachTier(t *testing.T) {
	doc := build(t, `{"systems": {"Terra": {"bodies": {"Henge Cluster": {"after": "Terra"}}}}}`)

	belt := find(t, doc, "Terra", "Henge Cluster")
	if belt.Tier != tierBelt {
		t.Errorf("belt tier = %q", belt.Tier)
	}
	if belt.KM != nil {
		t.Errorf("a belt renders as a fixed band and must carry no km, got %v", *belt.KM)
	}
	if belt.Subtype != "" {
		t.Errorf("a belt's subtype restates its tier, got %q", belt.Subtype)
	}
	if belt.Moons != nil {
		t.Error("a belt cannot have moons and must omit the key")
	}

	// A planet with no moons still emits the empty array, which is what the
	// committed file does and what Data.lua's ipairs walk expects.
	gen := find(t, doc, "Terra", "Gen")
	if gen.Moons == nil || len(*gen.Moons) != 0 {
		t.Errorf("Gen moons = %v, want an empty array", gen.Moons)
	}

	// A moon's own subtype ("Planetary Moon") restates its tier, so it is
	// dropped — unlike Pyro IV's, which is a planet's.
	if eda := find(t, doc, "Terra", "Eda"); eda.Subtype != "" {
		t.Errorf("Eda subtype = %q, want none", eda.Subtype)
	}
}

// findBelt is find() narrowed to the belt tier.
//
// Ellis needs the narrowing: its eleventh planet collided with its moon, and
// upstream records both halves unnamed and designated "Ellis XI", so a label
// alone does not name one body there.
func findBelt(t *testing.T, doc *Document, system, label string) Body {
	t.Helper()
	sys, ok := doc.Systems.Get(system)
	if !ok {
		t.Fatalf("no system %q in the output", system)
	}
	for _, b := range sys.Bodies {
		if b.Label == label && b.Tier == tierBelt {
			return b
		}
	}
	t.Fatalf("no belt %q in %s; the rail is %v", label, system, rail(t, doc, system))
	return Body{}
}

// TestBuildSentenceCasesAnUnnamedBeltThroughout is the house-style rule reaching
// the label and the page, not just the designation.
//
// Upstream names only some belts. For the ~48 it does not, the key falls back to
// the designation, so label and page are that designation — and recasing only
// the designation would leave the same string stored in two cases: the rail
// would print "Gurzil belt alpha" as a second line under "Gurzil Belt Alpha",
// and `page` would point at a title the wiki is turning into a redirect as those
// articles move to sentence case.
func TestBuildSentenceCasesAnUnnamedBeltThroughout(t *testing.T) {
	doc := build(t, `{"systems": {"Gurzil": {}, "Ellis": {}}}`)

	cases := []struct{ system, label string }{
		// The plain case: upstream writes "Gurzil Belt Alpha", "Ellis Belt Alpha".
		{"Gurzil", "Gurzil belt alpha"},
		{"Ellis", "Ellis belt alpha"},
		// A Roman numeral is an orbital slot and keeps its capitals, so this one
		// agrees by not moving at all. It is also the belt half of the pair that
		// shares a key with Ellis' protoplanet.
		{"Ellis", "Ellis XI"},
		// No system prefix to anchor to, so it is left exactly as upstream wrote
		// it — and label, page and designation still agree, because all three
		// come from the same untouched string. This is the only shape of that
		// case the output can hold: the eleven "Rings of <planet>" belts are
		// subtype "Planetary Ring" and unnamed, so they never reach it at all.
		{"Gurzil", "Protoplanetary Disk"},
	}
	for _, c := range cases {
		belt := findBelt(t, doc, c.system, c.label)
		// The point of the change: all three agree, so nothing is stored twice in
		// two cases and `page` is the title the article now has.
		if belt.Page != c.label {
			t.Errorf("%s: page = %q, want %q", c.label, belt.Page, c.label)
		}
		if belt.Designation != c.label {
			t.Errorf("%s: designation = %q, want it to agree with the label", c.label, belt.Designation)
		}
	}
}

// TestBuildKeepsANamedBeltsNameVerbatim is the exclusion the rule turns on, and
// the reason this change moves nothing already published.
//
// A belt upstream names carries a proper noun, not a description: lower-casing
// "Aaron Halo" would look wrong and would red-link the article. Only its
// designation is house style, and the two lines then say different things, which
// is what the rail prints both for.
//
// Every belt in the five systems live on the wiki is one of these six, which is
// why widening the rule to label and page is a no-op on the deployed file.
func TestBuildKeepsANamedBeltsNameVerbatim(t *testing.T) {
	doc := build(t, `{"systems": {"Stanton": {}, "Pyro": {}, "Nyx": {}, "Terra": {}}}`)

	cases := []struct{ system, name, designation string }{
		{"Stanton", "Aaron Halo", "Stanton belt alpha"},
		{"Pyro", "Akiro Cluster", "Pyro cluster alpha"},
		{"Nyx", "Glaciem Ring", "Nyx belt alpha"},
		{"Nyx", "Keeger Belt", "Nyx belt beta"},
		{"Terra", "Henge Cluster", "Terra cluster alpha"},
		{"Terra", "Marisol Belt", "Terra belt beta"},
	}
	for _, c := range cases {
		belt := findBelt(t, doc, c.system, c.name)
		if belt.Page != c.name {
			t.Errorf("%s: page = %q, want the upstream name verbatim", c.name, belt.Page)
		}
		if belt.Designation != c.designation {
			t.Errorf("%s: designation = %q, want %q", c.name, belt.Designation, c.designation)
		}
	}
}

// TestBuildSentenceCasesBeltsOnly keeps the rule off the other three tiers.
//
// The star is the case with teeth. Upstream names exactly one star in the whole
// dataset — Terra Nova — so the other 92 fall back to a designation for their
// label is a designation too — and a binary's components are designated
// "Bacchus A" and "Bacchus B", where the letter is not in the Roman-numeral
// alphabet. A rule that reached the star tier would store "Bacchus a".
//
// Synthetic, because the fixture cannot show it: every unnamed planet and moon
// upstream is designated "<System> <numeral>", which the numeral exception
// already leaves alone, so only the star tier has a visible instance — and the
// generator refuses a system with two stars, which is what Bacchus is.
func TestBuildSentenceCasesBeltsOnly(t *testing.T) {
	str := func(s string) *string { return &s }
	num := func(v int) *int { return &v }
	size := func(v float64) *starmap.Number {
		n := starmap.Number(v)
		return &n
	}
	// Every body unnamed, which is what puts its designation in its label.
	upstream := &starmap.Document{
		Systems: []starmap.System{{ID: 1, Name: "Bacchus"}},
		Objects: []starmap.Object{
			{ID: 1, StarSystemID: 1, Type: typeStar, Designation: str("Bacchus A"), Size: size(1.2),
				Subtype: &starmap.Subtype{Name: "Main Sequence-Dwarf-G"}},
			{ID: 2, StarSystemID: 1, Type: typePlanet, Designation: str("Bacchus I"), Size: size(11853),
				Subtype: &starmap.Subtype{Name: "Terrestrial Rocky"}},
			{ID: 3, StarSystemID: 1, Type: typeMoon, Designation: str("Bacchus 1a"), Size: size(0.7),
				Subtype: &starmap.Subtype{Name: "Planetary Moon"}, ParentID: num(2)},
			{ID: 4, StarSystemID: 1, Type: typeBelt, Designation: str("Bacchus Belt Alpha")},
		},
	}
	overlay, err := LoadOverlay([]byte(`{"systems": {"Bacchus": {}}}`))
	if err != nil {
		t.Fatal(err)
	}
	res, err := Build(Options{Starmap: upstream, Overlay: overlay})
	if err != nil {
		t.Fatal(err)
	}
	sys, _ := res.Document.Systems.Get("Bacchus")

	if sys.Star.Label != "Bacchus A" {
		t.Errorf("star label = %q, want Bacchus A: the component letter is not a common noun", sys.Star.Label)
	}
	if got := find(t, res.Document, "Bacchus", "Bacchus I"); got.Page != "Bacchus I" {
		t.Errorf("planet page = %q, want Bacchus I", got.Page)
	}
	if got := find(t, res.Document, "Bacchus", "Bacchus 1a"); got.Page != "Bacchus 1a" {
		t.Errorf("moon page = %q, want Bacchus 1a", got.Page)
	}
	// The belt in the same system, to show the rule is on and it is the tier
	// that decides — not something about this fixture.
	if got := findBelt(t, res.Document, "Bacchus", "Bacchus belt alpha"); got.Page != "Bacchus belt alpha" {
		t.Errorf("belt page = %q, want Bacchus belt alpha", got.Page)
	}
}

// TestBuildKeysTheOverlayByUpstreamCaseNotTheHouseStyledLabel pins the seam the
// widened rule opens: for an unnamed belt the rail now reads "Gurzil belt alpha"
// while the overlay key is still upstream's "Gurzil Belt Alpha".
//
// The key has to stay upstream's, because it is the body's identity across a
// refetch, not a display string — deriving it from the house-styled label would
// make every correction depend on a rule that is allowed to change. An editor
// keying the label they see gets the fail-loud error, not a silent no-op.
func TestBuildKeysTheOverlayByUpstreamCaseNotTheHouseStyledLabel(t *testing.T) {
	if _, err := buildOrErr(t, `{"systems": {"Gurzil": {"bodies": {"Gurzil belt alpha": {"after": "Gurzil I"}}}}}`); err == nil {
		t.Error("the house-styled label must not resolve as an overlay key; it would drift with the rule")
	}

	// The upstream form resolves, and a label written there is judgement: it is
	// stored exactly as an editor wrote it, capitals included. That is the escape
	// hatch for a belt whose article really is titled in Title Case.
	doc := build(t, `{"systems": {"Gurzil": {"bodies": {"Gurzil Belt Alpha": {"label": "Gurzil Belt Alpha"}}}}}`)
	belt := findBelt(t, doc, "Gurzil", "Gurzil Belt Alpha")
	if belt.Page != "Gurzil Belt Alpha" {
		t.Errorf("page = %q, want the overlay label verbatim", belt.Page)
	}
	if belt.Designation != "Gurzil belt alpha" {
		t.Errorf("designation = %q, want the house-styled form: the overlay overrode the label, "+
			"not the derivation rule", belt.Designation)
	}
}

// The named-belt guard cannot be exercised by the real fixture: no named belt in
// the whole dataset has a name beginning with its system name, so beltCase is a
// no-op for every one of them and the rule's guard never changes an outcome.
// TestBuildKeepsANamedBeltsNameVerbatim therefore passes with or without it.
//
// That makes the guard untested rather than unnecessary. Upstream names belts
// freely, and the day it ships "Vega Belt Prime" as a NAME, lower-casing it would
// both read wrong and red-link a real article. This builds the case upstream has
// not yet produced, so the guard is pinned by behaviour rather than by hope.
func TestBuildKeepsANamedBeltVerbatimWhenItsNameStartsWithTheSystemName(t *testing.T) {
	const synthetic = `{
	  "systems": [{"id": 900, "code": "VEGA", "name": "Vega"}],
	  "objects": [
	    {"id": 9001, "code": "VEGA.STARS.VEGA", "designation": "Vega", "size": 1200000,
	     "type": "STAR", "subtype": {"name": "Main Sequence-Dwarf-A", "type": "STAR"},
	     "star_system_id": 900},
	    {"id": 9002, "code": "VEGA.PLANETS.VEGAI", "designation": "Vega I", "size": 5000,
	     "type": "PLANET", "subtype": {"name": "Terrestrial Rocky", "type": "PLANET"},
	     "star_system_id": 900, "parent_id": 9001},
	    {"id": 9003, "code": "VEGA.BELTS.PRIME", "name": "Vega Belt Prime",
	     "designation": "Vega Belt Alpha", "size": 0, "type": "ASTEROID_BELT",
	     "subtype": {"name": "System Belt", "type": "ASTEROID_BELT"},
	     "star_system_id": 900, "parent_id": 9001}
	  ]
	}`

	doc, err := starmap.Decode([]byte(synthetic))
	if err != nil {
		t.Fatal(err)
	}
	overlay, err := LoadOverlay([]byte(`{"systems": {"Vega": {}}}`))
	if err != nil {
		t.Fatal(err)
	}
	res, err := Build(Options{Starmap: doc, Overlay: overlay})
	if err != nil {
		t.Fatal(err)
	}

	belt := findBelt(t, res.Document, "Vega", "Vega Belt Prime")

	// The name is a proper noun and survives untouched, even though it begins
	// with the system name and would otherwise match the house-style rule.
	if belt.Label != "Vega Belt Prime" {
		t.Errorf("label = %q, want the upstream name verbatim: it is a proper noun", belt.Label)
	}
	if belt.Page != "Vega Belt Prime" {
		t.Errorf("page = %q, want the upstream name verbatim: lower-casing red-links the article", belt.Page)
	}
	// The designation is not a name, so house style still applies to it.
	if belt.Designation != "Vega belt alpha" {
		t.Errorf("designation = %q, want %q", belt.Designation, "Vega belt alpha")
	}
}
