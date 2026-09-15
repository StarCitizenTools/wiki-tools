# Module:Entity/Combat

Renders a contract's combat encounter: the total hostile count, then one row per spawn group giving its role, whether it spawns on foot or as a ship, how many can be present at once, and which vehicles it draws from.

Editors use this through `{{Entity/Combat}}`; see [Template:Entity/Combat](https://starcitizen.tools/Template:Entity/Combat). Nothing is stored: the section renders from the API record only.

## For module editors

### API

`p.main(frame)` reads `apiData.combat` via [Module:Entity/Data](https://starcitizen.tools/Module:Entity/Data). All the shaping is in [Module:Entity/Combat/Lines](https://starcitizen.tools/Module:Entity/Combat/Lines); this module only turns those rows into a `Module:TableLua` table.

### Gotchas

- Gate on `Lines.hasData(combat)`, never on the record's own `has_combat` flag. They agree across the current corpus, but `hasData` asks the question the render actually depends on: is there a total or at least one spawn group to show.
- `concurrent_min` and `concurrent_max` are set on `Ship` groups only. Every `Npc` group in the corpus has neither, so the Concurrent cell is an em dash on foot encounters and that is correct, not missing data.
- The vehicle pool is comma-joined rather than a nested list, so a row stays one line tall when a patrol contract draws from thirty-odd ships.

### Styles

`t-entity-combat-table` shrinks the vehicle-pool column's type; the table itself scrolls horizontally through `wikitable--fluid`.
