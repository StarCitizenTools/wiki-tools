package systemmap

import (
	"strings"
	"testing"

	"github.com/StarCitizenTools/wiki-tools/scripts/internal/starmap"
)

// The topology this package now has to model, checked against the live RSI API
// rather than only against the mirror. Five systems have two stars, none has
// three, 83 have one, and two have none. The five split into two shapes, and
// this is the table the derivation is expected to reproduce.
var binaryTopology = []struct {
	system    string
	primary   string
	companion string
	shape     string
	why       string
}{
	{"Tyrol", "Tyrol A", "Tyrol B", shapeNested,
		"Tyrol B is parented to Tyrol A, and all nine bodies hang off A"},
	{"Kyuk'ya (Indra)", "Kyuk'ya A", "Kyuk'ya B", shapeNested,
		"Kyuk'ya B is parented to Kyuk'ya A"},
	{"Bacchus", "Bacchus A", "Bacchus B", shapePaired,
		"neither is parented; upstream puts both at distance 0.0735"},
	{"Baker", "Baker A", "Baker B", shapePaired,
		"neither is parented, and B is the LARGER of the two — order is the designation's, not size's"},
	{"Goss", "Goss A", "Goss B", shapePaired,
		"neither is parented; upstream puts both at distance 0.1065"},
}

// TestBuildDerivesEachBinaryShape is the acceptance test for the model: every
// system with two stars, built from the real fixture through the real overlay
// path, lands on the arrangement upstream's parent_id describes.
func TestBuildDerivesEachBinaryShape(t *testing.T) {
	for _, c := range binaryTopology {
		t.Run(c.system, func(t *testing.T) {
			overlay := `{"systems": {"` + c.system + `": {}}}`
			if c.system == "Kyuk'ya (Indra)" {
				// The only one that needs correcting at all: the wiki files this
				// system under "Kyuk'ya", not under upstream's Perry Line alias.
				overlay = `{"systems": {"Kyuk'ya (Indra)": {
					"star": {"label": "Kyuk'ya A", "page": "Kyuk'ya A"},
					"companion": {"label": "Kyuk'ya B", "page": "Kyuk'ya B"}}}}`
			}
			sys, ok := build(t, overlay).Systems.Get(c.system)
			if !ok {
				t.Fatalf("%s was not built", c.system)
			}
			if sys.Star == nil || sys.Companion == nil {
				t.Fatalf("star = %v, companion = %v; both are required (%s)", sys.Star, sys.Companion, c.why)
			}
			if sys.Star.Label != c.primary || sys.Companion.Label != c.companion {
				t.Errorf("stars = %q / %q, want %q / %q (%s)",
					sys.Star.Label, sys.Companion.Label, c.primary, c.companion, c.why)
			}
			if sys.CompanionShape != c.shape {
				t.Errorf("shape = %q, want %q (%s)", sys.CompanionShape, c.shape, c.why)
			}
			// Both stars are stars: a companion carries the same spectral fields
			// the primary does, which is what lets Data.lua give it a star glyph.
			if sys.Companion.Subtype == "" {
				t.Errorf("companion %s carries no subtype", sys.Companion.Label)
			}
		})
	}
}

// TestBinaryStarsTakeTheirOwnTitles pins the one derivation a second star
// changes. "<System> (star)" exists to disambiguate a star whose designation is
// just the system name; a binary's stars are already designated apart, and the
// convention's title does not exist on the wiki for any of the five. All ten
// titles here were checked against the live API with redirects resolved.
func TestBinaryStarsTakeTheirOwnTitles(t *testing.T) {
	sys, _ := build(t, `{"systems": {"Tyrol": {}}}`).Systems.Get("Tyrol")
	if sys.Star.Page != "Tyrol A" || sys.Companion.Page != "Tyrol B" {
		t.Errorf("star pages = %q / %q, want Tyrol A / Tyrol B", sys.Star.Page, sys.Companion.Page)
	}
	if strings.Contains(sys.Star.Page, "(star)") {
		t.Errorf("star page = %q; \"Tyrol (star)\" does not exist on the wiki", sys.Star.Page)
	}

	// And the convention is untouched where there is one star, which is what
	// keeps all ten published systems byte-identical.
	castra, _ := build(t, `{"systems": {"Castra": {}}}`).Systems.Get("Castra")
	if castra.Star.Page != "Castra (star)" {
		t.Errorf("single-star page = %q, want Castra (star)", castra.Star.Page)
	}
}

