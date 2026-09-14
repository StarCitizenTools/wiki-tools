# Module:Entity/Orders

Renders a Mission page's hauling-contract order table: a totals row (unique items, total units, total SCU) followed by one row per requested cargo line.

Editors use this through `{{Entity/Orders}}`; see [Template:Entity/Orders](https://starcitizen.tools/Template:Entity/Orders). The `Orders` property is written separately, by `{{Entity}}` from the Mission kind's own structured data.

## For module editors

### API

`p.main(frame)` reads `apiData.hauling_orders` via `Module:Entity/Data` and renders the totals row and the per-order table. `formatQuantity` and `cargoLabel` live in [Module:Entity/Orders/Lines](https://starcitizen.tools/Module:Entity/Orders/Lines), shared with `Module:Entity/Mission.getStructuredData` so the visible columns and the stored `Orders` property use the same quantity string and cargo label for a given order.

### Gotchas

- `formatSize` stays local to this module: it drives the visible "Size" column only and has no structured-data counterpart.
