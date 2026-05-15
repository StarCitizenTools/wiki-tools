# Module:Entity/UsedBy

Renders the list of vehicles that have this item (typically a vehicle component such as a quantum drive, shield generator, or weapon) installed in their loadout. Inverse of [Module:Entity/Related](https://starcitizen.tools/Module:Entity/Related): Related shows variants and set pieces of an item, UsedBy shows the hosts that equip it.

Sibling renderer parallel to [Module:Entity/Related](https://starcitizen.tools/Module:Entity/Related) and [Module:Entity/Description](https://starcitizen.tools/Module:Entity/Description) — consumes [Module:Entity/Data](https://starcitizen.tools/Module:Entity/Data) so it shares Apiunto's cache with the Entity infobox and any other Entity-family template on the page. Tile rendering is delegated to [Module:Tiles](https://starcitizen.tools/Module:Tiles).

Items only today (reads `apiData.vehicles`, populated by the `vehicles` include on the items endpoint via `Module:Entity/Item.getApiConfigs`). Non-item entities, API failures, and items not used by any vehicle all fall back to a muted empty-state placeholder so the page layout stays stable.

## Usage

Invoked through [Template:Entity/UsedBy](https://starcitizen.tools/Template:Entity/UsedBy), not called directly from other Lua:

```wikitext
{{Entity/UsedBy|uuid=08a5bfdb-1972-421f-83fe-be03b7ac5222}}
```

The `uuid` parameter falls back to the SMW UUID set by `Template:Entity` on a prior parse — so on a typical entity page the template is invoked bare:

```wikitext
{{Entity}}

== Used by ==
{{Entity/UsedBy}}
```

## API

### `p.main( frame )`

Entry point invoked from `Template:Entity/UsedBy`.

Resolves the UUID from `frame.args.uuid`, the parent frame, or SMW (in that order), fetches the entity's vehicles list via `Module:Entity/Data`, sorts by manufacturer code then by name, batches a single SMW query to resolve each vehicle's canonical wiki page and `Page Image`, and renders a single tile grid via `Module:Tiles`. The tile grid uses a `16 / 9` aspect ratio because vehicle hero shots are typically landscape.

Falls back to a muted empty-state placeholder ("No vehicles known to use this item.") when the upstream fetch fails, the entity isn't an item, or no vehicle equips it.

## Data

Reads the `vehicles` array off the merged Apiunto response. Shape (per entry):

```json
{
    "uuid": "8b7e0d33-21c1-4057-8e5b-bf391b5091b2",
    "name": "F7A Hornet Mk I",
    "role": "Medium Fighter",
    "size": 2,
    "is_spaceship": true,
    "manufacturer": { "code": "ANVL", "name": "Anvil Aerospace" }
}
```

| Field | Description |
|---|---|
| `name` | Vehicle name; rendered as the tile's primary label. |
| `role` | In-game role (e.g. `Medium Fighter`, `Cargo`); rendered as the small kicker above the name. |
| `manufacturer.code` | Manufacturer code (e.g. `ANVL`); used as the primary sort key so vehicles from the same brand cluster in the grid. Not rendered. |
| `uuid` | Join key for resolving the wiki page through SMW. |

Page titles and images are resolved via a single `mw.smw.ask` query against the `uuid` SMW property (set on render by [Module:Entity/StructuredData](https://starcitizen.tools/Module:Entity/StructuredData)). The query matches both the canonical lowercase `uuid` and the legacy capitalized `UUID` so unmigrated pages still resolve. Results are filtered to mainspace, non-subobject pages so a stray UUID stored as a subobject doesn't redirect the link off the canonical article; the SMW limit is over-fetched 5× to make sure the mainspace hit isn't truncated when a UUID also appears on a subobject. Vehicles whose UUID matches no mainspace page (never rendered with `Template:Entity`, or property hasn't propagated yet) fall back to the API name for both link and image, with the Tiles placeholder for the missing image.

The resolver mirrors [Module:Entity/Related](https://starcitizen.tools/Module:Entity/Related)'s logic; the duplication is deliberate for now and will be extracted into a shared `Module:Entity/PageResolver` once a third sibling needs the same lookup.

## CSS hooks

Tile-level classes (`.t-tiles__tile`, `.t-tiles__image`, etc.) live in [Module:Tiles](https://starcitizen.tools/Module:Tiles) — see that module's CSS hooks reference for skin overrides on the grid itself.

This module only ships the empty-state styling:

| Class | Purpose |
|---|---|
| `t-entity-usedby-empty` | The muted placeholder paragraph rendered in the empty state. |

## Architecture

```
Entity/UsedBy/
├── UsedBy.lua    # Data shaping, SMW resolution, Tiles delegation
└── styles.css    # Empty-state placeholder styling
```
