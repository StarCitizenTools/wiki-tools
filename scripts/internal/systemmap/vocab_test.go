package systemmap

import (
	"math"
	"strings"
	"testing"
)

func TestSizeKMPerTier(t *testing.T) {
	// Every expectation here was measured against the hand-written file the
	// generator has to reproduce, not taken from its %doc, which described the
	// star figures as diameters.
	cases := []struct {
		name         string
		upstreamType string
		size         float64
		want         float64
		omitted      bool
	}{
		{"planet is already km", typePlanet, 11853, 11853, false},
		{"planet keeps its fraction", typePlanet, 165.4, 165.4, false},
		{"moon is thousands of km", typeMoon, 0.7, 700, false},
		{"moon fraction survives the multiply", typeMoon, 0.51787, 517.87, false},
		{"small star is solar radii", typeStar, 1.2, 835608, false},
		{"large star is already km", typeStar, 571000.44, 571000, false},
		{"star rounds to whole km", typeStar, 965325.11564, 965325, false},
		{"just below the cutoff is solar radii", typeStar, 999.9, math.Round(999.9 * solarRadiusKM), false},
		{"at the cutoff is km", typeStar, 1000, 1000, false},
		{"belt has no diameter", typeBelt, 0, 0, true},
		{"cluster has no diameter", typeCluster, 12, 0, true},
		{"zero is not a size", typePlanet, 0, 0, true},
	}

	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			size := c.size
			got := sizeKM(c.upstreamType, &size)
			if c.omitted {
				if got != nil {
					t.Fatalf("sizeKM(%s, %v) = %v, want it omitted", c.upstreamType, c.size, *got)
				}
				return
			}
			if got == nil {
				t.Fatalf("sizeKM(%s, %v) was omitted, want %v", c.upstreamType, c.size, c.want)
			}
			if *got != c.want {
				t.Errorf("sizeKM(%s, %v) = %v, want %v", c.upstreamType, c.size, *got, c.want)
			}
		})
	}

	if got := sizeKM(typePlanet, nil); got != nil {
		t.Errorf("a null upstream size must be omitted, got %v", *got)
	}
}

// TestSizeKMFollowsUpstreamTypeNotPosition is the Pyro IV case: upstream still
// types it a planet, and it renders as a moon of Pyro V only because the overlay
// reparents it. Converting by its rendered tier would multiply it by 1000 and
// make a 3,214 km planet into a 3.2 million km one.
func TestSizeKMFollowsUpstreamTypeNotPosition(t *testing.T) {
	size := 3214.0
	got := sizeKM(typePlanet, &size)
	if got == nil || *got != 3214 {
		t.Fatalf("a planet reparented as a moon must keep planet scale, got %v", got)
	}
}

func TestRomanValue(t *testing.T) {
	cases := map[string]int{
		"I": 1, "II": 2, "III": 3, "IV": 4, "V": 5, "VI": 6,
		"IX": 9, "X": 10, "XIII": 13, "XL": 40,
	}
	for in, want := range cases {
		got, ok := romanValue(in)
		if !ok || got != want {
			t.Errorf("romanValue(%q) = %d, %v; want %d, true", in, got, ok, want)
		}
	}
	for _, in := range []string{"", "Delamar", "Gen", "1a", "Alpha"} {
		if got, ok := romanValue(in); ok {
			t.Errorf("romanValue(%q) = %d, true; want it rejected", in, got)
		}
	}
}

func TestOrbitalIndex(t *testing.T) {
	cases := []struct {
		designation string
		want        int
		ok          bool
	}{
		{"Stanton I", 1, true},
		{"Stanton IV", 4, true},
		{"Terra III", 3, true},
		{"Castra II", 2, true},
		// Upstream leaves stray trailing spaces on five designations.
		{"Ail'ka III ", 3, true},
		// No numeral: position has to come from the overlay's `after`.
		{"Delamar", 0, false},
		{"Stanton Belt Alpha", 0, false},
		{"Terra Cluster Alpha", 0, false},
		{"Pyro - Stanton", 0, false},
		// A bare numeral is a name, not a position.
		{"I", 0, false},
		{"", 0, false},
	}
	for _, c := range cases {
		got, ok := orbitalIndex(c.designation)
		if ok != c.ok || got != c.want {
			t.Errorf("orbitalIndex(%q) = %d, %v; want %d, %v", c.designation, got, ok, c.want, c.ok)
		}
	}
}

func TestMoonIndex(t *testing.T) {
	n, letters, ok := moonIndex("5a")
	if !ok || n != 5 || letters != "a" {
		t.Errorf(`moonIndex("5a") = %d, %q, %v`, n, letters, ok)
	}
	if _, _, ok := moonIndex("Pyro IV"); ok {
		t.Error("a reparented planet keeps a planet designation and must not sort as a moon")
	}
	for _, in := range []string{"", "1", "a", "1A", "1a2"} {
		if _, _, ok := moonIndex(in); ok {
			t.Errorf("moonIndex(%q) should be rejected", in)
		}
	}
}

