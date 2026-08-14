package systemmap

import (
	"os"
	"strings"
	"testing"

	"github.com/StarCitizenTools/wiki-tools/scripts/internal/starmap"
)

// upstreamOnlyExtents is the first half of the union on its own: every body in
// the given starmap, measured by upstream type. It exists only so a test can
// show what the union adds.
func upstreamOnlyExtents(doc *starmap.Document) *Extents {
	return anchorExtents(doc, &Document{})
}

// TestAnchorExtentsPutsPyroIVInsideTheMoonTier is the case that makes the union
// necessary rather than tidy.
//
// Upstream types Pyro IV a planet; the overlay reparents it as a moon of Pyro V.
// Measured by upstream type alone the moon tier stops at the largest true
// satellite, and Pyro IV — which renders AS a moon — sits outside its own tier's
// range. The union with what the file actually writes is what closes that.
func TestAnchorExtentsPutsPyroIVInsideTheMoonTier(t *testing.T) {
	fixture := loadFixture(t)
	doc := buildFromCommittedOverlay(t)

	byType := upstreamOnlyExtents(fixture)
	union := anchorExtents(fixture, doc)

	pyroIV := find(t, doc, "Pyro", "Pyro IV")
	if pyroIV.KM == nil {
		t.Fatal("Pyro IV has no km; the case this test is about cannot be checked")
	}
	if *pyroIV.KM <= byType.Moon.Max {
		t.Fatalf("Pyro IV is %g km and the by-type moon maximum is %g: upstream must have changed, "+
			"and this test no longer demonstrates anything", *pyroIV.KM, byType.Moon.Max)
	}
	if union.Moon.Max != *pyroIV.KM {
		t.Errorf("moon maximum is %g, want %g: a body rendered at the moon tier is outside the range "+
			"its own disc is scaled against", union.Moon.Max, *pyroIV.KM)
	}
	// The other half must survive too: the union widens, it does not replace.
	if union.Moon.Min != byType.Moon.Min {
		t.Errorf("moon minimum is %g, want the upstream-wide %g", union.Moon.Min, byType.Moon.Min)
	}
}

// TestAnchorExtentsSpansSystemsThatAreNotRendered is the reason the extents are
// written at all: a body in a system nobody has rolled out yet still has to set
// the scale, or the next rollout batch resizes the discs on every page already
// published.
//
// It is built from a synthetic starmap rather than the fixture because the
// fixture cannot show it — its seven systems are five rolled-out ones plus two
// whose bodies all happen to fall inside the range those five already set. The
// real 90-system mirror shows it plainly, and
// TestCommittedExtentsReachBeyondTheFile checks that end.
func TestAnchorExtentsSpansSystemsThatAreNotRendered(t *testing.T) {
	size := func(v float64) *starmap.Number {
		n := starmap.Number(v)
		return &n
	}
	upstream := &starmap.Document{Objects: []starmap.Object{
		{Type: typeStar, Size: size(1.2)},     // solar radii: the rendered star
		{Type: typeStar, Size: size(6260)},    // km: a smaller star, not rendered
		{Type: typeStar, Size: size(5848920)}, // km: a larger star, not rendered
		{Type: typePlanet, Size: size(137932)},
		{Type: typeMoon, Size: size(1.789)},
	}}

	rendered := &Document{}
	star := 1.2 * solarRadiusKM
	rendered.Systems.Set("Rendered", &System{Star: &Body{KM: &star}})

	got := anchorExtents(upstream, rendered)
	if got.Star.Min != 6260 || got.Star.Max != 5848920 {
		t.Errorf("star extent is %s, want 6260-5.84892e+06 km: the scale must come from the whole "+
			"dataset, not from the one system being written", got.Star)
	}
	if got.Planet == nil || got.Planet.Max != 137932 {
		t.Errorf("planet extent is %s, but no planet is rendered at all: an unrendered tier still "+
			"has to be measured, or the first system to use it moves everything", got.Planet)
	}
	if got.Moon == nil || got.Moon.Max != 1789 {
		t.Errorf("moon extent is %s, want the converted 1789 km", got.Moon)
	}
}

