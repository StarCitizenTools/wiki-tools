# Template:Location

Renders a star system or jump point infobox through the same `Module:Entity` engine as `{{Entity}}`, with the editing form scoped to location parameters. Place it at the top of a system or jump-point page in place of `{{Entity}}`.

## Usage

Lore star system, no UUID: the starmap record is found by the page title.

```wikitext
{{Location}}
```

Same, on a page whose title does not match the starmap name (`starmapname` overrides the lookup; `name` only sets the infobox title):

```wikitext
{{Location
| name        = Rihlah system
| starmapname = Rihlah
}}
```

In-game star system, everything from the API:

```wikitext
{{Location|uuid=17092f34-d9c8-4d50-89f6-a92940b9cd52}}
```

System the starmap does not list: identity comes from the editorial parameters.

```wikitext
{{Location
| name        = Krell system
| affiliation = [[Kr'Thak]]
| planets     = 9
| discoveredin = 2530 (after, known)
}}
```

In-game jump point: the location record supplies the entry system, parent anchor, jurisdiction, and travel data; `starmapcode` keys the starmap celestial object that supplies the destination, the gate size, and the Starmap footer button.

```wikitext
{{Location
| uuid        = 80bac534-3e84-4a2d-97c2-3edefa2d5bef
| name        = Pyro - Nyx jump point
| starmapcode = PYRO.JUMPPOINTS.NYX
}}
```

Starmap-only jump point (no location record exists): `family` names the leaf and `starmapcode` supplies everything renderable.

```wikitext
{{Location
| name        = Stanton - Magnus jump point
| family      = jumppoint
| starmapcode = STANTON.JUMPPOINTS.MAGNUS
}}
```

Star system with curated overrides and lore fields (the discovery citation belongs in the article body, not the parameter):

```wikitext
{{Location
| uuid            = c9c137cf-c520-47ee-9e6d-5d653dfbe201
| name            = Stanton system
| image           = Stanton 2D.png
| stations        = 24
| discoveredin    = [[2851]]
| discoveredby    = [[Toshi Aaron]]
| galactapediaurl = https://robertsspaceindustries.com/galactapedia/article/RX3lKBA3dq-stanton-system
}}
```

## Parameters

