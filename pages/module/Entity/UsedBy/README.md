# Module:Entity/UsedBy

Renders the vehicles that have this item installed in their loadout, as a grid of image tiles. Inverse of [Module:Entity/Related](https://starcitizen.tools/Module:Entity/Related): Related shows an item's own variants, UsedBy shows the vehicles that equip it.

Editors use this through `{{Entity/UsedBy}}`; see [Template:Entity/UsedBy](https://starcitizen.tools/Template:Entity/UsedBy). The pipeline and the hook table are on [Module:Entity](https://starcitizen.tools/Module:Entity).

## For module editors

### Hook

Unlike the other four sibling renderers, UsedBy consumes no Entity hook: it reads `result.apiData.vehicles` directly, an include only the items endpoint returns (wired by [Module:Entity/Item](https://starcitizen.tools/Module:Entity/Item)'s `getApiConfigs`). Non-item entities carry no `vehicles` key, so `buildRows` returns an empty list and the empty state renders. Row shape per vehicle: `name`, `role`, `manufacturer.code`, `uuid`; sort key is `manufacturer.code .. '|' .. name`, so same-brand vehicles cluster.

### Extending

There's no hook to extend: to surface a "used by" concept for another kind, wire an equivalent API include onto that kind's `getApiConfigs` and read the field here directly.

### Gotchas

- `manufacturer` can be a table or absent depending on API vintage; a missing one sorts to the front with an empty-string code rather than erroring.
- Link and image resolution go through the same shared [Module:Entity/PageResolver](https://starcitizen.tools/Module:Entity/PageResolver) as Related and Ports; a UUID with no matching mainspace page falls back to the API name plus Tiles' placeholder image.
- The tile grid uses a 200px minimum width, wider than Tiles' default, so 16:9 vehicle hero shots stay tall enough for the name overlay to read.
