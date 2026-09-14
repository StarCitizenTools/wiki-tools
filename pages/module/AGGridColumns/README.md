# Module:AGGridColumns

A shared, registry-based column-type library for [AG Grid](https://www.ag-grid.com/) (via [Extension:AGGrid](https://www.mediawiki.org/wiki/Extension:AGGrid)). Turns declarative column specs into AG Grid `columnDefs` + `rowData`, dispatching per column to a kind; the consumer owns the fetch, query, `gridOptions`, and render.

Required by [Module:DataGrid](https://starcitizen.tools/Module:DataGrid) and [Module:PledgeVehicleGrid](https://starcitizen.tools/Module:PledgeVehicleGrid); not invoked from templates.

## For module editors

### API

- `buildColumnDefs(specs)` → AG Grid `columnDefs`, one per spec.
- `buildRowData(results, specs)` → AG Grid `rowData`, one row per result the consumer fetched (a `Module:Entity/Store` row, for both current consumers).
- Each kind (`Module:AGGridColumns/Kind/<Name>`) exposes `p.type` (the JS colDef `type` string, or `false` for a type-less column), `p.buildColDef(spec)`, and `p.buildCellValue(spec, result)`, registered by name in [Module:AGGridColumns/Registry](https://starcitizen.tools/Module:AGGridColumns/Registry). [Module:AGGridColumns/Contract](https://starcitizen.tools/Module:AGGridColumns/Contract) validates the shape; `testcases` loops every kind through it, so a kind missing a piece fails a unit test, not a render.

Kinds, per [Module:AGGridColumns/Registry](https://starcitizen.tools/Module:AGGridColumns/Registry):

| kind | JS type | cell value | used by |
|---|---|---|---|
| `image` | `aggridImage` | linked thumbnail | none currently (spare) |
| `link` | `aggridLink` | linked page | DataGrid, PAGE-typed columns |
| `linkList` | `aggridLinkList` | list of links | PledgeVehicleGrid loaner |
| `valueList` | `aggridLinkList` | list of plain-text tags and/or links; an item wrapping one link links as a whole (set filter splits per value) | DataGrid, repeated TEXT columns |
| `text` | *(none)* | plain text | PledgeVehicleGrid text columns |
| `date` | *(none)* | ISO date string (`cellDataType: 'dateString'`) | PledgeVehicleGrid concept date |
| `smart` | `scwSmart` | numeric-aware text | DataGrid, TEXT columns |
| `number` | `numericColumn` | real number + Intl format | PledgeVehicleGrid stats |
| `card` | `scwEntityCard` | thumb + eyebrow + title | PledgeVehicleGrid vehicle card, DataGrid lead |
| `stackedValue` | `scwStackedValue` | primary over muted secondary | PledgeVehicleGrid prices |
| `badge` | `scwBadge` | BadgeLua-style pill | PledgeVehicleGrid production state |
| `badgeList` | `scwBadgeList` | multi-value badge list, via a consumer-supplied `classify` function | DataGrid `kind=effect` ([Module:DietaryEffect](https://starcitizen.tools/Module:DietaryEffect)'s `gridClassify`) |
| `boolean` | `scwBoolean` | icon-only tri-state yes/no/unknown, via a hardcoded (not consumer-supplied) [Module:Boolean](https://starcitizen.tools/Module:Boolean)`.gridClassify` call | DataGrid `kind=boolean` |
| `signedBar` | `scwSignedBar` | signed value drawn as a bar from a centre line, scaled to a column-wide `max` | DataGrid `kind=bar` |

Adding a kind: author `Kind/<Name>` satisfying the contract, add one line to `Registry`, and for an `scw*` type register the paired renderer in `MediaWiki:Gadget-aggridRenderers.js` via `ext.aggrid.register`.

### Gotchas

- `buildColumnDefs`/`buildRowData` raise a hard Lua error for a `kind` not in the registry; there is no silent fallback column.
- Stored-value decoding (`decodeScalar`, `toText`, `toNumber`, `parseLink`, `pageTarget`, `buildThumb`, `buildLinkList`, `buildValueList`, `cloneFormat`) lives in [Module:AGGridColumns/Util](https://starcitizen.tools/Module:AGGridColumns/Util), shared by every kind and by consumers directly.
- `Kind/Date`'s `cellDataType` is declared, not inferred: AG Grid reads `rowData[0][field]` alone to infer a column's data type, so a first row with a missing or non-ISO value would otherwise silently drop the date filter's comparator.
- `Kind/SignedBar`'s `good` is read against the value's sign, not a fixed polarity: 0 or a spec with no `good` leaves the cell's `good` field absent (neutral), distinct from `false` (leans the wrong way).
