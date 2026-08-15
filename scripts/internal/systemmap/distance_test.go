package systemmap

import (
	"os"
	"strings"
	"testing"

	"github.com/StarCitizenTools/wiki-tools/scripts/internal/starmap"
)

// The rule these tests exist for: upstream's `distance` is measured from a
// body's PARENT, so it orders SIBLINGS and nothing else. Read as star-relative
// it produces confident nonsense — Sol's rings are thousandths of an AU because
// they are measured from their planet, and Taranis' debris field is 0.3 from
// Taranis II rather than from the star it would then be drawn nearest to.

// au wraps a float as the optional upstream distance the mirror now carries.
func au(v float64) *starmap.Number {
	n := starmap.Number(v)
	return &n
}

func des(s string) *string { return &s }

func oid(v int) *int { return &v }

// loadCommittedOverlay reads the real overlay, so a test that speaks about a
// particular system reads the file an editor would edit rather than a copy.
func loadCommittedOverlay(t *testing.T) *Overlay {
	t.Helper()
	b, err := os.ReadFile(committedOverlay)
	if err != nil {
		t.Fatal(err)
	}
	overlay, err := LoadOverlay(b)
	if err != nil {
		t.Fatal(err)
	}
	return overlay
}

// railLabels is a rail's top-level labels alone. rail() folds each planet's
// moons into its label, which is what most tests want and is exactly wrong for
// one asking where a belt sits relative to Pluto.
func railLabels(t *testing.T, doc *Document, system string) []string {
	t.Helper()
	sys, ok := doc.Systems.Get(system)
	if !ok {
		t.Fatalf("no system %q in the output", system)
	}
	out := make([]string, 0, len(sys.Bodies))
	for _, b := range sys.Bodies {
		out = append(out, b.Label)
	}
	return out
}

// moonLabels is one planet's column, rings included.
func moonLabels(t *testing.T, doc *Document, system, planet string) []string {
	t.Helper()
	body := find(t, doc, system, planet)
	if body.Moons == nil {
		t.Fatalf("%s carries no moons array", planet)
	}
	out := make([]string, 0, len(*body.Moons))
	for _, m := range *body.Moons {
		out = append(out, m.Label)
	}
	return out
}

// railDoc builds a one-system upstream document: a star, then the bodies given,
// each parented to that star unless it already names a parent. It exists so the
// ordering rule can be exercised on arrangements upstream does not currently
// have — a rail with no distance at all, or a moon measured from a planet it is
// not drawn under.
func railDoc(bodies ...starmap.Object) *starmap.Document {
	const starID = 1
	doc := &starmap.Document{
		Systems: []starmap.System{{ID: 1, Name: "Vector", Type: "SINGLE_STAR"}},
		Objects: []starmap.Object{{
			ID: starID, Code: "VECTOR.STAR", Designation: des("Vector"),
			Type: typeStar, StarSystemID: 1, Distance: au(0),
		}},
	}
	for _, b := range bodies {
		b.StarSystemID = 1
		if b.Type == "" {
			b.Type = typePlanet
		}
		if b.ParentID == nil {
			b.ParentID = oid(starID)
		}
		doc.Objects = append(doc.Objects, b)
	}
	return doc
}

// vectorRail builds a synthetic document and renders its rail as one line, moons
// folded into their planet's label.
func vectorRail(t *testing.T, doc *starmap.Document, overlayJSON string) string {
	t.Helper()
	res, err := buildDoc(t, doc, overlayJSON)
	if err != nil {
		t.Fatal(err)
	}
	return strings.Join(rail(t, res.Document, "Vector"), ", ")
}

