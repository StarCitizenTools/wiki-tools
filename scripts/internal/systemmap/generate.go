package systemmap

import (
	"fmt"
	"sort"
	"strings"

	"github.com/StarCitizenTools/wiki-tools/scripts/internal/starmap"
)

// docComment is the %doc written into systems.json. It lives here rather than in
// the overlay so that regenerating cannot lose it, and so that changing what the
// file claims about itself is a code review.
const docComment = "Generated file, do not hand-edit: `mise run systemmap` rebuilds it from the ARK Starmap mirror " +
	"plus the hand-owned corrections in pages/module/SystemMap/overlay.json (wiki-tools repo), and an edit made here " +
	"is lost on the next regeneration. Make it in the overlay instead. " +
	"`star` is the system's star and is OPTIONAL: two upstream systems have none, and the key is then absent rather " +
	"than empty. `companion` is a second star, present for five systems and absent for the other 85, alongside " +
	"`companionShape`, which says how the two are drawn: `nested` where upstream parents the companion to the primary " +
	"and it genuinely orbits it (Tyrol, Kyuk'ya), or `paired` where neither is parented and the planets co-orbit both " +
	"(Bacchus, Baker, Goss). The shape is derived from parent_id, not from the system's upstream `type`, which reports " +
	"Tyrol as SINGLE_STAR despite its two stars. A nested companion is drawn where a moon is drawn but at star size, " +
	"and a pair shares one rail slot; either way the you-are-here marker lands on the individual star, because the two " +
	"are separate articles. No companion carries a body anywhere in the dataset, and the generator refuses to build one " +
	"that does. " +
	"`bodies` is everything orbiting the star, IN ORBITAL ORDER, planets and asteroid belts together. There is no sort " +
	"key: position is the array index. Planet order comes from the Roman numeral in the upstream designation, because " +
	"upstream has no orbit_period for 195 of its 326 planets; a body with no numeral (every belt, and Delamar) is " +
	"placed by the overlay's `after`. A belt is marked `tier: belt`, and the one moon upstream parents to the star " +
	"instead of to a planet — Odin's Gainey, which therefore has nothing to nest under — is marked `tier: moon` so " +
	"that it is still drawn, counted and measured as a moon; anything unmarked is a planet. A planet's `moons` " +
	"array also carries its rings, marked `tier: ring` — a ring nests where a moon nests, because that is the one " +
	"level of nesting the rail has, but it is drawn as a band rather than a disc and is counted separately. A ring " +
	"orbiting a MOON is dropped instead: it would need a level of its own, and the only one upstream has (Stanton's " +
	"Ring of Yela) has no article either. Belts and rings carry no " +
	"`km`, because upstream reports 0/null and neither has a meaningful diameter, so they render at a fixed size " +
	"rather than as a scaled disc. `km` is a diameter for planets and moons but a RADIUS for stars: upstream states " +
	"planets in km, moons in thousands of km, and stars either in solar radii (x696340, the Sun's radius) below 1000 " +
	"or in km above it. Mixing the two quantities is harmless because the disc scale is rank-preserving within a tier " +
	"and never compares across tiers. The unit rule is applied by each body's UPSTREAM type, which is why Pyro IV " +
	"keeps planet-scale km while sitting at the moon tier. A belt's designation is lower-cased after the system name " +
	"(\"Stanton belt alpha\"), which is house style rather than a correction, so it is derived here and not listed in " +
	"the overlay; a Roman numeral keeps its capitals, because that is an orbital slot. " +
	"`extents` is the disc scale: the smallest and largest km per tier ACROSS ALL 90 UPSTREAM SYSTEMS, unioned with " +
	"whatever this file renders, so that adding a system never resizes a disc on a page already published. " +
	"Module:SystemMap/Data.lua uses it when present and falls back to measuring this file when it is absent, which " +
	"is the behaviour that made the sizes move. Do not hand-trim it to the systems listed below. " +
	"See docs/superpowers/specs/2026-08-13-system-map-rollout-design.md."

// Options configures a build.
type Options struct {
	// Starmap is the upstream mirror, as produced by cmd/starmap.
	Starmap *starmap.Document
	// Overlay is the hand-owned corrections, and the roster: a system is built
	// only if the overlay lists it.
	Overlay *Overlay
}

// Result is a completed build.
type Result struct {
	Document *Document
	// Notes are human-readable lines about what was dropped and why: excluded
	// bodies, and exclusion patterns that matched nothing.
	Notes []string
	// Bodies counts everything written: stars, moons and rings included.
	Bodies int
}

// role is where a body sits on the rail. It decides which keys the body emits,
// which is not the same question as which unit its size is in — that is settled
// by the upstream type, so a reparented planet keeps its own scale.
type role int

