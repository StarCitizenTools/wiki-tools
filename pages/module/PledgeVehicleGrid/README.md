# Module:PledgeVehicleGrid

Renders the [List of pledge vehicles](https://starcitizen.tools/List_of_pledge_vehicles) as a sortable, filterable [AG Grid](https://www.ag-grid.com/) data table via the [AGGrid extension](https://www.mediawiki.org/wiki/Extension:AGGrid). It replaces the page's former `#ask format=datatables` table.

Every pledge vehicle is read from Semantic MediaWiki (`mw.smw.ask` over `Category:Pledge ships` / `Category:Pledge vehicles`), reshaped into AG Grid `rowData`, and rendered with rich cells: linked ship names, thumbnails, and loaner link-lists. Rows are virtualised and, on saved pages, served from the extension's cacheable REST endpoint instead of being inlined into the page HTML — so the page loads and scrolls far faster than the DataTables table it replaced.

## Usage

The module takes no parameters. Place it on the list page:

```wikitext
{{#invoke:PledgeVehicleGrid|main}}
```

`main` returns a `<templatestyles>` tag for `Module:PledgeVehicleGrid/styles.css` followed by the grid, wrapped in a `<div class="t-pledge-grid">`.

## Behavior

- **Data source** — one `mw.smw.ask` query with ~29 printouts (page image, name, manufacturer, career, role, size, production state and availability, the pledge / warbond / average prices, loaner vehicles, the physical specs, and the concept date). Tagging a vehicle into the pledge categories and filling its SMW properties is enough for it to appear; no edit to this module is needed.
- **Rich cells** — the name links to the ship page, the image is a thumbnail linked to the ship page, and loaners render as a comma-separated row of links. These resolve server-side, and sort / filter operate on the underlying text.
- **Filtering** — the low-cardinality categorical columns (manufacturer, career, role, size, production state, pledge availability) use the extension's checkbox **set filter** (`filter = 'aggridSet'`), with per-value row counts and a search box. Numeric columns use the number filter; name, loaner, and concept date use a text filter.
- **Numbers** — price and spec columns are coerced to real numbers. SMW returns formatted strings such as `$ 50.00` and `223 m/s` (with the space encoded as a literal entity), so the module HTML-decodes each value and strips the currency, units, and grouping before `tonumber`, letting numeric sort and the number filter work.
- **No pagination** — all vehicles load into one internally-scrolling grid; only the rows in view are ever in the DOM.
- **Column sizing** — columns auto-size to their content via `autoSizeStrategy = fitCellContents`. Each column also carries an explicit width in the source (currently unused) for an easy switch back to fixed widths.

## Styles

`Module:PledgeVehicleGrid/styles.css` is bundled automatically. Scoped to the `.t-pledge-grid` wrapper, it layers a few tweaks over the extension's theme: a taller (70vh) grid viewport, the image column's thumbnail filling its cell, vertically-centred cells, and right-aligned numeric columns.

## Requirements

- [Extension:AGGrid](https://www.mediawiki.org/wiki/Extension:AGGrid) — provides `mw.ext.aggrid` and the rich-cell column types (`aggrid.link`, `aggrid.thumb`, `aggrid.linkList`, and the matching column helpers).
- [Extension:SemanticScribunto](https://www.mediawiki.org/wiki/Extension:SemanticScribunto) — provides `mw.smw.ask`.

## Architecture

The module is intentionally specific to the pledge-vehicle list: the query and column set are hardcoded in `buildQuery()` and `COLUMNS`. The SMW-value helpers (`decodeScalar`, `toNumber`, `parseLink`, `buildThumb`, `buildLinkList`) absorb the formatted-string and wikilink-markup shapes that `mw.smw.ask` returns. If a second AG Grid browse table is ever needed, factor those helpers and the column-spec to `colDef` mapping into a shared module, the way [Module:DataTableLua](https://starcitizen.tools/Module:DataTableLua) generalises the DataTables format.