// TestDistanceOrdersSiblingsOnTheRail is the headline: upstream has always known
// how far out each belt sits, so the rail no longer needs an editor to say. Every
// case here is built through an EMPTY overlay and still lands on the order the
// wiki serves — which is what retired 50 of the overlay's 58 `after` entries.
func TestDistanceOrdersSiblingsOnTheRail(t *testing.T) {
	cases := []struct {
		system string
		want   string
		why    string
	}{
		{"Stanton", "Hurston, Crusader, Aaron Halo, ArcCorp, microTech",
			"the belt at 1.563 sits between Crusader's 1.28 and ArcCorp's 1.933"},
		{"Ellis", "Ellis I, Ellis II, Green, Kampos, Noble, Ellis VI, Ellis VII, Ellis VIII, " +
			"Ellis belt alpha, Walleye, Bombora, Ellis XI, Ellis XI, Judecca, Pinecone",
			"a belt with no numeral, between the eighth and ninth planets of fifteen. Both bodies " +
				"keyed `Ellis XI` are here because this overlay carries no `exclude` list"},
		{"Gliese", "Gliese I, Gliese II, Gliese belt alpha, Gliese III, Nogo, Gliese belt beta, " +
			"Gliese V, Gliese cluster gamma, Gliese VI",
			"three unnumbered regions interleaved with six planets, all from the one key"},
		{"Odin", "The Coil, Gainey, Odin II, Odin III, Odin IV",
			"Gainey is the one SATELLITE upstream parents to the STAR, so it is a sibling of the " +
				"planets; it ties The Coil at 1.1 and loses the tie to that body's numeral"},
	}
	for _, c := range cases {
		t.Run(c.system, func(t *testing.T) {
			doc := build(t, `{"systems": {"`+c.system+`": {}}}`)
			got := strings.Join(railLabels(t, doc, c.system), ", ")
			if got != c.want {
				t.Errorf("rail (%s):\n got %s\nwant %s", c.why, got, c.want)
			}
		})
	}
}

// TestDistanceOrdersMoonsWithinTheirColumn checks the same rule one level down.
// A moon's distance is measured from its planet, so the moons of one planet are
// comparable with each other and with nothing else in the system.
//
// The synthetic column comes first because it is the only half that can tell the
// two keys apart. Every live Stanton column has letters that already agree with
// its distances — Arial 0.000579 is 1a, Aberdeen 0.000648 is 1b — so a column
// sorted by either key renders the same, and reading Stanton alone would leave
// the rule this test is named for unpinned. Saturn is the one live column where
// they disagree, and it has TestSolOrdersSaturnsMoonsByDistance to itself.
func TestDistanceOrdersMoonsWithinTheirColumn(t *testing.T) {
	// Letters run 1a, 1b, 1c; distances run 1b, 1c, 1a. Upstream's figure wins.
	doc := railDoc(
		starmap.Object{ID: 10, Code: "V.I", Designation: des("Vector I"), Distance: au(3)},
		starmap.Object{ID: 11, Code: "V.1A", Designation: des("Vector 1a"), Type: typeMoon,
			ParentID: oid(10), Distance: au(0.9)},
		starmap.Object{ID: 12, Code: "V.1B", Designation: des("Vector 1b"), Type: typeMoon,
			ParentID: oid(10), Distance: au(0.2)},
		starmap.Object{ID: 13, Code: "V.1C", Designation: des("Vector 1c"), Type: typeMoon,
			ParentID: oid(10), Distance: au(0.5)},
	)
	if got, want := vectorRail(t, doc, `{"systems": {"Vector": {}}}`),
		"Vector I (Vector 1b, Vector 1c, Vector 1a)"; got != want {
		t.Errorf("a column whose letters and distances disagree must follow the distances:\n"+
			" got %s\nwant %s", got, want)
	}

	// And the four live columns, where the two keys agree and the output is the
	// order the wiki serves.
	live := build(t, `{"systems": {"Stanton": {}}}`)
	for planet, want := range map[string]string{
		"Hurston":   "Arial, Aberdeen, Magda, Ita",
		"Crusader":  "Cellin, Daymar, Yela",
		"ArcCorp":   "Lyria, Wala",
		"microTech": "Calliope, Clio, Euterpe",
	} {
		if got := strings.Join(moonLabels(t, live, "Stanton", planet), ", "); got != want {
			t.Errorf("%s's column:\n got %s\nwant %s", planet, got, want)
		}
	}
}

// TestDistanceIsNeverComparedAcrossParents is the whole subtlety, and getting it
// wrong is the failure that looks most like success: every figure is a real
// number in the same unit, so a rail sorted across parents renders without
// complaint and is simply wrong.
//
// Taranis is the live case. Its debris field is 0.3 from Taranis II, which
// upstream parents it to; Taranis I is 0.94 from the STAR. Comparing the two puts
// a body 4.6 AU out in the innermost slot on the rail.
func TestDistanceIsNeverComparedAcrossParents(t *testing.T) {
	doc := buildFromCommittedOverlay(t)
	got := railLabels(t, doc, "Taranis")
	if got[0] != "Taranis I" {
		t.Errorf("the rail must start at Taranis I (0.94 from the star), not at the debris field "+
			"(0.3 from Taranis II); got %v", got)
	}
	if debris, planet := indexOf(got, "Taranis 2a debris"), indexOf(got, "Taranis II"); debris != planet+1 {
		t.Errorf("the debris field belongs immediately after the planet it orbits; got %v", got)
	}
}

