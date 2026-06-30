# Module:Entity/Vehicle

The Vehicle kind is the second registered kind in the Entity pipeline, matched on Apiunto's `/vehicles/{uuid}` endpoint. It covers every flyable ship, ground vehicle, and hover bike (gravlev) in Star Citizen. It is the most field-rich kind in the system: the editorial manifest, the 4-layer field model, the class-percentile stat profile, and the subsection-tab constraint are all unique to Vehicle.

`Vehicle.lua` is now an **orchestrator**, not a monolith. It owns kind-level concerns (matching, subtype resolution, structured data, categories, external sites, acquisition, the header badge/subtitle, the short description) and delegates every infobox section to a per-section sub-builder under `Vehicle/`. See [Sub-builders](#sub-builders).

## Kind / subtype model

```
Module:Entity/Data
  ↓  kind probe: Vehicle.matches(apiData) — is_vehicle key present?
Module:Entity/Vehicle               ← kind orchestrator
  ↓  Vehicle.resolveSubtype(apiData, args) → Module:Entity/SubtypeResolver
Module:Entity/Vehicle/Ship          ← is_spaceship=true   (family token "ship")
Module:Entity/Vehicle/GroundVehicle ← is_vehicle=true     (family token "ground")
Module:Entity/Vehicle/Gravlev       ← is_gravlev=true     (family token "gravlev")
```

`matches()` identifies vehicles by the **presence** of the `is_vehicle` key (not its value: a spaceship carries `is_vehicle=false`). Items never have this key.

`resolveSubtype` derives a family **token** (`ship` / `ground` / `gravlev`) then hands off to `Module:Entity/SubtypeResolver.resolve(token, VEHICLE_FAMILY_MAP)`, which requires and returns the leaf module. Token derivation (`deriveFamily`) checks the three API family flags in priority order (gravlev → spaceship → ground vehicle); in editorial mode there is no API record and therefore no flags, so it falls back to the `|family=` arg (see [Planned vehicles](#planned-vehicles-editorial-mode)). When neither resolves, the Vehicle kind itself stays the leaf. Each subtype contributes only two things: `getTypeInfo` (the display type noun + browse category) and `getShortDescription` (which delegates to `Vehicle.formatShortDescription`). Everything else is orchestrated by `Vehicle.lua` and rendered by the sub-builders.

| Subtype | `getTypeInfo.name` | Browse category |
|---|---|---|
| Ship | `Spacecraft` | `Ships` |
| GroundVehicle | `Ground vehicle` | `Ground vehicles` |
| Gravlev | `Gravlev` | `Gravlevs` |

Short descriptions are manufacturer-led: `"<mfr short> <size|single-seat> <role-phrase> <type-noun>"`, e.g. `"RSI large multi-role ship"`. Ground vehicles and gravlevs omit the matrix size (`omitSize = true`); a crew-max of 1 substitutes `"single-seat"` for the size. The type-noun is dropped when the role phrase already ends with a ship-type word (fighter, bomber, corvette, …).

## Sub-builders

`getSections(apiData, args, resolved)` wraps `resolved` in an [Editorial view](#the-4-layer-field-model) **once** (`ed = Editorial.view(resolved)`), resolves the subtype to get its display type name, then composes the section list by calling each sub-builder and dropping the nils:

```lua
add(overview.build(apiData, args, ed, typeName))
add(capacity.build(apiData, args, ed))
add(cost.build(apiData, args, ed))
add(stats.build(apiData, args, ed))
add(vehicleDimensions.build(apiData, args, ed))
add(lore.build(apiData, args, ed))
add(development.build(apiData, args, ed))
```

Every section sub-builder exposes a single `build(apiData, args, ed)` and returns one InfoboxLua section (or nil when it has no data). They are **pure**: they consume already-fetched `apiData`, the raw `args`, and the shared `ed` view; they never fetch and never re-resolve the subtype (Overview is the only one that needs the type name, so the orchestrator passes it in as a fourth argument; this avoids a circular require back through `Vehicle.lua`). Overlap fields are read through `ed:value(field, apiFallback)`; pure-editorial fields through `ed:value(field)`.

One row per builder in the subtree:

| Module | Section / role | Notes |
|---|---|---|
| `Vehicle/Overview` | `overview` (labelless top group) | Type / Career / Role / Size / Model. Takes the orchestrator-supplied `typeName`. |
| `Vehicle/Capacity` | `Capacity` | Crew range / Cargo (SCU) / Inventory (µSCU from `vehicle_inventory`) |
| `Vehicle/Cost` | `Cost` | Subsection tabs: Universe / Pledge / Insurance |
| `Vehicle/Stats` | `Stats` | Subsection tabs: Overview ring + Offense / Defense / Mobility / Travel / Stealth (see [Stats](#stats-class-percentile-profile)) |
| `Vehicle/Stats/Overview` | Stats "Overview" tab | Row of percentile ring-gauges, one per scored axis |
| `Vehicle/Stats/Profile` | — | `axisScores`: computes the 5-axis class-percentile scores |
| `Vehicle/Stats/Standing` | — | Shared rank (`position`), podium medal, and olive→green colour scale |
| `Vehicle/Stats/PercentileBar` | — | A detail-tab row: value + bar filled to its class-percentile |
| `Vehicle/ClassStats` | — | The size-class cohort: one memoized `mw.smw.ask` + the Hazen `percentile` helper |
| `Vehicle/Dimensions` | `Dimensions` | Thin adapter over `Module:Dimensions` (vehicles carry flat `dimension.*`) |
| `Vehicle/Lore` | `Lore` | In-lore release / retirement dates, collapsed |
| `Vehicle/Development` | `Development` | Real-world concept announced / sale dates, collapsed |
| `Vehicle/Util` | — | Vehicle-domain shared helpers: `resolveCareer`, `matrixSize`, `DAMAGE_TYPES`, `meanArmorResistance` / `meanCrossSection` / `meanDeflection` |

**Adding a section.** Create `pages/module/Entity/Vehicle/<Name>/<Name>.lua` exposing `p.build(apiData, args, ed)` that returns a `Module:Entity/SectionBuilder.section{…}` (or nil), `require` it at the top of `Vehicle.lua`, and add one `add(<name>.build(apiData, args, ed))` line in `getSections`. Sections are data-gated (returning nil keeps an empty section out of the render), so order is the only other thing `getSections` decides.

## The 4-layer field model

For any field that can be curated by an editor *and* has an API counterpart, namely crew, cargo, speed, dimensions (length/width/height), mass, pledge price, and production state, the same field appears in four places with distinct concerns:

1. **`editorial.json`** (25 fields) maps a manifest key to `{ arg, smw, apiPath?, transform? }`. Fields with `apiPath` are *overlap* fields (the API provides a value; the wiki can override or fill gaps). Fields without `apiPath` are *pure-editorial* (the API does not model them at all: pledge prices, lore/development dates, series, generation).

2. **`properties.json`** (`modules: ["Vehicle"]`) declares the SMW property type and storage bucket for each `smw` key. Must be deployed **before** `Vehicle.lua` changes that write new properties.

3. **`getStructuredData`** writes SMW values for the *pure-API* fields not covered by the editorial manifest. Beyond the original taxonomy fields (Career, Role, Size, agility rates, armor signatures, fuel/quantum stats, insurance) it now also stores the **scoring-cohort stats**: Health/Shield HP, pilot/turret DPS (and the sustained variants), missile damage, IR/EM emission, cross section, armor resistance and deflection (plus the physical/energy split), the per-damage-type modifiers, the estimated buy/rent price, and ship-matrix size / storage capacity / loaner. These are the properties `ClassStats` reads back to build the size-class cohort (see [Stats](#stats-class-percentile-profile)). Editorial-manifest fields are stored by `Module:Entity/Editorial` and are intentionally absent here.

4. **Section builders** read display values through the Editorial **view** `ed` (an `Editorial.view(resolved)` object), not through named helpers:
   - `ed:value(field, apiFallback)` returns the editorial-resolved value when present, else the API fallback. Use for overlap fields.
   - `ed:value(field)` is a pure-editorial read, no API fallback. Use for fields with no `apiPath`.

   (`ed:source(field)` is also available for provenance: `'api'` / `'override'` / `'wiki'`.) The view **replaces** the old per-kind `effective` / `editorialValue` helpers, which no longer exist. `Module:Entity/Editorial` produces the `resolved` table from the manifest and passes it to `getSections` / `getStructuredData` as the third argument, where the orchestrator wraps it once.

**Why `resolveCareer` instead of the manifest?** The wiki curates the career taxonomy (e.g. the API says "Transporter", the wiki says "Transport"). This divergence is *systematic*, so reading `args.career` first (then falling back to the API value) is correct without flagging every vehicle page as a manual-API-data override. Putting it in the manifest would flood the maintenance category. The same logic applies to `|size=` via `matrixSize`. Both helpers live in `Module:Entity/Vehicle/Util` and are shared across the sub-builders and `getStructuredData`.

## Sections

`getSections` composes up to seven sections in fixed order:

| Section key | Label | Notes |
|---|---|---|
| `overview` | *(none, labelless top group)* | Type / Career / Role / Size / Model (series + generation) |
| `capacity` | `Capacity` | Crew range / Cargo (SCU) / Inventory (µSCU from `vehicle_inventory`) |
| `cost` | `Cost` | Subsection tabs: Universe / Pledge / Insurance |
| `stats` | `Stats` | Subsection tabs: Overview ring + Offense / Defense / Mobility / Travel / Stealth |
| `dimensions` | `Dimensions` | `Module:Dimensions` box. Length/width/height/mass (and the retracted dimensions) are editorial overlap fields, so a planned vehicle renders the box from `|length=`/`|width=`/`|height=`/`|mass=`; in-game vehicles fill from `apiData.dimension` |
| `lore` | `Lore` | In-lore release / retirement dates, collapsed by default |
| `development` | `Development` | Real-world concept announced / concept sale dates, collapsed by default |

**Cost › Universe tab** displays an estimated in-game price rather than a Yes/No flag. `universeCell` resolves each side (Buy / Rent) as: an editorial `canbuy`/`canrent` `=no` override is a hard **No**; otherwise it shows the estimated UEC price (`~<price>`, via `Module:Entity/Acquisition.estimatePrice`, the median of the latest patch's UEX terminal rows, prefixed `~` because it is a cross-terminal estimate). With no price: a `=yes` override → **Yes**; a flight-ready ship, or one with market data but none on this side, → a definitive **No** (the vehicle is in-game, so a missing UEX price means it is simply not sold); an unreleased ship with no data at all → nil (the row drops, Unknown). The Buy/Rent/Pledge *availability flags* that feed `{{Entity/Availability}}` are a separate concern (see [Acquisition](#acquisition)).

## Stats: class-percentile profile

The Stats section ranks a ship against its **size-class cohort** (every same-`Size` ship in `Category:Ships`) and presents both a glanceable ring profile and per-stat detail. Cohorts are ships-only; ground vehicles and gravlevs have no cohort and so render the detail rows as plain values with no ring.

**The cohort** (`Vehicle/ClassStats`). `cohortRows(family, size)` runs one `mw.smw.ask` per `family|size`, memoized in a render-local cache, pulling a fixed set of numeric SMW properties (`COHORT_PROPS`) for the cohort and decoding them to numbers. It returns nil when comparison is unavailable: no SMW store (headless tests), a non-ship family, or fewer than `MIN_COHORT = 5` members. `percentile(values, value)` is a Hazen-midpoint percentile (cohort median → 50, leader → ~100, floor → ~0; ties not inflated). This is why a stat must be stored by `getStructuredData` to participate: the ship reads its live value from `apiData`, but the *distribution* it is ranked against comes from the SMW properties of its cohort.

**The ring profile** (`Vehicle/Stats/Overview` + `/Profile`). `Profile.axisScores` computes five axes (**Offense / Defense / Mobility / Travel / Stealth**), each scored as the mean of its components' class-percentiles (weight-free; an axis with no component data is omitted). Stealth components (IR / EM / cross-section) are inverted so lower signature = higher score. Examples: Offense scores on sustained gun DPS (pilot + turret), with missile/torpedo alpha shown alongside as a non-scored annotation; Defense is the mean of shield HP, hull HP, and armor deflection. The Overview tab renders one `Module:ProgressTiles` ring per axis, coloured by `Standing.color` (an olive→green scale where a low standing is muted, never red), with a "Beta" badge and a `vs. N S<class> ships` cohort footer.

**The detail tabs** (`Vehicle/Stats` + `/PercentileBar`). The five same-named tabs (Offense / Defense / Mobility / Travel / Stealth) list the individual stats. Each comparable row is a `PercentileBar`: the stat's value plus a `Module:RangeBar` filled to its class-percentile and labelled with the ship's **rank** (`Standing.position`: 1st = best, a podium medal for the top 3). A row degrades to a plain value when there is no cohort, when the stat is missing, or when the ship is the lone cohort member with that stat (a vacuous "1st at 50%" is suppressed). `invert` ranks lower-as-better for signatures and spool time. Ships use `speed.*`; ground vehicles fall back to `drive.*`.

`Standing` is the shared visual language (rank, medal, colour scale) so the rings and the bars speak one scale. Any tab with no populated rows is omitted; the whole Stats section drops when nothing renders.

## Subsection-tab key gotcha

**Subsection tabs (the `sections` array inside a section) must be raw `{ label, items }` tables with NO `key`.**

`Module:Entity/Assembly.mergeSections` strips the Entity-internal `key` only at the top level (to merge sibling sections from chain links). A keyed subsection object passes straight through to InfoboxLua, which rejects it with a schema error and aborts the entire infobox render. Unit tests do not catch this because subsection rendering is browser-only. See the inline comment in `Cost.build` and `Stats.build` for the pattern; the Stats Overview sub-builder emits the same keyless `{ label, items }` subsection (consumed by `Stats.build`).

## Acquisition

`getAcquisition(apiData, args)` feeds `{{Entity/Availability}}` (distinct from the Cost section's Universe tab, which is purely about price display). It returns:

- **summary**: Buy / Rent / Pledge flags (Loot and Craft are omitted; neither applies to vehicles). Each flag is resolved by `Module:Entity/Acquisition.resolveFlag(override, derived)`: Buy and Rent derive from `inferCanAcquire` over the UEX `purchase` / `rental` rows; Pledge derives from the presence of `msrp`. An editor override wins over the inferred value.
- **cards**: two `terminals` cards, **Shops** (from `uex_prices.purchase`, with a Sell column when sell prices exist) and **Rentals** (from `uex_prices.rental`), each carrying the per-terminal price rows for the Availability template's terminal table.

## Planned vehicles (editorial mode)

Vehicle is the first kind to opt in to **editorial mode** (`p.editorialMode = true`). A planned vehicle is the same Vehicle kind rendered from a subset of the data, the editorial args alone, when there is no genuine API record yet. It is not a separate "lite" template or mode: it is the ordinary Vehicle render with the API-sourced sections naturally empty.

**How to declare one.** Set `|kind=Vehicle`, set `|family=` to one of `ship` / `ground` / `gravlev`, provide `|name=` (**required**: with no API record it is the only source of the entity name, and `Module:Entity` errors out when neither a uuid nor a name is given), and provide **no** `|uuid=`. The `|family=` arg selects the subtype (Ship / GroundVehicle / Gravlev) the way the API family flags do for in-game vehicles: a planned page has no API record, so there are no `is_spaceship` / `is_vehicle` / `is_gravlev` flags to read, and `deriveFamily` falls back to `args.family`. Then supply the usual editorial args (`manufacturer`, `model`, `career`, `size`, `productionstate`, `role`, the lore/development dates, the pledge prices, and so on, the same args documented in the 4-layer field model above). One caveat on `|role=`: it is not in `editorial.json`, so in editorial mode it only feeds the manufacturer-led short description (via `rolePhrase`); the Overview "Role" row reads `apiData.role` and so stays absent on a planned page. `Module:Entity/Data.get` sees the opted-in kind with no resolvable record, sets `apiData = {}`, and the chain renders editorial-first.

Worked example, the planned Hull E:

```wikitext
{{Entity|kind=Vehicle|family=ship|name=Hull E|manufacturer=MISC|model=Hull|career=Transport|size=Large|productionstate=In concept|role=Heavy Freight}}
```

**What renders.** Categories and the short description reach full parity with an in-game vehicle, because both source editorial-first (the manufacturer browse category, the subtype browse category, and the manufacturer-led short description are all built from args). The production-state badge renders from `|productionstate=`. Every editorial section that has data renders (Overview, Capacity, Cost's Pledge tab, **Dimensions** when `|length=`/`|width=`/`|height=`/`|mass=` are supplied, Lore, Development, and so on). The genuinely API-only sections omit themselves, since they are data-gated and there is no API data to gate on: Ports/hardpoints, the Cost Universe tab (UEX pricing), the acquisition flags/terminals, and the entire Stats profile (no cohort, no live stats) all drop out. A planned page is therefore a clean subset of the in-game render, not a different layout.

**Lifecycle.** When the vehicle enters the game and the API, add `|uuid=`. `Module:Entity/Data.get` then resolves the genuine record, and rendering hands back to the normal API path: `deriveFamily` reads the API family flags first, so `|family=` becomes a harmless no-op, and `|kind=` is likewise ignored once a real record exists. Any editorial fields the author already wrote persist as overlay overrides, the editor-wins layer described in the 4-layer field model (overlap fields fill or override the API value, pure-editorial fields carry through unchanged). No migration or rewrite of the page is needed: adding the uuid is the whole transition.

**Safety.** A planned page is the `name`-only case (no `|uuid=`), and it does **not** trigger any tracking category. But a `|uuid=` that does **not** resolve to a genuine record, a typo, or a uuid that is not yet in the API, emits `[[Category:Pages with an unresolved entity reference]]`. This stops a broken reference from silently masquerading as a planned page: a planned page deliberately has no uuid, so a present-but-unresolved uuid is always an error worth flagging.

## External sites

`getExternalSiteItems` builds two rows, **Official sites** and **Community sites**, via `Module:Entity/Format.buildSiteLinks` from `officialSites.json` and `communitySites.json`.

Official-site URL args are all named `<name>url`, for consistency:

| Arg | Label | Multiple? |
|---|---|---|
| `pledgeurl` | Pledge store | single (falls back to API `pledge_url`) |
| `galactapediaurl` | Galactapedia | single |
| `brochureurl` | Brochure | yes |
| `trailerurl` | Trailer | yes |
| `presentationurl` | Presentation | yes |
| `qaurl` | Q&A | yes |
| `whitleysguideurl` | Whitley's Guide | yes |

The five multi-value args (`brochureurl` / `trailerurl` / `presentationurl` / `qaurl` / `whitleysguideurl`) accept a **semicolon-separated list**, the wiki convention for multi-value parameters (`Module:Entity/Format.splitSemi`, mirroring Editorial/Company):

```wikitext
| presentationurl = https://…/first; https://…/second
```

`buildSiteLinks` renders one link per URL, **numbering the labels** when there is more than one ("Presentation 1 · Presentation 2"); a single URL keeps the bare label. Community sites (Universal Item Finder, #DPSCalculator, SPViewer, FleetYards, CCU Game, Wiki API) are derived from API identifiers (`uuid`, `class_name`, `shipmatrix_name`), not editor args.

## Operational notes

**Deploy ordering.** When landing changes that affect SMW property names or the editorial manifest:

1. Deploy `editorial.json` and `properties.json` first. `Module:Entity/Editorial` and `Module:Entity/Categories` read these at render time; deploying `Vehicle.lua` before them means structured-data writes target unregistered properties (stranding values until a type repair reparse) or the editorial resolver silently misses new fields.
2. Deploy `Vehicle.lua` and the sub-builders second.
3. `Module:Manufacturers/data.json` must be live for the manufacturer short name to resolve correctly in `formatShortDescription`. A missing short name silently omits the manufacturer token, producing a less specific short description rather than an error.

**New cohort stat.** A stat only participates in the percentile profile once it is stored: add the SMW property to `properties.json` (`modules: ["Vehicle"]`), write it in `getStructuredData`, add it to `ClassStats.COHORT_PROPS` (so the cohort query fetches it), and reference it from the relevant `Profile` axis component and/or the `Stats` detail row. Existing cohort pages must be reparsed (`forcelinkupdate`) before the new property is queryable across the cohort.

**Subtype additions.** Adding a fourth subtype requires: (1) a new leaf module at `pages/module/Entity/Vehicle/<Name>.lua` with `p.parent = 'Entity/Vehicle'`, `p.family` (the family token, threaded to `getCategories` for classification), `getTypeInfo`, and `getShortDescription`; (2) appending one `token → module path` entry to `VEHICLE_FAMILY_MAP` in `Vehicle.lua`, plus the matching flag check in `deriveFamily`. No change to the section sub-builders is needed; they are data-gated (they render only when the relevant API fields are populated).

## Architecture

```
Entity/Vehicle/
├── Vehicle.lua            # Orchestrator: matches, resolveSubtype, getSections (delegates),
│                          #   getStructuredData, getCategories, getSubtitle, getHeaderBadge,
│                          #   getExternalSiteItems, getAcquisition, getEditorialManifest,
│                          #   formatShortDescription
├── Ship.lua               # Subtype: getTypeInfo (Spacecraft / Ships) + getShortDescription
├── GroundVehicle.lua      # Subtype: getTypeInfo (Ground vehicle / Ground vehicles) + getShortDescription
├── Gravlev.lua            # Subtype: getTypeInfo (Gravlev / Gravlevs) + getShortDescription
├── Overview/Overview.lua  # Section: Type / Career / Role / Size / Model
├── Capacity/Capacity.lua  # Section: Crew / Cargo / Inventory
├── Cost/Cost.lua          # Section: Universe / Pledge / Insurance tabs
├── Stats/Stats.lua        # Section: Overview ring + Offense/Defense/Mobility/Travel/Stealth tabs
│   ├── Overview/Overview.lua  # Stats "Overview" tab — percentile ring gauges
│   ├── Profile/Profile.lua    # axisScores — 5-axis class-percentile
│   ├── Standing/Standing.lua  # rank + podium medal + olive→green colour scale
│   └── PercentileBar.lua      # detail-tab row — value + percentile bar
├── ClassStats/ClassStats.lua  # Size-class cohort #ask + Hazen percentile
├── Dimensions/Dimensions.lua  # Section: Module:Dimensions adapter
├── Lore/Lore.lua          # Section: in-lore dates (collapsed)
├── Development/Development.lua # Section: real-world dates (collapsed)
├── Util/Util.lua          # Vehicle-domain helpers: resolveCareer, matrixSize,
│                          #   DAMAGE_TYPES, meanArmorResistance / meanCrossSection / meanDeflection
├── editorial.json         # 25-field editorial manifest (overlap + pure-editorial fields)
├── officialSites.json     # Official external-site link definitions (<name>url args)
├── communitySites.json    # Community external-site link definitions (Universal Item Finder, #DPSCalculator, FleetYards, …)
└── testcases.lua          # ScribuntoUnit suite (sub-builders carry their own testcases too)
```
