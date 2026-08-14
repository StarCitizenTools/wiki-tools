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
	"`bodies` is everything orbiting the star, IN ORBITAL ORDER, planets and asteroid belts together. There is no sort " +
	"key: position is the array index. Planet order comes from the Roman numeral in the upstream designation, because " +
	"upstream has no orbit_period for 195 of its 326 planets; a body with no numeral (every belt, and Delamar) is " +
	"placed by the overlay's `after`. A belt is marked `tier: belt`; anything unmarked is a planet. Belts carry no " +
	"`km`, because upstream reports 0/null and a belt has no meaningful diameter, so they render as a fixed band " +
	"rather than a scaled disc. `km` is a diameter for planets and moons but a RADIUS for stars: upstream states " +
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
	// Bodies counts everything written, stars and moons included.
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
)

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
		res.Bodies += 1 + len(sys.Bodies)
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
			"dropped %s: unnamed planetary rings, and anything matching an exclusion pattern",
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
		star    *node
		nodes   []*node
		dropped int
	)
	byID := map[int]*node{}

	for i, obj := range objects {
		switch obj.Type {
		case typeStar, typePlanet, typeMoon, typeBelt, typeCluster:
		default:
			continue // jump points, landing zones, stations: not on the rail
		}

		// Unnamed planetary rings. All eleven upstream are unnamed, including
		// the one a reader might look for (Ring of Yela), and none has an
		// article: there is nothing to link, so there is nothing to render.
		if subtypeName(obj) == "Planetary Ring" && (obj.Name == nil || strings.TrimSpace(*obj.Name) == "") {
			dropped++
			continue
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
			if star != nil {
				// Upstream has 93 stars across 90 systems. The rail draws one,
				// so a binary needs a decision about what the second one is
				// before its system can ship.
				return nil, 0, fmt.Errorf("has more than one star (%s, %s); the rail renders one",
					star.key, n.key)
			}
			n.correction = corrections.Star
			star = n
			byID[obj.ID] = n
			continue
		}

		nodes = append(nodes, n)
		byID[obj.ID] = n
	}

	if star == nil {
		return nil, 0, fmt.Errorf("has no star")
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
	out.Star, err = buildBody(star, roleStar, name)
	if err != nil {
		return nil, 0, err
	}
	for _, n := range ordered {
		r := rolePlanet
		if n.obj.Type == typeBelt || n.obj.Type == typeCluster {
			r = roleBelt
		}
		body, err := buildBody(n, r, name)
		if err != nil {
			return nil, 0, err
		}
		if r == rolePlanet {
			sortMoons(n.moons, name)
			moons := make([]Body, 0, len(n.moons))
			for _, m := range n.moons {
				moon, err := buildBody(m, roleMoon, name)
				if err != nil {
					return nil, 0, err
				}
				moons = append(moons, moon)
			}
			body.Moons = &moons
		} else if len(n.moons) > 0 {
			return nil, 0, fmt.Errorf("overlay makes %q a moon of %q, which is a belt",
				n.moons[0].overlayKey, n.overlayKey)
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
func sortMoons(moons []*node, system string) {
	sort.SliceStable(moons, func(a, b int) bool {
		na, la, oka := moonIndex(normaliseDesignation(designationOf(moons[a]), system))
		nb, lb, okb := moonIndex(normaliseDesignation(designationOf(moons[b]), system))
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
	label := n.key
	if n.correction.Label != "" {
		label = n.correction.Label
	}

	body := Body{
		Page:      ucfirst(label),
		Label:     label,
		Icon:      n.correction.Icon,
		IconRatio: n.correction.IconRatio,
	}
	if r == roleStar {
		// The convention is "<System> (star)", which holds for Stanton, Pyro,
		// Nyx and Castra. Terra breaks it — its star is Terra Nova — and is an
		// overlay entry rather than a derivation, because deriving from the
		// upstream name would disagree with the four systems whose star has no
		// name at all.
		body.Page = system + " (star)"
	}
	if n.correction.Page != "" {
		body.Page = n.correction.Page
	}

	if r != roleStar {
		body.Designation = normaliseDesignation(designationOf(n), system)
	}
	if r == roleBelt {
		body.Tier = tierBelt
		// House style: the system name keeps its capitals, the rest of the
		// designation does not. Belts only — a planet's "Stanton IV" is a
		// numbered orbital slot, not a description.
		body.Designation = beltCase(body.Designation, system)
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

	if r != roleBelt {
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
	if obj.Name != nil {
		if name := strings.TrimSpace(*obj.Name); name != "" {
			return name
		}
	}
	if obj.Designation != nil {
		return strings.TrimSpace(*obj.Designation)
	}
	return ""
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