// TestSingleStarSystemsWriteNoCompanionKeys is the backward-compatibility gate
// in its most direct form: whatever the model can now express, a system with one
// star has to encode exactly as it did before it could express any of it.
func TestSingleStarSystemsWriteNoCompanionKeys(t *testing.T) {
	doc := build(t, `{"systems": {"Castra": {}}}`)
	b, err := Encode(doc)
	if err != nil {
		t.Fatal(err)
	}
	out := string(b)
	for _, key := range []string{`"companion"`, `"companionShape"`} {
		if strings.Contains(out, key) {
			t.Errorf("a single-star system emitted %s; the key must be absent, not empty", key)
		}
	}
	if !strings.Contains(out, "\"page\": \"Castra system\",\n\t\t\t\"star\": {") {
		t.Errorf("the key order changed; page must still be followed directly by star:\n%s", out)
	}
}

// TestBuildWithoutAStar covers the two systems upstream files no star for. They
// carry planets — Min carries four moons as well — so refusing to build them
// would make a real map unrenderable over a gap in upstream's data, and the
// model must not assume a head that is not there.
func TestBuildWithoutAStar(t *testing.T) {
	for _, name := range []string{"Min", "Tamsa"} {
		t.Run(name, func(t *testing.T) {
			res, err := buildOrErr(t, `{"systems": {"`+name+`": {}}}`)
			if err != nil {
				t.Fatalf("a starless system must still build: %v", err)
			}
			sys, ok := res.Document.Systems.Get(name)
			if !ok {
				t.Fatalf("%s was not built", name)
			}
			if sys.Star != nil || sys.Companion != nil {
				t.Errorf("star = %v, companion = %v, want neither", sys.Star, sys.Companion)
			}
			if len(sys.Bodies) == 0 {
				t.Errorf("%s lost its planets along with its star", name)
			}

			// Absent, not null: Data.lua guards `system.star` with a truth test,
			// and an explicit null would cost bytes on every render for nothing.
			// Encoded per system rather than whole-document, because `extents`
			// carries a "star" key of its own that a naive search would hit.
			encoded := encodeSystem(t, sys)
			if strings.Contains(encoded, `"star"`) {
				t.Errorf("emitted a star key for a system that has none:\n%s", encoded)
			}
			if !strings.Contains(encoded, `"bodies"`) {
				t.Errorf("a starless system must still write its bodies:\n%s", encoded)
			}

			// And the build says so, rather than leaving a headless rail to be
			// discovered on the page.
			var said bool
			for _, note := range res.Notes {
				if strings.Contains(note, name) && strings.Contains(note, "no star") {
					said = true
				}
			}
			if !said {
				t.Errorf("no build note mentions the missing star; notes were %v", res.Notes)
			}
		})
	}
}

// starDoc builds a one-system upstream document with the stars described, so the
// derivation can be exercised on shapes upstream does not currently have.
func starDoc(stars ...starmap.Object) *starmap.Document {
	doc := &starmap.Document{
		Systems: []starmap.System{{ID: 1, Name: "Vector", Type: "SINGLE_STAR"}},
	}
	for _, s := range stars {
		s.StarSystemID = 1
		s.Type = typeStar
		doc.Objects = append(doc.Objects, s)
	}
	return doc
}

func buildDoc(t *testing.T, doc *starmap.Document, overlayJSON string) (*Result, error) {
	t.Helper()
	overlay, err := LoadOverlay([]byte(overlayJSON))
	if err != nil {
		return nil, err
	}
	return Build(Options{Starmap: doc, Overlay: overlay})
}

