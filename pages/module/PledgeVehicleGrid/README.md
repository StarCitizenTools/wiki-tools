# Module:PledgeVehicleGrid

Renders the [List of pledge vehicles](https://starcitizen.tools/List_of_pledge_vehicles) as a sortable, filterable [AG Grid](https://www.ag-grid.com/) data table via the [AGGrid extension](https://www.mediawiki.org/wiki/Extension:AGGrid).

## For editors

Place `{{#invoke:PledgeVehicleGrid|main}}` directly on a page; it takes no parameters and isn't wrapped in a template. The only page currently doing so is [List of pledge vehicles](https://starcitizen.tools/List_of_pledge_vehicles) (not mirrored in this repository).

Every row comes from one [SMW](https://www.mediawiki.org/wiki/Extension:Semantic_MediaWiki) query over `Category:Pledge ships` / `Category:Pledge vehicles`: tagging a vehicle into either category and filling its SMW properties (manufacturer, type, size, prices, physical stats, and so on) is enough for it to appear, with no edit to this module. The grid does not query SMW live on every view: it is built from the categories' state as of this page's last save or forced reparse, so a vehicle just tagged in may not show until this page is next saved or purged with `forcelinkupdate`.

The grid carries a themed search box wired to AG Grid's quick filter (`quickSearch = true`), a toolbar button that reopens it in a full-window modal with filter and sort state carried over (`expand = true`), and no pagination: every vehicle loads into one virtualised, internally-scrolling grid where only the visible rows are ever in the DOM (`pagination = false`) (`PledgeVehicleGrid.lua:255-270`).

## For module editors

### API

- `buildQuery()`: the `mw.smw.ask` query array over `Category:Pledge ships`/`Pledge vehicles`, one aliased printout per column, capped at `limit=1000` (`PledgeVehicleGrid.lua:196-234`).
- `COLUMNS`: the declarative column spec array, one entry per grid column (`field`, `header`, `kind`, plus per-kind options), consumed by [Module:AGGridColumns](https://starcitizen.tools/Module:AGGridColumns)'s `buildColumnDefs`/`buildRowData`. `kind` selects the renderer: `card` (thumbnail + manufacturer eyebrow + name), `stackedValue` (current price over a muted original), `badge` (production state), `linkList` (loaners), `date` (concept date), `number`/`text` otherwise.
- `manufacturerEyebrow(result)`: the vehicle card's eyebrow, consumer-specific because the manufacturer-to-glyph mapping is this list's own (`PledgeVehicleGrid.lua:68-85`).
- `flightReadyLabel(value)`: strips the `Added in version` SMW Page's `Update:`/`Star Citizen ` prefixes to a bare version label for the `Flight ready` column (`PledgeVehicleGrid.lua:91-97`).
- `p.main(frame)`: entry point; runs the query, resolves `Flight ready` labels, builds `gridOptions`, and returns the grid.

### Gotchas

- `gridOptions.rowData` is built here in Lua from the query result and handed to `aggrid.render`; Extension:AGGrid strips `rowData` back out of a saved page's canonical parse and serves it from a per-page store instead, populated when this page is next saved or link-updated, not fetched live per request. A vehicle's own page can be edited freely; only a (re)parse of *this* page refreshes what the grid shows.
- The SMW-value decoding (`decodeScalar`, `toText`, `parseLink`) and every kind's renderer (`card` → `scwEntityCard`, `stackedValue` → `scwStackedValue`, `badge` → `scwBadge`, `linkList`/`text`/`number`/`date`) live in [Module:AGGridColumns](https://starcitizen.tools/Module:AGGridColumns) and its `Kind/*` submodules, not in this module. A second AG Grid browse table shares that library the way [Module:DataGrid](https://starcitizen.tools/Module:DataGrid) already does; only a new `buildQuery`/`COLUMNS` pair would be module-specific.
- The vehicle column's set filter lists manufacturers, not ship names: `Kind/Card`'s filter defaults to the card's eyebrow value, and `COLUMNS`' `vehicle` entry doesn't override that with `filterOn`.
- The manufacturer short name and brand-glyph code (`File:Sc-icon-brand-<code>.svg`) come from `Module:Manufacturers/data.json`, loaded once at module load into a name-keyed table (`PledgeVehicleGrid.lua:29-39`); a manufacturer missing from that map falls back to its full SMW name with no glyph.
- The `scwEntityCard`/`scwStackedValue`/`scwBadge` cell renderers are supplied by the aggridRenderers gadget (`MediaWiki:Gadget-aggridRenderers.js`/`.css`), gated to `Category:Pages using AG Grid`; without it those columns fall back to AG Grid's own rendering of the raw value.
- `PRODUCTION_VARIANT` maps `Production state` text to a badge colour: *Flight ready* → success, *Active production*/*Long term production* → warning, *In concept* → error; any other state (SQ42-only builds) gets the neutral base badge (`PledgeVehicleGrid.lua:58-63`).

### Styles

`Module:PledgeVehicleGrid/styles.css` is bundled automatically, scoped to the `.t-pledge-grid` wrapper: a 70vh grid height, vertically-centred cells, and right-aligned numerics. The card and stacked-value cells' own look is owned by the gadget's stylesheet, which loads with the renderers.
