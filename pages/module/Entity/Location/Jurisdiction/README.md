# Module:Entity/Location/Jurisdiction

Resolves which jurisdiction a location falls under and links it to where its laws are described. Used by the Location leaves; editors never invoke it.

## For module editors

### API

Place and Body walk the record's parent chain through it; JumpPoint, Star and StarSystem link their own record's jurisdiction through `display` alone, with no walk.

- `walk(record, fetch) → string|nil`: the record's own `jurisdiction.name`, else the first ancestor's, climbing `parent.uuid` through `fetch` for up to `MAX_HOPS` (5) hops.
- `resolve(record) → string|nil`: `walk` over the live `locations/%s` endpoint (`p.fetch`).
- `display(name) → string|nil`: a wikilink to `<Faction>#Jurisdiction`; `JURISDICTIONS` overrides the target for an API name whose wiki page title differs from the name (`UEE`, `microTech`, `ArcCorp`, `Rough & Ready`, `Citizens For Prosperity`) or whose resolved page carries no "Jurisdiction" section at all, linking the bare page instead (`Rough & Ready`, `Citizens For Prosperity`, `Headhunters`, `XenoThreat`, `Klescher Rehabilitation`, `Green Imperial`/`Green`, `Ungoverned`).

### Gotchas

- The walk follows the API parent chain, never a page's curated `|parent=`. A Lagrange station's game parent is the star, so it takes the system's jurisdiction, not the planet's.
- Some jurisdictions are defined as zones the parent tree does not capture. Grim HEX inherits Crusader Industries by the tree but is Green Imperial; such pages set `|jurisdiction=`.
- A curated `|jurisdiction=` override is not inherited by children that have their own record: their walk follows the API parents regardless. A child with no record of its own reads the override through its curated parent's stored `Jurisdiction` value instead.
- `p.fetch` is a module field so a suite can replace it. It reuses [Module:Entity/Location](https://starcitizen.tools/Module:Entity/Location)'s own `locations/%s` endpoint config, so each ancestor fetch shares the [Apiunto](https://www.mediawiki.org/wiki/Extension:Apiunto) cache entry of that ancestor's own page.
