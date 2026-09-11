# Module:WearableSet

Renders an infobox for a wearable set (an undersuit, helmet, core, arms, and legs) by fetching each named piece from the API and summing their protection stats into one combined rating.

Editors use this through `{{Infobox wearable}}` (`{{#invoke:WearableSet|main}}`, not mirrored in this repository).

## For module editors

### API

- `WearableSet.main(frame)`: the sole entry point. Reads `undersuit`, `helmet`, `core`, `arms`, `legs` (each a piece's uuid), `type`, `manufacturer`, `classification`, `sex`, `name`, `image`, `pressurized`; fetches every supplied uuid via [Module:Entity/Data](https://starcitizen.tools/Module:Entity/Data)'s `Data.get`, aggregates their stats, and renders an [Module:InfoboxLua](https://starcitizen.tools/Module:InfoboxLua) infobox.

### Aggregation

- Each piece's ports are read by hardcoded name/type (`wep_stocked_3`/`_2`, `wep_sidearm`, `utility_attach_1`/`_2`, a `Magazine`/`Grenade` sub-type count, an `FPS_Consumable` type count, a `Char_Armor_Backpack` type) (`WearableSet.lua:54-74`); a renamed port on the API side goes uncounted rather than erroring.
- `undersuit`'s ports always count, but its own resistance/temperature/radiation stats are added only when neither `arms` nor `legs` is also supplied; with either present, only its `gforce_resistance` carries over, on the assumption the arm/leg pieces supply the rest (`WearableSet.lua:163-179`). `helmet`, `core`, `arms`, and `legs` always contribute both ports and stats. With no `undersuit` at all, g-force resistance defaults to `0.9` (`WearableSet.lua:178`).
- Across the supplied pieces: resistance and radiation values take the **minimum** (the weakest piece sets the suit's rating); the survivable temperature range narrows to the **intersection** of each piece's min/max; magazine, grenade, and consumable slot counts and EM/IR emissions take the **maximum** (`WearableSet.lua:267-292`). Inventory capacity **sums** across pieces (`WearableSet.lua:121-123`); EVA fuel capacity does not: each piece carrying an EVA Fuel resource container **overwrites** the previous one, so with more than one, only the last piece processed (legs, if supplied) counts (`WearableSet.lua:103-110`).

### Gotchas

- `manufacturer` resolves through `require('Module:Manufacturer'):new():get(...)` (`WearableSet.lua:312`); no module named `Manufacturer` (singular) exists in this repository, only [Module:Manufacturers](https://starcitizen.tools/Module:Manufacturers) (plural, a plain table lookup with no `:new()`/`:get()` object interface). The sentinel values `UNKN` and `NONE` short-circuit before that call and never hit it.
- `type`/`classification` are sentence-cased and linked as typed (`[[<value>]]`); `type == 'Armor set'` also adds `Category:Personal armor`, and `classification == 'Racing suit'` or `'Armored flight suit'` categorizes as `Flight suit` instead of the literal value (`WearableSet.lua:294-334`).
- It calls two [Module:Entity](https://starcitizen.tools/Module:Entity) facets directly, [Module:Entity/Facet/Environment](https://starcitizen.tools/Module:Entity/Facet/Environment) and [Module:Entity/Facet/Armor](https://starcitizen.tools/Module:Entity/Facet/Armor), each with a hand-built `EntityHookContext`-shaped table (`{ apiData = <summed stats>, args = {} }`, `WearableSet.lua:336-349`) rather than one produced by `Module:Entity/Data`'s pipeline. `EntityHookContext` requires only `apiData` and `args`; every other field is nil-safe in pipeline order (`Types.lua:27-40`). WearableSet is not itself an Entity chain link or facet: it has no `matches`, `p.parent`, or Registry entry, and never calls `Data.get`.
- SMW facts are written with its own direct `mw.smw.set` call (`WearableSet.lua:414-426`), not validated against `Module:Entity`'s `properties.json` manifest; the two share no schema.
