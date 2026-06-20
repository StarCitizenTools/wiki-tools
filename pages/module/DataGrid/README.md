# Module:DataGrid

Builds an interactive, filterable browse table on [AG Grid](https://www.ag-grid.com/) via [Extension:AGGrid](https://www.mediawiki.org/wiki/Extension:AGGrid) for a category, a raw SMW condition, or both. The successor to [Module:DataTableLua](https://starcitizen.tools/Module:DataTableLua): the same [Template:Data table](https://starcitizen.tools/Template:Data_table) contract, but virtualised rows, rich cells (linked thumbnails and names), and REST-served data on saved pages.

## Usage

Invoked through `{{Data table}}`, a bare `{{#invoke:DataGrid|main}}`. The module reads `category`, `columns`, and `conditions` off the parent (template) frame via `Module:Arguments`.

- `category` — the category to browse. Optional when `conditions` is given; provide at least one of the two.
- `columns` — one column per line, `property; label=X; size=X; filter`. The first clause is the SMW property; the rest are modifiers. `label=` overrides the header (and the result-row key). The bare `filter` flag gives the column a checkbox set filter. `size=` is parsed for backward-compatibility but is **unused** — no live page sets it, and the lead thumbnail width is fixed.
- `conditions` — extra raw SMW query conditions (e.g. `[[Item type::Gun]]` or `[[Manufacturer::ArcCorp]]`). Appended to the category condition when both are given, or used on its own when no category is supplied ([[Template:Manufacturer products]] queries `[[Manufacturer::…]]` with no category). The query is always restricted to the main namespace with `[[:+]]`.

## Behaviour

- **Data source** — one `mw.smw.ask` query: a fixed `Page Image` + page-name lead, then one aliased printout per column. Every column is emitted with an explicit `=alias` (the `label`, else the property verbatim) so result rows key deterministically. Two columns resolving to the same alias — or one colliding with the reserved `Image`/`Name` lead keys — are rejected with an inline error.
- **Lead columns** — a blank-header linked thumbnail (`aggridImage`) and a linked name (`aggridLink`), both linking to the row's own page.
- **Column classification** — each editor column is classified from its values: a **page-link** column (`[[:Target|Display]]` values → `aggridLink`) or a **plain** column. This keeps page-valued columns such as Manufacturer rendering as links. Number-vs-text is deliberately not decided in Lua.
- **Numeric sort** — plain columns use the gadget's `scwSmart` type: numeric-looking values sort numerically and right-align per cell; text sorts alphabetically. No column-level numeric typing, so a stray text value never flips a column and a code like `S2` never mis-sorts.
- **Filtering** — `filter`-flagged columns get the checkbox set filter (`aggridSet`); other columns get a text filter. A global `quickSearch` box sits above the grid.
- **No pagination** — all rows load into one virtualised, internally-scrolling grid (70vh).
- **Empty category** — renders an empty grid (AG Grid's "no rows" overlay), not an error, so a new type with no pages yet still works.

## Requirements

- [Extension:AGGrid](https://www.mediawiki.org/wiki/Extension:AGGrid) — `mw.ext.aggrid`, the `aggridImage`/`aggridLink` column types, the `aggridSet` filter, `quickSearch`, and the `Pages using AG Grid` tracking category.
- [Extension:SemanticScribunto](https://www.mediawiki.org/wiki/Extension:SemanticScribunto) — `mw.smw.ask`.
- **aggridRenderers gadget** (`MediaWiki:Gadget-aggridRenderers.js`) — registers the generic `scwSmart` column type. Gated in `MediaWiki:Gadgets-definition` by `categories=Pages using AG Grid`, so it loads on grid pages. Without it, plain columns fall back to AG Grid's default string sort and left alignment.

## Architecture

```
DataGrid/
├── DataGrid.lua        parseColumns, columnAlias, duplicateAlias, buildQuery, render (main)
├── Util/
│   ├── Util.lua        decodeScalar, toText, parseLink, buildThumb, classifyColumn
│   └── testcases.lua   ScribuntoUnit tests
├── styles.css          grid styles, scoped to .t-datagrid
└── testcases.lua       ScribuntoUnit tests (parseColumns, columnAlias, duplicateAlias, buildQuery)
```

The SMW-value helpers in `Util` decode the formatted strings and wikilink markup `mw.smw.ask` returns. Per project convention the rendering paths (`buildRowData`, `buildColumnDefs`, `main`) are not unit-tested.
