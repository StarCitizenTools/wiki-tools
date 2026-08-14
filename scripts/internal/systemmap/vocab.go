package systemmap

import (
	"fmt"
	"math"
	"strings"
	"unicode"

	"github.com/StarCitizenTools/wiki-tools/scripts/internal/starmap"
)

// Upstream object types. Everything else — jump points, landing zones, stations,
// points of interest — is not a navigable body on the orbit rail and never
// enters the output.
const (
	typeStar    = "STAR"
	typePlanet  = "PLANET"
	typeMoon    = "SATELLITE"
	typeBelt    = "ASTEROID_BELT"
	typeCluster = "ASTEROID_FIELD"
)

// subtypePlanetaryRing is the subtype upstream gives all eleven of its rings.
// The type is no help: a ring is typed ASTEROID_BELT, the same as the regions on
// the planet rail, so the subtype is the only thing that separates them.
const subtypePlanetaryRing = "Planetary Ring"

// isRing reports whether an object is a planetary ring.
//
// It tests the subtype alone. The drop rule this replaced also required the ring
// to be unnamed, which was true of all eleven and was load-bearing there — the
// justification for dropping them was that an unnamed ring has nothing to link.
// It is not load-bearing here: a ring upstream names would take that name as its
// label and page like any other body, and it would still be a ring.
func isRing(obj *starmap.Object) bool {
	return subtypeName(obj) == subtypePlanetaryRing
}

// planetSubtypes maps the upstream Title Case subtype onto the display string
// systems.json stores.
//
// This is an explicit table rather than a lower-casing rule because it is not a
// mechanical transform: "Super-Earth" and "Super Jupiter" keep their capitals
// while "Gas Giant" becomes "Gas giant". It covers all 22 planet subtypes
// present across the 90 systems, so rolling out a new system needs no entry
// here — and an upstream addition is reported rather than silently passed
// through in the wrong case.
//
// Module:SystemMap/Data.lua keys its palette off these strings. Changing one
// here without changing SUBTYPE_KIND there silently downgrades a body to the
// neutral "unknown" disc.
var planetSubtypes = map[string]string{
	"Artificial":         "Artificial",
	"Carbon Planet":      "Carbon planet",
	"Chthonian Planet":   "Chthonian planet",
	"Coreless Planet":    "Coreless planet",
	"Desert Planet":      "Desert planet",
	"Dwarf Planet":       "Dwarf planet",
	"Evaporating Planet": "Evaporating planet",
	"Gas Dwarf":          "Gas dwarf",
	"Gas Giant":          "Gas giant",
	"Ice Giant":          "Ice giant",
	"Ice Planet":         "Ice planet",
	"Iron Planet":        "Iron planet",
	"Lava Planet":        "Lava planet",
	"Mesoplanet":         "Mesoplanet",
	"Ocean Planet":       "Ocean planet",
	"Protoplanet":        "Protoplanet",
	"Puffy Planet":       "Puffy planet",
	"Rogue Planet":       "Rogue planet",
	"Smog Planet":        "Smog planet",
	"Super Jupiter":      "Super Jupiter",
	"Super-Earth":        "Super-Earth",
	"Terrestrial Rocky":  "Terrestrial rocky",
}

// starKind is the display subtype and the glyph class for one upstream star
// subtype.
//
// class becomes `star-<lowercased class>` in Data.lua, so the two entries with
// no spectral letter carry a word instead: "degenerate" and "neutron" yield
// star-degenerate and star-neutron with no change to the Lua. Variable and
// Subgiant deliberately carry no class — one instance each, and neither implies
// a colour a reader would predict — so they fall back to the generic `star`.
type starKind struct {
	display string
	class   string
}

// starSubtypes covers all 13 star subtypes present across the 90 systems. An
// unknown one is an error rather than a fallback: a star with no class renders
// as the generic disc, which would silently misrepresent, say, a black hole.
var starSubtypes = map[string]starKind{
	"Main Sequence-Dwarf-O":    {"O-type main sequence", "O"},
	"Main Sequence-Dwarf-B":    {"B-type main sequence", "B"},
	"Main Sequence-Dwarf-A":    {"A-type main sequence", "A"},
	"Main Sequence-Dwarf-F":    {"F-type main sequence", "F"},
	"Main Sequence-Dwarf-G":    {"G-type main sequence", "G"},
	"Main Sequence-Dwarf-K":    {"K-type main sequence", "K"},
	"Main Sequence-Dwarf-M":    {"M-type main sequence", "M"},
	"Giants-Giant-M":           {"M-type giant", "M"},
	"White Dwarf-Degenerate-A": {"A-type white dwarf", "degenerate"},
	"Neutron":                  {"Neutron star", "neutron"},
	"Variable":                 {"Variable star", ""},
	"Subgiant":                 {"Subgiant", ""},
}

