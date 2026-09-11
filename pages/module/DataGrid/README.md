# Module:DataGrid

Builds an interactive, filterable browse table on [AG Grid](https://www.ag-grid.com/) (via [Extension:AGGrid](https://www.mediawiki.org/wiki/Extension:AGGrid)) for a category, a raw SMW condition, or both: virtualised rows, rich cells, and one `mw.smw.ask` query.

Editors use this through `{{Data table}}`; see [Template:Data table](https://starcitizen.tools/Template:Data_table).

## For module editors

### API

- `p.parseColumns(raw)`: the multi-line `columns` argument into `DataGridColumn[]` (`property`, `label`, `filter`, `eyebrow`, `kind`, `good`, `group`, `prefix`, `suffix`, `suffix1`).
- `p.columnAlias(column)`: a column's SMW alias / result-row key: `label`, else the property name.
- `p.duplicateAlias(columns)`: the first alias colliding with another column or a lead key (`Image`/`Name`), or `nil`.
- `p.buildQuery(category, columns, conditions)`: the `mw.smw.ask` query array: `[[:+]]` plus an optional category condition and the raw `conditions`, then one aliased printout per column.
- `p.main(frame)`: wikitext entry point; reads `category`/`columns`/`conditions`/`pinlead`, runs the query, and returns the rendered grid.

Column classification is data-driven, not user-set: a column whose rows hold several values becomes a multi-value list (`aggridLinkList`); one whose values are `[[:Target|Display]]` wikilinks becomes a page link (`aggridLink`); everything else is plain (the gadget's numeric-aware `scwSmart` type). `kind=effect`/`bar`/`boolean` overrides this with a [Module:DietaryEffect](https://starcitizen.tools/Module:DietaryEffect) badge list, a signed bar, or a [Module:Boolean](https://starcitizen.tools/Module:Boolean) icon; any other `kind` value is silently ignored.

### Gotchas

- `size=` is parsed for backward compatibility only; it has no effect on rendering.
- `kind=bar` scales every cell against its column's largest absolute value across all matching rows, not per cell, so two rows stay visually comparable.
- An `eyebrow` column's set filter (when also `filter`-flagged) keys on that one column's decorated text, not the composed multi-part line; otherwise every row would be its own filter option.
- Full rendering (the lead card, `scwSmart` sort/alignment) depends on the `aggridRenderers` gadget (`MediaWiki:Gadget-aggridRenderers.js`), gated to load on `Category:Pages using AG Grid`; without it AG Grid falls back to its own column defaults.
- The SMW-value decoding helpers (`decodeScalar`, `toText`, `parseLink`, `classifyColumn`) live in [Module:AGGridColumns/Util](https://starcitizen.tools/Module:AGGridColumns/Util), shared with other AG Grid renderers, not in a DataGrid-owned submodule; `buildRowData` and `buildColumnDefs` likewise belong to [Module:AGGridColumns](https://starcitizen.tools/Module:AGGridColumns) itself, not to this module. `testcases.lua` covers DataGrid's own pure column logic; its one untested, frame-dependent path is `main`, verified by browser QA instead, per project convention.
