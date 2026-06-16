# Module:Entity/Item

The Item kind is the dominant branch of the Entity pipeline. It covers every equippable in-game object served by Apiunto's `/items/{uuid}` endpoint — vehicle components (power plants, coolers, shields, quantum drives, flight blades, guns, turrets, racks), personal weapons, attachments, ordnance, mining and salvage equipment, FPS consumables, and habitat flair.

Over [Module:Entity/Base](https://starcitizen.tools/Module:Entity/Base), Item adds the items API endpoint, the size / grade / class / volume structured-data facets, and the community-sites external-link block. Its defining job is **subtype dispatch**: Item resolves the active leaf module from `apiData.type`, letting each subtype contribute its own stats section without Item knowing anything about the stat blocks involved.

Food and Drink are intentionally absent from the subtype mapping. The data-driven consumable facet (`Module:Entity/Facet/Consumable`) handles them entirely, reading the `food` block on any entity that carries it. Their category and subtitle still resolve via `types.json`, so they need no subtype leaf.

## Role in the pipeline

```
Module:Entity/Data
  ↓  kind probe: Item.matches(apiData) — uuid present?
Module:Entity/Item               ← kind module
  ↓  Item.resolveSubtype(apiData) — apiData.type → subtype module
Module:Entity/Item/<Subtype>     ← leaf (replaces Item in the chain)
```

Item is probed first among the registered kinds in [Module:Entity/Registry](https://starcitizen.tools/Module:Entity/Registry). `matches()` returns true whenever Apiunto returned a record with a `uuid` field — the items endpoint never follows the `items → vehicles` 302, so a vehicle UUID probed here returns nil data and `matches` returns false cleanly.

When a subtype resolves, `Module:Entity/Data` uses the subtype module as the chain leaf in place of Item. Hooks on the subtype (`getSections`, `getStructuredData`, `getShortDescription`) are called directly; hooks on Item itself (`getSections`, `getStructuredData`) are called because Item is the subtype's `parent` and the chain walks root-first. This means Item always contributes its General section (Manufacturer / Size / Class / Grade) and its structured-data facets (size, grade, class, item\_type, volume, base\_variant, rarity) regardless of which subtype is active.

## API

### `p.matches(apiData) → boolean`

```lua
--- @param apiData table|nil
--- @return boolean
function p.matches(apiData)
    return apiData ~= nil and apiData.uuid ~= nil
end
```

Positive identification heuristic: `uuid` present. Relies on Apiunto *not* following the items→vehicles 302 redirect — a vehicle UUID through the items endpoint yields nil data, so vehicles never pass this check accidentally. If Apiunto ever changes to follow the redirect, the test `testMatchesVehicleShapedDataCurrentlyReturnsTrue` documents what to tighten.

### `p.getApiConfigs() → EntityApiConfig[]`

Returns a single config targeting `items/%s` with `locale=en_EN` and `include=related_items,blueprints,vehicles,ports`. The `ports` include is required for two consumers: Turret reads the embedded `vehicle_weapon` off the equipped item in a locked gun port (the PDC case), and `Entity/Ports` needs the full port detail (type, editable flag) to render the Ports section correctly.

### `p.resolveSubtype(apiData) → table|nil`

```lua
--- @param apiData table|nil
--- @return table|nil  The resolved subtype module, or nil
function p.resolveSubtype(apiData)
    local subtype = apiData and apiData.type
    if subtype and itemSubtypeMapping[subtype] then
        return require('Module:' .. itemSubtypeMapping[subtype])
    end
    return nil
end
```

Exact-match lookup on `apiData.type` against `itemSubtypeMapping`. Returns the required module table, or nil when the type is absent or unrecognised (meaning Item itself acts as the leaf). See [Subtype dispatch](#subtype-dispatch) and [Gotchas](#gotchas).

### `p.getSections(apiData, args) → table[]`

Contributes one section (`key = 'general'`) with four items: Manufacturer (wikilinked), Size, Class, and Grade. Class and Grade are gated: Class is nil when `apiData.class` is absent or blank; Grade is nil when Class is nil (suppresses the constant grade 'A' that vehicle weapons carry but no class). Volume and the dimension diagram have moved to `Module:Entity/Facet/Dimensions`.

### `p.getStructuredData(apiData, args) → table`

Emits seven flat facet keys for the structured-data backend: `size`, `grade`, `class`, `item_type` (from `description_data`, the in-game "Item Type" label), `volume` (in µSCU — reads `dimension.volume_converted` + `volume_converted_unit`, converting SCU to µSCU; returns nil for unrecognised units rather than guessing), `base_variant` (the `is_base_variant` boolean when present), and `rarity`.

### `p.getShortDescription(apiData, args, typeInfo, prefix) → string`

Entry point for Item-level short descriptions. Tries `formatGradedShortDescription` first; falls back to `formatShortDescription`.

### `p.formatGradedShortDescription(typeInfo, apiData, args) → string|nil`

```lua
--- @return string|nil  e.g. "S3 Gr. A military power plant by Amon & Reese Co."
```

Produces the spec-style descriptor for graded vehicle components — those the API marks with both a `class` (Military / Civilian / Industrial / Competition / …) and a `grade` (A–D). Returns nil when any of class, grade, or size is missing, so the caller falls back to the generic form. Gating on `class` keeps this off vehicle weapons (constant grade 'A', no class) and FPS items (no grade or class).

### `p.formatShortDescription(typeInfo, apiData, args, prefix) → string`

```lua
--- @param prefix string|nil  Adjective to prepend (e.g. an effect name). Auto-cased.
--- @return string  e.g. "Power plant by Amon & Reese Co."
```

Generic item descriptor: `[<prefix> ]<type> [by <manufacturer>]`. Subtypes call this to produce a size-prefixed or signal-typed descriptor rather than returning `typeInfo.name` verbatim.

### `p.getExternalSiteItems(apiData, args) → EntityItemData[]`

Reads `Module:Entity/Item/communitySites.json` and returns a "Community sites" external-link block when any configured site has a URL pattern that resolves for the current item's uuid / name. Returns `{}` when no links resolve.

## Subtype dispatch

`itemSubtypeMapping` is a module-level table in `Item.lua` mapping API `type` strings to module paths relative to `Module:`:

```lua
local itemSubtypeMapping = {
    Module                          = 'Entity/Item/Module',
    Turret                          = 'Entity/Item/Turret',
    WeaponPersonal                  = 'Entity/Item/WeaponPersonal',
    WeaponAttachment                = 'Entity/Item/WeaponAttachment',
    FPS_Consumable                  = 'Entity/Item/FPSConsumable',
    Misc                            = 'Entity/Item/Misc',
    WeaponGun                       = 'Entity/Item/WeaponGun',
    PowerPlant                      = 'Entity/Item/PowerPlant',
    Cooler                          = 'Entity/Item/Cooler',
    Shield                          = 'Entity/Item/Shield',
    QuantumDrive                    = 'Entity/Item/QuantumDrive',
    JumpDrive                       = 'Entity/Item/JumpModule',
    Radar                           = 'Entity/Item/Radar',
    EMP                             = 'Entity/Item/EMP',
    QuantumInterdictionGenerator    = 'Entity/Item/QuantumInterdictionGenerator',
    FlightController                = 'Entity/Item/FlightController',
    Missile                         = 'Entity/Item/Missile',
    WeaponMissile                   = 'Entity/Item/Missile',
    Bomb                            = 'Entity/Item/Bomb',
    MissileLauncher                 = 'Entity/Item/Rack',
    BombLauncher                    = 'Entity/Item/Rack',
    TractorBeam                     = 'Entity/Item/Beam',
    TowingBeam                      = 'Entity/Item/Beam',
    MiningModifier                  = 'Entity/Item/MiningModule',
    WeaponMining                    = 'Entity/Item/WeaponMining',
    SalvageModifier                 = 'Entity/Item/Scraper',
    SalvageHead                     = 'Entity/Item/SalvageHead',
}
```

`resolveSubtype` does an exact case-sensitive match on `apiData.type` and immediately `require`s the resolved path. Adding a new subtype means: (1) write `pages/module/Entity/Item/<Subtype>.lua` with `p.parent = 'Entity/Item'`, (2) add one entry here. The mapping is the only place that wires the API type string to the implementation; `Module:Entity/Data` is oblivious to the details.

## Subtype catalog

One row per unique subtype module; the "API `type` key(s)" column reproduces `itemSubtypeMapping` exactly. The "Kind" column classifies each module's primary nature:

- **stat-block** — reads a named API block and renders its rows as an infobox section.
- **algorithmic** — derives a display value or category from multi-field API logic, not a simple read.
- **routing-shim** — has no stat section of its own. It exists either to route `sub_type` values to a browse category via `getTypeInfo` (WeaponAttachment, FPSConsumable, Misc), or to supply a type-specific `getShortDescription` — typically a size-prefixed form — that the generic Item fallback can't produce (Beam, MiningModule). Any stats come from facets.

| Subtype | API `type` key(s) | API block read | Section rows | SMW keys | Kind | Notes |
|---|---|---|---|---|---|---|
| **Module** | `Module` | `vehicles`, `related_items.set_name` | General: Vehicle(s) | `vehicle` | algorithmic | Vehicle resolution prefers `vehicles[]` relation; falls back to `related_items.set_name`. Multi-vehicle modules carry `vehicles[2..]` names as extra categories. Short desc: "Vehicle module for the \<vehicle\>". |
| **Turret** | `Turret` | `turret` (yaw\_axis, pitch\_axis, mounts) | Turret: Mounts, Yaw speed, Pitch speed; conditionally Weapon (locked gun) | `yaw_speed`, `pitch_speed` | algorithmic | For PDC turrets: finds the first port with `editable == false` and a `vehicle_weapon` block, then delegates to `WeaponGun.getVehicleWeaponSections`. Outer turret-housing types (TMSB-5, ball/nose) leave speed null — falls back to nil rather than reading from the inner gimbal mount. |
| **WeaponPersonal** | `WeaponPersonal` | `personal_weapon` (damage, ammunition, modes, range) | Weapon: Type, Class, Damage, DPS, Ammo, Muzzle velocity, Range; Fire modes | `weapon_class`, `damage_class`, `damage`, `dps`, `muzzle_velocity`, `max_range`, `ammo` | algorithmic | Routes sub\_types Knife/Grenade/Gadget to their own categories via `getTypeInfo`; Gadgets return an empty Weapon section (function is on the tool). Short desc: `S<size> <pw.type lowercase> by <mfr>`. Slated for its own deep doc in a later phase. |
| **WeaponAttachment** | `WeaponAttachment` | — | None | — | routing-shim | Routes sub\_types Magazine → Magazines, IronSight → Optics attachments, Barrel → Barrel attachments, BottomAttachment → Underbarrel attachments, Utility → Multi-Tool attachments. Actual stats come from per-sub\_type facets (Magazine, IronSight, WeaponModifier, etc.). |
| **FPSConsumable** | `FPS_Consumable` | — | None | — | routing-shim | Routes Medical / MedPack / OxygenCap → Medical consumables, Hacking → Cryptokeys. Stats rendered by Medical / Hacking / Consumable facets. |
| **Misc** | `Misc` | — | None | — | routing-shim | Routes sub\_type `Flair_Wall_Picture` → Wall flair category (otherwise types.json generic Misc mapping misroutes wall pictures). All other sub\_types fall through to types.json. |
| **WeaponGun** | `WeaponGun` | `vehicle_weapon` (damage, ammunition, modes, rpm, range, capacity) | Weapon: Type, Damage, DPS, Fire rate, Fire mode, Range, Speed, Ammo | `dps`, `alpha_damage`, `max_range`, `muzzle_velocity`, `fire_rate`, `ammo`, `damage_type`, `firing_type` | algorithmic | Parses the gun's `class_name` segment + `vehicle_weapon.type` label to derive two independent facets: `damage_type` (Ballistic / Energy / Distortion / …) and `firing_type` (Cannon / Repeater / Gatling / …) via a curated list in `weaponClasses.json`. Short desc: `S<size> <damage_type> <firing_type lowercase> by <mfr>`. `getVehicleWeaponSections` is a public helper consumed by Turret for its locked-gun case. Slated for its own deep doc. |
| **PowerPlant** | `PowerPlant` | `power_plant` (power\_output, power\_segment\_generation) | Power plant: Power output (when non-null), Power | `power_output`, `power_generation` | stat-block | `power_output` is null game-wide in the current resource-network model; row appears automatically when CIG repopulates it. Common component stats come from the Component facet. |
| **Cooler** | `Cooler` | `cooler` (cooling\_rate, coolant\_segment\_generation) | Cooler: Cooling rate (when non-null), Cooling | `cooling_rate`, `coolant_generation` | stat-block | Mirrors the PowerPlant pattern: `cooling_rate` is currently null; `coolant_segment_generation` is the active stat. Component facet renders shared hardware stats. |
| **Shield** | `Shield` | `shield` (max\_health, regen\_rate, regen\_delay, absorption, resistance) | Shield: HP, Regeneration, Regen delay, Downed delay, Absorption, Resistance | `shield_health`, `shield_regeneration`, `shield_regen_delay` | stat-block | Absorption row shows only damage types with partial shield penetration (max < 1); Resistance row shows types with any reduction (max > 0). Both are compact "Type X%", joined with " · ". Component facet renders hardware stats. |
| **QuantumDrive** | `QuantumDrive` | `quantum_drive` (standard\_jump: drive\_speed / \_formatted, spool\_up\_time, cooldown\_time; quantum\_fuel\_requirement) | Quantum drive: Quantum speed, Spool time, Cooldown, Fuel requirement | `quantum_speed` (Mm/s), `quantum_spool_time`, `quantum_cooldown`, `quantum_fuel_requirement` | stat-block | Uses `standard_jump` only (the primary interplanetary mode); `spline_jump` is omitted from headline rows. Speed prefers `drive_speed_formatted`; falls back to raw m/s → Mm/s conversion. Stored in Mm/s. |
| **JumpModule** | `JumpDrive` | `jump_drive` (alignment\_rate, tuning\_rate, fuel\_usage\_efficiency\_multiplier) | Jump module: Alignment rate, Tuning rate, Fuel usage multiplier | `jump_alignment_rate`, `jump_tuning_rate`, `jump_fuel_usage_multiplier` | stat-block | Note the API `type` is `JumpDrive` (the underlying hardware), not `JumpModule`. Component facet renders hardware stats. |
| **Radar** | `Radar` | `radar` (sensitivity: infrared, resource; cooldown, aim\_assist.distance\_max\_assignment) | Radar: Sensitivity, Resource sensitivity, Cooldown, Aim assist range | `radar_sensitivity`, `radar_resource_sensitivity`, `radar_cooldown`, `radar_aim_assist_range` | stat-block | IR / cross-section / EM share one sensitivity rating; infrared is representative. Sensitivity rendered as percentage (0..1 → %). Component facet renders hardware stats. |
| **EMP** | `EMP` | `emp` (emp\_radius, distortion\_damage, charge\_duration, unleash\_duration, cooldown\_duration) | EMP: Radius, Distortion damage, Charge time, Duration, Cooldown | `emp_radius`, `emp_distortion_damage`, `emp_charge_time`, `emp_duration`, `emp_cooldown` | stat-block | Component facet renders hardware stats. |
| **QuantumInterdictionGenerator** | `QuantumInterdictionGenerator` | `quantum_interdiction_generator` (pulse: radius, charge\_time, discharge\_time, cooldown\_time; jamming.range) | Quantum interdiction: Mode, Snare range, Dampener range, Charge time, Duration, Cooldown | `qig_mode`, `qig_snare_range`, `qig_dampener_range`, `qig_charge_time`, `qig_duration`, `qig_cooldown` | algorithmic | Derives wiki device class (QED / QDMP / QID) from the API: `pulse.radius > 1 m` = can snare (`radius == 1` is the "no snare" placeholder); `jamming.range > 0` = can dampen. QED = snare + dampener, QDMP = dampener only, QID = snare only. Short desc uses the full subdivision name ("Quantum enforcement device", "Quantum dampener", "Quantum interdiction device") instead of the umbrella type. |
| **FlightController** | `FlightController` | `flight_controller` (scm\_speed, boost\_speed\_forward, max\_speed, pitch/yaw/roll + \_boosted) | Flight performance: SCM speed (boost), Max speed, Pitch, Yaw, Roll | `scm_speed`, `boost_speed`, `max_speed`, `pitch`, `pitch_boosted`, `yaw`, `yaw_boosted`, `roll`, `roll_boosted` | stat-block | Boosted values are formatted as `base (boosted) unit`, e.g. "226 (520) m/s". No Component facet — flight blades have no durability block. |
| **Missile** | `Missile`, `WeaponMissile` | `missile` (signal\_type, damage\_total, explosion\_radius\_{min,max}, lock\_{time,range\_min/max,angle}, speed; flight.range) | Missile or Torpedo: Signal type, Damage, Explosion radius, Lock time, Lock range, Lock angle, Speed, Range | `signal_type`, `warhead_damage`, `explosion_radius`, `lock_time`, `lock_range`, `lock_angle`, `missile_speed`, `missile_range` | algorithmic | Two API `type`s route here: `Missile` (standard) and `WeaponMissile` (legacy). Torpedoes share the `missile` block: they arrive as `type=Missile, sub_type=Torpedo`; the stat section label switches to "Torpedo" on that sub\_type; their category routes via `classifications.json`. Lock signal type is normalised from CamelCase (`CrossSection` → `Cross Section`). Short desc surface signal type as the specific kind: "S1 infrared missile by Behring". |
| **Bomb** | `Bomb` | `bomb` (damage\_total, explosion\_radius\_{min,max}, arm\_time, maximum\_drop\_angle; nested under `explosion` / `delays` fallbacks) | Bomb: Damage, Explosion radius, Arm time, Drop angle | `warhead_damage`, `explosion_radius`, `arm_time`, `drop_angle` | stat-block | Unguided, so no signal/lock block. Radii and arm time have dual API locations (`bomb.*` top-level or `bomb.explosion.*` / `bomb.delays.*`); both paths checked. Fractional damage totals (API) rounded to whole numbers. Component facet fires. |
| **Rack** | `MissileLauncher`, `BombLauncher` | `missile_rack` (missile\_count, missile\_size) or top-level `max_bombs` + `max_size` | Missile rack or Bomb launcher: Capacity ("N × S\<size\>") | `capacity_count`, `capacity_size` | algorithmic | Two API `type`s share one module. MissileLauncher reads `missile_rack.missile_count/size`; BombLauncher reads top-level `max_bombs/max_size`. Section label and short desc noun are dynamically switched on `apiData.type`. Component facet fires. |
| **Beam** | `TractorBeam`, `TowingBeam` | — | None | — | routing-shim | Beam STATS (force, range, max angle, tether break, heavy-lift) live in `Module:Entity/Facet/Beam`, which fires on any entity with a `tractor_beam` block — this covers FPS handheld tractor beams as well. The subtype exists only to produce the size-prefixed short description ("S1 tractor beam by Greycat"). |
| **MiningModule** | `MiningModifier` | — | None | — | routing-shim | Stats rendered by `Module:Entity/Facet/Mining`. Short desc only: `S<size> mining module by <mfr>`. Component facet renders hardware stats. |
| **WeaponMining** | `WeaponMining` | `mining_laser` (laser\_power, module\_slots, optimal/maximum\_range, extraction\_throughput, modifier\_map) | Mining laser: Mining power, Module slots, Optimal range, Maximum range, Extraction rate, then each `modifier_map` effect as a signed % | `mining_power_min`, `mining_power_max`, `module_slots`, `optimal_range`, `maximum_range`, `extraction_throughput`, `modifier_<effect>` (dynamic) | stat-block | `modifier_map` is variable per head; all keys are sorted and rendered as signed percentages. The same effect vocabulary as MiningModule, so heads and modules compare directly. Component facet fires. |
| **Scraper** | `SalvageModifier` | `salvage_modifier` (salvage\_speed\_multiplier, radius\_multiplier, extraction\_efficiency) | Salvage: Salvage speed, Radius, Extraction efficiency | `salvage_speed_multiplier`, `radius_multiplier`, `extraction_efficiency` | stat-block | Speed and radius multipliers are colour-coded: green above ×1 (better), red below (worse), uncoloured at ×1 (neutral ReadyGrip). Efficiency displayed as a percentage. Component facet renders hardware stats where present (the ReadyGrip variant has no durability block). |
| **SalvageHead** | `SalvageHead` | `vehicle_weapon.range` | Salvage: Range | `beam_range` | stat-block | Range is read from `vehicle_weapon.range` (the vehicle-weapon block, not a dedicated salvage block). Full salvage stats (material efficiency, repair rates, ramp times) come from `Module:Entity/Facet/Salvage`, which fires on any entity with a Salvage fire mode. Both share `key = 'salvage'`, so the Range row prepends and the facet's rows follow. Component facet fires. |

## Gotchas

**`resolveSubtype`'s `require` is unguarded.** The lookup is an exact string match; if the module path in `itemSubtypeMapping` is misspelled (e.g. `'Entity/Item/PowerPlatn'`), `require` throws a module-not-found error, crashing the infobox for every page of that API type on the live wiki. There is no fallback. Test new entries in a sandbox before deploying.

**Exact-match on `apiData.type` — no partial matching, no fallback chain.** A type string that slightly differs from the key (different capitalisation, an underscore vs. no underscore) silently returns nil from `resolveSubtype`, meaning Item itself acts as the leaf with no subtype stats. If CIG renames a type in the API, the mapping entry must be updated.

**Stats shared across multiple API `type`s must be a facet, not a subtype.** Subtypes are single-type (one `type` key → one module). When a stat block appears on items of different API types — for example, the `tractor_beam` block appears on both `TractorBeam` and `TowingBeam` items, and also on FPS handheld tractor beams (a different `type` entirely) — a subtype cannot cover all cases. The right tool is a data-driven facet that fires on the presence of the block regardless of type. `Module:Entity/Facet/Beam` is the canonical example: Beam tractor-beam stats live there, and the Beam subtype is a routing-shim that delegates to it. See [Module:Entity/Registry](https://starcitizen.tools/Module:Entity/Registry) for the facet catalog.

**Food / Drink exclusion is explicit, not accidental.** The test `testResolveSubtypeFoodReturnsNil` and `testResolveSubtypeDrinkReturnsNil` document this choice. If those types are ever added to `itemSubtypeMapping`, the consumable facet path breaks.

**`WeaponMissile` is a legacy alias.** Both `Missile` and `WeaponMissile` map to the same `Missile` module. If CIG drops `WeaponMissile` from the API, remove the entry — it does nothing if no item has that type string.

**Volume precision.** `getVolume` reads `volume_converted` + `volume_converted_unit` rather than the raw `dimension.volume` field, which rounds sub-SCU items (like a 1 µSCU PDC) to zero. Missing `volume_converted_unit` is treated as SCU (the API default). An unrecognised unit returns nil rather than silently converting wrong.

## Tests

`testcases.lua` is a ScribuntoUnit suite covering `matches`, `resolveSubtype`, `getStructuredData`, `classContent`, `gradeContent`, `formatGradedShortDescription`, `getItemType`, and `getVolume`. It runs on-wiki via `Module:ScribuntoUnit`; deploy before running. It does not run in local CI.

Notable coverage: `testMatchesVehicleShapedDataCurrentlyReturnsTrue` documents the current permissive `matches` heuristic and what to tighten if Apiunto ever follows the items→vehicles redirect.

## Architecture

```
Entity/Item/
├── Item.lua                         # Kind module: hooks, dispatch table, shared helpers
├── testcases.lua                    # ScribuntoUnit suite
├── communitySites.json              # External-site link definitions
├── types.json                       # API type → category / display name fallback map
├── classifications.json             # classification path → { name, category }
│
├── Module.lua                       # Vehicle module (type=Module)
├── Turret.lua                       # Turret / gimbal mount / PDC
├── WeaponPersonal.lua               # FPS personal weapon
├── WeaponAttachment.lua             # Weapon attachment (routing shim)
├── FPSConsumable.lua                # FPS consumable (routing shim)
├── Misc.lua                         # Misc catch-all (routing shim)
├── WeaponGun.lua                    # Vehicle gun
├── PowerPlant.lua                   # Power plant
├── Cooler.lua                       # Cooler
├── Shield.lua                       # Shield generator
├── QuantumDrive.lua                 # Quantum drive
├── JumpModule.lua                   # Jump module (type=JumpDrive)
├── Radar.lua                        # Radar
├── EMP.lua                          # EMP generator
├── QuantumInterdictionGenerator.lua # QIG / QED / QDMP / QID
├── FlightController.lua             # Flight blade
├── Missile.lua                      # Missile + Torpedo (type=Missile or WeaponMissile)
├── Bomb.lua                         # Bomb
├── Rack.lua                         # Missile rack + Bomb launcher
├── Beam.lua                         # Tractor/towing beam (routing shim)
├── MiningModule.lua                 # Mining module (routing shim, type=MiningModifier)
├── WeaponMining.lua                 # Mining laser head
├── Scraper.lua                      # Scraper module (type=SalvageModifier)
└── SalvageHead.lua                  # Salvage head
```

All subtype modules declare `p.parent = 'Entity/Item'` so the chain walker in [Module:Entity/Base](https://starcitizen.tools/Module:Entity/Base) finds Item as the next link. Each module is a pure Lua table; no side effects on load.