// TestResolveStarsReadsParentIDNotTheSystemType is the derivation's own test,
// and the reason it exists. Upstream's `type` field says "BINARY" for four
// systems and "SINGLE_STAR" for Tyrol, which has two stars — so counting the
// stars and reading parent_id is the only answer that holds. Both fixtures here
// declare SINGLE_STAR, exactly as Tyrol does.
func TestResolveStarsReadsParentIDNotTheSystemType(t *testing.T) {
	str := func(s string) *string { return &s }
	num := func(v int) *int { return &v }

	nested := starDoc(
		starmap.Object{ID: 10, Designation: str("Vector A")},
		starmap.Object{ID: 11, Designation: str("Vector B"), ParentID: num(10)},
	)
	res, err := buildDoc(t, nested, `{"systems": {"Vector": {}}}`)
	if err != nil {
		t.Fatal(err)
	}
	sys, _ := res.Document.Systems.Get("Vector")
	if sys.CompanionShape != shapeNested || sys.Star.Label != "Vector A" || sys.Companion.Label != "Vector B" {
		t.Errorf("parented companion gave %q / %q / %q, want Vector A / Vector B / nested",
			sys.Star.Label, sys.Companion.Label, sys.CompanionShape)
	}

	// The same two stars with the parent link the other way round: the primary
	// is whichever one is NOT parented, not whichever comes first upstream.
	inverted := starDoc(
		starmap.Object{ID: 10, Designation: str("Vector A"), ParentID: num(11)},
		starmap.Object{ID: 11, Designation: str("Vector B")},
	)
	res, err = buildDoc(t, inverted, `{"systems": {"Vector": {}}}`)
	if err != nil {
		t.Fatal(err)
	}
	sys, _ = res.Document.Systems.Get("Vector")
	if sys.Star.Label != "Vector B" || sys.Companion.Label != "Vector A" {
		t.Errorf("stars = %q / %q; the primary is the unparented one, whatever its designation",
			sys.Star.Label, sys.Companion.Label)
	}

	// Neither parented: a pair, ordered by designation rather than by file order.
	// Bacchus is the live case — upstream lists B before A.
	paired := starDoc(
		starmap.Object{ID: 11, Designation: str("Vector B")},
		starmap.Object{ID: 10, Designation: str("Vector A")},
	)
	res, err = buildDoc(t, paired, `{"systems": {"Vector": {}}}`)
	if err != nil {
		t.Fatal(err)
	}
	sys, _ = res.Document.Systems.Get("Vector")
	if sys.CompanionShape != shapePaired || sys.Star.Label != "Vector A" || sys.Companion.Label != "Vector B" {
		t.Errorf("unparented stars gave %q / %q / %q, want Vector A / Vector B / paired",
			sys.Star.Label, sys.Companion.Label, sys.CompanionShape)
	}
}

// TestResolveStarsRefusesShapesNobodyHasDecided. Each of these is a real
// arrangement the rail has no drawing for, and every one of them would otherwise
// render as something the data does not say.
func TestResolveStarsRefusesShapesNobodyHasDecided(t *testing.T) {
	str := func(s string) *string { return &s }
	num := func(v int) *int { return &v }

	cases := map[string]struct {
		doc  *starmap.Document
		want string
	}{
		"three stars": {
			starDoc(
				starmap.Object{ID: 10, Designation: str("Vector A")},
				starmap.Object{ID: 11, Designation: str("Vector B")},
				starmap.Object{ID: 12, Designation: str("Vector C")},
			),
			"has 3 stars",
		},
		"each parented to the other": {
			starDoc(
				starmap.Object{ID: 10, Designation: str("Vector A"), ParentID: num(11)},
				starmap.Object{ID: 11, Designation: str("Vector B"), ParentID: num(10)},
			),
			"parented to the other",
		},
		"a star parented to something else": {
			starDoc(
				starmap.Object{ID: 10, Designation: str("Vector A")},
				starmap.Object{ID: 11, Designation: str("Vector B"), ParentID: num(99)},
			),
			"not\nthe system's other star",
		},
	}

	for name, c := range cases {
		t.Run(name, func(t *testing.T) {
			_, err := buildDoc(t, c.doc, `{"systems": {"Vector": {}}}`)
			if err == nil {
				t.Fatalf("want an error mentioning %q, got a clean build", c.want)
			}
			flat := strings.Join(strings.Fields(err.Error()), " ")
			if !strings.Contains(flat, strings.Join(strings.Fields(c.want), " ")) {
				t.Errorf("error is %v, want it to mention %q", err, c.want)
			}
		})
	}
}