// TestCommittedExtentsReachBeyondTheFile is the same property on the real data:
// the committed extents are built from all 90 upstream systems, so they must be
// wider than the five the file renders. If they ever collapse onto the file's
// own contents, the anchoring has been lost and the discs are free to move again.
func TestCommittedExtentsReachBeyondTheFile(t *testing.T) {
	doc := decodeFile(t, committedSystems)
	if doc.Extents == nil {
		t.Fatalf("%s records no extents; re-run `mise run systemmap`", committedSystems)
	}

	rendered := extentBuilder{}
	for _, name := range doc.Systems.Keys() {
		sys, _ := doc.Systems.Get(name)
		if sys.Star != nil {
			rendered.note(tierStar, sys.Star.KM)
		}
		if sys.Companion != nil {
			rendered.note(tierStar, sys.Companion.KM)
		}
		for i := range sys.Bodies {
			b := &sys.Bodies[i]
			if b.Tier == tierBelt {
				continue
			}
			rendered.note(tierPlanet, b.KM)
			if b.Moons == nil {
				continue
			}
			for j := range *b.Moons {
				rendered.note(tierMoon, (*b.Moons)[j].KM)
			}
		}
	}

	wider := 0
	for tier, recorded := range map[string]*Extent{
		tierStar:   doc.Extents.Star,
		tierPlanet: doc.Extents.Planet,
		tierMoon:   doc.Extents.Moon,
	} {
		have := rendered[tier]
		if have == nil || recorded == nil {
			t.Errorf("%s: recorded %s, rendered %s", tier, recorded, have)
			continue
		}
		if recorded.Min > have.Min || recorded.Max < have.Max {
			t.Errorf("%s: recorded %s does not contain the rendered range %s", tier, recorded, have)
		}
		if recorded.Min < have.Min || recorded.Max > have.Max {
			wider++
		}
	}
	if wider == 0 {
		t.Errorf("every recorded extent matches the file's own contents exactly, which is what "+
			"computing them from the file would produce: %+v", doc.Extents)
	}
}

// TestRingsDoNotEnterTheMoonExtents is the invariant that let rings ship onto 57
// live pages: adding them must not move a single disc.
//
// A ring sits in the moons array, so the second pass of the union walks straight
// past it — and if it were measured there, the moon scale would become a function
// of whatever upstream happens to report for a body nothing draws. The overlay's
// `km` reaches a ring like any other body, so "the field is empty upstream" is
// not enough on its own.
func TestRingsDoNotEnterTheMoonExtents(t *testing.T) {
	overlay, err := LoadOverlay([]byte(`{"systems": {"Sol": {}},
		"exclude": ["Protoplanetary Disk*", "Protoplentary Disk*"]}`))
	if err != nil {
		t.Fatal(err)
	}
	fixture := loadFixture(t)
	res, err := Build(Options{Starmap: fixture, Overlay: overlay})
	if err != nil {
		t.Fatal(err)
	}

	// Sol is the system with rings: four of them, one per giant.
	rings := 0
	for _, name := range res.Document.Systems.Keys() {
		sys, _ := res.Document.Systems.Get(name)
		for i := range sys.Bodies {
			if sys.Bodies[i].Moons == nil {
				continue
			}
			for _, m := range *sys.Bodies[i].Moons {
				if m.Tier == tierRing {
					rings++
				}
			}
		}
	}
	if rings != 4 {
		t.Fatalf("Sol built with %d rings, want 4; this test is no longer about anything", rings)
	}

	// Force one to carry a size, the way an overlay `km` or an upstream change
	// would, and the extents must not notice.
	sys, _ := res.Document.Systems.Get("Sol")
	before := anchorExtents(fixture, res.Document)
	for i := range sys.Bodies {
		if sys.Bodies[i].Moons == nil {
			continue
		}
		for j := range *sys.Bodies[i].Moons {
			if m := &(*sys.Bodies[i].Moons)[j]; m.Tier == tierRing {
				km := 999999.0
				m.KM = &km
			}
		}
	}
	after := anchorExtents(fixture, res.Document)
	if *before.Moon != *after.Moon {
		t.Errorf("a ring changed the moon extent from %s to %s", before.Moon, after.Moon)
	}
}

// TestAnchorExtentsIgnoresBeltsAndUnsizedBodies keeps a zero out of the minimum.
// Upstream reports 0 or null for every belt and for bodies it has no figure for,
// and a zero minimum makes the tier's logarithmic scale infinite — every disc on
// the page would compute NaN.
func TestAnchorExtentsIgnoresBeltsAndUnsizedBodies(t *testing.T) {
	union := anchorExtents(loadFixture(t), buildFromCommittedOverlay(t))
	for tier, e := range map[string]*Extent{
		tierStar:   union.Star,
		tierPlanet: union.Planet,
		tierMoon:   union.Moon,
	} {
		if e == nil {
			t.Errorf("%s has no extent at all", tier)
			continue
		}
		if e.Min <= 0 {
			t.Errorf("%s minimum is %g: a non-positive bound makes math.log infinite in Data.lua", tier, e.Min)
		}
		if e.Max < e.Min {
			t.Errorf("%s extent is inverted: %g-%g", tier, e.Min, e.Max)
		}
	}
}

