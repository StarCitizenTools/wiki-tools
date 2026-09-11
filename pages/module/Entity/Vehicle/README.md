# Module:Entity/Vehicle

The Vehicle kind covers every ship, ground vehicle, and gravlev served by Apiunto's `/vehicles/{uuid}` endpoint. `Vehicle.lua` is an orchestrator: it owns kind-level concerns (matching, subtype resolution, structured data, categories, acquisition, header badge, short description) and delegates every infobox section to a per-section sub-builder under `Vehicle/`.

Editors never invoke this module directly; it runs inside [Template:Vehicle](https://starcitizen.tools/Template:Vehicle), which declares the kind, or inside [Template:Entity](https://starcitizen.tools/Template:Entity) when the page's uuid resolves to a vehicle record (Item declines `is_vehicle` records, so the probe reaches Vehicle); the pipeline and the hook table are on [Module:Entity](https://starcitizen.tools/Module:Entity).

## For module editors

### Family model

`p.matches(apiData)` checks for the presence of the `is_vehicle` key, not its value: a spaceship carries `is_vehicle = false` alongside `is_spaceship = true`; items never carry the key at all.

`p.resolveSubtype` derives a family token (`gravlev`, `ship`, or `ground`) and dispatches it through [Module:Entity/SubtypeResolver](https://starcitizen.tools/Module:Entity/SubtypeResolver) against `VEHICLE_FAMILY_MAP`. Derivation checks the API family flags in priority order (`is_gravlev`, then `is_spaceship`, then `is_vehicle`); with no API record at all (`p.editorialMode = true`, a planned vehicle with no `|uuid=`) it falls back to the curated `|family=` arg instead. Each family leaf contributes only `getTypeInfo`, `getShortDescription` (delegating to `Vehicle.formatShortDescription`), and `getCategories` for its family-specific browse categories; every infobox section is orchestrated by `Vehicle.lua` itself, regardless of family.

| Subtype | `getTypeInfo.name` | Browse category |
|---|---|---|
| Ship | `Spacecraft` | `Ships` |
| GroundVehicle | `Ground vehicle` | `Ground vehicles` |
| Gravlev | `Grav-lev vehicle` | `Grav-lev vehicles` |

### Field precedence

For a field that both an editor and the API can supply (crew, cargo, speed, dimensions, mass, pledge price, production state; declared in [editorial.json](https://starcitizen.tools/Module:Entity/Vehicle/editorial.json)), `Module:Entity/Editorial` resolves one display value per field:

| Order | Source | Wins when |
|---|---|---|
| 1 | The editor's arg (`def.arg`, first non-empty alias) | present: displaces a differing API value (`override`) or fills an absent one (`fill`) |
| 2 | The manifest's `default` | used only when the arg is absent, then competes with the API value exactly as an editor value would (no field in `editorial.json` declares one) |
| 3 | The API value at `def.apiPath` | used when neither an arg nor a default resolved |
| 4 | The sub-builder's own `fallback` argument to `ed:value(field, fallback)` | used only when the field resolved nothing at all |

Section sub-builders read through the shared view: `ed:value(field, apiFallback)` for overlap fields, `ed:value(field)` for pure-editorial ones (dates, pledge tiers, series, generation).

### Sub-builders

`getSections` wraps `ctx.resolved` once (`ed = Editorial.view(ctx.resolved)`) and calls each sub-builder in fixed order, dropping the `nil`s:

| Module | Section key | Role |
|---|---|---|
| `Vehicle/Overview` | `overview` | Type / Career / Role / Size / Model, a labelless top group |
| `Vehicle/Capacity` | `capacity` | Subsection tabs Overview (crew/cargo/inventory headline) + Cargo/Crew detail; collapses to flat rows when there's nothing to drill into |
| `Vehicle/Cost` | `cost` | Subsection tabs: Universe / Pledge / Insurance |
| `Vehicle/Stats` | `stats` | Subsection tabs: Overview (percentile ring gauges) + Offense / Defense / Mobility / Travel / Stealth |
| `Vehicle/Dimensions` | `dimensions` | Adapter over `Module:Dimensions` |
| `Vehicle/Lore` | `lore` | In-lore release/retirement dates, collapsed |
| `Vehicle/Development` | `development` | Real-world dates, flight-ready patch, production note, collapsed |

`Vehicle/Stats/Overview`, `/Profile`, `/Standing`, `/PercentileBar`, and `Vehicle/ClassStats` support the Stats sub-builder (the size-class cohort query and its percentile math) but expose no section of their own. `Vehicle/Util` holds vehicle-domain helpers (`resolveCareer`, `matrixSize`, `DAMAGE_TYPES`, the mean armor / cross-section / deflection functions) shared across the sub-builders and `getStructuredData`.

Every sub-builder exposes one `build(apiData, args, ed)` returning an `EntitySectionEntry` or `nil`, except `Vehicle/Overview`, whose `build(apiData, args, ed, typeName)` takes a fourth argument: the resolved subtype's `getTypeInfo().name`, computed once in `getSections` and passed in so the sub-builder never requires back into `Vehicle.lua`. They are pure: they never fetch and never re-resolve the subtype.

### Extending

A fourth family: write `pages/module/Entity/Vehicle/<Name>.lua` with `p.parent = 'Entity/Vehicle'`, `p.family` (the token the map dispatches on, and the value editors write to `|family=`, trimmed and lowercased before lookup so casing is free), `getTypeInfo`, `getShortDescription`, and its own `getCategories`; add one `token = 'Entity/Vehicle/<Name>'` entry to `VEHICLE_FAMILY_MAP` in `Vehicle.lua`, plus the matching flag check in `deriveFamily`. No sub-builder changes are needed: every section is data-gated and renders only when the relevant API or editorial fields are populated.

### Gotchas

- Subsection tabs (a section's nested `sections` array) must be raw `{ label, items }` tables with no `key`. `Assembly.mergeSections` strips the Entity-internal `key` only at the top level; a keyed subsection reaches InfoboxLua as-is, which rejects it with a schema error and aborts the whole infobox render. Rendering is browser-only, so unit tests never catch this.
- The percentile profile only compares ships against ships of the same `Size` in `Category:Ships`; ground vehicles and gravlevs have no cohort, so their Stats detail rows render as plain values with no bar.
- A new cohort stat participates only once it is stored: add the SMW property, write it in `getStructuredData`, add it to the `COHORT_PROPS` table in `ClassStats.lua` (a file-local, not an export), and reference it from the relevant `Profile` axis. A size class with fewer than 5 stored ships (`MIN_COHORT`) also yields no cohort. Existing cohort pages need `forcelinkupdate` before the property is queryable across the cohort.
- `career` and `size` are read directly through `Vehicle/Util`'s `resolveCareer`/`matrixSize`, not through the editorial manifest, on purpose: both diverge from the API systematically (a curated taxonomy, not a data correction), and a manifest field would flag every such vehicle into the `Entities with manual API data` maintenance category for a difference that isn't an error.
- Deploy `editorial.json` and any new `properties.json` entries before a `Vehicle.lua` change that reads or writes them: `getEditorialManifest` loads `editorial.json` directly, and `StructuredData.store` still writes a field absent from `properties.json`, just flagged back as unregistered and stored untyped until the property catches up.
