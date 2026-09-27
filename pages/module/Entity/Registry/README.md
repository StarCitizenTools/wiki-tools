# Module:Entity/Registry

The declarative list of every Entity kind and facet: `p.kinds` is probed in order to resolve a page's primary kind, `p.facets` are matched additively regardless of which kind matched. Registering either is one entry here, the component module itself, and a passing conformance test.

Editors never invoke this module directly; it runs inside [Template:Entity](https://starcitizen.tools/Template:Entity), [Template:Vehicle](https://starcitizen.tools/Template:Vehicle) and [Template:Location](https://starcitizen.tools/Template:Location); the pipeline and the hook table are on [Module:Entity](https://starcitizen.tools/Module:Entity).

## For module editors

### Catalog

`p.kinds`, probed in this order until one matches: `Item`, `Vehicle`, `Commodity`, `Mission`, `Location`. Order is a probe-cost optimisation only (Item dominates the page mix, so it goes first): the declared-`kind` gate can hand any kind's `matches()` a record belonging to a different kind, so each `matches()` must stand on its own regardless of position.

`p.facets`, matched additively in registration order; a single page can match several at once. Each facet entry lists as `keys` the top-level record fields its match condition reads, and a facet loads only on a record carrying one of them.

| Facet | Match condition | Section key(s) |
|---|---|---|
| Consumable | `apiData.food ~= nil` | `consumable` |
| Seat | `type(apiData.seat) == 'table'` | `seat` |
| Knife | `apiData.melee_weapon` or `apiData.knife` is a table | `melee` |
| Grenade | `type(apiData.grenade) == 'table'` | `grenade` |
| Gadget | `apiData.sub_type == 'Gadget'` | `gadget` |
| Salvage | a `Salvage`-type mode in `vehicle_weapon.modes` or `personal_weapon.modes` | `salvage` |
| Heal | a `healingbeam`-type mode in `personal_weapon.modes` or `vehicle_weapon.modes` | `heal` |
| Medical | `type(apiData.medical) == 'table'` | `medical` |
| Hacking | `type(apiData.hacking_chip) == 'table'` | `hacking` |
| WeaponModifier | `type(apiData.weapon_modifier) == 'table'`, and no `mining_modifier` block | `weapon_modifier` |
| IronSight | `type(apiData.iron_sight) == 'table'` | `iron_sight` |
| Magazine | `type(apiData.magazine) == 'table'` | `magazine` |
| LaserPointer | `type(apiData.laser_pointer) == 'table'` | `laser_pointer` |
| Flashlight | `type(apiData.flashlight) == 'table'` | `flashlight` |
| Mining | `type(apiData.mining_modifier) == 'table'` | `mining` |
| Beam | `type(apiData.tractor_beam) == 'table'` | `tractor_beam` |
| Armor | `type(apiData.suit_armor) == 'table'` | `armor` |
| Environment | `type(apiData.temperature_resistance) == 'table'` | `environment` |
| DamageFalloff | `personal_weapon` or `vehicle_weapon` has meaningful damage falloff | the weapon block's own key (`personal_weapon` or `vehicle_weapon`) |
| Inventory | `apiData.inventory` has a positive computed capacity | `inventory` |
| Component | `type(apiData.durability) == 'table'` | `component` |
| Dimensions | `apiData.dimension.dimensions` or `.cargo_dimension` is a drawable box | `dimensions` |

### Extending

A new kind implements `matches` and `getApiConfigs` (required), a string `p.name` (required per `Contract.KIND_FIELDS`; non-empty and unique across `p.kinds` per the registry's own tests), and optionally `resolveSubtype`, then gets a `p.kinds` entry holding its `name`, a `load = function() return require('Module:Entity/<Name>') end`, and as `api` a copy of its `getApiConfigs()[1]`. The probe fetches that endpoint before loading the kind and loads it only when a non-empty record comes back, so a location page never loads Vehicle. A new facet implements `matches` and `getSections` (required), then gets a `p.facets` entry with the same `load` shape and `keys`, the top-level record fields its `matches` reads; reach for the shared helpers in [Module:Entity/Facet/Util](https://starcitizen.tools/Module:Entity/Facet/Util) (`withUnit`, `rangeStr`, `titleCase`, `DAMAGE_TYPES`) rather than re-implementing display logic, and render yes/no rows through [Module:Boolean](https://starcitizen.tools/Module:Boolean) so they match the house convention. See [Module:Entity/Contract](https://starcitizen.tools/Module:Entity/Contract) for the full hook spec.

The registry's test suite (`testcases.lua` beside this module in the repository, run by `mise run test`) loads every entry and checks it: `Contract.validate(component, KIND or FACET, { strict = true })`, `Contract.validateFields(kind, KIND_FIELDS)` for kinds, a kind entry's `name` and `api` against its module's own `p.name` and `getApiConfigs()[1]`, that no kind claims `nil` or `{}`, and name uniqueness. A new facet also needs a record its `matches` accepts in the suite's `FACET_MATCH_FIXTURES`, one per field it reads: the suite fails when such a record still matches with every gate key removed, which is how a missing key is caught.

### Gotchas

- Keep each `load` a literal `require('Module:…')` inside its function. A page records every module it loads as a dependency and re-parses when one changes, so a require moved to load time re-parses every Entity page on each edit to that module. [Module:Dependencies](https://starcitizen.tools/Module:Dependencies) reads requires from source text and records nothing for a computed name, so `require(entry.page)` would list the kinds and facets as unused.
- Subtypes are not registered here: dispatch is kind-internal (Item's `itemSubtypeMapping`, Vehicle's `VEHICLE_FAMILY_MAP`). See [Module:Entity/Item](https://starcitizen.tools/Module:Entity/Item) and [Module:Entity/Vehicle](https://starcitizen.tools/Module:Entity/Vehicle).
- A facet that adds items under a key a chain link already owns (DamageFalloff into `personal_weapon`/`vehicle_weapon`) renders at that key's position in the infobox, set by the chain link, not by the facet's own place in `p.facets`: chain sections are merged before facet sections.