const (
	roleStar role = iota
	rolePlanet
	roleBelt
	roleMoon
	// roleRing sits alongside roleMoon rather than under it: a ring occupies a
	// moon's slot on the rail and none of a moon's other properties. It carries
	// no size (see buildBody) and it is drawn as a band, not a disc.
	roleRing
	// roleRailMoon is a moon that sits on the PLANET rail, because upstream
	// parents it to the star and there is no planet under which to nest it. Odin's
	// Gainey is the only one in all 90 systems.
	//
	// It is a role of its own because the two questions the rail asks about a body
	// disagree here for the only time: where it sits (a top-level slot, like a
	// planet) and what it is (a moon). Left as rolePlanet the file said "planet"
	// by omission, and everything downstream believed it — the card header counted
	// four planets in a three-planet system, the disc was measured against the
	// planet range, and the glyph fell through to the neutral grey "unknown" disc
	// because only planets and stars carry a subtype to key a colour off.
	roleRailMoon
)

// describeRole names a role for an error message, as a noun phrase a sentence
// can end on.
func describeRole(r role) string {
	switch r {
	case roleBelt:
		return "a belt"
	case roleRailMoon:
		return "itself a moon"
	case roleRing:
		return "a ring"
	case roleStar:
		return "a star"
	case roleMoon:
		return "a moon"
	}
	return "a planet"
}

// node is one upstream body while it is being placed.
type node struct {
	obj *starmap.Object
	// key is the body's identity and its default label: the upstream name, or
	// the designation when the name is null (which it is for Pyro I, Delamar,
	// and every star except Terra Nova).
	key string
	// overlayKey is how the overlay addresses the body. It is `key`, except
	// where two bodies in one system share a key — upstream names neither, so
	// both are promoted to the type-qualified form, which is the only handle
	// that tells them apart. See indexByOverlayKey.
	overlayKey string
	// order is the body's position in the upstream file, the tiebreak that keeps
	// output deterministic when nothing else separates two bodies.
	order int
	// overlayOrder is the body's position in the overlay's `bodies` object, or
	// -1. It orders two bodies inserted after the same anchor.
	overlayOrder int
	correction   Correction
	moons        []*node
	// soleStar marks the star of a system that has exactly one, which is the
	// only case the "<System> (star)" page convention holds for. See buildBody.
	soleStar bool
}

// Build renders the systems the overlay lists.
func Build(opts Options) (*Result, error) {
	if opts.Starmap == nil {
		return nil, fmt.Errorf("systemmap: a starmap document is required")
	}
	if opts.Overlay == nil {
		return nil, fmt.Errorf("systemmap: an overlay is required")
	}

	systemsByName := map[string][]*starmap.System{}
	for i := range opts.Starmap.Systems {
		s := &opts.Starmap.Systems[i]
		systemsByName[s.Name] = append(systemsByName[s.Name], s)
	}

	objectsBySystem := map[int][]*starmap.Object{}
	for i := range opts.Starmap.Objects {
		o := &opts.Starmap.Objects[i]
		objectsBySystem[o.StarSystemID] = append(objectsBySystem[o.StarSystemID], o)
	}

	res := &Result{Document: &Document{Doc: docComment}}
	excluded := 0

	for _, name := range opts.Overlay.Order {
		matches := systemsByName[name]
		switch len(matches) {
		case 1:
		case 0:
			return nil, fmt.Errorf("overlay names system %q, which is not in the starmap", name)
		default:
			return nil, fmt.Errorf("overlay names system %q, which the starmap has %d of", name, len(matches))
		}

		sys, dropped, err := buildSystem(name, matches[0], objectsBySystem[matches[0].ID], opts.Overlay)
		if err != nil {
			return nil, fmt.Errorf("system %s: %w", name, err)
		}
		excluded += dropped
		res.Document.Systems.Set(name, sys)
		res.Bodies += len(sys.Bodies)
		if sys.Star != nil {
			res.Bodies++
		}
		if sys.Companion != nil {
			res.Bodies++
			res.Notes = append(res.Notes, fmt.Sprintf("%s has two stars, drawn %s: %s and %s",
				name, sys.CompanionShape, sys.Star.Label, sys.Companion.Label))
		}
		if sys.Star == nil {
			res.Notes = append(res.Notes, fmt.Sprintf(
				"%s: upstream files no star, so the rail is drawn without a head", name))
		}
		for _, b := range sys.Bodies {
			if b.Moons != nil {
				res.Bodies += len(*b.Moons)
			}
		}
	}

	// Anchored to the whole upstream dataset, not to the systems just built, so
	// that the next rollout batch cannot resize a disc on a page already live.
	res.Document.Extents = anchorExtents(opts.Starmap, res.Document)
	res.Notes = append(res.Notes, res.Document.Extents.summarise())

	if excluded > 0 {
		res.Notes = append(res.Notes, fmt.Sprintf(
			"dropped %s: rings that orbit a moon, and anything matching an exclusion pattern",
			plural(excluded, "body", "bodies")))
	}
	res.Notes = append(res.Notes, unmatchedExclusions(opts.Starmap, opts.Overlay)...)
	return res, nil
}

