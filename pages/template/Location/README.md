# Template:Location

Renders a location's infobox through Module:Entity, the same engine that powers Template:Entity. Currently covers in-game star systems: supply the location UUID and the infobox fills itself from the live game data and the RSI starmap, including affiliation, jurisdiction, star types, sensor readings, and astronomical object counts. The editorial parameters below override a wrong or missing API value with a hand-curated one.

## Usage

In-game star system, everything from the API:

```wikitext
{{Location|uuid=17092f34-d9c8-4d50-89f6-a92940b9cd52}}
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
| `uuid` | UUID | string | No | (falls back to the UUID stored on the page) | Location UUID from the game data API. Only in-game systems have one; lore systems omit it. | `c9c137cf-c520-47ee-9e6d-5d653dfbe201` |
| `starmapname` | Starmap name | string | No | (page title) | Starmap lookup name override — only when the page name does not resolve the starmap record. | `Rihlah` |
| `name` | Name | string | No | (page title) | Infobox display title. | `Stanton system` |
| `image` | Image | wiki-file-name | No |  | Infobox image. | `Stanton 2D.png` |
| `size` | Size | number | No | (starmap aggregated size) | System size in AU, overriding the starmap value. | `9.83` |
| `startypes` | Star types | string | No | (derived from the starmap star list) | Star type display text, overriding the starmap-derived list. | `Flare star` |
| `population` | Population | string | No |  | Population figure or description. | `10 billion` |
| `discoveredin` | Discovered in | content | No |  | Lore year of discovery. Keep citations in the article body. | `[[2851]]` |
| `discoveredby` | Discovered by | content | No |  | Discoverer of the system. Keep citations in the article body. | `[[Toshi Aaron]]` |
| `historicalnames` | Historical names | string | No |  | Former names of the system, comma-separated. | `Cathcart` |
| `galactapediaurl` | Galactapedia URL | url | No |  | Galactapedia article URL, rendered as a footer button. | `https://robertsspaceindustries.com/galactapedia/article/RX3lKBA3dq-stanton-system` |
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

- The infobox, page categories, short description, and SMW properties are all owned by the single invocation, exactly like Template:Entity.
- The starmap record is fetched by system name; affiliation, jurisdiction, size, star types, sensor readings (economy and population), and object-count tiles come from it. Hand counts beat starmap tallies wherever both exist, in the display and in the stored properties alike.
- The RSI Starmap footer button is generated from the starmap system code; the Galactapedia button appears when `galactapediaurl` is supplied.
- Stored property values are sanitized: wiki links are reduced to their display text and reference tags are stripped, so query results stay clean.