| Name | Label | Type | Required | Default | Description | Example | Aliases |
|------|-------|------|----------|---------|-------------|---------|---------|
| `uuid` | UUID | string | No | (none) | Location UUID from the game data API. Only in-game systems have one; lore systems omit it and the infobox renders from the starmap record plus the parameters below. There is no fallback to a UUID stored on the page: this template declares its kind, which deliberately suppresses that lookup so a stale or placeholder stored UUID cannot resurrect itself. | `c9c137cf-c520-47ee-9e6d-5d653dfbe201` |  |
| `starmapname` | Starmap name | string | No | (the API record's name, else `name`, else the page title) | Starmap lookup name override, used only when neither the page title nor `name` resolves the starmap record. | `Rihlah` |  |
| `name` | Name | string | No | (page title) | Infobox display title. | `Stanton system` |  |
| `family` | Family | string | No | (none) | Leaf selector for a page with no location record: `jumppoint` renders the jump-point infobox from the starmap celestial object alone (the starmap-only tunnels, e.g. Stanton - Magnus); `place` renders a station, outpost, landing zone or venue from the parameters alone. Ignored when a genuine record resolves. | `jumppoint` |  |
| `classification` | Classification | string | No | (none) | A class from the closed vocabulary in Module:Entity/Location/Place/classes.json, naming what a place is rather than where it sits. Missing or unrecognised text renders the generic Location type and files the page in `Locations with an unknown classification`. | `Landing zone` |  |
| `parent` | Parent | content | No | (the record's own parent) | The page a place is on, in or near, a plain title or a `[[wikilink]]`; a piped link shows its own text, otherwise the target with a trailing qualifier such as "(planet)" dropped. Wins over the record's own parent, which the API gets wrong for Lagrange stations (parented to the star, not the point). | `[[Yela]]` |  |
| `lagrange` | Lagrange point | string | No | (none) | A Lagrange point of `parent`: `L1` to `L5`, case-insensitive, stored upper-case; any other value is dropped rather than shown or stored. Forces `zone` to `lagrange`. A valid point given without a curated `parent` still applies, but files the page in `Locations with an invalid zone or Lagrange point`, since a Lagrange point is a point of a body. | `L1` |  |
| `zone` | Zone | string | No | (the record, else the class's own default) | Where the place sits: `surface`, `orbit`, `lagrange`, `inside` or `star`. Wins over the record, which can be wrong (the API parents Levski to the star, Nyx, though it sits on Delamar), but loses to a valid `lagrange`. A value outside the vocabulary is dropped and files the page in `Locations with an invalid zone or Lagrange point`. | `orbit` |  |
| `operator` | Operator | content | No | (none) | The company or faction running the place, the same `[[wikilink]]` shape as `parent`. A raw value that already opens with a wikilink renders exactly as written, so a trailing `<ref>` survives after the link; the stored value and category still use the parsed target. | `[[Hurston Dynamics]]` |  |
| `jurisdiction` | Jurisdiction | string | No | (resolved from the record's parent chain) | Override for a zone-defined jurisdiction the parent chain misses (or, for a page with no record, the curated `parent` page's own stored jurisdiction). Displayed linked to where that law is described. | `Rough & Ready` |  |
| `system` | System | string | No | (the record's own system) | The star system the place is in, short form (`Stanton`); used when the place has no game record, and ignored in favour of the record's system when it has one. | `Stanton` |  |
| `founder` | Founder | content | No |  | Founder of the place. Keep citations in the article body. | `[[Magda Hurston]]` |  |
| `founded` | Founded | content | No |  | Lore year the place was founded. Keep citations in the article body. | `{{SDA\|2912\|sctime=yes}}` |  |
| `starmapcode` | Starmap code | string | No | (none) | ARK starmap code of a jump point's celestial object, a star, or a place, the `?location=` key on the RSI starmap. Star systems derive their code from the starmap record instead; wins over the legacy alias when both are set. | `PYRO.JUMPPOINTS.NYX` | `code` |
| `image` | Image | wiki-file-name | No |  | Infobox image. | `Stanton 2D.png` |  |
| `size` | Size | number | No | (starmap aggregated size) | System size in AU, overriding the starmap value. | `9.83` |  |
| `startypes` | Star types | string | No | (derived from the starmap star list) | Star type display text, overriding the starmap-derived list. | `Flare star` |  |
| `affiliation` | Affiliation | content | No | (from the starmap record) | Controlling polity, for systems the starmap does not list or gets wrong. Canonical names (`UEE`, `Xi'an Empire`, `Banu Protectorate`, `Unclaimed`, `Vanduul`, `Developing`) render as their standard link; anything else renders exactly as written (link it yourself if a page exists). | `[[Kr'Thak]]` |  |
| `systemtype` | System type | string | No | (from the starmap record) | Starmap system-type code (`SINGLE_STAR`, `BINARY`, `TRINARY`; case-insensitive), for systems the starmap does not list. Drives the type label, category, and stored `System type`. | `TRINARY` | `type` |
| `population` | Population | string | No |  | Population figure or description, for a system or a place. | `10 billion` |  |
| `discoveredin` | Discovered in | content | No |  | Lore year of discovery. Keep citations in the article body. | `[[2851]]` |  |
| `discoveredby` | Discovered by | content | No |  | Discoverer of the system. Keep citations in the article body. | `[[Toshi Aaron]]` |  |
| `historicalnames` | Historical names | string | No |  | Former names of the system, comma-separated. | `Cathcart` |  |
| `galactapediaurl` | Galactapedia URL | url | No |  | Galactapedia article URL, rendered as a footer button. | `https://robertsspaceindustries.com/galactapedia/article/RX3lKBA3dq-stanton-system` |  |
| `verseguideurl` | VerseGuide URL | url | No |  | VerseGuide location URL, rendered as a footer button after the Starmap one. | `https://verseguide.com/location/STANTON` |  |
| `planets` | Planets | number | No | (starmap tally) | Hand count of planets, overriding the starmap tally. | `4` |  |
| `satellites` | Moons | number | No | (starmap tally) | Hand count of moons, overriding the starmap tally. | `12` |  |
| `asteroidbelts` | Asteroid belts | number | No | (starmap tally) | Hand count of asteroid belts, overriding the starmap tally. | `2` |  |
| `asteroidfields` | Asteroid fields | number | No | (starmap tally) | Hand count of asteroid fields, overriding the starmap tally. | `1` |  |
| `anomalies` | Anomalies | number | No | (starmap tally) | Hand count of anomalies, overriding the starmap tally. | `1` |  |
| `stations` | Stations | number | No | (starmap tally) | Hand count of stations, overriding the starmap tally. | `24` |  |
| `jumppoints` | Jump points | number | No | (starmap tally) | Hand count of jump points, overriding the starmap tally. | `4` |  |
| `blackholes` | Black holes | number | No | (starmap tally) | Hand count of black holes, overriding the starmap tally. | `1` |  |
| `pois` | Points of interest | number | No | (starmap tally) | Hand count of points of interest, overriding the starmap tally. | `3` |  |

## Behavior

- The infobox, page categories, short description, and stored properties are all owned by the single invocation, exactly like `{{Entity}}`.
- No parameter is required. With no `uuid`, the page identifies itself by its own title: that is the infobox heading and the starmap lookup key alike, so a bare `{{Location}}` never hits the "no uuid, name, or kind" error.
- A `uuid` that is supplied but doesn't resolve to a genuine record is not treated as a lore system either: it adds the page to `Pages with an unresolved entity reference` instead of silently rendering one.
- The starmap record is fetched by system name; affiliation, jurisdiction, size, star types, sensor readings (economy and population), and object-count tiles come from it. Hand counts beat starmap tallies wherever both exist, in the display and in the stored properties alike.
- A count or size parameter that is not a number ("?", "TBD", "Unknown") is ignored rather than displayed, so a placeholder cannot blank a real starmap value. Leave the parameter out instead; the starmap figure is used.
- The starmap does not publish a survey for every system (the Vanduul systems and those with incomplete probe data). Where it withholds one, the size and the economy/population readings are omitted rather than shown as the placeholder figures the starmap returns.
- The RSI Starmap footer button is generated from the starmap system code (star systems) or from the fetched celestial object's code falling back to `starmapcode` (jump points); the Galactapedia and VerseGuide buttons appear when `galactapediaurl` / `verseguideurl` are supplied.
- A jump point's Destination row is omitted rather than guessed when the celestial designation names neither side as the entry system.
- `affiliation` feeds a `<value> systems` browse category directly from whatever text is written: a canonical name (`UEE`, `Xi'an Empire`, ...) normalizes to its standard entry, but anything else is used verbatim, so a typo or inconsistent spelling files the page under its own new category instead of the intended one.
- Stored property values are sanitized: wiki links are reduced to their display text and reference tags are stripped, so query results stay clean.

## See also

- [Template:Entity](https://starcitizen.tools/Template:Entity), the generic entry point into the same module; used directly for items, commodities, and missions.
- [Template:Vehicle](https://starcitizen.tools/Template:Vehicle), the sibling kind-scoped facade for ships and ground vehicles.
- [Module:Entity/Location](https://starcitizen.tools/Module:Entity/Location), the implementation.
