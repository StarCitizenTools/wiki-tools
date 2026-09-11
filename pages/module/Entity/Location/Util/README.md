# Module:Entity/Location/Util

Location-internal shared helpers used by more than one Location leaf: the starmap vocabulary (affiliation and system-type tables with their resolvers), the system-name helpers, and the two starmap bridges the leaves' `enrich` hooks call. Not cross-kind (see [Module:Entity/Facet/Util](https://starcitizen.tools/Module:Entity/Facet/Util)) and not kind identity (see [Module:Entity/Location](https://starcitizen.tools/Module:Entity/Location)).

Editors never invoke this module directly; it runs inside [Template:Location](https://starcitizen.tools/Template:Location); the two leaves that call it are on [Module:Entity/Location](https://starcitizen.tools/Module:Entity/Location).

## For module editors

### API

- `p.AFFILIATIONS`: starmap affiliation code (lowercased) → `{ label, short }`. `short` (falling back to `label`) is the compact form stored as the SMW `Affiliation` value, matching the vocabulary the pre-Entity pages already store (`UEE`, `Unclaimed`).
- `p.affiliationEntry(starsystem) → { label, short }|nil`: the starmap record's first affiliation entry.
- `p.affiliationFromText(text) → { label, short?, display? }|nil`: editorial affiliation text matched against `AFFILIATIONS` on code, label or short after normalising case and punctuation; anything unmatched passes through as free text (`label` delinked for storage/categories, `display` keeps the editor's markup so they choose whether it links).
- `p.SYSTEM_TYPES`: starmap system-type code → `{ label, category }`.
- `p.systemTypeEntry(text) → code, entry`: editorial system-type text normalised (case, separators) and looked up in `SYSTEM_TYPES`; unrecognised text resolves to nothing rather than inventing a row.
- `p.systemShortName(name) → string|nil`: a system name reduced to its bare form (trailing `System`/`system` stripped, an alias parenthetical and the Vanduul catalogue form removed).
- `p.entrySystem(apiData) → string|nil`: `apiData.system` (a plain string on the live API) reduced through `systemShortName`.
- `p.gateEntrySystem(apiData) → string|nil`: the location record's system when one exists, else the entry-first side of the celestial designation; lets a record-less `|family=jumppoint` page still know its system.
- `p.resolveSystemType(starsystem, resolved) → code, entry`: the editorial value wins over the starmap record's; an unmapped record code still returns, so it stores faithfully.
- `p.resolveAffiliation(starsystem, resolved) → entry|nil`: the same editorial-first precedence as `resolveSystemType`.
- `p.attachStarsystem(apiData, args) → apiData`: bridges by name to `/api/starsystems`, attaching the picked and normalised record as `apiData.starsystem`. Soft-fails: an error or empty result leaves the record absent.
- `p.attachCelestialObject(apiData, code) → apiData`: bridges by the editor-supplied starmap code to `/api/celestial-objects/<code>`, attaching the record as `apiData.celestialobject`. No code, no fetch; soft-fails the same way.

### Gotchas

- `attachStarsystem`'s `locale` rides the endpoint string (`...&locale=en_EN`), not `params`: Apiunto appends `params` as a second `?query`, which would corrupt the `?filter[...]` the endpoint already carries. `attachCelestialObject`'s endpoint carries no query string of its own, so its `locale` rides `params` safely.
- `normalizeAggregates` drops the ARK's withheld-survey stub (the twelve Vanduul systems' identical population/economy/size block, and the incomplete-probe systems' zero block) whenever a record has no catalogued bodies and an unpublished status (`M`/`N`); neither test alone is safe, since `size <= 0` misses stubs reporting 1 or 7 AU and "no bodies" alone would strip the genuinely-published Gurzil. A zero size is dropped regardless of status.
- `pickStarsystem` resolves a `filter[name]` substring-match result list by precedence: an exact name match, then the Xi'an `<name> (<alias>)` form, then the first row.
- `systemShortName` strips the Vanduul catalogue form (`VS-9 "Vulture"` becomes `Vulture`) and an alias parenthetical (`Kyuk'ya (Indra)` becomes `Kyuk'ya`) before the ` System` suffix; neither decoration is a wiki page name, so leaving one in would render a red link and file a bogus category.
