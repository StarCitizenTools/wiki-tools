# Module:Navplate vehicles

Renders the vehicle browse navbox shown at the bottom of ship and ground vehicle pages: one labelled row per manufacturer, grouped under a Ships section and a Ground vehicles section. Reached through [Template:Navplate vehicles](https://starcitizen.tools/Template:Navplate_vehicles), which wraps `{{#invoke:Navplate vehicles|main}}` with no arguments.

## For module editors

### API

- `NavplateVehicles.main(frame)`: builds and returns one instance's rendered navbox.
- `methodtable.getRows(self, category)`: reads [Module:Entity/Store](https://starcitizen.tools/Module:Entity/Store) for every page in `category` (bare title + Manufacturer), sorted by manufacturer then page, and caches the result per category on the instance. Returns `nil` on a Store failure or an empty result; `make` turns that into an error hatnote.
- `methodtable.group(self, data, groupKey, suffix)`: groups Store rows by `groupKey` (e.g. `manufacturer`) into `[[page|name]]` wikilinks, sorted alphabetically by display name within each group; `self` is unused. `p._internal.group`/`.sortRows` re-export `group` (without the unused `self`) and the row sort for the ScribuntoUnit suite; neither is part of the module's real API.
- `methodtable.make(self)`: builds the Ships and Ground vehicles sections, resolves each manufacturer's brand glyph via [Module:Manufacturer](https://starcitizen.tools/Module:Manufacturer), and hands the assembled args to [Module:Navplate](https://starcitizen.tools/Module:Navplate).

### Gotchas

- i18n strings load from `Module:Navplate vehicles/i18n.json` via [Module:Translate](https://starcitizen.tools/Module:Translate), plus `Module:i18n`'s own data; neither is mirrored in this repository.
