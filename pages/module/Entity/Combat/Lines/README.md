# Module:Entity/Combat/Lines

Pure formatting for a contract's combat spawn data: the hostile count range, and one row per spawn group carrying its role label, spawn kind, concurrent count and deduplicated vehicle pool. It has no requires beyond `strict`, matching [Module:Entity/Orders/Lines](https://starcitizen.tools/Module:Entity/Orders/Lines) and [Module:Entity/Rewards/Lines](https://starcitizen.tools/Module:Entity/Rewards/Lines), so a kind hook could share it without creating a require cycle.

Required by [Module:Entity/Combat](https://starcitizen.tools/Module:Entity/Combat) (the visible combat table).

## For module editors

### API

- `p.countRange(min, max)`: `'5 - 10'` for a spread, `'5'` when the bounds are equal or only one is known, nil when neither is.
- `p.groupLabel(spawn)`: the game's own group name, verbatim.
- `p.spawnKind(spawn)`: `'Ship'` or `'Npc'` as the API spells it, nil when unset.
- `p.shipLinks(spawn)`: the group's vehicle pool as links, in API order, deduplicated by display name.
- `p.spawnRows(combat)`: every group as `{ role, roleLabel, label, kind, count, ships }`, ordered by `p.ROLE_ORDER` and then by API order within a role.
- `p.totalEnemies(combat)`: the `summary.total` range.
- `p.hasData(combat)`: whether there is a total or any spawn group.

### Gotchas

- The group name already carries its own count (`Soldier x 2`, `Juggernaut x 1 - Target`). It is passed through untouched, because rewriting it would desync the label from the `concurrent` figures beside it.
- `shipLinks` deduplicates because a group routinely lists several `class_name` variants that share one display name (`AEGS_Hammerhead_GS` and `AEGS_Hammerhead` are both Aegis Hammerhead), which would otherwise render the same link twice.
- The four roles the API uses are `enemy`, `escort_target`, `defend_target` and `other`. A role outside that set still renders, after the known ones, under its own raw name rather than being dropped.
