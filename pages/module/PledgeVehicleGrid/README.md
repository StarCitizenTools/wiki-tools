# Module:PledgeVehicleGrid

Renders the [List of pledge vehicles](https://starcitizen.tools/List_of_pledge_vehicles) as a sortable, filterable [AG Grid](https://www.ag-grid.com/) data table via the [AGGrid extension](https://www.mediawiki.org/wiki/Extension:AGGrid). It replaces the page's former `#ask format=datatables` table.

Every pledge vehicle is read from Semantic MediaWiki (`mw.smw.ask` over `Category:Pledge ships` / `Category:Pledge vehicles`), reshaped into AG Grid `rowData`, and rendered with rich cells: a combined vehicle card (thumbnail + manufacturer + name), stacked prices, and loaner link-lists. Rows are virtualised and, on saved pages, served from the extension's cacheable REST endpoint instead of being inlined into the page HTML — so the page loads and scrolls far faster than the DataTables table it replaced.

## Usage

The module takes no parameters. Place it on the list page:

```wikitext
{{#invoke:PledgeVehicleGrid|main}}
```

`main` returns a `<templatestyles>` tag for `Module:PledgeVehicleGrid/styles.css` followed by the grid, wrapped in a `<div class="t-pledge-grid">`.

The cell renderers are supplied by the **aggridRenderers gadget** (see [Requirements](#requirements)); the module only packs the data and references the renderers by column `type`.

## Behavior

- **Data source** — one `mw.smw.ask` query (page image, name, manufacturer, career, role, size, production state and availability, the pledge / warbond / average prices, loaner vehicles, the physical specs, and the concept date). Tagging a vehicle into the pledge categories and filling its SMW properties is enough for it to appear; no edit to this module is needed.
- **Vehicle card** — the former Image, Name, and Manufacturer columns are collapsed into one card cell (`scwEntityCard`): a thumbnail, the manufacturer as an eyebrow, the ship name as the title, and the manufacturer's brand glyph as a faint right-edge watermark. The name and image link to the ship page; the eyebrow links to the manufacturer. Sort, quick-search and CSV export key on the **ship name** (`valueFormatter`); the **set filter lists manufacturers** in full, each with its brand glyph, via `filterValueGetter` + `filterParams.itemRenderer` (decoupled from the display scalar).
- **Manufacturer name + glyph** — the eyebrow uses the manufacturer's short name (e.g. `Origin` rather than `Origin Jumpworks`) for compactness, while the card also carries the full name (`eyebrowFull`) used as the set-filter value. The short/full names and the brand glyph file (`File:Sc-icon-brand-<code>.svg`) all come from `Module:Manufacturers/data.json` (keyed `CODE → { name, short }`). A manufacturer missing from the map falls back to its full name with no glyph.
- **Stacked prices** — Pledge and Warbond each render the current price over the original price (`scwStackedValue`), with the original shown as a muted second line **only when it differs** from the current. Sort and the number filter operate on the current price.
- **Production badges** — the production state renders as a `scwBadge` pill styled like [Module:BadgeLua](https://starcitizen.tools/Module:BadgeLua): _Flight ready_ → success, _Active / Long term production_ → warning, other states (concept, SQ42-only) → the neutral base badge. The variant per state is mapped in `PRODUCTION_VARIANT`; sort and the set filter key on the state text.
- **Rich cells** — loaners render as a comma-separated row of links. These resolve server-side, and sort / filter operate on the underlying text.
- **Filtering** — the categorical columns (manufacturer via the card, career, role, size, production state, pledge availability) use the extension's checkbox **set filter** (`filter = 'aggridSet'`). Numeric columns (including the stacked prices) use the number filter; loaner and concept date use a text filter.
- **Number formatting and units** — each plain numeric column carries a serialisable `format` spec (`{ style = 'number', suffix = ' m' }`, etc.) that the extension applies client-side via `Intl`: thousands separators plus a unit (`m`, `kg`, `SCU`, `m/s`, `°/s`, `aUEC` for the in-game average prices), while the underlying value stays a real number. The stacked price cells are pre-formatted (`$` + grouping) in Lua and carry the raw current number for sort/filter. Crew counts are unformatted; Vehicle inventory (Stowage) is grouped without a unit (SMW stores none).
- **No pagination** — all vehicles load into one internally-scrolling grid; only the rows in view are ever in the DOM.
- **Column sizing** — plain columns auto-size to their content via `autoSizeStrategy = fitCellContents`; the custom-rendered columns (card, stacked prices) carry an explicit width and opt out of auto-sizing, since their DOM does not measure meaningfully.

## Styles

`Module:PledgeVehicleGrid/styles.css` is bundled automatically. Scoped to the `.t-pledge-grid` wrapper, it carries only grid-level tweaks (a taller 70vh viewport, vertically-centred cells, right-aligned numerics). The look of the card and stacked-value cells is owned by the gadget's stylesheet (`MediaWiki:Gadget-aggridRenderers.css`), which loads with the renderers.

## Requirements

- [Extension:AGGrid](https://www.mediawiki.org/wiki/Extension:AGGrid) — provides `mw.ext.aggrid`, the built-in rich-cell column types, and the `ext.aggrid.register` hook the gadget extends.
- [Extension:SemanticScribunto](https://www.mediawiki.org/wiki/Extension:SemanticScribunto) — provides `mw.smw.ask`.
- **aggridRenderers gadget** (`MediaWiki:Gadget-aggridRenderers.js` / `.css`) — registers the `scwEntityCard` and `scwStackedValue` column types via `ext.aggrid.register`. Gated in `MediaWiki:Gadgets-definition` by `categories=Pages using AG Grid` (the extension's tracking category), so it loads only on grid pages. Without it, those columns fall back to AG Grid's default rendering of the raw value object.
- `Module:Manufacturers/data.json` — the manufacturer short name + brand code source.

## Architecture

The module is intentionally specific to the pledge-vehicle list: the query and column set are hardcoded in `buildQuery()` and `COLUMNS`. The SMW-value helpers (`decodeScalar`, `toNumber`, `parseLink`, `buildThumb`, `buildLinkList`) absorb the formatted-string and wikilink-markup shapes that `mw.smw.ask` returns; `buildCard` and `buildPriceStack` pack the structured values the gadget renderers consume. The renderers themselves (`scwEntityCard`, `scwStackedValue`) live in the gadget and are generic — reusable by any future AG Grid browse table — keeping SCW-specific cell rendering out of the extension. If a second browse table is needed, factor the SMW-value helpers and the column-spec to `colDef` mapping into a shared module, the way [Module:DataTableLua](https://starcitizen.tools/Module:DataTableLua) generalises the DataTables format.