// unmatchedExclusions reports exclusion patterns that hit nothing anywhere in
// the input. It is a note, not an error: the patterns are global while the
// output is only the systems the overlay lists, so a pattern for a system that
// has not been rolled out yet legitimately matches nothing today. It still wants
// saying, because the other reason a pattern stops matching is that upstream
// renamed what it was hiding.
func unmatchedExclusions(doc *starmap.Document, overlay *Overlay) []string {
	if len(overlay.Exclude) == 0 {
		return nil
	}
	hits := make(map[string]int, len(overlay.Exclude))
	for i := range doc.Objects {
		obj := &doc.Objects[i]
		key := bodyKey(obj)
		for _, pattern := range overlay.Exclude {
			if globMatch(pattern, key) || globMatch(pattern, qualifiedKey(key, obj)) {
				hits[pattern]++
			}
		}
	}
	var notes []string
	for _, pattern := range overlay.Exclude {
		if hits[pattern] == 0 {
			notes = append(notes, fmt.Sprintf("exclusion pattern %q matched nothing upstream", pattern))
		}
	}
	return notes
}

// buildSystem assembles one system and reports how many bodies it dropped.
func buildSystem(name string, sys *starmap.System, objects []*starmap.Object, overlay *Overlay) (*System, int, error) {
	corrections := overlay.Systems[name]
	if corrections == nil {
		corrections = &SystemOverlay{Bodies: map[string]Correction{}}
	}

	var (
		stars   []*node
		nodes   []*node
		dropped int
	)
	byID := map[int]*node{}

	// Every object in the system by upstream id, including the ones that never
	// reach the rail. A ring's parent has to be resolved before the node graph
	// exists, because whether the ring is rendered at all depends on what that
	// parent is.
	objectsByID := make(map[int]*starmap.Object, len(objects))
	for _, obj := range objects {
		objectsByID[obj.ID] = obj
	}

	for i, obj := range objects {
		switch obj.Type {
		case typeStar, typePlanet, typeMoon, typeBelt, typeCluster:
		case typeBlackHole:
			// Refused rather than dropped. Everything else the default arm
			// discards is a thing the rail is not FOR — a jump point, a station, a
			// landing zone — and leaving it out is the whole point of the filter.
			// A black hole is a body the rail is for and cannot yet draw, and it
			// is the head of its system: dropping it renders every planet in
			// orbit around nothing. Failing here costs a build; the alternative
			// costs a wrong picture on a live article that nothing would report.
			return nil, 0, fmt.Errorf("upstream files a %s here (%q), and the rail has no tier or "+
				"glyph for one, so the map would omit the object the system orbits. Give it a kind "+
				"in vocab.go and in Module:SystemMap/Data.lua before listing this system",
				obj.Type, bodyKey(obj))
		default:
			continue // jump points, landing zones, stations: not on the rail
		}

		// A ring around a MOON is dropped, and only that. The rail nests exactly
		// one level, so a ring hung off a moon has nowhere to be drawn — it would
		// need a fourth level of its own, for one body.
		//
		// That body is Stanton's Ring of Yela, the sole instance upstream, and it
		// has no article under any title either, so there is also nothing to
		// link. A ring around a PLANET has both a place to go and, in every case
		// upstream has, an article: it renders in the planet's moons list.
		if isRing(obj) {
			var parent *starmap.Object
			if obj.ParentID != nil {
				parent = objectsByID[*obj.ParentID]
			}
			if parent == nil || parent.Type != typePlanet {
				dropped++
				continue
			}
		}

		// Both forms are offered to `exclude` so that one of two bodies sharing
		// a key can be dropped on its own; the plain form still drops both,
		// which is what an editor writing a bare name means.
		key := bodyKey(obj)
		if overlay.excludes(key) || overlay.excludes(qualifiedKey(key, obj)) {
			dropped++
			continue
		}

		n := &node{obj: obj, key: key, overlayKey: key, order: i, overlayOrder: -1}
		if obj.Type == typeStar {
			stars = append(stars, n)
			byID[obj.ID] = n
			continue
		}

		nodes = append(nodes, n)
		byID[obj.ID] = n
	}

	// --- the head of the rail ------------------------------------------------
	star, companion, shape, err := resolveStars(stars)
	if err != nil {
		return nil, 0, err
	}
	if star != nil {
		star.correction = corrections.Star
		star.soleStar = companion == nil
	} else if corrections.HasStar {
		// The same promise the companion block makes, and it has to be made
		// separately now that a starless system builds rather than erroring out
		// before the corrections were ever applied. Min is the one, and a `star`
		// block written for it would otherwise be discarded in silence — the exact
		// loss the overlay exists to prevent.
		return nil, 0, fmt.Errorf("overlay corrects the star, but upstream files %s here",
			plural(len(stars), "star", "stars"))
	}
	if companion != nil {
		companion.correction = corrections.Companion
	} else if corrections.HasCompanion {
		return nil, 0, fmt.Errorf("overlay corrects a companion star, but upstream files %s here",
			plural(len(stars), "star", "stars"))
	}
	if corrections.CompanionShape != "" {
		if companion == nil {
			return nil, 0, fmt.Errorf("overlay sets companionShape %q, but upstream files %s here",
				corrections.CompanionShape, plural(len(stars), "star", "stars"))
		}
		shape = corrections.CompanionShape
	}

	// The rail hangs bodies off the primary and nothing off the companion, which
	// is true of all 90 systems upstream: no companion carries a planet, a belt
	// or a moon anywhere in the dataset. It is upstream data rather than a law of
	// nature, so it is checked rather than assumed — a body parented to the
	// companion would otherwise be drawn on the rail as if it orbited the pair,
	// which is a different claim from the one the data makes.
	if companion != nil {
		for _, n := range nodes {
			if n.obj.ParentID != nil && *n.obj.ParentID == companion.obj.ID {
				return nil, 0, fmt.Errorf("%q orbits the companion star %q, and the rail draws "+
					"bodies under the primary only; upstream has never done this before, so decide "+
					"how the map should say it rather than letting it render as an orbit of the pair",
					n.key, companion.key)
			}
		}
	}

	// --- overlay identity -----------------------------------------------------
	byKey, shared, err := indexByOverlayKey(nodes)
	if err != nil {
		return nil, 0, err
	}
	for _, n := range nodes {
		n.correction = corrections.Bodies[n.overlayKey]
		for pos, k := range corrections.BodyOrder {
			if k == n.overlayKey {
				n.overlayOrder = pos
				break
			}
		}
	}

	// --- the overlay must have bitten ---------------------------------------
	//
	// A correction keyed to a body that is not there is how a correction gets
	// lost across a refetch: upstream renames something, the entry stops
	// matching, and the map quietly loses an icon or a reparenting. Refusing to
	// build is the only way that failure is visible.
	for _, key := range corrections.BodyOrder {
		if _, ok := byKey[key]; ok {
			continue
		}
		return nil, 0, fmt.Errorf("overlay corrects %s", unresolvedKey(key, shared))
	}
	for _, n := range nodes {
		if after := n.correction.After; after != "" {
			if _, ok := byKey[after]; !ok {
				return nil, 0, fmt.Errorf("overlay places %q after %s",
					n.overlayKey, unresolvedKey(after, shared))
			}
		}
	}

	// --- moons ---------------------------------------------------------------
	rail := make([]*node, 0, len(nodes))
	parentOf := map[*node]*node{}
	for _, n := range nodes {
		parent, err := moonParent(n, byKey, shared, byID)
		if err != nil {
			return nil, 0, err
		}
		if parent == nil {
			rail = append(rail, n)
			continue
		}
		if parent == n {
			return nil, 0, fmt.Errorf("overlay makes %q a moon of itself", n.overlayKey)
		}
		parentOf[n] = parent
		parent.moons = append(parent.moons, n)
	}

	// The rail nests exactly one level: a planet carries moons, and a moon
	// carries nothing. So a body hung off another moon has nowhere to be drawn —
	// and having left the rail, it is not drawn anywhere else either. It would
	// simply not be written, which is the silent loss this whole two-file design
	// exists to prevent, and the same editorial mistake `after` already refuses.
	// It reaches here two ways: an overlay `moonOf` chain, and an upstream
	// satellite whose planet the overlay has since reparented.
	onRail := map[*node]bool{}
	for _, n := range rail {
		onRail[n] = true
	}
	for _, n := range nodes {
		parent := parentOf[n]
		if parent == nil || onRail[parent] {
			continue
		}
		return nil, 0, fmt.Errorf("%q is a moon of %q, which is itself a moon: the rail nests one "+
			"level, so %q would be dropped from the output entirely. Hang it off a body on the "+
			"planet rail, or check whether two `moonOf` entries point at each other",
			n.overlayKey, parent.overlayKey, n.overlayKey)
	}

	// --- order ---------------------------------------------------------------
	ordered, err := arrange(rail)
	if err != nil {
		return nil, 0, err
	}

	// Non-nil even when it stays empty. Fifteen upstream systems are a star and
	// nothing else, and a nil slice encodes as `null`, which Data.lua walks with
	// ipairs() in two places — including tierExtents, which reads EVERY system to
	// scale the discs. One null there does not break one map; it raises "table
	// expected, got nil" on every page the component renders.
	out := &System{Page: name + " system", Bodies: make([]Body, 0, len(ordered))}
	if corrections.Page != "" {
		out.Page = corrections.Page
	}
	// Both stars are optional and independently so: two systems upstream have
	// none at all, and the key is simply left out rather than written empty, so
	// a single-star system's bytes are what they always were.
	if star != nil {
		body, err := buildBody(star, roleStar, name)
		if err != nil {
			return nil, 0, err
		}
		out.Star = &body
	}
	if companion != nil {
		body, err := buildBody(companion, roleStar, name)
		if err != nil {
			return nil, 0, err
		}
		out.Companion = &body
		out.CompanionShape = shape
	}
	for _, n := range ordered {
		// What a top-level slot holds is decided by the upstream type, not by the
		// slot: a belt is a region, and a SATELLITE that reached the rail is a moon
		// upstream parents to the star (see moonParent). Only the third case is a
		// planet, and it is the one the file marks with no tier at all.
		r := rolePlanet
		switch n.obj.Type {
		case typeBelt, typeCluster:
			r = roleBelt
		case typeMoon:
			r = roleRailMoon
		}
		body, err := buildBody(n, r, name)
		if err != nil {
			return nil, 0, err
		}
		if r == rolePlanet {
			sortMoons(n.moons, name)
			moons := make([]Body, 0, len(n.moons))
			for _, m := range n.moons {
				// A ring shares the moons array and nothing else about a moon.
				// The role is what keeps the two apart from here on: it decides
				// the tier written into the file, and it is why a ring carries no
				// km even when upstream reports one.
				r := roleMoon
				if isRing(m.obj) {
					r = roleRing
				}
				moon, err := buildBody(m, r, name)
				if err != nil {
					return nil, 0, err
				}
				moons = append(moons, moon)
			}
			body.Moons = &moons
		} else if len(n.moons) > 0 {
			// Named rather than assumed to be a belt: a rail moon cannot hold one
			// either, and the rail nests exactly one level, so "a moon of a moon"
			// is as unrenderable as "a moon of a belt" and wants saying as itself.
			return nil, 0, fmt.Errorf("overlay makes %q a moon of %q, which is %s",
				n.moons[0].overlayKey, n.overlayKey, describeRole(r))
		}
		out.Bodies = append(out.Bodies, body)
	}

	// Backstop on the invariant every check above is a specific instance of:
	// every body read is a body written. The checks fire first and say what is
	// wrong; this only catches a way of losing a body that nobody has thought of
	// yet, which is exactly the failure that must not be silent.
	written := len(out.Bodies)
	for _, b := range out.Bodies {
		if b.Moons != nil {
			written += len(*b.Moons)
		}
	}
	if written != len(nodes) {
		return nil, 0, fmt.Errorf("wrote %d of %d bodies: %d went missing between the rail and "+
			"the output", written, len(nodes), len(nodes)-written)
	}

	return out, dropped, nil
}