// TestABodyMeasuredFromAPlanetDoesNotOrderTheRail is the synthetic form of the
// same guard, on a rail where the odd body carries no `after` to save it.
//
// The whole rail falls back to the Roman numeral, and the body upstream measures
// from somewhere else lands at the end, where it is visible. That is deliberate:
// mixing "closer to the star" with "numbered earlier" in one comparison is not a
// total order, so the answer would depend on which pairs sort happened to
// compare. Falling back loudly beats sorting confidently by two different
// questions.
func TestABodyMeasuredFromAPlanetDoesNotOrderTheRail(t *testing.T) {
	doc := railDoc(
		starmap.Object{ID: 10, Code: "V.I", Designation: des("Vector I"), Distance: au(3)},
		starmap.Object{ID: 11, Code: "V.II", Designation: des("Vector II"), Distance: au(9)},
		// 0.4 from Vector II, not from the star. Sorted against the planets it
		// would take the innermost slot on the rail.
		starmap.Object{ID: 12, Code: "V.DEBRIS", Name: des("Inner Debris"), Type: typeCluster,
			ParentID: oid(11), Distance: au(0.4)},
	)
	if got, want := vectorRail(t, doc, `{"systems": {"Vector": {}}}`),
		"Vector I, Vector II, Inner Debris"; got != want {
		t.Errorf("rail:\n got %s\nwant %s", got, want)
	}
}

// TestAReparentedMoonDoesNotOrderItsNewColumn is the same guard inside a planet's
// moons array. An overlay `moonOf` moves a body the map knows better than
// upstream does, and a body moved under a planet it is not upstream-parented to
// brings a distance measured from somewhere else entirely.
//
// The one live reparenting agrees with upstream — Pyro IV is upstream-parented to
// Pyro V, which is exactly why `moonOf` is right about it — so this arrangement
// has to be built to be tested.
func TestAReparentedMoonDoesNotOrderItsNewColumn(t *testing.T) {
	doc := railDoc(
		starmap.Object{ID: 10, Code: "V.I", Designation: des("Vector I"), Distance: au(3)},
		starmap.Object{ID: 11, Code: "V.II", Designation: des("Vector II"), Distance: au(9)},
		starmap.Object{ID: 12, Code: "V.1A", Designation: des("Vector 1a"), Type: typeMoon,
			ParentID: oid(10), Distance: au(0.9)},
		starmap.Object{ID: 13, Code: "V.1B", Designation: des("Vector 1b"), Type: typeMoon,
			ParentID: oid(10), Distance: au(0.2)},
		// Upstream parents this one to Vector II; the overlay hangs it off Vector I.
		// Its 0.05 is measured from the wrong planet, so the column has to stop
		// reading distances and sort by the lettered designation instead.
		starmap.Object{ID: 14, Code: "V.2A", Designation: des("Vector 2a"), Type: typeMoon,
			ParentID: oid(11), Distance: au(0.05)},
	)
	got := vectorRail(t, doc, `{"systems": {"Vector": {"bodies": {"Vector 2a": {"moonOf": "Vector I"}}}}}`)
	if want := "Vector I (Vector 1a, Vector 1b, Vector 2a), Vector II"; got != want {
		t.Errorf("a column holding a body measured from another planet must fall back to the "+
			"letters:\n got %s\nwant %s", got, want)
	}

	// Without the reparenting the same three distances DO order their columns,
	// which is what shows the fallback above was the parent test firing rather
	// than the letters winning by accident.
	got = vectorRail(t, doc, `{"systems": {"Vector": {}}}`)
	if want := "Vector I (Vector 1b, Vector 1a), Vector II (Vector 2a)"; got != want {
		t.Errorf("rail:\n got %s\nwant %s", got, want)
	}
}

