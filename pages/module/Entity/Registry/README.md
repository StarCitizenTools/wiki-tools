# Module:Entity/Registry

The single declarative home for every Entity kind and facet. Registering one is a one-line edit here, plus the module file itself and a passing conformance test; no other file changes. `Module:Entity/Data` reads `registry.kinds` for endpoint discovery and `registry.facets` for additive detection, and the [Module:Entity/Registry/testcases](https://starcitizen.tools/Module:Entity/Registry/testcases) suite runs `Contract.validate` over whatever is in those lists automatically.

**Subtypes** are intentionally NOT registered here. Subtype dispatch is a kind-internal concern owned by each kind's `resolveSubtype` function. Both `Module:Entity/Item` (via its `itemSubtypeMapping` table) and `Module:Entity/Vehicle` (its `Ship` / `GroundVehicle` / `Gravlev` family leaves) dispatch this way, which is why their leaves aren't registered alongside the kinds below. See [Module:Entity/Item](https://starcitizen.tools/Module:Entity/Item) and [Module:Entity/Vehicle](https://starcitizen.tools/Module:Entity/Vehicle).

## Role in the pipeline

```
[contributor adds kind/facet]
        │
        ▼
  Registry.lua ──────────────────────────────┐
  p.kinds  (probe order)                     │ registry/testcases
  p.facets (additive detection order)        │ → Contract.validate
        │                                    └────────────────────
        ▼
  Module:Entity/Data
  ├── probe registry.kinds in order
  │     → first match wins; resolves API endpoint + enrichment
  └── scan registry.facets in order
        → each whose matches(apiData) is true contributes sections additively
```

[`Module:Entity/Data`](https://starcitizen.tools/Module:Entity/Data) is the only consumer of Registry at render time. It probes `registry.kinds` to resolve the primary kind (and thus the infobox template, API configs, and short description), then independently walks `registry.facets` to attach every matching additive section, regardless of which kind matched.

## Kinds

```lua
p.kinds = {
    require('Module:Entity/Item'),
    require('Module:Entity/Vehicle'),
    require('Module:Entity/Commodity'),
    require('Module:Entity/Mission'),
}
```

Kinds are probed **in order**: the first kind whose `matches(apiData)` returns true is selected as the primary kind for that page. Order therefore encodes precedence.

`Item` is listed first because it dominates the page mix: most wiki pages are items, so placing Item first short-circuits the probe on the most common case and avoids three wasted endpoint calls. `Vehicle` follows because ships and vehicles are the second-largest population. `Commodity` and `Mission` are narrow types that fail quickly on the common-case frames that reach them, so their position at the tail has negligible cost.

A kind contributes a full set of lifecycle hooks: `getApiConfigs` (required, defines what to fetch), `matches` (required, identity probe), and optionally `resolveSubtype`, `enrich`, `getTypeInfo`, `getSections`, `getStructuredData`, `getShortDescription`, and `getExternalSiteItems`. See [Module:Entity/Contract](https://starcitizen.tools/Module:Entity/Contract) for the full required/optional split.

## Facets

```lua
p.facets = {
    require('Module:Entity/Facet/Consumable'),
    -- … 21 more, in registration order
}
```

Facets are **additive**: after the primary kind is resolved, every facet whose `matches(apiData)` returns true contributes its section to the infobox, independently of the kind and of each other. A single entity can match ten facets simultaneously.

Registration order matters: when two facets emit sections under *different* keys, their order in `p.facets` is the order their sections appear in the merged infobox. A facet that injects into an *existing* key (e.g. DamageFalloff appending a chart item into the `personal_weapon` key) renders at the key owner's position, not its own.

A facet must implement `matches(apiData)` (required) and `getSections(apiData, args)` (required), and optionally `getStructuredData`, `getShortDescriptionPrefix`. See [Module:Entity/Contract](https://starcitizen.tools/Module:Entity/Contract).

When you build a facet's rows, reach for the shared helpers in [`Module:Entity/Facet/Util`](https://starcitizen.tools/Module:Entity/Facet/Util) rather than re-implementing display logic: `withUnit(value, unit)`, `rangeStr(min, max, unit)`, `titleCase(key)`, and the canonical `DAMAGE_TYPES` order (with `damageKeys` / `damageLabels` views). These were extracted from the individual facets, so their output is byte-identical to the per-facet originals. Boolean (yes / no) fields render through [`Module:Boolean`](https://starcitizen.tools/Module:Boolean) `render()`, a tri-state yes / no / unknown icon (No is grey, not red), so a new boolean row matches the house convention used by Consumable and Seat.

## Facet catalog

All 22 registered facets, in registration order. The columns read as:

- **Matches on**: the `apiData` field or condition that `matches()` tests.
- **Section rows / output**: what `getSections` renders ("custom HTML via `<primitive>`" for chart/bar/tile facets).
- **SMW keys**: the keys returned by `getStructuredData`, or "—" when absent.
- **Short-desc prefix**: whether the facet implements `getShortDescriptionPrefix`.

| # | Facet | Matches on (`apiData` field) | Section rows / output | SMW keys | Short-desc prefix | Notes |
|---|---|---|---|---|---|---|
| 1 | **Consumable** | `apiData.food ~= nil` | NDR, HEI, Effects (coloured `DietaryEffect` badges), Single use, Reclosable (both tri-state `Boolean` icons) | `ndr`, `hei`, `effects` | Yes, food effects joined with Oxford-comma "and" (e.g. "Stimulant and Healing") | Covers both Food and Drink; `can_be_reclosed` row collapses for food, appears for drink, no kind branching needed |
| 2 | **Seat** | `type(apiData.seat) == 'table'` | Yaw (±° range), Pitch (±° range), Ejection seat (tri-state `Boolean` icon) | `yaw`, `pitch`, `yaw_min`, `yaw_max`, `pitch_min`, `pitch_max` | — | For manned turrets and cockpit seats; `has_ejection` rendered only, not stored as SMW |
| 3 | **Knife** | `apiData.melee_weapon` or `apiData.knife` (table) | Damage (collapsed to one row when slash=stab), Takedown | `slash_damage`, `stab_damage` | — | Block key is `melee_weapon` with `knife` as fallback; covers any future melee weapon data-driven |
| 4 | **Grenade** | `type(apiData.grenade) == 'table'` | Damage type, Damage, Blast radius (min–max m) | `damage`, `damage_type`, `blast_radius` | — | Collapses to empty for flares/light sticks whose grenade block is all-null |
| 5 | **Gadget** | `apiData.sub_type == 'Gadget'` | Type, Range (m, suppressed when Beam facet also matches), Capacity | `max_range` | — | Only facet that matches on `sub_type` rather than a data block; Range row deferred to Beam facet when `tractor_beam` block is present |
| 6 | **Salvage** | `mode.type == 'Salvage'` found in `vehicle_weapon.modes` or `personal_weapon.modes` | Material efficiency (%), Health repair rate, Damage repair rate, Health-to-ammo ratio, Ramp up / down (s), Max vehicle damage (%), Repaired material (%) | `material_efficiency`, `health_repair_rate`, `damage_repair_rate`, `ramp_up_time`, `ramp_down_time` | — | Cross-kind: fires on both vehicle salvage heads and FPS salvage tools; when a SalvageHead subtype contributes a Range row under the same `salvage` key, its rows appear first |
| 7 | **Heal** | `mode.type == 'healingbeam'` found in `personal_weapon.modes` or `vehicle_weapon.modes` | Healing rate (/s), Range (m), Sensor range (m) | — | — | No `getStructuredData`; first healing-beam mode taken when twin Heal/SelfHeal modes are present |
| 8 | **Medical** | `type(apiData.medical) == 'table'` | Blood drug level, Combat buffs, Impact resistances, Debuffs | `blood_drug_level` | — | For injector pens (type FPS_Consumable, sub_type Medical/MedPack); OxyPen uses `food` block → Consumable facet instead |
| 9 | **Hacking** | `type(apiData.hacking_chip) == 'table'` | Charges, Hack time (×multiplier, coloured lower-is-better), Error chance (%) | `charges`, `error_chance` | — | Hack-time row collapses when multiplier == 1 (no modification) |
| 10 | **WeaponModifier** | `type(apiData.weapon_modifier) == 'table'` | Magnification, Fire rate ×, Damage ×, Damage over time ×, Projectile speed ×, Ammo cost ×, Heat generation ×, Sound radius ×, Charge time ×, Recoil ×, Recoil recovery ×, Spread ×, Spread recovery ×, ADS time × | `magnification` (only when >1×) | — | Every multiplier coloured green/red by good direction; rows collapse when value == 1 (no-op); guns do NOT carry this block |
| 11 | **IronSight** | `type(apiData.iron_sight) == 'table'` | Max range (m), Range increment (m), Auto-zeroing (s) | `max_range`, `range_increment` | — | Optical magnification is NOT here: it is owned by WeaponModifier; a scope shows zoom under "Modifier" and ranging under "Sight" |
| 12 | **Magazine** | `type(apiData.magazine) == 'table'` | Capacity, Velocity (m/s), Range (m), Damage (type-tagged), Explosion radius (m range) | `ammo`, `muzzle_velocity`, `max_range`, `damage` | — | Branches on `impact_damage_map` vs `detonation_damage_map`; Capacity collapses when `max_ammo_count` is 0 (missile mags) |
| 13 | **LaserPointer** | `type(apiData.laser_pointer) == 'table'` | Range (m) | `laser_range` | — | Colour field present in API block but deferred (usually null) |
| 14 | **Flashlight** | `type(apiData.flashlight) == 'table'` | One row per named light mode: beam type + radius (m), sorted by `port_name` | — | — | No `getStructuredData`; multi-mode lights render one row each |
| 15 | **Mining** | `type(apiData.mining_modifier) == 'table'` | Type, Power (signed %, coloured by sign), Charges, Duration (s), then each `modifier_map` key as a signed % | `mining_type`, `power_modifier`, `charges`, `duration`, plus `modifier_<key>` for each `modifier_map` entry | — | Auto-titles snake_case modifier keys; new map effects surface without code changes; plain rows (no custom-HTML primitive) |
| 16 | **Beam** | `type(apiData.tractor_beam) == 'table'` | Force (N), Tow force or Cargo force (N, vehicle-only heavy-lift), Range (m), Max angle (°), Tether break time (s) | `beam_force`, `beam_mode_force`, `beam_range`, `beam_max_angle`, `beam_tether_break` | — | Section label adapts: "Towing beam" for TowingBeam type, "Tractor beam" otherwise; FPS beams suppress the heavy-lift row (sentinel value) |
| 17 | **Armor** | `type(apiData.suit_armor) == 'table'` | Custom HTML via `Module:ProgressTiles`: one tile per damage type with a resistance value, rendered as a ring-gauge row | `weight_class`, `physical_resistance`, `energy_resistance`, `distortion_resistance`, `thermal_resistance`, `biochemical_resistance`, `stun_resistance`, `impact_resistance` | Yes, weight class ("Heavy", "Medium", "Light", "Super heavy") or "Flight" for flight gear; nil for undersuits | `sub_type` must be a real weight class or the prefix is nil; "Helmet" and "UNDEFINED" sub_types are not weight classes |
| 18 | **Environment** | `type(apiData.temperature_resistance) == 'table'` | Custom HTML via `Module:RangeBar` (temperature, ice–fire gradient, 0 °C reference tick) + `Module:MeterBar` (radiation protection REM, radiation scrub rate REM·s⁻¹) + plain row G resistance (coloured by sign) | `minimum_temperature`, `maximum_temperature`, `radiation_capacity`, `radiation_dissipation`, `g_force_resistance` | — | Temperature 0–0 range collapses (no thermal rating); radiation rows appear only when positive; G-force row appears only when non-zero |
| 19 | **DamageFalloff** | `personal_weapon` or `vehicle_weapon` carries meaningful falloff: `perMeter > 0`, `alpha > minDamage`, `minDist < range` | Custom HTML via `Module:FalloffChart`: damage-over-distance curve injected into the `personal_weapon` or `vehicle_weapon` section key | `full_damage_range`, `min_damage` | — | Flat weapons (laser) and weapons whose falloff begins beyond range do not fire; fixed per-class x/y scales for within-class comparability; ship guns dormant until API provides falloff data |
| 20 | **Inventory** | `apiData.inventory.scu_converted` is present and positive | Storage capacity (µSCU) | `storage_capacity` | — | Matches on computed capacity, not bare block presence; empty or zero-capacity blocks collapse the section |
| 21 | **Component** | `type(apiData.durability) == 'table'` | Health, EM signature, IR signature, Distortion, Resistance (types with factor < 1 only, inline) | `health`, `em_signature`, `ir_signature`, `distortion` | — | Section renders collapsed by default; resistance row collapses when no type resists; also fires on non-vehicle items that carry a `durability` block |
| 22 | **Dimensions** | `apiData.dimension.dimensions` or `apiData.dimension.cargo_dimension` is a drawable `{length, width, height}` box | Custom HTML via `Module:Dimensions`: Cargo tab (packed footprint, volume footer) and/or Physical tab (actual size vs. human/banana reference, mass footer) | — | — | Cargo tab leads; the cargo diagram carries no reference object, only its axis measurements; no `getStructuredData` |

## Conformance

[`Module:Entity/Registry/testcases`](https://starcitizen.tools/Module:Entity/Registry/testcases) runs five tests:

1. `testRegistryNonEmpty`: both `Registry.kinds` and `Registry.facets` are non-empty.
2. `testAllKindsConform`: calls `Contract.validate(kind, Contract.KIND, { strict = true })` for every entry in `Registry.kinds`. A kind missing `matches` or `getApiConfigs` fails here.
3. `testAllKindsDeclareName`: every kind declares a non-empty, unique string `name` (the canonical kind name exposed as `Data.get().result.kind`).
4. `testAllFacetsConform`: calls `Contract.validate(facet, Contract.FACET, { strict = true })` for every entry in `Registry.facets`. A facet missing `matches` or `getSections` fails here.
5. `testAllKindsConformFields`: calls `Contract.validateFields(kind, Contract.KIND_FIELDS)` over each kind's non-function fields (`name`, `editorialMode`).

Adding a new kind or facet to Registry automatically extends coverage; no change to the test file is needed. The conformance gate uses [`Module:Entity/Contract`](https://starcitizen.tools/Module:Entity/Contract) as the validator.

**What the conformance tests do NOT cover:** chain-link hooks (`getTypeInfo`, `getExternalSiteItems`, etc. on `CHAIN_LINK` components) are validated by `Contract.CHAIN_LINK`, but that spec is not exercised from the Registry test suite. Chain links are internal to their kind and validated separately via kind-level tests.

## Tests

Tests run on-wiki via `Module:ScribuntoUnit`. Deploy the module before running; there is no local CI runner. The documentation template on the module's wiki page surfaces results inline.

## Architecture

```
Entity/Registry/
├── Registry.lua      # p.kinds + p.facets — the entire registry
└── testcases.lua     # ScribuntoUnit conformance suite (5 tests)
```

`Registry.lua` has no logic: it is purely a list of `require` calls. All behaviour lives in the component modules themselves. This means the file is safe to read at a glance and cheap to diff when a component is added or removed.
