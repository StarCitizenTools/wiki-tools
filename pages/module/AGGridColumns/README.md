# Module:AGGridColumns

A shared, registry-based column-type library for [AG Grid](https://www.ag-grid.com/) grids on the Star Citizen Wiki (via [Extension:AGGrid](https://www.mediawiki.org/wiki/Extension:AGGrid)). It turns a list of declarative **column specs** into AG Grid `columnDefs` + `rowData`, dispatching per-column to a registry of **kinds**.

Consumers (Module:DataGrid for `{{Data table}}`, Module:PledgeVehicleGrid) build their own column specs, fetch via `mw.smw.ask`, assemble `gridOptions`, and call `render` — this library owns only the column building.

## Kinds

| kind | JS type | cell value | used by |
|---|---|---|---|
| `image` | `aggridImage` | linked thumbnail | *(spare — generic thumbnail column)* |
| `link` | `aggridLink` | linked page | DataGrid page-link columns |
| `linkList` | `aggridLinkList` | list of links | pledge loaner |
| `valueList` | `aggridLinkList` | list of plain-text tags and/or links (set filter splits per value) | DataGrid multi-valued columns |
| `text` | *(none)* | plain text | pledge text columns |
| `smart` | `scwSmart` | numeric-aware text | DataGrid plain columns |
| `number` | `numericColumn` | real number + Intl format | pledge stats |
| `card` | `scwEntityCard` | thumb + eyebrow + title | pledge vehicle, DataGrid lead |
| `stackedValue` | `scwStackedValue` | primary over muted secondary | pledge prices |
| `badge` | `scwBadge` | BadgeLua-style pill | pledge production state |

## API

- `buildColumnDefs(specs)` → AG Grid `columnDefs` (one per spec).
- `buildRowData(results, specs)` → AG Grid `rowData` (one row per `mw.smw.ask` result).

Each kind module (`Kind/X`) exposes `p.type` (the JS column type string, or `false`), `p.buildColDef(spec)`, and `p.buildCellValue(spec, result)`.

## Adding a kind

1. Author `Module:AGGridColumns/Kind/<Name>` with `type` + `buildColDef` + `buildCellValue` (satisfying `Module:AGGridColumns/Contract`).
2. Add one line to `Module:AGGridColumns/Registry`.
3. For an `scw*` type, register the paired renderer in `MediaWiki:Gadget-aggridRenderers.js` via `ext.aggrid.register`.

`Module:AGGridColumns/testcases` loops the registry through the contract, so a kind missing a half fails a unit test.

## Architecture

```
AGGridColumns.lua   buildColumnDefs / buildRowData (generic loops)
Registry.lua        kind name -> module
Contract.lua        COLUMN_KIND + validate
Util/Util.lua       SMW decoders (decodeScalar/toText/toNumber/parseLink/buildThumb/
                    buildLinkList/buildValueList/classifyColumn/cloneFormat)
Kind/*.lua          one module per kind
```