// TestTheNumeralOrdersARailUpstreamGivesNoDistance keeps the rule that was there
// before: the Roman numeral is the fallback, not a thing that was replaced.
// Upstream leaves 13 objects with no distance at all.
func TestTheNumeralOrdersARailUpstreamGivesNoDistance(t *testing.T) {
	doc := railDoc(
		starmap.Object{ID: 12, Code: "V.III", Designation: des("Vector III")},
		starmap.Object{ID: 10, Code: "V.I", Designation: des("Vector I")},
		starmap.Object{ID: 11, Code: "V.II", Designation: des("Vector II")},
	)
	if got, want := vectorRail(t, doc, `{"systems": {"Vector": {}}}`),
		"Vector I, Vector II, Vector III"; got != want {
		t.Errorf("rail:\n got %s\nwant %s", got, want)
	}
}

// TestOneMissingDistanceSendsTheWholeRailBackToTheNumeral pins the granularity of
// the decision, which is the part that is easy to get subtly wrong.
//
// The choice of key is made once for the rail, not per body, because a comparison
// answering "closer to the star" for some pairs and "numbered earlier" for the
// rest is not a total order. So one gap sends everything back — and a belt, which
// has no numeral to fall back to, lands at the end where it is visible rather
// than silently somewhere plausible.
func TestOneMissingDistanceSendsTheWholeRailBackToTheNumeral(t *testing.T) {
	bodies := []starmap.Object{
		{ID: 10, Code: "V.I", Designation: des("Vector I"), Distance: au(3)},
		{ID: 11, Code: "V.II", Designation: des("Vector II"), Distance: au(9)},
		{ID: 12, Code: "V.BELT", Designation: des("Vector Belt Alpha"), Type: typeBelt, Distance: au(5)},
	}
	if got, want := vectorRail(t, railDoc(bodies...), `{"systems": {"Vector": {}}}`),
		"Vector I, Vector belt alpha, Vector II"; got != want {
		t.Fatalf("with every distance present:\n got %s\nwant %s", got, want)
	}

	bodies[1].Distance = nil
	if got, want := vectorRail(t, railDoc(bodies...), `{"systems": {"Vector": {}}}`),
		"Vector I, Vector II, Vector belt alpha"; got != want {
		t.Errorf("with one distance missing:\n got %s\nwant %s", got, want)
	}
}

// TestADistanceTieFallsBackToTheNumeral covers upstream's ties, which are real
// rather than sloppy: Kilian files its three Sisters at 0.1 apiece.
//
// The bodies are handed over numeral-DESCENDING, which is the only arrangement
// that can tell the tiebreak apart from "keep upstream's file order". A tie left
// to file order is not stable in any sense that matters — upstream sorts its
// mirror by code, so `Kilian III` arrives before `Kilian II` — and a test fed the
// answer in the input would pass with the rule deleted.
func TestADistanceTieFallsBackToTheNumeral(t *testing.T) {
	doc := railDoc(
		starmap.Object{ID: 12, Code: "V.III", Designation: des("Vector III"), Distance: au(0.4)},
		starmap.Object{ID: 11, Code: "V.II", Designation: des("Vector II"), Distance: au(0.4)},
		starmap.Object{ID: 10, Code: "V.I", Designation: des("Vector I"), Distance: au(0.4)},
	)
	if got, want := vectorRail(t, doc, `{"systems": {"Vector": {}}}`),
		"Vector I, Vector II, Vector III"; got != want {
		t.Errorf("three bodies upstream cannot separate must be ordered by their numeral, whatever "+
			"order they arrive in:\n got %s\nwant %s", got, want)
	}
}

// TestANumberedBodyWinsATieWithAnUnnumberedOne is the other half of the tie rule,
// and the belt is filed FIRST for the same reason: upstream's own mirror files
// `CROSHAW.BELTS.DAEDALUSCLUSTER` ahead of `CROSHAW.PLANETS.CROSHAWIV`, and
// `KABAL.BELTS.KABALCLUTERALPHA` ahead of every Kabal planet.
func TestANumberedBodyWinsATieWithAnUnnumberedOne(t *testing.T) {
	doc := railDoc(
		starmap.Object{ID: 12, Code: "V.BELT", Designation: des("Vector Belt Alpha"), Type: typeBelt,
			Distance: au(2)},
		starmap.Object{ID: 10, Code: "V.I", Designation: des("Vector I"), Distance: au(2)},
	)
	if got, want := vectorRail(t, doc, `{"systems": {"Vector": {}}}`),
		"Vector I, Vector belt alpha"; got != want {
		t.Errorf("a body with a numeral takes the earlier slot when upstream ties it with one that "+
			"has none:\n got %s\nwant %s", got, want)
	}
}