// TestNoBodyOrbitsACompanion pins the fact the nested drawing rests on: the
// companion is a leaf. No companion carries a planet, a belt or a moon anywhere
// in the dataset, so the rail can hang everything off the primary. That is
// upstream data rather than a law, so it is checked across the whole fixture
// rather than assumed — and the generator refuses to build a system that breaks
// it, because such a body would otherwise be drawn as orbiting the pair.
func TestNoBodyOrbitsACompanion(t *testing.T) {
	doc := loadFixture(t)
	starsBySystem := map[int][]*starmap.Object{}
	byID := map[int]*starmap.Object{}
	for i := range doc.Objects {
		o := &doc.Objects[i]
		byID[o.ID] = o
		if o.Type == typeStar {
			starsBySystem[o.StarSystemID] = append(starsBySystem[o.StarSystemID], o)
		}
	}
	binaries := 0
	for _, stars := range starsBySystem {
		if len(stars) != 2 {
			continue
		}
		binaries++
		companions := map[int]bool{}
		for _, s := range stars {
			if s.ParentID != nil {
				companions[s.ID] = true // nested: the parented one
			}
		}
		if len(companions) == 0 {
			for _, s := range stars[1:] { // paired: neither is the centre
				companions[s.ID] = true
			}
		}
		for i := range doc.Objects {
			o := &doc.Objects[i]
			if o.Type == typeStar || o.ParentID == nil || !companions[*o.ParentID] {
				continue
			}
			t.Errorf("%s is parented to a companion star; the rail draws bodies under the "+
				"primary only, and the generator now refuses this", o.Code)
		}
	}
	if binaries != 5 {
		t.Errorf("the fixture holds %d binaries, want the 5 upstream has", binaries)
	}
}

func TestBuildFailsWhenABodyOrbitsTheCompanion(t *testing.T) {
	str := func(s string) *string { return &s }
	num := func(v int) *int { return &v }

	doc := starDoc(
		starmap.Object{ID: 10, Designation: str("Vector A")},
		starmap.Object{ID: 11, Designation: str("Vector B"), ParentID: num(10)},
	)
	doc.Objects = append(doc.Objects, starmap.Object{
		ID: 12, StarSystemID: 1, Type: typeMoon, Designation: str("Vector 1a"), ParentID: num(11),
	})

	_, err := buildDoc(t, doc, `{"systems": {"Vector": {}}}`)
	if err == nil {
		t.Fatal("a body orbiting the companion must stop the build, not render as an orbit of the pair")
	}
	if !strings.Contains(err.Error(), "orbits the companion star") {
		t.Errorf("error is %v, want it to name the companion", err)
	}
}

// TestOverlayOverridesTheDerivedShape. The derivation reads one upstream field,
// which is a thin basis for a claim about what orbits what, so the judgement is
// overridable — the same escape hatch every other derived value here has.
func TestOverlayOverridesTheDerivedShape(t *testing.T) {
	doc := build(t, `{"systems": {"Tyrol": {"companionShape": "paired"}}}`)
	sys, _ := doc.Systems.Get("Tyrol")
	if sys.CompanionShape != shapePaired {
		t.Errorf("shape = %q, want the overridden paired (derived is nested)", sys.CompanionShape)
	}
	// The override moves the drawing, not the identity: Tyrol A is still the
	// primary, because that is what parent_id says.
	if sys.Star.Label != "Tyrol A" || sys.Companion.Label != "Tyrol B" {
		t.Errorf("stars = %q / %q, want Tyrol A / Tyrol B", sys.Star.Label, sys.Companion.Label)
	}
}

func TestBuildAppliesEveryCompanionCorrectionKey(t *testing.T) {
	doc := build(t, `{"systems": {"Tyrol": {"companion": {
		"page": "Tyrol B (star)", "label": "Tyrol Beta", "km": 4321,
		"icon": "TyrolB.png", "iconRatio": 1.25
	}}}}`)
	sys, _ := doc.Systems.Get("Tyrol")
	if sys.Companion.Page != "Tyrol B (star)" || sys.Companion.Label != "Tyrol Beta" {
		t.Errorf("companion page/label = %q / %q", sys.Companion.Page, sys.Companion.Label)
	}
	if sys.Companion.KM == nil || *sys.Companion.KM != 4321 {
		t.Errorf("companion km = %v, want the override 4321 (derived is 14834)", sys.Companion.KM)
	}
	if sys.Companion.Icon != "TyrolB.png" || sys.Companion.IconRatio != 1.25 {
		t.Errorf("companion icon = %q / %v", sys.Companion.Icon, sys.Companion.IconRatio)
	}

	// The two that mean nothing on a body the planet rail does not hold.
	for _, key := range []string{"after", "moonOf"} {
		if _, err := LoadOverlay([]byte(
			`{"systems": {"Tyrol": {"companion": {"` + key + `": "Tyrol I"}}}}`)); err == nil {
			t.Errorf("`%s` on a companion should be an error", key)
		}
	}
}

