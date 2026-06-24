# Module:Entity/Vehicle

The Vehicle kind is the second registered kind in the Entity pipeline, matched on Apiunto's `/vehicles/{uuid}` endpoint. It covers every flyable ship, ground vehicle, and hover bike (gravlev) in Star Citizen. It is the most field-rich kind in the system — the editorial manifest, the 4-layer field model, and the subsection-tab constraint are all unique to Vehicle.

## Kind / subtype model

```
Module:Entity/Data
  ↓  kind probe: Vehicle.matches(apiData) — is_vehicle key present?
Module:Entity/Vehicle               ← kind module (all section logic lives here)
  ↓  Vehicle.resolveSubtype(apiData, args)
Module:Entity/Vehicle/Ship          ← is_spaceship=true
Module:Entity/Vehicle/GroundVehicle ← is_vehicle=true
Module:Entity/Vehicle/Gravlev       ← is_gravlev=true
```

`matches()` identifies vehicles by the **presence** of the `is_vehicle` key (not its value — a spaceship carries `is_vehicle=false`). Items never have this key.

`resolveSubtype` checks the three family flags in priority order (gravlev → spaceship → ground vehicle) and returns the subtype module, or nil when none is set (Vehicle itself stays the leaf). In editorial mode there is no API record and therefore no family flags, so it falls back to the `|family=` arg (`ship` / `ground` / `gravlev`) — see [Planned vehicles](#planned-vehicles-editorial-mode). Each subtype contributes only two things: `getTypeInfo` (the display type noun + browse category) and `getShortDescription` (which delegates to `Vehicle.formatShortDescription`). All section rendering, structured data, categories, and external links are centralised in `Vehicle.lua`.

| Subtype | `getTypeInfo.name` | Browse category |
|---|---|---|
| Ship | `Spacecraft` | `Ships` |
| GroundVehicle | `Ground vehicle` | `Ground vehicles` |
| Gravlev | `Gravlev` | `Gravlevs` |

Short descriptions are manufacturer-led: `"<mfr short> <size|single-seat> <role-phrase> <type-noun>"`, e.g. `"RSI large multi-role ship"`. Ground vehicles and gravlevs omit the matrix size (`omitSize = true`); a crew-max of 1 substitutes `"single-seat"` for the size. The type-noun is dropped when the role phrase already ends with a ship-type word (fighter, bomber, corvette, …).

## The 4-layer field model

For any field that can be curated by an editor *and* has an API counterpart — crew, cargo, speed, dimensions (length/width/height), mass, pledge price, production state — the same field appears in four places with distinct concerns:

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
| `buildDimensions` | `dimensions` | `Dimensions` | `Module:Dimensions` box. Length/width/height/mass (and the retracted dimensions) are editorial overlap fields, so a planned vehicle renders the box from `|length=`/`|width=`/`|height=`/`|mass=`; in-game vehicles fill from `apiData.dimension` |
| `buildLore` | `lore` | `Lore` | In-lore release / retirement dates — collapsed by default |
| `buildDevelopment` | `development` | `Development` | Real-world concept announced / concept sale dates — collapsed by default |

**Universe tab** infers buy/rent availability from UEX price data. `acquireRow` applies an editorial `canbuy`/`canrent` override first; when absent, it calls `inferCanAcquire` (true when a non-zero price exists in the UEX rows, false when rows exist but no price, nil when no data). Flight-ready ships treat nil as a definitive **No** (the vehicle is in-game, so a missing UEX price means it is simply not sold). Unreleased ships with no data drop the row (Unknown).

**Stats tab set** folds the fuel sections into Stats rather than a separate section. The Flight tab reads `speed.*` for ships/gravlevs and `drive.*` for ground vehicles; the Hull tab renders HP, shield HP, armor resistance tiles (via `Module:ProgressTiles`), and signature modifier labels; the Hydrogen and Quantum tabs cover fuel/QD figures. Any tab with no populated rows is omitted entirely.

## Subsection-tab key gotcha

**Subsection tabs — the `sections` array inside a section — must be raw `{ label, items }` tables with NO `key`.**

`Module:Entity/Assembly.mergeSections` strips the Entity-internal `key` only at the top level (to merge sibling sections from chain links). A keyed subsection object passes straight through to InfoboxLua, which rejects it with a schema error and aborts the entire infobox render. Unit tests do not catch this because subsection rendering is browser-only. See the inline comment in `buildCost` and `buildStats` for the pattern; the Dimensions facet uses the same shape.

## Planned vehicles (editorial mode)

Vehicle is the first kind to opt in to **editorial mode** (`p.editorialMode = true`). A planned vehicle is the same Vehicle kind rendered from a subset of the data, the editorial args alone, when there is no genuine API record yet. It is not a separate "lite" template or mode: it is the ordinary Vehicle render with the API-sourced sections naturally empty.

**How to declare one.** Set `|kind=Vehicle`, set `|family=` to one of `ship` / `ground` / `gravlev`, provide `|name=` (**required**: with no API record it is the only source of the entity name, and `Module:Entity` errors out when neither a uuid nor a name is given), and provide **no** `|uuid=`. The `|family=` arg selects the subtype (Ship / GroundVehicle / Gravlev) the way the API family flags do for in-game vehicles: a planned page has no API record, so there are no `is_spaceship` / `is_vehicle` / `is_gravlev` flags to read, and `Vehicle.resolveSubtype` falls back to `args.family`. Then supply the usual editorial args (`manufacturer`, `model`, `career`, `size`, `productionstate`, `role`, the lore/development dates, the pledge prices, and so on, the same args documented in the 4-layer field model above). One caveat on `|role=`: it is not in `editorial.json`, so in editorial mode it only feeds the manufacturer-led short description (via `rolePhrase`); the Overview "Role" row reads `apiData.role` and so stays absent on a planned page. `Module:Entity/Data.get` sees the opted-in kind with no resolvable record, sets `apiData = {}`, and the chain renders editorial-first.

Worked example, the planned Hull E:

```wikitext
{{Entity|kind=Vehicle|family=ship|name=Hull E|manufacturer=MISC|model=Hull|career=Transport|size=Large|productionstate=In concept|role=Heavy Freight}}
```

**What renders.** Categories and the short description reach full parity with an in-game vehicle, because both source editorial-first (the manufacturer browse category, the subtype browse category, and the manufacturer-led short description are all built from args). The production-state badge renders from `|productionstate=`. Every editorial section that has data renders (Overview, Capacity, Cost's Pledge tab, **Dimensions** when `|length=`/`|width=`/`|height=`/`|mass=` are supplied, Lore, Development, and so on). The genuinely API-only sections omit themselves, since they are data-gated and there is no API data to gate on: Ports/hardpoints, the Cost Universe tab (UEX availability and pricing), and the API-derived flight stats (Stats tabs) all drop out. A planned page is therefore a clean subset of the in-game render, not a different layout.

**Lifecycle.** When the vehicle enters the game and the API, add `|uuid=`. `Module:Entity/Data.get` then resolves the genuine record, and rendering hands back to the normal API path: `resolveSubtype` reads the API family flags first, so `|family=` becomes a harmless no-op, and `|kind=` is likewise ignored once a real record exists. Any editorial fields the author already wrote persist as overlay overrides, the editor-wins layer described in the 4-layer field model (overlap fields fill or override the API value, pure-editorial fields carry through unchanged). No migration or rewrite of the page is needed: adding the uuid is the whole transition.

**Safety.** A planned page is the `name`-only case (no `|uuid=`), and it does **not** trigger any tracking category. But a `|uuid=` that does **not** resolve to a genuine record, a typo, or a uuid that is not yet in the API, emits `[[Category:Pages with an unresolved entity reference]]`. This stops a broken reference from silently masquerading as a planned page: a planned page deliberately has no uuid, so a present-but-unresolved uuid is always an error worth flagging.

## External sites

`getExternalSiteItems` builds two rows — **Official sites** and **Community sites** — via `Module:Entity/Format.buildSiteLinks` from `officialSites.json` and `communitySites.json`.

Official-site URL args are all named `<name>url`, for consistency:

| Arg | Label | Multiple? |
|---|---|---|
| `pledgeurl` | Pledge store | single (falls back to API `pledge_url`) |
| `galactapediaurl` | Galactapedia | single |
| `brochureurl` | Brochure | yes |
| `trailerurl` | Trailer | yes |
| `presentationurl` | Presentation | yes |
| `qaurl` | Q&A | yes |

The four multi-value args (`brochureurl` / `trailerurl` / `presentationurl` / `qaurl`) accept a **semicolon-separated list** — the wiki convention for multi-value parameters (`Module:Entity/Format.splitSemi`, mirroring Editorial/Company):

```wikitext
| presentationurl = https://…/first; https://…/second
```

`buildSiteLinks` renders one link per URL, **numbering the labels** when there is more than one ("Presentation 1 · Presentation 2"); a single URL keeps the bare label. Community sites (UEX, Erkul, Ship Matrix, Universal Item Finder, Wiki API) are derived from API identifiers (`uuid`, `class_name`, `shipmatrix_name`), not editor args.

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
├── editorial.json       # 25-field editorial manifest (overlap + pure-editorial fields)
├── officialSites.json   # Official external-site link definitions (<name>url args)
├── communitySites.json  # Community external-site link definitions (UEX, Erkul, Ship Matrix, …)
└── testcases.lua        # ScribuntoUnit suite
```
