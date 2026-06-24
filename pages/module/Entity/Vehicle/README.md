# Module:Entity/Vehicle

The Vehicle kind is the second registered kind in the Entity pipeline, matched on Apiunto's `/vehicles/{uuid}` endpoint. It covers every flyable ship, ground vehicle, and hover bike (gravlev) in Star Citizen. It is the most field-rich kind in the system — the editorial manifest, the 4-layer field model, and the subsection-tab constraint are all unique to Vehicle.

## Kind / subtype model

```
Module:Entity/Data
  ↓  kind probe: Vehicle.matches(apiData) — is_vehicle key present?
Module:Entity/Vehicle               ← kind module (all section logic lives here)
  ↓  Vehicle.resolveSubtype(apiData)
Module:Entity/Vehicle/Ship          ← is_spaceship=true
Module:Entity/Vehicle/GroundVehicle ← is_vehicle=true
Module:Entity/Vehicle/Gravlev       ← is_gravlev=true
```

`matches()` identifies vehicles by the **presence** of the `is_vehicle` key (not its value — a spaceship carries `is_vehicle=false`). Items never have this key.

`resolveSubtype` checks the three family flags in priority order (gravlev → spaceship → ground vehicle) and returns the subtype module, or nil when none is set (Vehicle itself stays the leaf). Each subtype contributes only two things: `getTypeInfo` (the display type noun + browse category) and `getShortDescription` (which delegates to `Vehicle.formatShortDescription`). All section rendering, structured data, categories, and external links are centralised in `Vehicle.lua`.

| Subtype | `getTypeInfo.name` | Browse category |
|---|---|---|
| Ship | `Spacecraft` | `Ships` |
| GroundVehicle | `Ground vehicle` | `Ground vehicles` |
| Gravlev | `Gravlev` | `Gravlevs` |

Short descriptions are manufacturer-led: `"<mfr short> <size|single-seat> <role-phrase> <type-noun>"`, e.g. `"RSI large multi-role ship"`. Ground vehicles and gravlevs omit the matrix size (`omitSize = true`); a crew-max of 1 substitutes `"single-seat"` for the size. The type-noun is dropped when the role phrase already ends with a ship-type word (fighter, bomber, corvette, …).

## The 4-layer field model

For any field that can be curated by an editor *and* has an API counterpart — crew, cargo, speed, mass, pledge price, production state — the same field appears in four places with distinct concerns:

1. **`editorial.json`** — maps a manifest key to `{ arg, smw, apiPath?, transform? }`. Fields with `apiPath` are *overlap* fields (the API provides a value; the wiki can override or fill gaps). Fields without `apiPath` are *pure-editorial* (the API does not model them at all: pledge prices, lore/development dates, series, generation).

2. **`properties.json`** (`modules: ["Vehicle"]`) — declares the SMW property type and storage bucket for each `smw` key. Must be deployed **before** `Vehicle.lua` changes that write new properties.

3. **`getStructuredData`** — writes SMW values for the *pure-API* fields not covered by the editorial manifest (Career, Role, Size class, agility rates, armor signatures, fuel/quantum stats, insurance). Editorial-manifest fields are stored by `Module:Entity/Editorial` and are intentionally absent here.

4. **Section builders** — `buildOverview`, `buildCapacity`, `buildCost`, `buildStats`, `buildDimensions`, `buildLore`, `buildDevelopment` — read values through the two resolver helpers:
   - `effective(resolved, field, apiFallback)` — returns the editorial-resolved value when present, else the API fallback. Use for overlap fields.
   - `editorialValue(resolved, field)` — pure-editorial read, no API fallback. Use for fields with no `apiPath`.

The `resolved` table is produced by `Module:Entity/Editorial` and passed to `getSections` / `getStructuredData` as the third argument.

**Why `resolveCareer` instead of the manifest?** The wiki curates the career taxonomy (e.g. the API says "Transporter", the wiki says "Transport"). This divergence is *systematic*, so reading `args.career` first (then falling back to the API value) is correct without flagging every vehicle page as a manual-API-data override. Putting it in the manifest would flood the maintenance category. The same logic applies to `|size=` via `matrixSize`.

## Sections

`getSections` composes up to seven sections in fixed order:

| Builder | Section key | Label | Notes |
|---|---|---|---|
| `buildOverview` | `overview` | *(none — labelless top group)* | Type / Career / Role / Size / Model (series + generation) |
| `buildCapacity` | `capacity` | `Capacity` | Crew range / Cargo (SCU) / Inventory (µSCU from `vehicle_inventory`) |
| `buildCost` | `cost` | `Cost` | Subsection tabs: Universe / Pledge / Insurance |
| `buildStats` | `stats` | `Stats` | Subsection tabs: Flight / Hull / Hydrogen / Quantum |
| `buildDimensions` | `dimensions` | `Dimensions` | `Module:Dimensions` box; includes retracted dimensions from editorial manifest |
| `buildLore` | `lore` | `Lore` | In-lore release / retirement dates — collapsed by default |
| `buildDevelopment` | `development` | `Development` | Real-world concept announced / concept sale dates — collapsed by default |

**Universe tab** infers buy/rent availability from UEX price data. `acquireRow` applies an editorial `canbuy`/`canrent` override first; when absent, it calls `inferCanAcquire` (true when a non-zero price exists in the UEX rows, false when rows exist but no price, nil when no data). Flight-ready ships treat nil as a definitive **No** (the vehicle is in-game, so a missing UEX price means it is simply not sold). Unreleased ships with no data drop the row (Unknown).

**Stats tab set** folds the fuel sections into Stats rather than a separate section. The Flight tab reads `speed.*` for ships/gravlevs and `drive.*` for ground vehicles; the Hull tab renders HP, shield HP, armor resistance tiles (via `Module:ProgressTiles`), and signature modifier labels; the Hydrogen and Quantum tabs cover fuel/QD figures. Any tab with no populated rows is omitted entirely.

## Subsection-tab key gotcha

**Subsection tabs — the `sections` array inside a section — must be raw `{ label, items }` tables with NO `key`.**

`Module:Entity/Assembly.mergeSections` strips the Entity-internal `key` only at the top level (to merge sibling sections from chain links). A keyed subsection object passes straight through to InfoboxLua, which rejects it with a schema error and aborts the entire infobox render. Unit tests do not catch this because subsection rendering is browser-only. See the inline comment in `buildCost` and `buildStats` for the pattern; the Dimensions facet uses the same shape.

## Operational notes

**Deploy ordering.** When landing changes that affect SMW property names or the editorial manifest:

1. Deploy `editorial.json` and `properties.json` first. `Module:Entity/Editorial` and `Module:Entity/Categories` read these at render time; deploying `Vehicle.lua` before them means structured-data writes target unregistered properties (stranding values until a type repair reparse) or the editorial resolver silently misses new fields.
2. Deploy `Vehicle.lua` (and subtypes) second.
3. `Module:Manufacturers/data.json` must be live for the manufacturer short name to resolve correctly in `formatShortDescription`. A missing short name silently omits the manufacturer token, producing a less specific short description rather than an error.

**Subtype additions.** Adding a fourth subtype requires: (1) a new leaf module at `pages/module/Entity/Vehicle/<Name>.lua` with `p.parent = 'Entity/Vehicle'`, `getTypeInfo`, and `getShortDescription`; (2) a new branch in `resolveSubtype`. No change to `Vehicle.lua`'s section builders is needed — they are data-gated (they render only when the relevant API fields are populated).

## Architecture

```
Entity/Vehicle/
├── Vehicle.lua          # Kind: matches, resolveSubtype, all section builders, getSections,
│                        #   getStructuredData, getCategories, getSubtitle, getHeaderBadge,
│                        #   getExternalSiteItems, getEditorialManifest, formatShortDescription
├── Ship.lua             # Subtype: getTypeInfo (Spacecraft / Ships) + getShortDescription
├── GroundVehicle.lua    # Subtype: getTypeInfo (Ground vehicle / Ground vehicles) + getShortDescription
├── Gravlev.lua          # Subtype: getTypeInfo (Gravlev / Gravlevs) + getShortDescription
├── editorial.json       # 22-field editorial manifest (overlap + pure-editorial fields)
├── officialSites.json   # Official external-site link definitions
├── communitySites.json  # Community external-site link definitions (UEX, Erkul, Ship Matrix, …)
└── testcases.lua        # ScribuntoUnit suite
```
