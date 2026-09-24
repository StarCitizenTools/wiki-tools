# Module:RentalVehicleGrid

Renders the [Ship renting](https://starcitizen.tools/Ship_renting) rental price table as a sortable, filterable [AG Grid](https://www.ag-grid.com/) data table via the [AGGrid extension](https://www.mediawiki.org/wiki/Extension:AGGrid), one row per ship/location pairing at its lowest available rental price.

## For editors

[Template:RentalVehicleGrid](https://starcitizen.tools/Template:RentalVehicleGrid) calls this module; place `{{RentalVehicleGrid}}` on a page. It takes no parameters (`p.main` never reads `frame.args`). [Ship renting](https://starcitizen.tools/Ship_renting) is the only page currently doing so (not mirrored in this repository).

Every row's price, vehicle and terminal data comes from [UEX](https://uexcorp.space) via [Extension:Apiunto](https://www.mediawiki.org/wiki/Extension:Apiunto); manufacturer, role and thumbnail come from [Module:Entity/Store](https://starcitizen.tools/Module:Entity/Store) (Bucket), keyed by the ship's page title after redirect resolution. A ship UEX reports that has no matching Store row still shows, with a blank manufacturer/role/image.

## For module editors

### API

- `getCoreDatabase()`: fetches and indexes the three UEX datasets (`vehicles_rentals_prices_all`, `vehicles`, `terminals`) via Apiunto; returns `nil` plus an error string on a missing extension or an unparseable response.
- `fetchWikiShipProperties(shipNames)`: `Store.resolvePages(shipNames)` mapped to `{ manufacturer, role, image }` per page, keyed by `normalizeKey(page)`. `p._internal.mapWikiShips` re-exports the mapping step for the ScribuntoUnit suite; it is not part of the module's real API.
- `getTerminalLocationKeys(terminal, rental)`: the location label(s) a rental groups under; falls back to matching "Vantage"/"Traveler" in the terminal or company name when UEX's own `city_name` is blank.
- `p.master_table(frame)` / `p.main(frame)`: build the full dataset, resolve manufacturers via [Module:Manufacturers](https://starcitizen.tools/Module:Manufacturers), and return the rendered grid plus its UEX-attribution footer.

### Gotchas

- `resolveRedirect` follows a ship's page redirect (e.g. "Dragonfly Black" → "Dragonfly") before every Store lookup and display link, so a ship is grouped and priced under its current canonical title even when UEX still reports the old name.
- Only the cheapest rental per ship/location pairing is kept; a costlier duplicate at the same location is dropped rather than shown alongside it.
- The card, link, and value-list cell renderers come from [Module:AGGridColumns](https://starcitizen.tools/Module:AGGridColumns) and its `Kind/*` submodules, not from this module.
- `Module:RentalVehicleGrid/styles.css` is bundled automatically, scoped to the `.t-pledge-grid` wrapper it shares with [Module:PledgeVehicleGrid](https://starcitizen.tools/Module:PledgeVehicleGrid).

### Styles

[Module:RentalVehicleGrid/styles.css](https://starcitizen.tools/Module:RentalVehicleGrid/styles.css) styles the `.t-pledge-grid` wrapper, the class this module reuses from [Module:PledgeVehicleGrid](https://starcitizen.tools/Module:PledgeVehicleGrid). Each module loads its own copy, so the two files may differ. A cell holds one line and clips what does not fit, matching the pledge grid: AG Grid sizes its line height to centre a single line in the row, so a wrapping cell would put its lines almost a row apart.
