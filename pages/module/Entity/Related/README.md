# Module:Entity/Related

Renders an entity's related entries: for items, set components and cosmetic variants as image tiles; for commodities, cargo-box packaging sizes as a table.

Editors use this through `{{Entity/Related}}`; see [Template:Entity/Related](https://starcitizen.tools/Template:Entity/Related).

## For module editors

### Hook

Draws `getRelated`, resolved leaf-first (see the Hooks table on [Module:Entity](https://starcitizen.tools/Module:Entity)). Payload (`EntityRelatedPayload` in [Module:Entity/Types](https://starcitizen.tools/Module:Entity/Types)):

- `items`: Base's default, `{ items = ctx.apiData.related_items }` (`set_items` / `base_item` / `variant_items`); inherited by every kind that doesn't override it. Rendered as tiles, resolved to wiki pages + `Page Image` through [Module:Entity/PageResolver](https://starcitizen.tools/Module:Entity/PageResolver)'s two batched asks, one per uuid property (shared with UsedBy and Ports).
- `cargo`: `{ scu, mass_kg }[]` ascending by SCU, returned only by Commodity, in place of `items`. Rendered as a sortable table instead of tiles, since cargo boxes share one image and have no pages of their own.

### Extending

A kind with a different "related" concept returns either `items` (same shape as `apiData.related_items`) or `cargo` (the packaging-table shape). There's no third payload shape: a genuinely different concept needs a code change here, not just a new field.

### Gotchas

- Cargo-box external dimensions are not read from the API: `BOX_DIMENSIONS` is an in-module constant for the standard CIG container line (1/8 through 32 SCU); a non-standard size gets `-` cells.
- The variant grid drops `base_item` only when its uuid matches the current page, the one self-reference case the API exposes; `set_items` needs no such filter.
- A variant's size/grade caption appears only when that dimension actually varies across the family (`variantDimensionDiffers`); a uniform family gets no caption.
- A set item's tile label is its API name, unchanged; `resolveTypeName` only maps the item's API `type` to the small kicker caption above it, via [Module:Entity/Item/types.json](https://starcitizen.tools/Module:Entity/Item/types.json), falling through to the raw type string when unmapped.
