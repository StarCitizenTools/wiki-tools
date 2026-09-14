# Module:WearableSet

Renders an infobox for a wearable set (an undersuit, helmet, core, arms, and legs) by fetching each named piece from the API and combining their protection stats into one rating.

Editors use this through `{{Infobox wearable}}` (`{{#invoke:WearableSet|main}}`, not mirrored in this repository).

## For module editors

### API

- `WearableSet.main(frame)`: the sole entry point. Reads `undersuit`, `helmet`, `core`, `arms`, `legs` (each a piece's uuid), `type`, `manufacturer`, `classification`, `sex`, `name`, `image`, `pressurized`; fetches every supplied uuid via [Module:Entity/Data](https://starcitizen.tools/Module:Entity/Data)'s `Data.get`, aggregates their stats, and renders an [Module:InfoboxLua](https://starcitizen.tools/Module:InfoboxLua) infobox.
- `WearableSet.bucketRows(args, processed, values)`: pure. The [Bucket](https://www.mediawiki.org/wiki/Extension:Bucket) rows, `{ entity = {...}, wearable_set = {...} }`, from the same `args`/`processed`/`values` `WearableSet.main` computes, values shaped by `Module:Entity/StructuredData.shape`.

**Data schema**: `properties.json` maps each property to a source key (the `src` table `bucketRows` builds from `args`/`processed`/`values`) and a `bucket`/`field` (the Bucket table and column). `Name`, `Subject type`, `Image` and `Manufacturer` route to the `entity` bucket (shared with Module:Entity and Module:Company); every other property routes to `wearable_set`.

### Aggregation

- Each piece's ports are read by hardcoded name/type (`wep_stocked_3`/`_2`, `wep_sidearm`, `utility_attach_1`/`_2`, a `Magazine`/`Grenade` sub-type count, an `FPS_Consumable` type count, a `Char_Armor_Backpack` type) (`WearableSet.lua:57-77`); a renamed port on the API side goes uncounted rather than erroring.
- `undersuit`'s ports always count, but its own resistance/temperature/radiation stats are added only when neither `arms` nor `legs` is also supplied; with either present, only its `gforce_resistance` is folded in instead, on the assumption the arm/leg pieces supply the rest (`WearableSet.lua:205-221`). `helmet`, `core`, `arms`, and `legs` always contribute both ports and stats. With no `undersuit` at all, g-force resistance defaults to `0.9` (`WearableSet.lua:220`).
- G-force resistance is the one protection stat that **sums** rather than takes the weakest piece: every contributing piece adds its own `gforce_resistance` (`WearableSet.lua:116,216`), and the total feeds [Module:Entity/Facet/Environment](https://starcitizen.tools/Module:Entity/Facet/Environment) as `apiData.gforce_resistance` (`:385`).
- Across the supplied pieces, damage resistance and radiation values take the **minimum** (the weakest piece sets the suit's rating); the survivable temperature range narrows to the **intersection** of each piece's min/max; magazine, grenade, and consumable slot counts and EM/IR emissions take the **maximum** (`WearableSet.lua:309-334`). Inventory capacity **sums** across pieces (`WearableSet.lua:124-126`); EVA fuel capacity does not: each piece carrying an EVA Fuel resource container **overwrites** the previous one, so with more than one, only the last piece processed (legs, if supplied) counts (`WearableSet.lua:106-113`).

### Gotchas

- `manufacturer` resolves through `require('Module:Manufacturer'):new():get(...)` (`WearableSet.lua:354`), an older, OOP-style module (`:new()`/`:get()`) that exists on the live wiki but has no mirror under this repository's `pages/module/`; it is a separate module from [Module:Manufacturers](https://starcitizen.tools/Module:Manufacturers) (plural), the Entity family's own lookup. The sentinel values `UNKN` and `NONE` short-circuit before that call and never hit it.
- `type`/`classification` are sentence-cased and linked as typed (`[[<value>]]`); `type == 'Armor set'` also adds `Category:Personal armor`, and `classification == 'Racing suit'` or `'Armored flight suit'` categorizes as `Flight suit` instead of the literal value (`WearableSet.lua:336-376`).
- It calls two [Module:Entity](https://starcitizen.tools/Module:Entity) facets directly, [Module:Entity/Facet/Environment](https://starcitizen.tools/Module:Entity/Facet/Environment) and [Module:Entity/Facet/Armor](https://starcitizen.tools/Module:Entity/Facet/Armor), each with a hand-built `EntityHookContext`-shaped table (`{ apiData = <combined stats>, args = {} }`, `WearableSet.lua:378-391`) rather than one produced by `Module:Entity/Data`'s pipeline. `EntityHookContext` requires only `apiData` and `args`; every other field is nil-safe in pipeline order (`Types.lua:27-40`). It does call `Data.get` directly, once per named piece (`WearableSet.lua:206,223,232,252,261`); it just isn't itself an Entity chain link or facet: no `matches`, `p.parent`, or Registry entry.
