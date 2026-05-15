# Module:Entity/Related

Renders an entity's related entries as image tile grids: set components first (helmet/torso/legs etc.), then cosmetic variants. Sibling renderer parallel to [Module:Entity/Availability](https://starcitizen.tools/Module:Entity/Availability) and [Module:Entity/Description](https://starcitizen.tools/Module:Entity/Description) — consumes [Module:Entity/Data](https://starcitizen.tools/Module:Entity/Data) so it shares Apiunto's cache with the Entity infobox and any other Entity-family template on the page.

Tile rendering itself is delegated to [Module:Tiles](https://starcitizen.tools/Module:Tiles). This module pulls the related-items data, resolves wiki pages and images via SMW, and shapes rows into the Tiles row schema. Tiles owns the visual treatment (image + label + fakelink), this module owns the data shaping.

Items only today (reads `apiData.related_items`, which only the items endpoint provides). The container always renders — non-item entities, API failures, and items with no set pieces or variants all fall back to a muted empty-state placeholder so the page layout stays stable.

## Usage

Invoked through [Template:Entity/Related](https://starcitizen.tools/Template:Entity/Related), not called directly from other Lua:

```wikitext
{{Entity/Related|uuid=80ee3b95-5665-4548-9e2d-d2067895c0ac}}
```

The `uuid` parameter falls back to the SMW UUID set by `Template:Entity` on a prior parse — so on a typical entity page the template is invoked bare:

```wikitext
{{Entity}}

== Related ==
{{Entity/Related}}
```

## API

### `p.main( frame )`

Entry point invoked from `Template:Entity/Related`.

Resolves the UUID from `frame.args.uuid`, the parent frame, or SMW (in that order), fetches related items via `Module:Entity/Data`, batches a single SMW query to resolve each item's canonical wiki page and `Page Image`, and renders up to two tile grids via `Module:Tiles`: **Set pieces** then **Variants**. The tile grids use a `3 / 4` aspect ratio because Star Citizen item renders are typically portrait product shots.

Falls back to a muted empty-state placeholder ("No related items available from the API.") when the upstream fetch fails, the entity has no `related_items`, or both buckets are empty.

## Data

Reads the `related_items` block from the merged Apiunto response. Shape:

```json
{
    "related_items": {
        "set_items": [
            { "name": "Helmet name", "uuid": "…", "type": "Char_Armor_Helmet" }
        ],
        "base_item": { "name": "Base item name", "uuid": "…", "variant_name": "Default" },
        "variant_items": [
            { "name": "Variant name", "uuid": "…", "variant_name": "Black" }
        ]
    }
}
```

| Field | Description |
|---|---|
| `set_items` | Other items that make up a wearable set. Rendered first, with the resolved type (e.g. `Helmet`) as a small kicker above the name. |
| `base_item` | The canonical base item for a variant family. Rendered at the top of the **Variants** grid. Filtered out when its UUID matches the queried entity (the only self-reference case the API exposes). |
| `variant_items` | Cosmetic or specification variants of the base item. Rendered in API order, with `variant_name` as the primary label — falling back to `name` when the API doesn't expose a separate variant name. Tiles also surface size and grade as a small caption above the name when those dimensions vary across the family (e.g. quantum drives where every variant is size 1 but grades differ → `Grade A`, `Grade B`; if everything is the same, no caption). |

Display names for set-item types come from [Module:Entity/Item/types.json](https://starcitizen.tools/Module:Entity/Item/types.json) (keyed by the API type string). Unmapped types fall through to the raw API string so new types are still discoverable on-page.

Page titles and images are both resolved via a single `mw.smw.ask` query against the `uuid` SMW property (set on render by [Module:Entity/StructuredData](https://starcitizen.tools/Module:Entity/StructuredData)). The query matches both the canonical lowercase `uuid` and the legacy capitalized `UUID` so unmigrated pages still resolve. Results are filtered to mainspace, non-subobject pages so a stray UUID stored as a subobject or in a `User:` test page doesn't redirect the link off the canonical article; the SMW limit is over-fetched 5× to make sure the mainspace hit isn't truncated when a UUID also appears on a subobject. This decouples the link target from the API name — disambiguated page titles like `Hyperion (quantum drive)` link correctly while the tile label keeps the friendly API name `Hyperion`. Items whose UUID matches no mainspace page (never rendered with `Template:Entity`, or property hasn't propagated yet) fall back to the API name for both link and image, with the Tiles placeholder for the missing image.

## CSS hooks

Tile-level classes (`.t-tiles__tile`, `.t-tiles__image`, etc.) live in [Module:Tiles](https://starcitizen.tools/Module:Tiles) — see that module's CSS hooks reference for skin overrides on the grid itself.

This module only ships the empty-state styling:

| Class | Purpose |
|---|---|
| `t-entity-related-empty` | The muted placeholder paragraph rendered in the empty state. |

## Architecture

```
Entity/Related/
├── Related.lua    # Data shaping, SMW resolution, Tiles delegation
└── styles.css     # Empty-state placeholder styling
```