// TestTheNumeralDecidesFourLiveRails names them. Upstream ties bodies in four of
// the seventy-five systems on the wiki, and in every one of them the mirror files
// the loser first — it is sorted by code, and `BELTS` precedes `PLANETS` just as
// `KILIANIII` precedes `KILIANII`. So all four rails are the tiebreak's output
// rather than upstream's file order, and dropping the rule reorders every one.
func TestTheNumeralDecidesFourLiveRails(t *testing.T) {
	doc := buildFromCommittedOverlay(t)
	cases := []struct {
		system string
		want   string
		tie    string
	}{
		{"Pyro", "Pyro I, Akiro Cluster, Monox, Bloom, Pyro V, Terminus",
			"Pyro I ties Akiro Cluster at 0.553, and the mirror files the cluster first"},
		{"Kilian", "First Sister, Second Sister, Third Sister, Magma, MacArthur, Osha, Keene, " +
			"Kilian VIII, Corin, Kilian X, Kilian XI, Kilian XII, Kilian XIII, Kilian XIV",
			"the three Sisters all sit at 0.1, and the mirror files them I, III, II"},
		{"Croshaw", "Croshaw I, Angeli, Vann, Croshaw IV, Icarus Cluster, Daedalus Cluster",
			"Croshaw IV shares 2.76 with both clusters and is the only one of the three with a " +
				"numeral; the mirror files both clusters ahead of it"},
		{"Kabal", "Kabal I, Kabal II, Kabal III, Kabal cluster alpha",
			"Kabal III ties Kabal cluster alpha at 1.84, and the mirror files the cluster first"},
	}
	for _, c := range cases {
		t.Run(c.system, func(t *testing.T) {
			if got := strings.Join(railLabels(t, doc, c.system), ", "); got != c.want {
				t.Errorf("rail (%s):\n got %s\nwant %s", c.tie, got, c.want)
			}
		})
	}
}

// --- the three systems the change was measured against ----------------------

// TestTangaPutsItsBeltInnermost is the fix.
//
// The belt sits at 3.31 against Tanga I's 7.632, so upstream puts it inside the
// first planet — which is what the belt's own article describes, calling it the
// remnants of the system's former inner planets from before the star expanded.
// The retired `after: Tanga I` came from one sentence of prose that contradicted
// the rest of that article.
func TestTangaPutsItsBeltInnermost(t *testing.T) {
	doc := buildFromCommittedOverlay(t)
	want := "Tanga belt alpha, Tanga I, Tanga II"
	if got := strings.Join(railLabels(t, doc, "Tanga"), ", "); got != want {
		t.Errorf("rail:\n got %s\nwant %s", got, want)
	}
}

// TestSolOrdersSaturnsMoonsByDistance is the one moon column in the whole file
// where upstream's letters and upstream's distances disagree, and the distances
// are right: Tethys, Dione, Rhea, Titan, Iapetus is the real Saturnian system,
// while the letters (6a Titan, 6b Rhea, 6c Tethys, 6d Dione) run by fame.
//
// The letters are outward for every system CIG invented and only for those, which
// is why the fallback is a fallback and not the rule.
func TestSolOrdersSaturnsMoonsByDistance(t *testing.T) {
	doc := buildFromCommittedOverlay(t)
	// The ring stays ahead of every moon, decided by role rather than by distance.
	want := "Rings of Saturn, Tethys, Dione, Rhea, Titan, Iapetus"
	if got := strings.Join(moonLabels(t, doc, "Sol", "Saturn"), ", "); got != want {
		t.Errorf("Saturn's column:\n got %s\nwant %s", got, want)
	}
}

// TestSolKeepsTheKuiperBeltAheadOfPluto records an open editorial question, and
// records that the generator is not the thing that answers it.
//
// Both figures are real AU from the Sun — Pluto 39.5, the Kuiper Belt 45 — so
// upstream would put Pluto first. The wiki's own article says the belt lies
// beyond Neptune and contains objects such as Pluto, which puts the belt first.
// Both are defensible, so the overlay's `after: Neptune` is KEPT, under the rule
// this change adopts: an `after` that agrees with upstream is redundant, and one
// that disagrees is a signal, which is reported rather than deleted.
//
// If an editor decides upstream is right, deleting that one overlay entry and
// regenerating is the whole change — and this test is what tells them the
// decision was taken here rather than overlooked.
func TestSolKeepsTheKuiperBeltAheadOfPluto(t *testing.T) {
	doc := buildFromCommittedOverlay(t)
	got := railLabels(t, doc, "Sol")
	belt, pluto := indexOf(got, "Kuiper Belt"), indexOf(got, "Pluto")
	if belt < 0 || pluto < 0 {
		t.Fatalf("Sol should carry both the Kuiper Belt and Pluto; got %v", got)
	}
	if belt > pluto {
		t.Errorf("the overlay still places the Kuiper Belt after Neptune, ahead of Pluto; got %v", got)
	}
}