func TestNormaliseDesignation(t *testing.T) {
	cases := []struct{ in, system, want string }{
		{"Stanton 1a", "Stanton", "1a"},
		{"Terra 3a", "Terra", "3a"},
		// A planet's designation is never shortened, which is what keeps
		// "Pyro IV" whole when the overlay hangs it under Pyro V.
		{"Pyro IV", "Pyro", "Pyro IV"},
		{"Stanton I", "Stanton", "Stanton I"},
		{"Stanton Belt Alpha", "Stanton", "Stanton Belt Alpha"},
		{"Ail'ka III ", "Ail'ka", "Ail'ka III"},
		{"Delamar", "Nyx", "Delamar"},
	}
	for _, c := range cases {
		if got := normaliseDesignation(c.in, c.system); got != c.want {
			t.Errorf("normaliseDesignation(%q, %q) = %q, want %q", c.in, c.system, got, c.want)
		}
	}
}

func TestUcfirst(t *testing.T) {
	cases := map[string]string{
		"microTech": "MicroTech",
		"Hurston":   "Hurston",
		"":          "",
		"ArcCorp":   "ArcCorp",
	}
	for in, want := range cases {
		if got := ucfirst(in); got != want {
			t.Errorf("ucfirst(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestPlanetSubtypeIsATableNotARule(t *testing.T) {
	cases := map[string]string{
		"Gas Giant":         "Gas giant",
		"Terrestrial Rocky": "Terrestrial rocky",
		"Smog Planet":       "Smog planet",
		// Lower-casing every word but the first would ruin these two.
		"Super-Earth":   "Super-Earth",
		"Super Jupiter": "Super Jupiter",
	}
	for in, want := range cases {
		got, err := planetSubtype(in)
		if err != nil || got != want {
			t.Errorf("planetSubtype(%q) = %q, %v; want %q", in, got, err, want)
		}
	}
	if _, err := planetSubtype("Hycean Planet"); err == nil {
		t.Error("an unmapped subtype must be reported, not passed through in upstream case")
	}
	if got, err := planetSubtype(""); err != nil || got != "" {
		t.Errorf("a body with no subtype must stay blank, got %q, %v", got, err)
	}
}

func TestStarSubtypeClasses(t *testing.T) {
	cases := []struct{ in, display, class string }{
		{"Main Sequence-Dwarf-G", "G-type main sequence", "G"},
		{"Main Sequence-Dwarf-B", "B-type main sequence", "B"},
		{"Giants-Giant-M", "M-type giant", "M"},
		// No spectral letter, so the class carries a word instead and
		// Data.lua's 'star-' .. lower(class) still lands on a real kind.
		{"White Dwarf-Degenerate-A", "A-type white dwarf", "degenerate"},
		{"Neutron", "Neutron star", "neutron"},
		// One instance each, and neither implies a predictable colour, so they
		// fall back to the generic star disc.
		{"Variable", "Variable star", ""},
		{"Subgiant", "Subgiant", ""},
	}
	for _, c := range cases {
		got, err := starSubtype(c.in)
		if err != nil {
			t.Errorf("starSubtype(%q): %v", c.in, err)
			continue
		}
		if got.display != c.display || got.class != c.class {
			t.Errorf("starSubtype(%q) = %q/%q, want %q/%q", c.in, got.display, got.class, c.display, c.class)
		}
	}
	if _, err := starSubtype("Hypergiant"); err == nil {
		t.Error("an unmapped star subtype must be reported: it would render as the generic disc")
	}
}

// TestSubtypeTablesCoverUpstream pins the counts measured across all 90 systems.
// A shortfall means the palette work was done against a smaller sample than the
// data actually holds.
func TestSubtypeTablesCoverUpstream(t *testing.T) {
	if len(planetSubtypes) != 22 {
		t.Errorf("planetSubtypes has %d entries; upstream ships 22 planet subtypes", len(planetSubtypes))
	}
	if len(starSubtypes) != 12 {
		t.Errorf("starSubtypes has %d entries; upstream ships 12, plus 15 stars with no subtype at all", len(starSubtypes))
	}
}

// TestBeltCaseKeepsTheSystemNameAndLowersTheRest pins the derivation rule that
// replaced four hand edits on the wiki.
//
// The awkward names are the point. A rule that lower-cased "every word but the
// first" would produce "Ē'aluth (eealus) belt alpha", and one that assumed a
// two-word prefix would produce "Ail'ka Belt alpha". Anchoring on the system
// name itself is what survives a vocabulary this irregular.
func TestBeltCaseKeepsTheSystemNameAndLowersTheRest(t *testing.T) {
	cases := []struct{ system, in, want string }{
		// The four the wiki fixed by hand in rev 374302.
		{"Stanton", "Stanton Belt Alpha", "Stanton belt alpha"},
		{"Pyro", "Pyro Cluster Alpha", "Pyro cluster alpha"},
		{"Nyx", "Nyx Belt Alpha", "Nyx belt alpha"},
		{"Nyx", "Nyx Belt Beta", "Nyx belt beta"},
		// The pilot systems, derived rather than transcribed.
		{"Terra", "Terra Cluster Alpha", "Terra cluster alpha"},
		{"Terra", "Terra Belt Beta", "Terra belt beta"},

		// System names upstream writes with apostrophes, macrons and full stops.
		// Every one of these is a real designation.
		{"Ail'ka", "Ail'ka Belt Alpha", "Ail'ka belt alpha"},
		{"Croshaw", "Croshaw Cluster Beta", "Croshaw cluster beta"},
		{"Gliese", "Gliese Cluster Gamma", "Gliese cluster gamma"},

		// The nine systems upstream files under a parenthetical alias reach this
		// rule already de-aliased — dealiasDesignation runs first, and buildBody
		// passes the wiki name — so these are the pairs the generator actually
		// forms. See TestDealiasDesignationDropsTheStarmapAlias for the step
		// before.
		{"Ē'aluth", "Ē'aluth Belt Alpha", "Ē'aluth belt alpha"},
		{"Yā'mon", "Yā'mon Belt Alpha", "Yā'mon belt alpha"},
		{"Kyuk'ya", "Kyuk'ya Belt Alpha", "Kyuk'ya belt alpha"},
		{"Th.us'ūng", "Th.us'ūng Belt Alpha", "Th.us'ūng belt alpha"},
		{"La'uo", "La'uo Belt Beta", "La'uo belt beta"},
		{"K.ap'a'ri", "K.ap'a'ri Belt Alpha", "K.ap'a'ri belt alpha"},

		// Handed a name that really does carry a parenthetical, the rule still
		// anchors on the whole of it. beltCase takes no view on what a system is
		// called; it is the caller that decides which name to pass.
		{"K.ap'a'ri (Khabari)", "K.ap'a'ri (Khabari) Belt Alpha", "K.ap'a'ri (Khabari) belt alpha"},

		// A Roman numeral is an orbital slot, and the file writes those in
		// capitals everywhere else ("Stanton I", "Pyro V").
		{"Odin", "Odin I", "Odin I"},
		{"Ellis", "Ellis XI", "Ellis XI"},
		{"Hades", "Hades IV split", "Hades IV split"},
		{"Kallis", "Kallis V Accretion Disk", "Kallis V accretion disk"},
		{"Taranis", "Taranis 2a Debris", "Taranis 2a debris"},

		// No system prefix to anchor to: left exactly as upstream wrote it,
		// because which word is the proper noun is not derivable.
		{"Sol", "Jovian Rings", "Jovian Rings"},
		{"Sol", "Rings of Saturn", "Rings of Saturn"},
		{"Vega", "Rings of Aremis", "Rings of Aremis"},
		{"Kyuk'ya", "Rings of Kyuk'ya I", "Rings of Kyuk'ya I"},

		// The prefix must end at a word boundary, or a system whose name starts
		// another word would eat into it.
		{"Nyx", "Nyxus Belt Alpha", "Nyxus Belt Alpha"},
		{"Terra", "Terra", "Terra"},
		{"Terra", "", ""},
	}
	for _, c := range cases {
		if got := beltCase(c.in, c.system); got != c.want {
			t.Errorf("beltCase(%q, %q) = %q, want %q", c.in, c.system, got, c.want)
		}
	}
}

// TestWikiNameDropsTheStarmapAlias pins the shape of the rule rather than a list
// of the nine systems it fires on, since a tenth wants no code change.
func TestWikiNameDropsTheStarmapAlias(t *testing.T) {
	cases := map[string]string{
		// The nine upstream files under a Cold War alias.
		"Ē'aluth (Eealus)":    "Ē'aluth",
		"Yā'mon (Hadur)":      "Yā'mon",
		"Kyuk'ya (Indra)":     "Kyuk'ya",
		"Kai'pua (Kayfa)":     "Kai'pua",
		"K.ap'a'ri (Khabari)": "K.ap'a'ri",
		"Malkail (Markahil)":  "Malkail",
		"Th.us'ūng (Pallas)":  "Th.us'ūng",
		"R.il'a (Rihlah)":     "R.il'a",
		"La'uo (Virtus)":      "La'uo",

		// Everything else is returned untouched, alias or not.
		"Stanton": "Stanton", "Pyro": "Pyro", "T.āl": "T.āl", "Ail'ka": "Ail'ka",

		// A parenthetical that is not a trailing alias is not one: no closing
		// bracket at the end, nothing to the left of the bracket, or no bracket
		// at all. None of these is in the data; they are the shapes the cut must
		// decline rather than guess at.
		"Vector (star) II": "Vector (star) II",
		"(Khabari)":        "(Khabari)",
		" (Khabari)":       " (Khabari)",
		"Vector(Khabari)":  "Vector(Khabari)",
		"":                 "",
	}
	for in, want := range cases {
		if got := wikiName(in); got != want {
			t.Errorf("wikiName(%q) = %q, want %q", in, got, want)
		}
	}
}

// TestDealiasDesignationDropsTheStarmapAlias covers the step that turns
// upstream's designation into the one the map prints.
//
// The alias appears nowhere on the wiki as part of a body's designation: the
// article for Pi'tua files it as "La'uo I", not "La'uo (Virtus) I". Printing
// upstream's form put a string on 36 body cards across seven systems that no
// article, category or search on the wiki agrees with.
func TestDealiasDesignationDropsTheStarmapAlias(t *testing.T) {
	cases := []struct{ system, in, want string }{
		// Planets, in their own orbital slot.
		{"La'uo (Virtus)", "La'uo (Virtus) I", "La'uo I"},
		{"Th.us'ūng (Pallas)", "Th.us'ūng (Pallas) V", "Th.us'ūng V"},
		{"R.il'a (Rihlah)", "R.il'a (Rihlah) VI", "R.il'a VI"},
		// A moon, whose prefix normaliseDesignation strips afterwards.
		{"Kyuk'ya (Indra)", "Kyuk'ya (Indra) 1a", "Kyuk'ya 1a"},
		// A belt, which beltCase then sentence-cases.
		{"Ē'aluth (Eealus)", "Ē'aluth (Eealus) Belt Alpha", "Ē'aluth Belt Alpha"},

		// No alias to drop: the 81 systems upstream names plainly.
		{"Stanton", "Stanton IV", "Stanton IV"},
		{"Ail'ka", "Ail'ka Belt Alpha", "Ail'ka Belt Alpha"},

		// A designation that names a planet rather than the system has no prefix
		// to rewrite, and keeps upstream's string whole.
		{"Kyuk'ya (Indra)", "Rings of Kyuk'ya I", "Rings of Kyuk'ya I"},
		{"La'uo (Virtus)", "", ""},
	}
	for _, c := range cases {
		if got := dealiasDesignation(c.in, c.system); got != c.want {
			t.Errorf("dealiasDesignation(%q, %q) = %q, want %q", c.in, c.system, got, c.want)
		}
	}
}

// TestDealiasDesignationIsIdempotent guards the same drift beltCase is guarded
// against: the generator conceptually runs on its own output, and a rule that
// cut a little more each pass would rewrite the page with no input change.
func TestDealiasDesignationIsIdempotent(t *testing.T) {
	for _, c := range []struct{ system, in string }{
		{"La'uo (Virtus)", "La'uo (Virtus) I"},
		{"Kyuk'ya (Indra)", "Rings of Kyuk'ya I"},
		{"Stanton", "Stanton IV"},
	} {
		once := dealiasDesignation(c.in, c.system)
		if twice := dealiasDesignation(once, c.system); twice != once {
			t.Errorf("dealiasDesignation is not idempotent for %q: %q then %q", c.in, once, twice)
		}
	}
}

// TestBeltCaseIsIdempotent matters because the generator runs on its own output
// conceptually every time: a rule that lower-cased a little more on each pass
// would drift the page without any input changing.
func TestBeltCaseIsIdempotent(t *testing.T) {
	for _, in := range []string{"Stanton Belt Alpha", "Ellis XI", "Rings of Saturn", "Ail'ka Belt Alpha"} {
		system := strings.Fields(in)[0]
		once := beltCase(in, system)
		if twice := beltCase(once, system); twice != once {
			t.Errorf("beltCase is not idempotent for %q: %q then %q", in, once, twice)
		}
	}
}

func TestIsOrbitalNumeralNeedsCapitals(t *testing.T) {
	cases := map[string]bool{
		"I": true, "IV": true, "XI": true, "MCM": true,
		// Lower case is a word, not a numeral: "mix" must not survive as a
		// proper noun just because it is spelled out of numeral letters.
		"i": false, "iv": false, "mix": false,
		// Not in the numeral alphabet at all.
		"Alpha": false, "BELT": false, "": false, "2a": false,
	}
	for in, want := range cases {
		if got := isOrbitalNumeral(in); got != want {
			t.Errorf("isOrbitalNumeral(%q) = %v, want %v", in, got, want)
		}
	}
}