// TestAnchorExtentsReturnsNilForAnEmptyDataset keeps the key out of the file
// rather than writing an empty object Data.lua would have to interpret.
func TestAnchorExtentsReturnsNilForAnEmptyDataset(t *testing.T) {
	if got := anchorExtents(&starmap.Document{}, &Document{}); got != nil {
		t.Errorf("want nil extents for an empty dataset, got %+v", got)
	}
}

// TestCommittedExtentsCoverEveryBodyInTheFile is the invariant the union exists
// to guarantee, checked against the real committed page rather than the fixture:
// no body it renders may fall outside the range its own tier is scaled against.
// Data.lua clamps such a body to the tier cap, so the failure is silent — two
// bodies of different sizes drawn at the same diameter.
func TestCommittedExtentsCoverEveryBodyInTheFile(t *testing.T) {
	doc := decodeFile(t, committedSystems)
	if doc.Extents == nil {
		t.Fatalf("%s records no extents; re-run `mise run systemmap`", committedSystems)
	}
	check := func(tier, where string, e *Extent, km *float64) {
		if km == nil {
			return
		}
		if e == nil {
			t.Errorf("%s has a %s km but the file records no %s extent", where, tier, tier)
			return
		}
		if *km < e.Min || *km > e.Max {
			t.Errorf("%s is %g km, outside the recorded %s range %g-%g", where, *km, tier, e.Min, e.Max)
		}
	}
	for _, name := range doc.Systems.Keys() {
		sys, _ := doc.Systems.Get(name)
		if sys.Star != nil {
			check(tierStar, name+" star", doc.Extents.Star, sys.Star.KM)
		}
		if sys.Companion != nil {
			check(tierStar, name+" companion", doc.Extents.Star, sys.Companion.KM)
		}
		for i := range sys.Bodies {
			b := &sys.Bodies[i]
			if b.Tier == tierBelt {
				continue
			}
			check(tierPlanet, name+"/"+b.Label, doc.Extents.Planet, b.KM)
			if b.Moons == nil {
				continue
			}
			for j := range *b.Moons {
				m := (*b.Moons)[j]
				check(tierMoon, name+"/"+b.Label+"/"+m.Label, doc.Extents.Moon, m.KM)
			}
		}
	}
}

// TestCommittedExtentsContainTheFixture is the relation that stands in for a
// byte comparison of the extents block.
//
// The committed file is generated from the full 90-system mirror, which is
// gitignored; the tests build from a seven-system cut of it. The seven are a
// subset, so their extents must sit inside the committed ones — and if the
// committed block were ever regenerated from a partial mirror, or hand-trimmed
// to the systems listed in the file, this is what would catch it.
func TestCommittedExtentsContainTheFixture(t *testing.T) {
	committed := decodeFile(t, committedSystems)
	if committed.Extents == nil {
		t.Fatalf("%s records no extents; re-run `mise run systemmap`", committedSystems)
	}
	fromFixture := anchorExtents(loadFixture(t), buildFromCommittedOverlay(t))

	for _, c := range []struct {
		tier         string
		outer, inner *Extent
	}{
		{tierStar, committed.Extents.Star, fromFixture.Star},
		{tierPlanet, committed.Extents.Planet, fromFixture.Planet},
		{tierMoon, committed.Extents.Moon, fromFixture.Moon},
	} {
		if c.inner == nil {
			continue
		}
		if c.outer == nil {
			t.Errorf("%s: the committed file records no extent, but the fixture measures %s", c.tier, c.inner)
			continue
		}
		if c.outer.Min > c.inner.Min || c.outer.Max < c.inner.Max {
			t.Errorf("%s: committed %s does not contain the fixture's %s — the committed extents look "+
				"like they were built from a partial mirror, or trimmed by hand",
				c.tier, c.outer, c.inner)
		}
	}
}