// resolveStars decides which of a system's stars is the primary, which is the
// companion, and how the two are drawn. All three results are empty for a system
// upstream files no star for.
//
// The shape is DERIVED, from parent_id, because upstream describes two different
// objects under one word and the map has to say which it is:
//
//   - Where one star is parented to the other — Tyrol B to Tyrol A, Kyuk'ya B to
//     Kyuk'ya A — it genuinely orbits the primary, and both systems put every
//     planet under the primary too. That is a hierarchy, and it nests.
//   - Where neither is parented — Bacchus, Baker, Goss — nothing in the data
//     makes either the centre, and upstream puts both at the same distance from
//     the barycentre (Bacchus A and B are both 0.0735). That is a pair, and the
//     planets orbit both.
//
// Drawing the second the way the first is drawn would invent a hierarchy the
// data denies, so the two shapes are the honest reading rather than a special
// case for five systems.
//
// The system's own upstream `type` is deliberately not consulted. It says
// "BINARY" for Bacchus, Baker, Goss and Kyuk'ya — and "SINGLE_STAR" for Tyrol,
// which has two. Counting the stars is the only reliable answer.
func resolveStars(stars []*node) (primary, companion *node, shape string, err error) {
	switch len(stars) {
	case 0:
		// Min. It carries a rogue gas giant and four moons, so the rail is still
		// worth drawing; it simply has no head. Refusing to build would make it
		// unrenderable for a fact about upstream's data rather than about the map.
		//
		// Tamsa files no STAR either and does not reach here: buildSystem refuses
		// it, because upstream files a head for it typed BLACKHOLE and a rail with
		// that dropped is head-less by omission rather than by nature. This branch
		// is for a system that genuinely has no head, not for one whose head the
		// vocabulary cannot name.
		return nil, nil, "", nil
	case 1:
		return stars[0], nil, "", nil
	case 2:
	default:
		keys := make([]string, 0, len(stars))
		for _, s := range stars {
			keys = append(keys, s.key)
		}
		return nil, nil, "", fmt.Errorf("has %d stars (%s); the rail draws one or two, and no "+
			"system upstream has ever had a third", len(stars), strings.Join(keys, ", "))
	}

	a, b := stars[0], stars[1]
	aOrbitsB := a.obj.ParentID != nil && *a.obj.ParentID == b.obj.ID
	bOrbitsA := b.obj.ParentID != nil && *b.obj.ParentID == a.obj.ID
	switch {
	case aOrbitsB && bOrbitsA:
		return nil, nil, "", fmt.Errorf("stars %q and %q are each parented to the other, so "+
			"neither can be the primary", a.key, b.key)
	case aOrbitsB:
		return b, a, shapeNested, nil
	case bOrbitsA:
		return a, b, shapeNested, nil
	}

	// Neither orbits the other, so neither dominates — unless one of them is
	// parented to something else entirely, which would be a third arrangement
	// nobody has looked at. Upstream leaves both parent_ids null in all three
	// co-orbiting systems.
	for _, s := range []*node{a, b} {
		if s.obj.ParentID != nil {
			return nil, nil, "", fmt.Errorf("star %q is parented to upstream id %d, which is not "+
				"the system's other star; the map has no shape for that", s.key, *s.obj.ParentID)
		}
	}

	// A pair has no primary, so file order is the designation's: "Bacchus A"
	// before "Bacchus B". It decides only which of the two is written first and
	// therefore drawn on the left — the rail treats them as equals either way.
	if b.key < a.key || (b.key == a.key && b.order < a.order) {
		a, b = b, a
	}
	return a, b, shapePaired, nil
}

