# Module:Entity/Related

Renders an entity's "related entries"; what counts as related depends on the entity kind. A sibling renderer parallel to [Module:Entity/Availability](https://starcitizen.tools/Module:Entity/Availability) and [Module:Entity/Description](https://starcitizen.tools/Module:Entity/Description), it consumes [Module:Entity/Data](https://starcitizen.tools/Module:Entity/Data) so it shares Apiunto's cache with the Entity infobox and any other Entity-family template on the page.

`p.main` dispatches on `result.kind`, giving two distinct render paths:

- **Items**: set components (helmet/torso/legs etc.) and cosmetic variants, rendered as image tile grids via [Module:Tiles](https://starcitizen.tools/Module:Tiles). Reads `apiData.related_items` (only the items endpoint provides it).
- **Commodities**: the physical cargo-box packaging variants (the SCU ladder), rendered as a sortable table inside a [Module:CollapsibleCard](https://starcitizen.tools/Module:CollapsibleCard). These "related entities" all share one image and have no pages of their own, so tiles don't fit.

The container always renders. Non-supported kinds, API failures, and entities with nothing to show (no set pieces or variants; no cargo box sizes) all fall back to a muted empty-state placeholder so the page layout stays stable.

## Usage

Invoked through [Template:Entity/Related](https://starcitizen.tools/Template:Entity/Related), not called directly from other Lua:

```wikitext
{{Entity/Related|uuid=80ee3b95-5665-4548-9e2d-d2067895c0ac}}
```

The `uuid` parameter falls back to the SMW UUID set by `Template:Entity` on a prior parse, so on a typical entity page you invoke it bare:

```wikitext
{{Entity}}

== Related ==
{{Entity/Related}}
```

## API

### `p.main( frame )`

Entry point invoked from `Template:Entity/Related`. Resolves args and fetches the merged Apiunto response via `Module:Entity/Data`, then dispatches:

1. **API error** (`result.hasApiError`) → empty-state placeholder.
2. **`result.kind == 'Commodity'`** → `renderCargoVariants` (cargo-box table, see the "Data: commodities" section).
3. **Otherwise (items)** → resolves the UUID, reads `apiData.related_items`, batches a single SMW lookup through [Module:Entity/PageResolver](https://starcitizen.tools/Module:Entity/PageResolver) to map each item to its canonical wiki page and `Page Image`, and renders up to two tile grids via `Module:Tiles`: **Set pieces** then **Variants**. The tile grids use a `3 / 4` aspect ratio because Star Citizen item renders are typically portrait product shots.

Falls back to the muted empty-state placeholder ("No related items available from the API.") when the entity is a non-supported kind, has no `related_items`/box sizes, or both render buckets come back empty.

## Data: items

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
| `variant_items` | Cosmetic or specification variants of the base item. Rendered in API order, with `variant_name` as the primary label, falling back to `name` when the API doesn't expose a separate variant name. Tiles also surface size and grade as a small caption above the name when those dimensions vary across the family: size uses the SC-native shorthand (`S1`, `S2`, …) and grade stays long-form (`Grade A`, `Grade B`). If everything is the same, no caption. |

Display names for set-item types come from [Module:Entity/Item/types.json](https://starcitizen.tools/Module:Entity/Item/types.json) (keyed by the API type string). Unmapped types fall through to the raw API string so new types are still discoverable on-page.

### Page and image resolution

Page titles and images are resolved through the shared [Module:Entity/PageResolver](https://starcitizen.tools/Module:Entity/PageResolver). `PageResolver.resolve(uuids)` returns a `uuid → { page, image }` map from batched `mw.smw.ask` queries (one per UUID property). This module just collects the unique UUIDs across both buckets and hands them over; the resolver owns the SMW mechanics (mainspace/non-subobject filtering, the 5× limit over-fetch, and the dual read across the canonical lowercase `uuid` and legacy capitalized `UUID` properties). Because it's shared by **Entity/Related, Entity/UsedBy and Entity/Ports**, changing how related links resolve means editing `PageResolver.lua` once, and that change ripples to all three consumers. It is also the single seam to swap when SMW is replaced.

Resolving by UUID rather than API name decouples the link target from the label: a disambiguated page title like `Hyperion (quantum drive)` links correctly while the tile label keeps the friendly API name `Hyperion`. Items whose UUID matches no mainspace page (never rendered with `Template:Entity`, or the property hasn't propagated yet) are absent from the map and fall back to the API name for both link and image, with the Tiles placeholder for the missing image.

## Data: commodities

When `result.kind == 'Commodity'`, `renderCargoVariants` reads the refined record (`apiData._refinedRecord`, falling back to `apiData`) and shapes its cargo-box ladder into a table:

| Field | Description |
|---|---|
| `box_sizes_scu` | Array of SCU box sizes the commodity ships in (e.g. `[1, 2, 4, 8]`). Each becomes one table row, sorted ascending. No box sizes → empty-state placeholder. |
| `density_g_per_cc` | Material density. Mass per box is derived: `mass_kg = scu × density × 1000`. |

External box dimensions are **not** read from the API. They come from `BOX_DIMENSIONS`, an in-module game-constant table mapping each standard SCU size to its `{ length, width, height }` in metres (1/8 through 32 SCU; the standard CIG cargo-container line, identical for every commodity). A non-standard SCU size has no entry, so its dimension cells render as `-`. The 1/8 SCU box (`0.125`) prints as the fraction `1/8`; whole sizes print as their number.

The result is a sortable table with columns **SCU / Length / Width / Height / Mass**, wrapped in a `Module:CollapsibleCard` titled *Cargo variants* with a `"N sizes"` (or `"1 size"`) description. The card and table own their own styling; this module's `styles.css` only covers the empty state.

## CSS hooks

Tile-level classes (`.t-tiles__tile`, `.t-tiles__image`, etc.) live in [Module:Tiles](https://starcitizen.tools/Module:Tiles); the cargo table and its wrapper are styled by [Module:TableLua](https://starcitizen.tools/Module:TableLua) and [Module:CollapsibleCard](https://starcitizen.tools/Module:CollapsibleCard). See those modules' CSS hooks references for those.

This module only ships the empty-state styling:

| Class | Purpose |
|---|---|
| `t-entity-related-empty` | The muted placeholder paragraph rendered in the empty state. |

## Requirements

- [Module:Entity/Data](https://starcitizen.tools/Module:Entity/Data): arg parsing + cached API fetch and kind resolution.
- [Module:Entity/PageResolver](https://starcitizen.tools/Module:Entity/PageResolver): shared UUID → page/image lookup (items path).
- [Module:Tiles](https://starcitizen.tools/Module:Tiles): image-tile grid rendering (items path).
- [Module:TableLua](https://starcitizen.tools/Module:TableLua) + [Module:CollapsibleCard](https://starcitizen.tools/Module:CollapsibleCard): cargo-variants table + card wrapper (commodity path).
- [Module:Entity/Format](https://starcitizen.tools/Module:Entity/Format): `formatNum` for SCU/dimension/mass formatting.

## Testing

The pure cargo helpers are unit-tested off-wiki. `p._internal` exports `buildCargoRows` and `boxDimensions` for `testcases.lua` (mass-from-density, ascending sort, the 1/8 standard box, non-standard-size `nil`). Run via `mise run test`. The items/tiles path and the live SMW lookup are not covered here; verify those in a browser.

## Architecture

```
Entity/Related/
├── Related.lua     # Kind dispatch; items tile-shaping + commodity cargo table
├── styles.css      # Empty-state placeholder styling
└── testcases.lua   # buildCargoRows / boxDimensions unit tests
```

UUID → page/image resolution for the items path lives in the shared `Module:Entity/PageResolver`, not here.