// TestCompanionCorrectionsMustBite is the same promise the body corrections make.
// A companion block or a shape override on a system that has one star is a
// correction that has stopped matching — upstream dropped a star, or somebody
// wrote it under the wrong system — and ignoring it is how the judgement gets
// lost across a refetch.
//
// The `star` rows matter most, because that is the key the starless systems made
// droppable: before they built at all, a `star` block could not reach nothing.
// Both directions are covered — a star block on a system upstream files no star
// for (Tamsa, Min), which is the new hole, and the pre-existing shapes.
func TestCompanionCorrectionsMustBite(t *testing.T) {
	cases := map[string]string{
		"companion block on a single-star system": `{"systems": {"Castra": {"companion": {"page": "Castra B"}}}}`,
		"shape on a single-star system":           `{"systems": {"Castra": {"companionShape": "paired"}}}`,
		"shape on a starless system":              `{"systems": {"Min": {"companionShape": "nested"}}}`,
		"star block on a starless system":         `{"systems": {"Tamsa": {"star": {"page": "Tamsa Prime"}}}}`,
		"empty star block on a starless system":   `{"systems": {"Min": {"star": {}}}}`,
	}
	for name, overlay := range cases {
		t.Run(name, func(t *testing.T) {
			if _, err := buildOrErr(t, overlay); err == nil {
				t.Error("a correction that reaches no companion must stop the build")
			}
		})
	}
}

func TestOverlayRejectsAnUnknownCompanionShape(t *testing.T) {
	_, err := LoadOverlay([]byte(`{"systems": {"Tyrol": {"companionShape": "orbiting"}}}`))
	if err == nil {
		t.Fatal("an unrecognised shape must be refused at load, not silently drawn as nested")
	}
	if !strings.Contains(err.Error(), "companionShape") {
		t.Errorf("error is %v, want it to name the key", err)
	}
}

// TestOverlayCorrectsASystemPage covers the other key this work added. Upstream
// calls one system "Kyuk'ya (Indra)", carrying the name it went by during the
// Xi'an Cold War; the wiki files it under "Kyuk'ya system" and redirects "Indra
// system" there. The derived title would red-link the header of every map in the
// system, and a redirect check that only asked "does the page exist" would have
// passed it.
func TestOverlayCorrectsASystemPage(t *testing.T) {
	doc := build(t, `{"systems": {"Kyuk'ya (Indra)": {"page": "Kyuk'ya system"}}}`)
	sys, _ := doc.Systems.Get("Kyuk'ya (Indra)")
	if sys.Page != "Kyuk'ya system" {
		t.Errorf("system page = %q, want the override Kyuk'ya system", sys.Page)
	}

	// Absent, the derivation is unchanged for everybody else.
	castra, _ := build(t, `{"systems": {"Castra": {}}}`).Systems.Get("Castra")
	if castra.Page != "Castra system" {
		t.Errorf("system page = %q, want the derived Castra system", castra.Page)
	}
}

// TestCommittedFileCarriesTheVerifiedTopology pins the shipped data against the
// table at the top of this file, so a refetch that changes a parent_id shows up
// as a failing test rather than as a rearranged rail on a live page.
func TestCommittedFileCarriesTheVerifiedTopology(t *testing.T) {
	doc := decodeFile(t, committedSystems)

	seen := 0
	for _, name := range doc.Systems.Keys() {
		sys, _ := doc.Systems.Get(name)
		if sys.Companion == nil {
			if sys.CompanionShape != "" {
				t.Errorf("%s records a companion shape with no companion", name)
			}
			continue
		}
		seen++
		var want *struct {
			system    string
			primary   string
			companion string
			shape     string
			why       string
		}
		for i := range binaryTopology {
			if binaryTopology[i].system == name {
				want = &binaryTopology[i]
			}
		}
		if want == nil {
			t.Errorf("%s has a companion but is not in the verified topology", name)
			continue
		}
		if sys.Star == nil || sys.Star.Label != want.primary || sys.Companion.Label != want.companion {
			t.Errorf("%s stars = %v / %q, want %q / %q",
				name, sys.Star, sys.Companion.Label, want.primary, want.companion)
		}
		if sys.CompanionShape != want.shape {
			t.Errorf("%s shape = %q, want %q (%s)", name, sys.CompanionShape, want.shape, want.why)
		}
	}
	if seen != len(binaryTopology) {
		t.Errorf("the file carries %d binaries, want the %d rolled out", seen, len(binaryTopology))
	}
}