// indexByOverlayKey settles how the overlay addresses each body, and reports the
// alternatives for any key that names more than one.
//
// Upstream leaves plenty of bodies unnamed, so the designation stands in — and
// two bodies can then land on the same key. Ellis has exactly that: an unnamed
// asteroid cluster and an unnamed protoplanet, both designated "Ellis XI". Left
// alone they render as two identical discs linking to one article, and no
// correction can reach either, because a key that names two bodies is ambiguous.
//
// Promoting both to the type-qualified form — "Ellis XI (PLANET)" — gives the
// overlay a handle on each without changing what either is labelled. It is a
// data fix rather than a code fix, which is the promise the design makes about
// rolling out a new system.
func indexByOverlayKey(nodes []*node) (map[string]*node, map[string][]string, error) {
	plain := map[string][]*node{}
	for _, n := range nodes {
		plain[n.key] = append(plain[n.key], n)
	}

	byKey := make(map[string]*node, len(nodes))
	shared := map[string][]string{}
	for _, n := range nodes {
		if len(plain[n.key]) > 1 {
			n.overlayKey = qualifiedKey(n.key, n.obj)
			shared[n.key] = append(shared[n.key], n.overlayKey)
		}
		if prev, seen := byKey[n.overlayKey]; seen {
			// Two bodies of the same upstream type sharing a key. Nothing in the
			// data separates them, so there is no handle to invent: upstream has
			// to name one, or the overlay has to exclude one. No system upstream
			// is in this state today.
			return nil, nil, fmt.Errorf("has two bodies both keyed %q as %s (upstream ids %d and "+
				"%d), and names neither, so the overlay cannot tell them apart",
				n.key, n.obj.Type, prev.obj.ID, n.obj.ID)
		}
		byKey[n.overlayKey] = n
	}
	return byKey, shared, nil
}

