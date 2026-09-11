# Module:Entity/Item

The Item kind covers every equippable object served by Apiunto's `/items/{uuid}` endpoint: vehicle components, personal weapons, attachments, ordnance, mining and salvage gear, FPS consumables, and habitat flair. Item resolves a subtype leaf from the API `type` string; Food and Drink have none, so their stats come from the data-driven [Module:Entity/Facet/Consumable](https://starcitizen.tools/Module:Entity/Facet/Consumable) instead, while their label and browse category still resolve through `types.json` like any other unmapped type.

Editors never invoke this module directly; it runs inside [Template:Entity](https://starcitizen.tools/Template:Entity), [Template:Vehicle](https://starcitizen.tools/Template:Vehicle) and [Template:Location](https://starcitizen.tools/Template:Location); the pipeline and the hook table are on [Module:Entity](https://starcitizen.tools/Module:Entity).

## For module editors

### API

- `p.matches(apiData) → boolean`: `apiData.uuid` and `apiData.class_name` present, `apiData.is_vehicle` absent.
- `p.getApiConfigs() → EntityApiConfig[]`: one config, `items/%s` with `include=related_items,blueprints,vehicles,ports`; `ports` is required so Turret can read a locked equipped gun's embedded `vehicle_weapon`, and so [Module:Entity/Ports](https://starcitizen.tools/Module:Entity/Ports) gets full port detail.
- `p.resolveSubtype(apiData, args) → module|nil`: hands `apiData.type` and `itemSubtypeMapping` to [Module:Entity/SubtypeResolver](https://starcitizen.tools/Module:Entity/SubtypeResolver); `nil` for an unmapped or missing type means Item itself stays the leaf.
- `p.getSections(ctx) → table[]`: one `general` section with Manufacturer, Size, Class, Grade. Class is `nil` when `apiData.class` is absent or blank; Grade is `nil` whenever Class is, which suppresses the constant grade `A` that vehicle weapons otherwise carry.
- `p.getStructuredData(ctx) → table`: `size`, `grade`, `class`, `item_type` (the in-game "Item Type" description-data label), `volume` (µSCU, from `volume_converted` / `volume_converted_unit`; `nil` for an unrecognised unit rather than guessing), `base_variant`, `rarity`.
- `p.getShortDescription(ctx) → string`: `formatGradedShortDescription` first, else `formatShortDescription`.
- `p.formatGradedShortDescription(typeInfo, apiData, args) → string|nil`: the spec-style form, e.g. "S3 Gr. A military power plant by Amon & Reese Co.", only when `class`, `grade`, and `size` are all present.
- `p.formatShortDescription(typeInfo, apiData, args, prefix) → string`: the generic `[<prefix> ]<type> [by <manufacturer>]` form; subtypes call this to build a size-prefixed or type-specific descriptor.
- `p.getExternalSiteItems(ctx) → EntityItemData[]`: a "Community sites" link block from `communitySites.json`, when any configured site's URL pattern resolves for the item's uuid or name.
- `p.getAcquisition(ctx) → { summary, cards }`: Buy / Loot / Craft / Pledge flags (Rent appears only when an editor sets it) and a single Shops terminal card from `uex_prices.purchase`. Runs for every item page regardless of subtype: no Item subtype defines its own `getAcquisition`.

### Subtype catalog

`itemSubtypeMapping`, API `type` key to subtype module (all under `Module:Entity/Item/`):

| API `type` | Module |
|---|---|
| `Module` | Module |
| `Turret` | Turret |
| `WeaponPersonal` | WeaponPersonal |
| `WeaponAttachment` | WeaponAttachment |
| `FPS_Consumable` | FPSConsumable |
| `Misc` | Misc |
| `WeaponGun` | WeaponGun |
| `PowerPlant` | PowerPlant |
| `Cooler` | Cooler |
| `Shield` | Shield |
| `QuantumDrive` | QuantumDrive |
| `JumpDrive` | JumpModule |
| `Radar` | Radar |
| `EMP` | EMP |
| `QuantumInterdictionGenerator` | QuantumInterdictionGenerator |
| `FlightController` | FlightController |
| `Missile`, `WeaponMissile` | Missile |
| `Bomb` | Bomb |
| `MissileLauncher`, `BombLauncher` | Rack |
| `TractorBeam`, `TowingBeam` | Beam |
| `MiningModifier` | MiningModule |
| `WeaponMining` | WeaponMining |
| `SalvageModifier` | Scraper |
| `SalvageHead` | SalvageHead |

### Extending

A new subtype: write `pages/module/Entity/Item/<Subtype>.lua` with `p.parent = 'Entity/Item'` and its rendering hooks (`getTypeInfo` and/or `getShortDescription` and/or `getSections`, as needed), then add one `type key = 'Entity/Item/<Subtype>'` entry to `itemSubtypeMapping`. A stat block that can appear on more than one API `type`, or on an FPS item of a different type entirely, belongs in a facet keyed on the block's presence instead of in a subtype; see [Module:Entity/Registry](https://starcitizen.tools/Module:Entity/Registry).

### Gotchas

- The `class_name` discriminator: items and vehicles both carry `class_name`, so `matches` also excludes `apiData.is_vehicle`, the one field vehicles carry and items never do. A bare "has a uuid" test would claim both kinds.
- The subtype `require` is unguarded: a misspelled path in `itemSubtypeMapping` throws a module-not-found error for every page of that API type, live, with no fallback.
- The lookup is an exact, case-sensitive match on `apiData.type`; a renamed or differently-cased API type silently resolves to `nil`, and Item itself renders as the leaf with no subtype stats.
- `WeaponMissile` and `Missile` both resolve to the same module; either key can be dropped once no item carries that API type string.
