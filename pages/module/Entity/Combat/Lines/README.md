# Module:Entity/Combat/Lines

Pure formatting for a contract's combat spawn data: the hostile count range, and one row per spawn group carrying its role label, spawn kind, concurrent count and deduplicated vehicle pool. It has no requires beyond `strict`, matching [Module:Entity/Orders/Lines](https://starcitizen.tools/Module:Entity/Orders/Lines) and [Module:Entity/Rewards/Lines](https://starcitizen.tools/Module:Entity/Rewards/Lines), so a kind hook could share it without creating a require cycle.

Required by [Module:Entity/Combat](https://starcitizen.tools/Module:Entity/Combat) (the visible combat table).

## For module editors

### API

- `p.countRange(min, max)`: `'5 - 10'` for a spread, `'5'` when the bounds are equal or only one is known, nil when neither is.
- `p.groupLabel(spawn)`: the game's own group name, verbatim.
- `p.spawnKind(spawn)`: `'Ship'` or `'Npc'` as the API spells it, nil when unset.
- `p.shipLabels(spawn, resolvePage)`: the group's vehicle pool, one entry per distinct vehicle, sorted by visible text. An entry links when `resolvePage` finds a wiki page for one of its class names, and renders as plain text when it does not. Class names are lowercased before lookup, so `resolvePage` must be keyed lowercase.
- `p.spawnRows(combat, resolvePage)`: every group as `{ role, roleLabel, label, kind, count, ships }`, ordered by `p.ROLE_ORDER` and then by API order within a role. `resolvePage` passes through to `shipLabels`.
- `p.totalEnemies(combat)`: the `summary.total` range.
- `p.hasData(combat)`: whether there is a total or any spawn group.

### Gotchas

- The group name already carries its own count (`Soldier x 2`, `Juggernaut x 1 - Target`). It is passed through untouched, because rewriting it would desync the label from the `concurrent` figures beside it.
- `shipLabels` groups by display name BEFORE resolving. A group routinely lists several class names sharing one display name (`AEGS_Hammerhead_GS` and `AEGS_Hammerhead` are both Aegis Hammerhead) and typically only the base one has a page, so resolving first emitted the linked and the plain form of one ship side by side.
- Entries sort on the visible text, not the wikitext. `[` sorts after every letter, so sorting the markup files every link after every plain entry instead of interleaving them.
- Class names are lowercased before lookup: the two sources disagree on case for the same identifier (`ORIG_85x` against the page's `ORIG_85X`).
- A class name with no Bucket row is usually one the game's own mission data has left stale: the combat records still reference `AEGS_Hammerhead`, `AEGS_Idris` and `RSI_Aurora_LX` where the current vehicle records use `AEGS_Hammerhead_GS`, `AEGS_Idris_M`/`_P` and `RSI_Aurora_GS_LX`. Grouping by display name rescues these wherever a current sibling class name appears in the same pool.
- Do NOT add an alias table for those. They are upstream identifiers CIG is expected to update, and hard-coding them here would encode stale game data as if it were canonical, then quietly go wrong when it changes. Plain text is the correct answer until the source agrees with itself.
- A vehicle is never linked by guessing its title from the display name. The wiki titles vehicle pages by model alone, so linking the API's `Aegis Gladius` verbatim is a red link where `Gladius` is not; the class-name lookup links only what Bucket confirms exists.
- The four roles the API uses are `enemy`, `escort_target`, `defend_target` and `other`. A role outside that set still renders, after the known ones, under its own raw name rather than being dropped.