// qualifiedKey is the disambiguated form of a body key: the key plus the
// upstream type, which is what separates two bodies upstream has left unnamed.
func qualifiedKey(key string, obj *starmap.Object) string {
	return key + " (" + obj.Type + ")"
}

// unresolvedKey says why an overlay key reached no body, as a clause an error
// can finish a sentence with. There are two reasons and they want different
// advice: the key is absent, or it is ambiguous — in which case the error names
// the forms that do resolve, so an editor is told the fix and not just the fault.
func unresolvedKey(key string, shared map[string][]string) string {
	alts := shared[key]
	if len(alts) == 0 {
		return fmt.Sprintf("%q, which is not a body in this system "+
			"(it may have been renamed upstream, excluded, or misspelled here)", key)
	}
	quoted := make([]string, 0, len(alts))
	for _, a := range alts {
		quoted = append(quoted, fmt.Sprintf("%q", a))
	}
	return fmt.Sprintf("%q, which names %d bodies in this system: address one of %s",
		key, len(alts), strings.Join(quoted, " or "))
}

// moonParent resolves which planet a body hangs under, or nil if it stays on the
// planet rail.
//
// The overlay wins, then upstream's parent_id. A satellite whose parent is not a
// body on this rail — Odin's Gainey, which upstream parents to the star — stays
// on the rail rather than being dropped or forced under an unrelated planet.
func moonParent(n *node, byKey map[string]*node, shared map[string][]string, byID map[int]*node) (*node, error) {
	if target := n.correction.MoonOf; target != "" {
		parent, ok := byKey[target]
		if !ok {
			return nil, fmt.Errorf("overlay makes %q a moon of %s",
				n.overlayKey, unresolvedKey(target, shared))
		}
		return parent, nil
	}
	if isRing(n.obj) {
		// A ring is only kept when buildSystem has already established that its
		// upstream parent is a planet in this system, so the only way to reach
		// this and find nothing is that the overlay excluded that planet — which
		// leaves the ring orbiting a body the map does not draw. Saying so is the
		// point: silently rendering it loose on the planet rail would put a ring
		// where a world belongs.
		var parent *node
		if n.obj.ParentID != nil {
			parent = byID[*n.obj.ParentID]
		}
		if parent == nil {
			return nil, fmt.Errorf("%q is a ring of a body that is not in the output; "+
				"exclude the ring too, or keep its planet", n.overlayKey)
		}
		return parent, nil
	}
	if n.obj.Type != typeMoon || n.obj.ParentID == nil {
		return nil, nil
	}
	parent, ok := byID[*n.obj.ParentID]
	if !ok || parent.obj.Type != typePlanet {
		return nil, nil
	}
	return parent, nil
}

