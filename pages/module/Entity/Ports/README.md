# Module:Entity/Ports

Renders an entity's port loadout as a vertical stack of category cards: one aggregated row per distinct port group, with an indented child tree under parent ports whose category opts into expansion (turrets, missile racks, quantum drives).

Editors use this through `{{Entity/Ports}}`; see [Template:Entity/Ports](https://starcitizen.tools/Template:Entity/Ports).

## For module editors

`Ports.lua` is a thin coordinator delegating to `Pipeline` (data transforms, which itself pulls in `Categories` for config) and `Render` (wikitext): parse args, resolve the chain's `getPorts` payload, `Pipeline.process`, resolve equipped-item links through [Module:Entity/PageResolver](https://starcitizen.tools/Module:Entity/PageResolver), `Render.fromGroups`.

### Hook

Draws `getPorts`, resolved leaf-first (see the Hooks table on [Module:Entity](https://starcitizen.tools/Module:Entity)). Payload (`EntityPortsPayload` in [Module:Entity/Types](https://starcitizen.tools/Module:Entity/Types)): `ports` (the raw API port tree) and `narrowChildren` (boolean). Base's default is `{ ports = ctx.apiData.ports }`; Vehicle overrides it with `narrowChildren = true`. Item, Commodity, Mission, and Location inherit Base's default and skip that extra narrowing pass; every kind still has collapsed-category children stripped from its tree by `cleanChildren`, regardless of `narrowChildren`.

### Extending

To catalogue a new API category, add it to `categories.json`'s `categories` map:

```jsonc
{
  "categories": {
    "<category_label>": {
      "order": 10,                          // primary-card sort position, lower first (mutually exclusive with collapsed)
      "collapsed": true,                    // routes into the "Other" card instead of a primary card
      "expandIntoTypes": ["Turret", "…"]    // optional: child types kept in the L-tree; its mere presence also gates whether a category's children render as a tree at all, for every kind
    }
  },
  "typeAliases": { "<api type string>": "<category label>" }
}
```

An uncatalogued label still renders as its own primary card at `order: 999` (fails open) so nothing breaks before it's synced from [HardpointCategory.php](https://github.com/StarCitizenWiki/API/blob/develop/app/Support/Game/HardpointCategory.php). `typeAliases` supplies a category for ports without an API `category_label` (children, item-endpoint ports) before falling through to [Module:Entity/Item/types.json](https://starcitizen.tools/Module:Entity/Item/types.json) and then to a humanised slug.

### Gotchas

- Two sibling ports aggregate into one row only when type, subType, size range, equipped item name, editable flag, accepted `compatible_types`, and the full recursive child signature all match. The `compatible_types` check is what keeps differently-restricted empty attachment slots (the M4A Cannon's BAR/MEC/POW/VEN mounts) from collapsing into one row.
- The size pill shows the equipped item's size when something's installed, not the port's accepted range; only an empty port falls back to the range.
- Only the narrowing itself is vehicle-only: `narrowChildren` applies each parent category's `expandIntoTypes` allowlist to its own children after the collapsed-category filter runs, dropping a child type even when its own category isn't `collapsed`; this is how cockpit-panel/display noise gets dropped from a turret's L-tree. Items and the other kinds skip that pass but still get the L-tree itself whenever `expandIntoTypes` is set on the category (`computeExpandable`), so an item port under an expandable category can show more children than a vehicle port in the same category.
- `expandIntoTypes` lives on a `mw.loadJsonData` table, where `#`/`next()` are unsafe; `computeExpandable` checks `allow[1] ~= nil` instead.
- A docking port's own `equipped_item` is docking-tube hardware with a placeholder name; Normalize substitutes the docked vehicle (from `attached_vehicle`) for display and skips that vehicle's own internal ports.
- `Render` reads `agg.expandable`, pre-computed by `Pipeline`, never `representative.category.expandIntoTypes`; this keeps `Render` decoupled from `Categories` internals.
