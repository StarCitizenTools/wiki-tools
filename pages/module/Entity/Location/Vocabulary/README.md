# Module:Entity/Location/Vocabulary

The RSI starmap's vocabularies as the wiki names them: affiliations and system, star, body and asteroid-formation types, each with the label, index page and category the wiki uses, and the resolvers that map a starmap value or an editor's wording onto an entry.

Editors never invoke this module directly; it runs inside [Template:Location](https://starcitizen.tools/Template:Location), which declares the kind, or inside [Template:Entity](https://starcitizen.tools/Template:Entity) when the probe claims a location record; the leaves that call it are on [Module:Entity/Location](https://starcitizen.tools/Module:Entity/Location). [Module:SystemMap](https://starcitizen.tools/Module:SystemMap) reads `affiliationEntry` for its header.

## For module editors

### API

- `p.AFFILIATIONS`: starmap affiliation code (lowercased) → `{ label, short }`. `short` (falling back to `label`) is the compact form stored as the `Affiliation` value, matching the vocabulary the pre-Entity pages already store (`UEE`, `Unclaimed`).
- `p.affiliationEntry(starsystem) → { label, short }|nil`: the starmap record's first affiliation entry.
- `p.affiliationFromText(text) → { label, short?, display? }|nil`: editorial affiliation text matched against `AFFILIATIONS` on code, label or short after normalising case and punctuation; anything unmatched passes through as free text (`label` delinked for storage/categories, `display` keeps the editor's markup so they choose whether it links).
- `p.STAR_TYPES`: starmap star `sub_type.name` → `{ classification, label?, category, page?, maxRadiusKm? }`. `classification` doubles as the index page title. `maxRadiusKm` is a physical ceiling used to reject a starmap size the class cannot have.
- `p.starTypeEntry(subType) → entry|nil`, `p.starTypeLabel(entry) → string|nil`, `p.starTypeFromText(text) → entry|nil`, `p.starTypeLink(entry, text) → string`: the star vocabulary's lookups. `starTypeFromText` matches an editor's wording against the classification or the short label; `starTypeLink` links the entry's index page while displaying the caller's text.
- `p.BODY_TYPES`: starmap planet `sub_type.name` → `{ classification, category }`, the planet counterpart. Moons carry one uniform sub_type and so have no entry.
- `p.BELT_TYPES`: starmap `sub_type.name` → `{ classification, category, page }` for asteroid belts, clusters and planetary rings. Every entry names `page` because the family has one concept page rather than per-type index pages, so without it the subtitle would link at nothing.
- `p.beltTypeEntry(subType, objectType) → entry|nil`: the formation vocabulary keyed on a starmap object's `sub_type`, falling back to its bare `type` token only when the sub_type is absent or blank, which is how the three ARK belts that carry no sub_type still resolve. A sub_type the vocabulary does not map returns nil rather than falling through.
- `p.beltTypeFromText(text) → entry|nil`: the same vocabulary from an editor's wording, matching the same three forms the body one accepts.
- `p.bodyTypeEntry(subType) → entry|nil`, `p.bodyTypeFromText(text) → entry|nil`: the body vocabulary's lookups. `bodyTypeFromText` matches the wiki classification, the ARK's spelling and the singular of the category name, because the corpus writes several classes in the category's wording.
- `p.SYSTEM_TYPES`: starmap system-type code → `{ label, category }`.
- `p.systemTypeEntry(text) → code, entry`: editorial system-type text normalised (case, separators) and looked up in `SYSTEM_TYPES`; unrecognised text resolves to nothing rather than inventing a row.
- `p.resolveSystemType(starsystem, resolved) → code, entry`: the editorial value wins over the starmap record's; an unmapped record code still returns, so it stores faithfully.
- `p.resolveAffiliation(starsystem, resolved) → entry|nil`: the same editorial-first precedence as `resolveSystemType`. For DISPLAY: it keeps an editor's markup whole.
- `p.storedAffiliation(starsystem, resolved) → string|nil`: the compact token to store, from the first `<br>`-delimited segment only. A page may name two affiliations in one arg against a single-valued column, and `toStoredValue` strips the tag with no separator, so the raw value would store as the unqueryable `VanduulIndependent`.
