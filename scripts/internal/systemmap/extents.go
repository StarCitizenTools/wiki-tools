package systemmap

import (
	"fmt"

	"github.com/StarCitizenTools/wiki-tools/scripts/internal/starmap"
)

// The three tiers that scale. They are the keys of Data.lua's DISC table, and
// the field names of Extents; a belt has no entry because it renders as a fixed
// band rather than a scaled disc.
const (
	tierStar   = "star"
	tierPlanet = "planet"
	tierMoon   = "moon"
)

// upstreamTier maps an upstream object type onto the tier its size belongs to
// when the whole dataset is measured. It is the body's UPSTREAM type, which is
// the same basis sizeKM converts on — and the reason this pass alone is not
// enough. See anchorExtents.
var upstreamTier = map[string]string{
	typeStar:   tierStar,
	typePlanet: tierPlanet,
	typeMoon:   tierMoon,
}

// anchorExtents computes the disc scale recorded in systems.json: for each tier,
// the smallest and largest km it will ever have to render.
//
// It is the UNION of two passes, and both are needed.
//
// The first measures every body upstream has, by upstream type, so the scale is
// a property of the dataset rather than of whichever systems have been rolled
// out. That is the whole point: a disc must not resize on a published page
// because a later batch added a bigger planet somewhere else.
//
// The second measures the file actually being written, by the tier each body
// renders at. Upstream type and rendered tier are not the same question, and
// where they disagree the first pass puts a rendered body outside its own tier.
// Pyro IV is the live case: upstream types it a planet, the overlay reparents it
// as a moon of Pyro V, and at 3,214 km it is nearly twice the largest true moon
// in all 90 systems (Gainey, 1,789 km). Recording 1,789 as the moon maximum
// would push Pyro IV past the end of its own scale.
//
// Returns nil when nothing measurable was found, which keeps the key out of the
// file rather than writing an empty object Data.lua would have to interpret.
func anchorExtents(doc *starmap.Document, out *Document) *Extents {
	b := extentBuilder{}

	for i := range doc.Objects {
		obj := &doc.Objects[i]
		// A ring is never drawn as a scaled body, so it never sets the scale for
		// the ones that are. Upstream types all eleven ASTEROID_BELT, which the
		// tier map already skips; this makes the rule about what the object IS
		// rather than about how upstream happens to type it, which is the same
		// basis the ring is recognised on everywhere else.
		if isRing(obj) {
			continue
		}
		tier, ok := upstreamTier[obj.Type]
		if !ok {
			continue
		}
		b.note(tier, sizeKM(obj.Type, sizeOf(obj)))
	}

	for _, name := range out.Systems.Keys() {
		sys, ok := out.Systems.Get(name)
		if !ok {
			continue
		}
		// Both stars, and neither assumed to be there: two systems upstream have
		// no star, and a companion is a star at the star tier like any other —
		// pass one already measured it by upstream type, so this only has to
		// agree rather than to widen anything.
		if sys.Star != nil {
			b.note(tierStar, sys.Star.KM)
		}
		if sys.Companion != nil {
			b.note(tierStar, sys.Companion.KM)
		}
		for i := range sys.Bodies {
			body := &sys.Bodies[i]
			// A belt is skipped rather than relied on to carry no km: an overlay
			// `km` on one would otherwise widen the planet tier with a figure
			// nothing renders.
			if body.Tier == tierBelt {
				continue
			}
			b.note(tierPlanet, body.KM)
			if body.Moons == nil {
				continue
			}
			for j := range *body.Moons {
				moon := &(*body.Moons)[j]
				// A ring shares the moons array with real moons and is skipped
				// for the same reason a belt is skipped above: it renders as a
				// fixed band, so a km on one — an overlay override, or a figure
				// upstream invents later — would widen the moon tier with a
				// number nothing draws, and resize every moon on every published
				// page.
				if moon.Tier == tierRing {
					continue
				}
				b.note(tierMoon, moon.KM)
			}
		}
	}

	if len(b) == 0 {
		return nil
	}
	return &Extents{Star: b[tierStar], Planet: b[tierPlanet], Moon: b[tierMoon]}
}

// extentBuilder accumulates the smallest and largest km seen per tier.
type extentBuilder map[string]*Extent

// note widens a tier's extent to include km. A nil or non-positive size is not
// a measurement — upstream reports both for bodies it has no figure for — and is
// ignored rather than recorded as a zero minimum, which would make the tier's
// logarithmic scale infinite.
func (b extentBuilder) note(tier string, km *float64) {
	if km == nil || *km <= 0 {
		return
	}
	e, ok := b[tier]
	if !ok {
		b[tier] = &Extent{Min: *km, Max: *km}
		return
	}
	if *km < e.Min {
		e.Min = *km
	}
	if *km > e.Max {
		e.Max = *km
	}
}

// summarise renders the extents as one line for the build report, so that a
// change to the disc scale of every published page is visible in the run that
// caused it rather than only in the committed diff.
func (e *Extents) summarise() string {
	if e == nil {
		return "extents: none recorded"
	}
	return fmt.Sprintf("extents anchored across the whole dataset: star %s, planet %s, moon %s",
		e.Star, e.Planet, e.Moon)
}

// String renders one tier's bounds. A nil extent is a tier with no measurable
// body anywhere, which is worth saying rather than printing as 0.
func (e *Extent) String() string {
	if e == nil {
		return "(none)"
	}
	return fmt.Sprintf("%g-%g km", e.Min, e.Max)
}