// arrange puts the planet rail in orbital order.
//
// Numbered bodies sort by their Roman numeral. Everything else is placed
// relative to a body that is already there, via the overlay's `after`; a body
// with neither a numeral nor an `after` lands at the end, in upstream order,
// which is visible in the output and easy to correct.
func arrange(nodes []*node) ([]*node, error) {
	var numbered, floating []*node
	anchored := map[string][]*node{}

	for _, n := range nodes {
		if after := n.correction.After; after != "" {
			anchored[after] = append(anchored[after], n)
			continue
		}
		if _, ok := orbitalIndex(designationOf(n)); ok {
			numbered = append(numbered, n)
			continue
		}
		floating = append(floating, n)
	}

	sort.SliceStable(numbered, func(a, b int) bool {
		ia, _ := orbitalIndex(designationOf(numbered[a]))
		ib, _ := orbitalIndex(designationOf(numbered[b]))
		if ia != ib {
			return ia < ib
		}
		return numbered[a].order < numbered[b].order
	})
	for anchor := range anchored {
		group := anchored[anchor]
		sort.SliceStable(group, func(a, b int) bool { return group[a].overlayOrder < group[b].overlayOrder })
	}

	out := make([]*node, 0, len(nodes))
	placed := map[*node]bool{}
	var place func(n *node)
	place = func(n *node) {
		if placed[n] {
			return
		}
		placed[n] = true
		out = append(out, n)
		for _, dependent := range anchored[n.overlayKey] {
			place(dependent)
		}
	}
	for _, n := range numbered {
		place(n)
	}
	for _, n := range floating {
		place(n)
	}

	if len(out) != len(nodes) {
		for _, group := range anchored {
			for _, n := range group {
				if !placed[n] {
					return nil, fmt.Errorf("overlay places %q after %q, which is not on the planet rail "+
						"(it may be a moon, or the two may be waiting on each other)",
						n.overlayKey, n.correction.After)
				}
			}
		}
		return nil, fmt.Errorf("placed %d of %d bodies", len(out), len(nodes))
	}
	return out, nil
}

// sortMoons orders moons by their lettered designation: 5a, 5b, 5c. A moon
// without one is a reparented planet (Pyro IV), which keeps a planet's
// designation and so goes last.
//
// The designation is normalised first: upstream writes "Pyro 5a", and it is the
// part after the system name that carries the ordering.
//
// Rings sort ahead of every moon. The column means distance from the planet —
// that is what the letters encode — and a ring is inside its planet's moons in
// all five cases here and in every ring system anybody has looked at. Letting a
// ring fall to the end with the other undesignated bodies would put it where
// Pyro IV goes, which is the outermost position, and claim the opposite.
func sortMoons(moons []*node, system string) {
	// The same two steps buildBody applies, so the string sorted on is the string
	// written out. Sorting one string and storing another is how the two quietly
	// come apart later.
	key := func(n *node) (int, string, bool) {
		return moonIndex(normaliseDesignation(designationOf(n), system))
	}
	sort.SliceStable(moons, func(a, b int) bool {
		if ra, rb := isRing(moons[a].obj), isRing(moons[b].obj); ra != rb {
			return ra
		}
		na, la, oka := key(moons[a])
		nb, lb, okb := key(moons[b])
		if oka != okb {
			return oka
		}
		if !oka {
			return moons[a].order < moons[b].order
		}
		if na != nb {
			return na < nb
		}
		if la != lb {
			return la < lb
		}
		return moons[a].order < moons[b].order
	})
}