// planetSubtype resolves a planet's display subtype.
func planetSubtype(name string) (string, error) {
	if name == "" {
		return "", nil
	}
	display, ok := planetSubtypes[name]
	if !ok {
		return "", fmt.Errorf("unknown planet subtype %q: add it to planetSubtypes, "+
			"and give it a kind in Module:SystemMap/Data.lua", name)
	}
	return display, nil
}

// starSubtype resolves a star's display subtype and glyph class.
func starSubtype(name string) (starKind, error) {
	if name == "" {
		return starKind{}, nil
	}
	kind, ok := starSubtypes[name]
	if !ok {
		return starKind{}, fmt.Errorf("unknown star subtype %q: add it to starSubtypes, "+
			"and style star-<class> in Module:SystemMap/styles.css", name)
	}
	return kind, nil
}

// ---------------------------------------------------------------------------
// Sizes
// ---------------------------------------------------------------------------

// solarRadiusKM is the Sun's radius. Upstream states small star sizes in solar
// radii — Sol itself is exactly 1.000, which is what identifies the unit.
const solarRadiusKM = 696340

// starSolarRadiiCutoff separates the two units upstream mixes in the star tier.
// The split is not close: across all 93 stars the largest solar-radii value is
// 13.91 and the smallest kilometre value is 6260.
const starSolarRadiiCutoff = 1000

// moonThousandsKM converts the moon tier, which upstream states in thousands of
// kilometres.
const moonThousandsKM = 1000

// sizeKM converts an upstream size to the kilometre figure systems.json stores.
//
// The rule is applied by the body's UPSTREAM type, not by where the overlay puts
// it. That is what keeps Pyro IV — a planet reparented as a moon of Pyro V —
// multiplied by 1 rather than by 1000.
//
// Belts return nil: upstream reports 0 or null for every one of them, and a belt
// has no meaningful diameter, so it renders as a fixed band instead of a scaled
// disc.
func sizeKM(upstreamType string, size *float64) *float64 {
	if size == nil || *size <= 0 {
		return nil
	}
	v := *size

	switch upstreamType {
	case typeStar:
		if v < starSolarRadiiCutoff {
			v *= solarRadiusKM
		}
		// Whole kilometres. A stellar radius carries its fraction as noise:
		// upstream's own figures run to five decimals on a number in the
		// hundreds of thousands.
		v = math.Round(v)
	case typeMoon:
		v = round6(v * moonThousandsKM)
	case typePlanet:
		v = round6(v)
	default:
		return nil
	}

	if v <= 0 {
		return nil
	}
	return &v
}

// round6 strips float noise from the unit conversion without discarding real
// precision: 0.7 * 1000 is 700.0000000000001 in float64, and Delamar is
// genuinely 165.4 km across.
func round6(v float64) float64 {
	return math.Round(v*1e6) / 1e6
}

// ---------------------------------------------------------------------------
// Designations
// ---------------------------------------------------------------------------

// romanValues is enough of the numeral alphabet for orbital positions; upstream
// tops out at XIII.
var romanValues = map[byte]int{'I': 1, 'V': 5, 'X': 10, 'L': 50, 'C': 100, 'D': 500, 'M': 1000}

// romanValue parses a Roman numeral. It is deliberately strict about the
// alphabet and lax about form: upstream writes well-formed numerals, and a
// malformed one should still sort somewhere rather than abort a system.
func romanValue(s string) (int, bool) {
	if s == "" {
		return 0, false
	}
	total := 0
	for i := 0; i < len(s); i++ {
		v, ok := romanValues[s[i]]
		if !ok {
			return 0, false
		}
		if i+1 < len(s) {
			if next, ok := romanValues[s[i+1]]; ok && next > v {
				total -= v
				continue
			}
		}
		total += v
	}
	return total, true
}

// orbitalIndex reads the Roman numeral that ends a designation: "Terra I" is 1,
// "Stanton IV" is 4.
//
// This is the ordering signal, in place of orbit_period, which upstream leaves
// null for 195 of its 326 planets. Planets are numbered outward from the star by
// convention, and sorting Stanton by numeral reproduces
// Hurston, Crusader, ArcCorp, microTech exactly.
//
// A designation with no numeral — "Delamar", every belt — returns false, and its
// position has to come from the overlay's `after`.
func orbitalIndex(designation string) (int, bool) {
	fields := strings.Fields(designation)
	if len(fields) < 2 {
		// A bare numeral with nothing before it is a body called "I", not the
		// first planet of an unnamed system.
		return 0, false
	}
	return romanValue(fields[len(fields)-1])
}