// TestEncodeOmitsAbsentExtents keeps the key out of a document that has none, so
// that Data.lua's fallback path stays reachable and the pre-generator fixture
// still round-trips.
func TestEncodeOmitsAbsentExtents(t *testing.T) {
	b, err := Encode(&Document{Doc: "doc"})
	if err != nil {
		t.Fatal(err)
	}
	if got := string(b); strings.Contains(got, "extents") {
		t.Errorf("a document with no extents must not write the key:\n%s", got)
	}

	// And the round trip preserves one that is present, including the key order
	// the page is stored in.
	doc := &Document{Doc: "doc", Extents: &Extents{
		Star:   &Extent{Min: 6260, Max: 58489200},
		Planet: &Extent{Min: 165.4, Max: 137932},
		Moon:   &Extent{Min: 44.6, Max: 3214},
	}}
	encoded, err := Encode(doc)
	if err != nil {
		t.Fatal(err)
	}
	back, err := Decode(encoded)
	if err != nil {
		t.Fatal(err)
	}
	if back.Extents == nil || *back.Extents.Star != *doc.Extents.Star ||
		*back.Extents.Planet != *doc.Extents.Planet || *back.Extents.Moon != *doc.Extents.Moon {
		t.Errorf("extents did not survive a round trip: %+v", back.Extents)
	}
	if want := "\"extents\": {\n\t\t\"star\": {\n\t\t\t\"min\": 6260,\n\t\t\t\"max\": 58489200\n\t\t},"; !strings.Contains(string(encoded), want) {
		t.Errorf("want star first and min before max, got:\n%s", encoded)
	}
}

// TestGeneratorWritesTheExtentsIntoTheFile is the end-to-end seam: the command
// writes what Build computed, and `mise run systemmap` is what puts it on disk.
func TestGeneratorWritesTheExtentsIntoTheFile(t *testing.T) {
	if _, err := os.Stat(committedSystems); err != nil {
		t.Fatal(err)
	}
	doc := decodeFile(t, committedSystems)
	if doc.Extents == nil || doc.Extents.Star == nil || doc.Extents.Planet == nil || doc.Extents.Moon == nil {
		t.Fatalf("%s must record all three scaling tiers; got %+v", committedSystems, doc.Extents)
	}
}

// The extents are the one number in the file that changes what ALREADY-PUBLISHED
// pages look like. Every disc on every live page is scaled against them, so
// moving a bound silently resizes 57 pages that nobody edited.
//
// Nothing else here catches that. TestCommittedExtentsCoverEveryBodyInTheFile
// only asserts bodies fall INSIDE the range, and TestCommittedExtentsReachBeyondTheFile
// only asserts the range is wider than the file — so WIDENING a bound passes both
// while shrinking every disc. Verified: setting the star max to 99999999 leaves
// the whole suite, Lua included, green.
//
// So the values are pinned outright. They are derived across all 90 upstream
// systems, which is what makes them stable as the rollout adds systems — adding a
// system already inside the range must NOT move them. If this test fails, either
// upstream gained a genuinely new extreme body, or something regressed. Deciding
// which is the point: updating these numbers is a deliberate act that repaints
// every live page, never a reflex to make CI pass.
func TestCommittedExtentsAreTheAnchoredValues(t *testing.T) {
	doc := decodeFile(t, committedSystems)
	if doc.Extents == nil {
		t.Fatalf("%s records no extents; re-run `mise run systemmap`", committedSystems)
	}

	for _, c := range []struct {
		tier     string
		got      *Extent
		min, max float64
		why      string
	}{
		{tierStar, doc.Extents.Star, 6260, 58489200,
			"Odin (smallest star) to Hadrian (largest)"},
		{tierPlanet, doc.Extents.Planet, 165.4, 137932,
			"Delamar to Helios III, a system not yet rolled out"},
		{tierMoon, doc.Extents.Moon, 44.6, 3214,
			"Epheet to Pyro IV — Pyro IV is upstream-typed a PLANET but renders as a moon, so it enters via the union"},
	} {
		if c.got == nil {
			t.Errorf("%s extent is absent, want %g-%g (%s)", c.tier, c.min, c.max, c.why)
			continue
		}
		if c.got.Min != c.min || c.got.Max != c.max {
			t.Errorf("%s extent is %g-%g, want %g-%g (%s).\n"+
				"Changing this resizes every %s disc on every published page. "+
				"Only update it if upstream really gained a new extreme.",
				c.tier, c.got.Min, c.got.Max, c.min, c.max, c.why, c.tier)
		}
	}
}
