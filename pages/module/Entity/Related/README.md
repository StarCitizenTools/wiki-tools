# Module:Entity/Related

Renders an entity's related entries: for items, set components and cosmetic variants as image tiles; for vehicles with an editorial series, the other vehicles in that series; for commodities, cargo-box packaging sizes as a table.

Editors use this through `{{Entity/Related}}`; see [Template:Entity/Related](https://starcitizen.tools/Template:Entity/Related).

## For module editors

### Hook

Draws `getRelated`, resolved leaf-first, skipping a `nil` answer (see the Hooks table on [Module:Entity](https://starcitizen.tools/Module:Entity)). Payload (`EntityRelatedPayload` in [Module:Entity/Types](https://starcitizen.tools/Module:Entity/Types)):

- `items`: Base's default, `{ items = ctx.apiData.related_items }` (`set_items` / `base_item` / `variant_items`); inherited by every kind that doesn't override it. Rendered as tiles, resolved to wiki pages + `Page Image` through [Module:Entity/PageResolver](https://starcitizen.tools/Module:Entity/PageResolver)'s two batched asks, one per uuid property (shared with UsedBy and Ports).
- `cargo`: `{ scu, mass_kg }[]` ascending by SCU, returned only by Commodity, in place of `items`. Rendered as a sortable table instead of tiles, since cargo boxes share one image and have no pages of their own.
- `vehicleSeries`: the page's `series` name, returned only by Vehicle. It is the editorial `series` argument, read back from [Module:Entity/Store](https://starcitizen.tools/Module:Entity/Store) when the invocation carries none, so `{{Entity/Related}}` needs no argument on a vehicle page (the Bucket read shows the empty state until the page's first link update has run). Once resolved, this module queries Store again for every other vehicle page sharing it (gravlevs included: the series filter alone selects vehicle rows, no category is consulted), and renders as 16:9 tiles in a wider column than the item grid's portrait ones, since vehicle promo shots are landscape and vehicle names are long, the current page's tile flagged `selected`. Vehicle returns `nil` (not this field) when neither source has a series, which falls through to Base's `items` instead of showing nothing.

### Extending

A kind with a different "related" concept returns `items` (same shape as `apiData.related_items`), `cargo` (the packaging-table shape), or `vehicleSeries` (a Bucket-backed name to query). There's no fourth payload shape: a genuinely different concept needs a code change here, not just a new field.

### Gotchas

- Cargo-box external dimensions are not read from the API: `BOX_DIMENSIONS` is an in-module constant for the standard CIG container line (1/8 through 32 SCU); a non-standard size gets `-` cells.
- The variant grid drops `base_item` only when its uuid matches the current page, the one self-reference case the API exposes; `set_items` needs no such filter.
- A variant's size/grade caption appears only when that dimension actually varies across the family (`variantDimensionDiffers`); a uniform family gets no caption.
- A set item's tile label is its API name, unchanged; `resolveTypeName` only maps the item's API `type` to the small kicker caption above it, via [Module:Entity/Item/types.json](https://starcitizen.tools/Module:Entity/Item/types.json), falling through to the raw type string when unmapped.
- A series of exactly one page (the vehicle itself, nothing else queried) renders the empty state, same as no `related_items`; the Store query failing (rate limit, bad manifest) does too, contained in a `pcall`.
