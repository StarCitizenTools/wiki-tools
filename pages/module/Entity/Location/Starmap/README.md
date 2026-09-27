# Module:Entity/Location/Starmap

The ARK starmap records a Location leaf reads: the two bridges its `enrich` hook calls, lookups inside an attached system payload, and the system names and starmap code a page resolves to.

Editors never invoke this module directly; it runs inside [Template:Location](https://starcitizen.tools/Template:Location), which declares the kind, or inside [Template:Entity](https://starcitizen.tools/Template:Entity) when the probe claims a location record; the leaves that call it are on [Module:Entity/Location](https://starcitizen.tools/Module:Entity/Location).

## For module editors

### API

- `p.systemShortName(name) → string|nil`: a system name reduced to its bare form (trailing `System`/`system` stripped, an alias parenthetical and the Vanduul catalogue form removed).
- `p.entrySystem(apiData) → string|nil`: `apiData.system` (a plain string on the live API) reduced through `systemShortName`.
- `p.gateEntrySystem(apiData) → string|nil`: the location record's system when one exists, else the entry-first side of the celestial designation; lets a record-less `|family=jumppoint` page still know its system.
- `p.subjectName(apiData, args) → string|nil`: the name of whatever the page is about: `|starmapname=`, else the location record's own name, else `|name=`, else the page title. It is the starmap lookup key for a system page and the body's own name for a planet or moon, which is why it is public.
- `p.attachStarsystem(apiData, args, name?) → apiData`: bridges by name to `/api/starsystems`, attaching the picked and normalised record as `apiData.starsystem`. The name is `subjectName` unless the caller passes one; a leaf whose subject is NOT the system must pass it, since a body's own name would look up a system that does not exist. Soft-fails: an error or empty result leaves the record absent.
- `p.attachCelestialObject(apiData, code) → apiData`: bridges by the editor-supplied starmap code to `/api/celestial-objects/<code>`, attaching the record as `apiData.celestialobject`. No code, no fetch; soft-fails the same way.
- `p.celestialByCode(starsystem, code) → object|nil`, `p.celestialByName(starsystem, name, types?) → object|nil`: find one object inside an attached system payload. Codes match whole and case-sensitively; a name match should pass `types` (a set of ARK `type` values) because a star carries no `name` and its designation is the system's, so an unrestricted match from a body page can land on the star.
- `p.celestialName(obj) → string|nil`: an object's display name, its own `name` when the ARK gives one, else the designation stripped of decorations. Terra's star is why `name` wins: it is "Terra Nova" against a "Terra" designation. Most objects have no `name`, so the designation path is the common one, and the alias parenthetical is stripped wherever it sits, not only trailing as `systemShortName` does it (the ARK writes `Kyuk'ya (Indra) A`).
- `p.celestialParent(starsystem, obj) → object|nil`: resolves an object's numeric `parent_id` against its own system's object list, which a single-object fetch cannot do. nil for the eleven planets the ARK gives no parent.
- `p.celestialStarmapCode(apiData, fallback) → string|nil`: the code on an attached celestial-object record, else the raw `|starmapcode=` arg, so a page whose fetch failed still gets the button and row keyed by the code the editor supplied.
- `p.starsystemOf(apiData) → table|nil`, `p.manifestArg(args, manifest, key) → string|nil`, `p.systemNameFrom(apiData, args, manifest) → string|nil`, `p.resolvedStarmapCode(args, manifest, obj) → string|nil`: a leaf's own reads before editorial resolution has run. `manifestArg` reads the raw arg through the leaf's own manifest entry, so each leaf keeps its own aliases; `systemNameFrom` prefers the record's system over the arg and never reads the starmap code's first segment, which is not always the system.

### Gotchas

- `attachStarsystem`'s `locale` rides the endpoint string (`...&locale=en_EN`), not `params`: [Apiunto](https://www.mediawiki.org/wiki/Extension:Apiunto) appends `params` as a second `?query`, which would corrupt the `?filter[...]` the endpoint already carries. `attachCelestialObject`'s endpoint carries no query string of its own, so its `locale` rides `params` safely.
- `normalizeAggregates` drops the ARK's withheld-survey stub (the Vanduul systems' identical population/economy/size block, and the incomplete-probe systems' zero block) whenever a record has no catalogued bodies and an unpublished status (`M`/`N`); neither test alone is safe, since `size <= 0` misses stubs reporting 1 or 7 AU and "no bodies" alone would strip the genuinely-published Gurzil. A zero size is dropped regardless of status.
- `pickStarsystem` resolves a `filter[name]` substring-match result list by precedence: an exact name match, then the Xi'an `<name> (<alias>)` form, then the first row.
- `systemShortName` strips decorations in a fixed order: the Vanduul catalogue form (`VS-9 "Vulture"` becomes `Vulture`) first, then the trailing ` System`/`system` suffix, and only then the alias parenthetical (`Yā'mon (Hadur) System` becomes `Yā'mon`). The suffix must strip before the parenthetical: the parenthetical match anchors on the end of the string (`%b()$`), so while the suffix still trails it can't match. Neither decoration is a wiki page name, so leaving one in would render a red link and file a bogus category.
