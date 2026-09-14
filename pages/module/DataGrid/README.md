# Module:DataGrid

Builds an interactive, filterable browse table on [AG Grid](https://www.ag-grid.com/) (via [Extension:AGGrid](https://www.mediawiki.org/wiki/Extension:AGGrid)) from a [Module:Entity/Store](https://starcitizen.tools/Module:Entity/Store) query: a category, a `filter` clause list, or both.

Editors use this through `{{Data table}}`; see [Template:Data table](https://starcitizen.tools/Template:Data_table).

## For module editors

### API

- `p.parseColumns(raw)`: the multi-line `columns` argument into `DataGridColumn[]` (`property`, `label`, `filter`, `eyebrow`, `kind`, `good`, `group`, `prefix`, `suffix`, `suffix1`).
- `p.columnAlias(column)`: a column's result-row key: `label`, else the property name.
- `p.duplicateAlias(columns, options)`: the first alias colliding with another column or a lead key (`Image`/`Name`/`DisplayName`), or `nil`.
- `p.parseFilters(raw)`: the multi-line `filter` argument into Store filter entries, or `nil` plus the first line that does not parse. `Property = A; B` is the Or form (`||` is also accepted, from an editor's `{{!}}{{!}}`); the property name and every value are entity-decoded.
- `p.parseCategory(raw)`: the `category` argument into a Store category filter (`'Category:X'`, or `{ any = {...} }` for `A; B`), or `nil` plus the offending part. Names are entity-decoded.
- `p.parseSort(raw, columns)`: the `sort` argument (`<label or property> [asc|desc]`, direction defaulting to `asc`) into `{ alias, direction }`, or `nil` for an empty `raw`. The name matches a column's alias (`columnAlias`) or its raw property, so it still finds a relabelled column; an unrecognized name or direction returns a ready-to-display error.
- `p.buildSpec(kind, categoryFilter, filters, columns, options)`: the `Store.query` spec: the lead columns plus one per editor column. Resolves every property against Store so an unknown or cross-kind one errors here, not as an empty column.
- `p.resolveArgs(args, options)`: the whole argument table into `{ spec, columns, kind, sort }`, or `nil` plus a ready-to-display message for the first contract violation. [Module:DataGrid/Static](https://starcitizen.tools/Module:DataGrid/Static) calls it too, which is what keeps one grammar and one set of messages behind both templates. `options` passes straight through to `duplicateAlias` and `buildSpec`.
- `p.runQuery(spec)`: runs the Store query, returning `nil` plus the error on a Bucket infrastructure failure instead of letting it script-error the page.
- `p.sortRows(results)`: orders results by the `Name` alias, in place.
- `p.main(frame)`: wikitext entry point; reads `category`/`filter`/`kind`/`columns`/`pinlead`/`sort`, runs the query, and returns the rendered grid.

Column kinds come from `Store.resolve(property, kind).type`, not from the fetched values: PAGE becomes `link` (`linkList` when repeated); a repeated non-PAGE property becomes `valueList`; INTEGER/DOUBLE becomes `number`; BOOLEAN becomes `boolean`; anything else is `smart`. `kind=effect`/`bar`/`boolean` on a column overrides this with a [Module:DietaryEffect](https://starcitizen.tools/Module:DietaryEffect) badge list, a signed bar, or a [Module:Boolean](https://starcitizen.tools/Module:Boolean) icon; any other `kind` value is silently ignored.

### Gotchas

- The lead columns are the page title (as `Name`), the page image (`Image`) and the stored name (`DisplayName`), ahead of the editor's own. `options.leadImage = false` on `resolveArgs`, `buildSpec` or `duplicateAlias` omits the `Image` one and frees that alias for an editor column, which is how [Module:DataGrid/Static](https://starcitizen.tools/Module:DataGrid/Static) lets a table place its own image. A caller that passes no options, this module included, gets all three leads and keeps `Image` reserved.
- `Maximum temperature`, `Minimum temperature` and `Type` are stored per kind but resolve to the item and mission tables without `kind` ([Module:Entity/Store](https://starcitizen.tools/Module:Entity/Store) searches Entity's manifest before WearableSet's), so a wearable-set table must pass `kind = 'Wearable set'` or those columns come back empty.
- `size=` is parsed for backward compatibility only; it has no effect on rendering.
- `main` calls `sortRows` (the `Name` alias, byte comparison, unassigned first) right after `runQuery` and before `buildSpecs`, so rows are listed by page title unless `sort` chooses a column; Bucket otherwise returns them in store order.
- `sort` only ever names one of the editor's non-`eyebrow` `columns` lines; `buildSpecs` matches it against each spec's `label` and sets that spec's `sort` field, which every kind's `buildColDef` (in `Module:AGGridColumns/Kind`) forwards unchanged to AG Grid's own initial-sort key. `parseSort` excludes `eyebrow` columns from matching, since one is folded into the lead card and never gets its own spec to sort; naming one is the same `no column named` error as naming an unknown property.
- `kind=bar` scales every cell against its column's largest absolute value across all matching rows, not per cell, so two rows stay visually comparable.
- An `eyebrow` column's set filter (when also `filter`-flagged) keys on that one column's decorated text, not the composed multi-part line; otherwise every row would be its own filter option. Only a PAGE-typed eyebrow column links; a text-typed one never does, even when its value happens to read like a title.
- Full rendering (the lead card, `scwSmart` sort/alignment) depends on the `aggridRenderers` gadget (`MediaWiki:Gadget-aggridRenderers.js`), gated to load on `Category:Pages using AG Grid`; without it AG Grid falls back to its own column defaults.
- The value-decoding helpers (`decodeScalar`, `toText`, `pageTarget`, `cloneFormat`) live in [Module:AGGridColumns/Util](https://starcitizen.tools/Module:AGGridColumns/Util), shared with other AG Grid renderers, not in a DataGrid-owned submodule; `buildRowData` and `buildColumnDefs` likewise belong to [Module:AGGridColumns](https://starcitizen.tools/Module:AGGridColumns) itself, not to this module. `testcases.lua` covers DataGrid's own pure column logic; its one untested, frame-dependent path is `main`, verified by browser QA instead, per project convention.
