# Template:Location

Renders a location's infobox through `Module:Entity`, the same engine that powers `{{Entity}}`. Currently covers star systems and jump points: supply the location UUID and the infobox fills itself from the live game data and the RSI starmap — for a star system that means affiliation, jurisdiction, star types, sensor readings, and astronomical object counts; for a jump point (a record the API names `… Jump Point`) it means the entry and destination systems, the parent anchor (star or gateway station), the gate size, and the travel data (arrival/obstruction radii, starmap visibility), with the starmap side keyed by `starmapcode`. Lore systems that exist only in the starmap have no UUID and need no parameters at all — the template looks the starmap record up by the page title. Systems the starmap does not list at all (Hyoton, Krell, …) supply their identity through `affiliation` and `systemtype` instead. The editorial parameters below override a wrong or missing API value with a hand-curated one.

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

| Name | Label | Type | Required | Default | Description | Example |
|------|-------|------|----------|---------|-------------|---------|
| `uuid` | UUID | string | No | (none) | Location UUID from the game data API. Only in-game systems have one; lore systems omit it and the infobox renders from the starmap record plus the parameters below. There is no fallback to a UUID stored on the page: this template declares its kind, which deliberately suppresses that lookup so a stale or placeholder stored UUID cannot resurrect itself. | `c9c137cf-c520-47ee-9e6d-5d653dfbe201` |
| `starmapname` | Starmap name | string | No | (the API record's name, else `name`, else the page title) | Starmap lookup name override — only when neither the page title nor `name` resolves the starmap record. | `Rihlah` |
| `name` | Name | string | No | (page title) | Infobox display title. | `Stanton system` |
| `starmapcode` | Starmap code | string | No | (none) | ARK starmap code of a jump point's celestial object — the `?location=` key on the RSI starmap. Keys the starmap fetch that supplies the destination system and gate size, and feeds the Starmap footer button and the Metadata row. Jump points only; star systems derive their code from the starmap record. `code` works as a legacy alias (the `{{Astronomical object}}` parameter name); `starmapcode` wins when both are set. | `PYRO.JUMPPOINTS.NYX` |
| `image` | Image | wiki-file-name | No |  | Infobox image. | `Stanton 2D.png` |
| `size` | Size | number | No | (starmap aggregated size) | System size in AU, overriding the starmap value. | `9.83` |
| `startypes` | Star types | string | No | (derived from the starmap star list) | Star type display text, overriding the starmap-derived list. | `Flare star` |
| `affiliation` | Affiliation | content | No | (from the starmap record) | Controlling polity, for systems the starmap does not list or gets wrong. Canonical names (`UEE`, `Xi'an Empire`, `Banu Protectorate`, `Unclaimed`, `Vanduul`, `Developing`) render as their standard link; anything else renders exactly as written — link it yourself if a page exists — and feeds the `<affiliation> systems` category and the stored `Affiliation` value as plain text. | `[[Kr'Thak]]` |
| `systemtype` | System type | string | No | (from the starmap record) | Starmap system-type code (`SINGLE_STAR`, `BINARY`, `TRINARY`; case-insensitive), for systems the starmap does not list. Drives the type label, category, and stored `System type`. `type` works as a legacy alias. | `TRINARY` |
| `population` | Population | string | No |  | Population figure or description. | `10 billion` |
| `discoveredin` | Discovered in | content | No |  | Lore year of discovery. Keep citations in the article body. | `[[2851]]` |
| `discoveredby` | Discovered by | content | No |  | Discoverer of the system. Keep citations in the article body. | `[[Toshi Aaron]]` |
| `historicalnames` | Historical names | string | No |  | Former names of the system, comma-separated. | `Cathcart` |
| `galactapediaurl` | Galactapedia URL | url | No |  | Galactapedia article URL, rendered as a footer button. | `https://robertsspaceindustries.com/galactapedia/article/RX3lKBA3dq-stanton-system` |
| `verseguideurl` | VerseGuide URL | url | No |  | VerseGuide location URL, rendered as a footer button after the Starmap one. | `https://verseguide.com/location/STANTON` |
| `planets` | Planets | number | No | (starmap tally) | Hand count of planets, overriding the starmap tally. | `4` |
| `satellites` | Moons | number | No | (starmap tally) | Hand count of moons, overriding the starmap tally. | `12` |
| `asteroidbelts` | Asteroid belts | number | No | (starmap tally) | Hand count of asteroid belts, overriding the starmap tally. | `2` |
| `asteroidfields` | Asteroid fields | number | No | (starmap tally) | Hand count of asteroid fields, overriding the starmap tally. | `1` |
| `anomalies` | Anomalies | number | No | (starmap tally) | Hand count of anomalies, overriding the starmap tally. | `1` |
| `stations` | Stations | number | No | (starmap tally) | Hand count of stations, overriding the starmap tally. | `24` |
| `jumppoints` | Jump points | number | No | (starmap tally) | Hand count of jump points, overriding the starmap tally. | `4` |
| `blackholes` | Black holes | number | No | (starmap tally) | Hand count of black holes, overriding the starmap tally. | `1` |
| `pois` | Points of interest | number | No | (starmap tally) | Hand count of points of interest, overriding the starmap tally. | `3` |

## Behavior

- The infobox, page categories, short description, and SMW properties are all owned by the single invocation, exactly like `{{Entity}}`.
- No parameter is required. With no `uuid`, the page identifies itself by its own title: that is the infobox heading and the starmap lookup key alike.
- The starmap record is fetched by system name; affiliation, jurisdiction, size, star types, sensor readings (economy and population), and object-count tiles come from it. Hand counts beat starmap tallies wherever both exist, in the display and in the stored properties alike.
- A count or size parameter that is not a number ("?", "TBD", "Unknown") is ignored rather than displayed, so a placeholder cannot blank a real starmap value. Leave the parameter out instead; the starmap figure is used.
- The starmap does not publish a survey for every system (the Vanduul systems and those with incomplete probe data). Where it withholds one, the size and the economy/population readings are omitted rather than shown as the placeholder figures the starmap returns.
- The RSI Starmap footer button is generated from the starmap system code (star systems) or from the fetched celestial object's code falling back to `starmapcode` (jump points); the Galactapedia and VerseGuide buttons appear when `galactapediaurl` / `verseguideurl` are supplied.
- A jump point's Distance from star row is omitted when the starmap reports 0 (no measurement), and its Destination row is omitted rather than guessed when the celestial designation names neither side as the entry system.
- Stored property values are sanitized: wiki links are reduced to their display text and reference tags are stripped, so query results stay clean.