// buildBody renders one node.
func buildBody(n *node, r role, system string) (Body, error) {
	// Whether upstream names a body at all is what separates a label that is a
	// proper noun from one that merely restates the designation, and those two
	// want opposite treatment from the house-style rule below.
	_, named := upstreamName(n.obj)

	label := n.key
	switch {
	case n.correction.Label != "":
		// An overlay label is judgement, and is stored exactly as written.
		label = n.correction.Label
	case r == roleBelt && !named:
		// House style reaches the label and, through it, the page — but only for
		// a belt upstream leaves unnamed, because for those the label IS the
		// designation. Leaving it in upstream's case would store the same string
		// twice in two different cases, so the rail would stack "Bacchus belt
		// alpha" under "Bacchus Belt Alpha", and would point `page` at a title
		// the wiki is turning into a redirect as those articles move to sentence
		// case.
		//
		// A belt upstream DID name — Aaron Halo, Keeger Belt, Glaciem Ring,
		// Marisol Belt, Henge Cluster, Akiro Cluster — keeps that name verbatim.
		// It is a proper noun, not a description: lower-casing it would look
		// wrong and would red-link the article. Every belt in the five systems
		// shipped so far is one of those, which is why this rule changes nothing
		// already published.
		label = beltCase(label, system)
	}

	body := Body{
		Page:      ucfirst(label),
		Label:     label,
		Icon:      n.correction.Icon,
		IconRatio: n.correction.IconRatio,
	}
	if r == roleStar && n.soleStar {
		// The convention is "<System> (star)", which holds for Stanton, Pyro,
		// Nyx and Castra. Terra breaks it — its star is Terra Nova — and is an
		// overlay entry rather than a derivation, because deriving from the
		// upstream name would disagree with the four systems whose star has no
		// name at all.
		//
		// It holds only where there IS one star. The convention exists to
		// disambiguate a star whose designation is just the system name, and a
		// binary's stars are designated apart already: the articles are "Tyrol
		// A" and "Tyrol B", and "Tyrol (star)" does not exist. So a star sharing
		// its system with another keeps its own key as its title, the way every
		// other body does. Checked against the wiki for all ten stars of the
		// five binaries.
		body.Page = system + " (star)"
	}
	if n.correction.Page != "" {
		body.Page = n.correction.Page
	}

	if r != roleStar {
		designation := designationOf(n)
		if r == roleBelt {
			// House style: the system name keeps its capitals, the rest of the
			// designation does not. Belts only — a planet's "Stanton IV" is a
			// numbered orbital slot, not a description, and a ring's designation
			// names the planet it circles.
			//
			// Applied BEFORE the prefix is stripped, because the rule is defined
			// against the designation as upstream writes it, prefix included. It
			// makes no difference to any belt designated "<System> Belt Alpha" —
			// stripping only fires when a digit follows the system name — and it
			// is what keeps Taranis' "Taranis 2a Debris" reading as "2a debris"
			// rather than stacking a capitalised "2a Debris" under the label
			// "Taranis 2a debris" the same rule already produced.
			designation = beltCase(designation, system)
		}
		body.Designation = normaliseDesignation(designation, system)
	}
	switch r {
	case roleBelt:
		body.Tier = tierBelt
	case roleRing:
		body.Tier = tierRing
	case roleRailMoon:
		// The one top-level body that is not a planet by omission. Without the
		// marker Data.lua infers "planet" from the position, and measures, colours
		// and counts it as one.
		body.Tier = tierMoon
	}

	switch n.obj.Type {
	case typeStar:
		kind, err := starSubtype(subtypeName(n.obj))
		if err != nil {
			return Body{}, fmt.Errorf("%s: %w", n.overlayKey, err)
		}
		body.Subtype = kind.display
		body.Class = kind.class
	case typePlanet:
		// Only planets and stars carry a subtype. "Planetary Moon" and
		// "System Belt" restate the tier, which the model already encodes.
		subtype, err := planetSubtype(subtypeName(n.obj))
		if err != nil {
			return Body{}, fmt.Errorf("%s: %w", n.overlayKey, err)
		}
		body.Subtype = subtype
	}

	// A belt and a ring are both regions rather than bodies: neither has a
	// diameter to scale, and both render at a fixed size. The test is on the ROLE
	// and not on what sizeKM would return, so that a ring can never widen the moon
	// tier's extents and resize the moons on a published page — upstream reports
	// 0 or null for all eleven today, but "the field happens to be empty" is not
	// the reason a ring has no size.
	if r != roleBelt && r != roleRing {
		body.KM = sizeKM(n.obj.Type, sizeOf(n.obj))
	}
	if n.correction.KM != nil {
		km := *n.correction.KM
		body.KM = &km
	}

	return body, nil
}

// bodyKey is a body's identity to the overlay and its default label: the
// upstream name, or the designation when there is no name.
func bodyKey(obj *starmap.Object) string {
	if name, ok := upstreamName(obj); ok {
		return name
	}
	if obj.Designation != nil {
		return strings.TrimSpace(*obj.Designation)
	}
	return ""
}

// upstreamName is the name upstream gives a body, trimmed, and whether it gives
// one at all. Plenty of bodies have none: 59 of its 80 belts, plus Pyro I,
// Delamar, and all 93 stars but Terra Nova. Of those 59 belts, 48 across 30
// systems reach the output; the other 11 are unnamed planetary rings, dropped
// before this is consulted.
//
// It is one function rather than two identical tests on purpose. bodyKey falls
// back to the designation exactly when this reports false, and buildBody is
// entitled to sentence-case a belt's label exactly when that fallback happened —
// so if the two ever disagreed about what "unnamed" means, the generator would
// either recase a proper noun or leave a designation in upstream's case.
func upstreamName(obj *starmap.Object) (string, bool) {
	if obj.Name == nil {
		return "", false
	}
	name := strings.TrimSpace(*obj.Name)
	return name, name != ""
}

func plural(n int, one, many string) string {
	if n == 1 {
		return fmt.Sprintf("%d %s", n, one)
	}
	return fmt.Sprintf("%d %s", n, many)
}

func designationOf(n *node) string {
	if n.obj.Designation == nil {
		return ""
	}
	return *n.obj.Designation
}

func subtypeName(obj *starmap.Object) string {
	if obj.Subtype == nil {
		return ""
	}
	return obj.Subtype.Name
}

func sizeOf(obj *starmap.Object) *float64 {
	if obj.Size == nil {
		return nil
	}
	v := float64(*obj.Size)
	return &v
}
