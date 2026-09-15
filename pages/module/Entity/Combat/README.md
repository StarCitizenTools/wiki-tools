# Module:Entity/Combat

Renders a contract's combat encounter: the total hostile count, then one row per spawn group giving its role, whether it spawns on foot or as a ship, how many can be present at once, and which vehicles it draws from.

Editors use this through `{{Entity/Combat}}`; see [Template:Entity/Combat](https://starcitizen.tools/Template:Entity/Combat). Nothing is stored: the section renders from the API record only.

## For module editors

### API

`p.main(frame)` reads `apiData.combat` via [Module:Entity/Data](https://starcitizen.tools/Module:Entity/Data), builds the class-name lookup, and turns the rows from [Module:Entity/Combat/Lines](https://starcitizen.tools/Module:Entity/Combat/Lines) into a `Module:TableLua` table. All the shaping is in Lines.

### Gotchas

- Gate on `Lines.hasData(combat)`, never on the record's own `has_combat` flag. They agree across the current corpus, but `hasData` asks the question the render actually depends on: is there a total or at least one spawn group to show.
- `concurrent_min` and `concurrent_max` are set on `Ship` groups only. Every `Npc` group in the corpus has neither, so the Concurrent cell is an em dash on foot encounters and that is correct, not missing data.
- The vehicle pool is comma-joined rather than a nested list, and shows every entry. A reader checking whether one specific ship can appear needs the complete list; linking by canonical page title is what keeps it readable.
- The class-name lookup is ONE Bucket read per page, not one query per ship, which keeps it well inside Bucket's per-query budget. It is wrapped in `pcall`, so a Bucket failure degrades every entry to plain text instead of taking the section down.
- The subject-type narrowing belongs in the QUERY, not in Lua. The entity bucket holds far more rows than one query returns, so an unfiltered read is silently truncated by the row limit and loses every vehicle past the cut.
- The map is keyed lowercase. The two sources disagree on case for the same identifier: the combat data gives `ORIG_85x` and `ARGO_Mole` where the pages store `ORIG_85X` and `ARGO_MOLE`, which silently cost a link each.
- A vehicle whose page has not reparsed since `class_name` was added has no Bucket row, so it renders as plain text until it does. That is the intended degradation, not a bug.
- Some pool entries stay plain text because the game's mission data references a stale class name (see [Module:Entity/Combat/Lines](https://starcitizen.tools/Module:Entity/Combat/Lines)). That resolves itself when the source is updated upstream; it is not something to patch here.

### Styles

`t-entity-combat-table` shrinks the vehicle-pool column's type; the table itself scrolls horizontally through `wikitable--fluid`.
