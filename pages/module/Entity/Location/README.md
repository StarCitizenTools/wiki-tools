# Module:Entity/Location

Location kind: entities backed by the game-data `/api/locations` endpoint (star systems, jump points). Two leaves render it, StarSystem and JumpPoint; every other location type stays unclaimed until a leaf exists for it.

Editors never invoke this module directly; it runs inside [Template:Location](https://starcitizen.tools/Template:Location), which declares the kind, or inside [Template:Entity](https://starcitizen.tools/Template:Entity) when the page's uuid resolves to a location record the kind claims; the pipeline and the hook table are on [Module:Entity](https://starcitizen.tools/Module:Entity).

## For module editors

### API

- `p.name = 'Location'`: canonical kind name, exposed as `Data.get().result.kind`.
- `p.editorialMode = true`: a kind-declared page (`{{Location}}` injects `|kind=Location`) with no genuine record renders through the editorial fork, the entry path for lore systems that exist only in the starmap.
- `p.defaultFamily = 'starsystem'`: the leaf a kind-declared page with no typed record resolves to.
- `p.matches(apiData) → boolean`: true for a location signature (`respawn_location_type`) and a record one of the leaves renders: SolarSystem records, and jump-point gates. The locations API types jump-point gates as `Anomaly`, a token it shares with non-gate records (wreck sites), so the type alone can't dispatch; a gate is recognised by its name instead, an exact `Jump Point` suffix (every record but one) or an exact `Jump Point ` prefix (the one upstream misnaming, a real Pyro gate). A handful of Stanton-side gates are typed `JumpPoint` outright and match on the type token alone, with no name check.
- `p.resolveSubtype(apiData, args) → module|nil`: a typed record decides alone (its family token, or nil for a record no leaf models; a wreck site is never rescued by a declared kind or `|family=`). With no typed record, a curated `|family=` names the leaf when it maps one of the two tokens; otherwise a kind-declared page falls back to `p.defaultFamily`, and an undeclared page resolves nothing.
- `p.getApiConfigs() → EntityApiConfig[]`: the `locations/%s` identity endpoint.
- `p.getEditorialManifest() → table`: the three kind-level Lore fields every leaf renders, `discoveredin`, `discoveredby`, `historicalnames`.
- **StarSystem** (`p.family = 'starsystem'`): `enrich` bridges to the starmap by name through `locationUtil.attachStarsystem`, attaching the record as `apiData.starsystem`. `getTypeInfo` reads the system-type code from `|systemtype=`/`|type=` (the legacy arg name) through `Editorial.rawArg`, ahead of editorial resolution. Contributes its own editorial manifest fragment (size, population, star types, affiliation, system type, the object-count overrides) and `getCategories` (the system-type and affiliation trees).
- **JumpPoint** (`p.family = 'jumppoint'`): `enrich` bridges to the starmap by the editor-supplied `|starmapcode=`/`|code=` through `locationUtil.attachCelestialObject`, attaching the record as `apiData.celestialobject`. `getCategories` files the gate under its entry system's category (`<System> system`), a functional membership `{{System navplate}}` depends on, not just browse taxonomy. Also contributes the Starmap footer button and the entry/destination systems, derived off the page's own canonical name first, the starmap designation as fallback.

### Extending

A third leaf: `pages/module/Entity/Location/<Name>.lua` with `p.parent = 'Entity/Location'` and `p.family` (the token `resolveSubtype` dispatches on, and the value editors write to `|family=`). Add one `token = 'Entity/Location/<Name>'` entry to `LOCATION_SUBTYPE_MAP` in `Location.lua`, and teach `recordFamily` to return that token for the records the new leaf should claim, the one function `matches()` and `resolveSubtype()` both go through, so a typed record must decide there, not in the leaf. `Module:Entity/Location/testcases`'s `testSubtypeLeavesConformToChainLinkContract` iterates every entry in the map and validates it against [Module:Entity/Contract](https://starcitizen.tools/Module:Entity/Contract)'s `CHAIN_LINK` spec in strict mode, so a new leaf is covered automatically once it's in the map, no new test to write.

### Gotchas

- A record-less lore system (a kind-declared page with no uuid, or a uuid that never resolves) renders through the editorial fork: `apiData` resets to `{}` and the chain reruns `enrich` from `args` alone, which is how a starmap-only system still gets its `attachStarsystem` bridge.
- The StarSystem and JumpPoint enrich bridges are mutually exclusive by construction: a location record is either SolarSystem-typed or Anomaly-typed, never both, so a page never carries both `apiData.starsystem` and `apiData.celestialobject`.
- `attachStarsystem` attaches the starmap record namespaced as `apiData.starsystem`, never flat-merged into `apiData`: the two payloads carry colliding `name`/`type`/`description`/`affiliation` keys.
- The `Jump Point` name anchors `isJumpPointRecord` matches on are case-sensitive and untrimmed on purpose: the API emits the title-case form with no trailing whitespace on every observed record, and normalising the check would loosen the gate beyond what the data actually shows.