// moonIndex parses a normalised moon designation such as "1a": the planet's
// orbital number and the moon's letter within it. Moons are lettered outward,
// so the pair sorts them.
func moonIndex(designation string) (int, string, bool) {
	digits := 0
	for digits < len(designation) && designation[digits] >= '0' && designation[digits] <= '9' {
		digits++
	}
	if digits == 0 || digits == len(designation) {
		return 0, "", false
	}
	letters := designation[digits:]
	for i := 0; i < len(letters); i++ {
		if letters[i] < 'a' || letters[i] > 'z' {
			return 0, "", false
		}
	}
	n := 0
	for i := 0; i < digits; i++ {
		n = n*10 + int(designation[i]-'0')
	}
	return n, letters, true
}

// normaliseDesignation trims upstream's stray trailing spaces ("Ail'ka III ")
// and drops the system prefix from moon designations, so "Stanton 1a" is stored
// as "1a".
//
// The prefix is only dropped when what follows starts with a digit. That is what
// keeps "Pyro IV" whole when it is reparented as a moon of Pyro V: its
// designation is a planet's, and shortening it to "IV" would claim an orbital
// slot it no longer occupies.
func normaliseDesignation(designation, system string) string {
	d := strings.TrimSpace(designation)
	prefix := system + " "
	if rest, ok := strings.CutPrefix(d, prefix); ok && rest != "" && rest[0] >= '0' && rest[0] <= '9' {
		return rest
	}
	return d
}

// beltCase applies the wiki's house style to a belt designation: the system name
// keeps its capitals, everything after it drops to lower case. Upstream writes
// "Stanton Belt Alpha"; the page says "Stanton belt alpha".
//
// It applies to a belt's label and page as well as its designation, but only
// where upstream gives the belt no name and all three are therefore derived from
// the one designation — see buildBody, which owns that condition. A belt upstream
// names keeps that name verbatim in label and page; only its designation is
// recased here.
//
// This is a derivation rule rather than four overlay entries because it is not a
// judgement — it is the same sentence-case convention the rest of the wiki uses
// for common nouns, and it has to hold for the 69 belts still to be rolled out.
// It was applied by hand on the wiki (rev 374302, "Fix casing") and that edit
// was never mirrored back to git, which is how the repo copy came to be stale.
//
// The rule keys off the system name rather than a word count, because the name
// is not always one word: upstream designates a belt of "Ē'aluth (Eealus)" as
// "Ē'aluth (Eealus) Belt Alpha" and one of "Ail'ka" as "Ail'ka Belt Alpha".
// Cutting the exact prefix handles both, and every apostrophe, macron and
// parenthetical in between.
//
// Two things are deliberately left alone:
//
// A Roman numeral keeps its capitals. Four belts upstream are designated after a
// planet rather than with a Greek letter — "Ellis XI", "Odin I", "Hades IV
// split", "Kallis V Accretion Disk" — and that numeral is an orbital position,
// which every planet designation in the file writes in capitals ("Stanton I",
// "Pyro V"). Lower-casing it would be a different claim, not a casing change.
//
// A designation that does not start with its system name is returned unchanged.
// That is the eleven "Rings of <planet>" belts and Sol's "Jovian Rings": there
// is no prefix to anchor to, and guessing which word is the proper noun would be
// worse than doing nothing.
func beltCase(designation, system string) string {
	rest, ok := strings.CutPrefix(designation, system)
	// The remainder must start at a word boundary, so that a system whose name
	// is a prefix of a longer first word is not silently treated as a match.
	if !ok || !strings.HasPrefix(rest, " ") {
		return designation
	}

	// Split and Join on a single space rather than Fields: Fields would collapse
	// any run of spaces upstream wrote, which is a change this rule is not
	// entitled to make.
	words := strings.Split(rest, " ")
	for i, word := range words {
		if isOrbitalNumeral(word) {
			continue
		}
		words[i] = strings.ToLower(word)
	}
	return system + strings.Join(words, " ")
}

// isOrbitalNumeral reports whether a word is a Roman numeral written as a
// designation writes one. Both halves are required: parsing alone would also
// accept a lower-case word that happens to be spelled out of I, V, X, L, C, D
// and M, and the capitals are what mark it as a numeral rather than a name.
func isOrbitalNumeral(word string) bool {
	if word == "" || word != strings.ToUpper(word) {
		return false
	}
	_, ok := romanValue(word)
	return ok
}

// ucfirst upper-cases the first rune, the way MediaWiki normalises a page title.
// It is what turns the label "microTech" into the title "MicroTech".
func ucfirst(s string) string {
	for i, r := range s {
		return string(unicode.ToUpper(r)) + s[i+len(string(r)):]
	}
	return s
}