// TestTaranisKeepsItsDebrisFieldWithTaranisII records the second of the three,
// and what "sits with Taranis II" can mean on a rail that nests exactly one
// level.
//
// The debris field is upstream-parented to Taranis II and its own article says it
// surrounds that planet, so it must not compete with the star's own children —
// which the sibling rule already guarantees, since 0.3 from a planet is not a
// figure any star-relative distance can be compared with. What the sibling rule
// cannot do is give it a position: it has no numeral either, so without the
// overlay it would float to the end of the rail. Its `after: Taranis II` is
// therefore KEPT, and is doing real work.
//
// Moving it INTO Taranis II's moons array would need a belt tier inside `moons`,
// which Module:SystemMap/Data.lua does not have: that array carries moons and
// rings, and a debris field filed there would be drawn as a moon and measured on
// the moon scale. That is a Lua-side change, not an overlay one.
func TestTaranisKeepsItsDebrisFieldWithTaranisII(t *testing.T) {
	overlay := loadCommittedOverlay(t)
	if after := overlay.Systems["Taranis"].Bodies["Taranis 2a Debris"].After; after != "Taranis II" {
		t.Fatalf("the debris field has no comparable distance and no numeral, so its `after` is "+
			"load-bearing; got %q", after)
	}
	doc := buildFromCommittedOverlay(t)
	want := "Taranis I, Taranis II, Taranis 2a debris, Taranis belt alpha, Taranis III, " +
		"Taranis belt beta, Taranis IV"
	if got := strings.Join(railLabels(t, doc, "Taranis"), ", "); got != want {
		t.Errorf("rail:\n got %s\nwant %s", got, want)
	}
}

// TestOnlyEightAfterEntriesSurvive pins the retirement, and names every survivor
// with the reason it is still there. Fifty of the fifty-eight were transcribing a
// position upstream had all along; these eight are not.
//
// Two are structural — a body upstream measures from a planet, and a body upstream
// gives no distance at all — two are ties upstream cannot break, and four are
// placements upstream actively disagrees with. A NEW disagreement appearing here
// after a refetch is upstream having moved something, and wants reading rather
// than deleting.
func TestOnlyEightAfterEntriesSurvive(t *testing.T) {
	want := map[string]string{
		"Nyx/Delamar":                    "ties Glaciem Ring at 2.1; upstream cannot separate them",
		"Croshaw/Icarus Cluster":         "ties Daedalus Cluster at 2.76; upstream cannot separate them",
		"Taranis/Taranis 2a Debris":      "0.3 is measured from Taranis II, and it has no numeral",
		"Kallis/Kallis V Accretion Disk": "upstream gives it no distance at all",
		"Sol/Kuiper Belt":                "DISAGREES: 45 puts it beyond Pluto's 39.5; the article puts it before",
		"Taranis/Taranis Belt Alpha":     "DISAGREES: 2.15 puts it inside Taranis II's 4.62",
		"Taranis/Taranis Belt Beta":      "DISAGREES: 3.39 puts it inside Taranis II's 4.62",
		"Kallis/Kallis Belt Beta":        "DISAGREES: 1.27 puts it outside Kallis IV's 1.09",
	}
	got := map[string]bool{}
	for name, sys := range loadCommittedOverlay(t).Systems {
		for body, corr := range sys.Bodies {
			if corr.After != "" {
				got[name+"/"+body] = true
			}
		}
	}
	for key, why := range want {
		if !got[key] {
			t.Errorf("`after` on %s was retired, but it is there because it %s", key, why)
		}
		delete(got, key)
	}
	for key := range got {
		t.Errorf("`after` on %s is not one of the eight upstream's distance cannot retire; "+
			"if it now agrees with upstream, delete it and regenerate", key)
	}
}

func indexOf(items []string, want string) int {
	for i, s := range items {
		if s == want {
			return i
		}
	}
	return -1
}
