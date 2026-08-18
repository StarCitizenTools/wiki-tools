# Module:Entity

Renders the entity infobox and owns the page's metadata (SMW structured data,
short description, and categories) from a single `{{Entity}}` invocation. Sibling
renderers (Availability, Related, Ports, UsedBy, Description, Blueprints, and the
Mission-only Orders / Rewards) consume `Module:Entity/Data` and render their own
page sections off the same fetch.

## Pipeline walkthrough

A single `{{Entity}}` invocation runs this sequence inside
[Module:Entity/Data](https://starcitizen.tools/Module:Entity/Data).get. Each step
feeds the next:

1. **Parse args**: `Data.parseArgs` merges direct `#invoke` args with parent-frame
   args. When **neither** `uuid` **nor** `kind` is set, it falls back to the
   SMW-stored UUID via `#show` so sibling templates can omit it. The `not kind`
   guard matters: an editorial page that declares `|kind=` states its identity in
   wikitext and must **not** resurrect a stale/placeholder stored uuid (an all-zeros
   or legacy dev-stub value), which would defeat editorial mode.

2. **Probe kinds**: iterates `Registry.kinds` (from
   [Module:Entity/Registry](https://starcitizen.tools/Module:Entity/Registry)) in
   registration order. For each kind, [Module:Entity/Api](https://starcitizen.tools/Module:Entity/Api)
   fetches the kind's primary endpoint and calls `kind.matches(apiData)`; the first
   true result wins and the loop short-circuits. Common-case Item is listed first, so
   most pages pay one fetch. With no uuid, nothing is probed (see the editorial fork
   below). When the page declares `|kind=` **alongside** a uuid, the declaration is
   trusted ahead of the probe behind a validity gate — the declared kind's endpoint is
   fetched directly and holds when `matches(data)` or `resolveSubtype(data, {})`
   accepts the record. This is how records a deliberately-narrow `matches()` rejects
   get in (a jump point's location record is typed `Anomaly`); see
   [Module:Entity/Data](https://starcitizen.tools/Module:Entity/Data)'s Flow for the
   gate semantics.

3. **Resolve subtype leaf**: if the matched kind exposes `resolveSubtype(apiData,
   args)`, it is called now to refine the kind to a more-specific leaf module. The
   mechanical lookup is shared: both Item and Vehicle derive a string token and pass
   it to [Module:Entity/SubtypeResolver](https://starcitizen.tools/Module:Entity/SubtypeResolver).resolve(token,
   map). Item dispatches on `apiData.type` (`itemSubtypeMapping`, e.g. `WeaponGun`);
   Vehicle dispatches on the family flag or curated `|family=` (`VEHICLE_FAMILY_MAP`
   → Ship / GroundVehicle / Gravlev). With no subtype match the kind module itself
   stays the leaf (Item stays Item, Vehicle stays Vehicle). Separately, when **no
   kind** matched back in step 2, the leaf falls back to Item, flagged
   `hasApiError` only when a uuid was supplied but resolved to nothing.

4. **Build the chain**: [Module:Entity/Assembly](https://starcitizen.tools/Module:Entity/Assembly).buildChain
   walks the leaf's `p.parent` pointers upward to Base, then reverses to return
   `[Base, …, Leaf]` root-first.

5. **Fetch chain extras**: any `getApiConfigs` endpoint not already fetched during
   probing is collected from every chain link and fetched via
   [Module:Entity/Api](https://starcitizen.tools/Module:Entity/Api).fetchAllApis;
   results are merged into `apiData`.

6. **Enrich**: if the matched kind exposes an `enrich(apiData, args)` hook, it runs
   now to post-process or normalise the merged data, or to attach a secondary record
   the primary endpoint does not carry (Commodity attaches raw/refined records;
   Location attaches the RSI starmap star-system record, looked up by name — or, for
   jump-point records, the starmap celestial object, keyed by `|starmapcode=`). It also
   runs on the editorial fork, where `apiData` is empty and `args` is the only input
   — that is how a kind-declared lore page with no uuid still fills its infobox.

7. **Resolve typeInfo / displayType**: the leaf's `getTypeInfo(apiData, args)` is
   tried first. On nil, [Module:Entity/TypeResolver](https://starcitizen.tools/Module:Entity/TypeResolver).resolve
   walks `classifications.json` (Ship.* prefix ladder) then `types.json` (raw `type`
   key) to produce the `{ name, category }` pair that becomes the infobox header
   label and the browse category. `typeInfo.name` is the page's most-specific
   structural type; `Module:Entity` also persists it as the queryable **Subject
   type** SMW property, distinct from the coarse `result.kind` (Item / Vehicle / …).

8. **Resolve editorial fields**: when the matched kind exposes
   `getEditorialManifest()`, [Module:Entity/Editorial](https://starcitizen.tools/Module:Entity/Editorial).resolve(apiData,
   args, manifest) reconciles editor-supplied values against the API per the
   manifest (editor input wins, fills gaps the API lacks, records every manual value
   for later retirement). It yields `resolved` (field → `{ value, source, apiValue }`,
   read by section builders through `Editorial.view(resolved):value(field, fallback)`),
   the SMW projection `editorialData`, and `hasManualApiData`.

9. **Append kind categories**: if the matched kind exposes `getCategories`, it is
   called as `getCategories(apiData, args, resolved, family)` (the leaf's `family`
   token is threaded from `Data.get` so it isn't re-resolved) and its results are
   appended to the structural + manufacturer categories.

10. **Detect facets**: iterates `Registry.facets` in registration order; every facet
   whose `matches(apiData)` is true is appended to the result list (no
   short-circuit; facets are additive). This runs last because it is independent of
   typeInfo.

[Module:Entity/Data](https://starcitizen.tools/Module:Entity/Data) then returns a
single result table to the caller, exposing (among others) `args`, `kind`, `apiData`,
`chain`, `facets`, `typeInfo`, `displayType`, `matchedKind`, `family`, `resolved`,
`editorialData`, `hasManualApiData`, `hasApiError`, and `unresolvedReference`.
`Module:Entity` (the infobox renderer) iterates the chain and facet lists, calling
`getSections` and `getStructuredData` on each (both receiving `resolved`), and passes
the merged lists to
[Module:Entity/Assembly](https://starcitizen.tools/Module:Entity/Assembly).mergeSections
and `.mergeStructuredData`. It then hands off to `Module:Entity/Infobox`,
`Module:Entity/Categories`, and `Module:Entity/StructuredData` to write the page
metadata. See [Module:Entity/Data](https://starcitizen.tools/Module:Entity/Data) for
the full Flow section with edge-case semantics.

### Editorial / planned-entity fork

A page with **no genuine in-game record** (no `apiData.uuid`: either nothing came
back, or the API returned a stub the matched kind accepted) but a `|kind=` that names
a kind which opted into editorial mode (`p.editorialMode == true`) renders **without
an identity record**. After step 6, `Data.get` resets `apiData = {}`, re-resolves the
leaf from args (Vehicle reads the curated `|family=`; Location defaults to its
StarSystem leaf), rebuilds the chain, and then runs the kind's `enrich(apiData, args)`
on that empty payload. The rest of the pipeline runs unchanged, so such a page is a
clean data-gated subset.

What fills it depends on the kind. Vehicle has no `enrich`, so a concept ship renders
purely from the `resolved` editorial layer — this is how not-yet-in-game vehicles
render before they exist in the API. Location does have one, so a lore star system
with no uuid still fetches its RSI starmap record by page title and renders real
affiliation, size, sensor and object-count data alongside the editorial fields.

A kind-declared page is also identifiable on that basis alone: `Module:Entity`'s
identity guard accepts a `uuid`, a name, **or** a kind that claimed the page (whose
identity is its title), so a bare `{{Location}}` is a valid invocation. The guard
tests the resolved `matchedKind`, so a misspelled `|kind=` still errors.

The opt-in is harmless on a page that later gets a uuid: the genuine record takes
over. Two tracking categories surface the state: `Entities with manual API data`
(when `hasManualApiData`) and `Pages with an unresolved entity reference` (when a uuid
was supplied but resolved to no genuine record, `unresolvedReference`). Vehicle and
Location are the kinds that opt in today.

## Composition model

An entity page is assembled from three kinds of component, plus an optional editorial
overlay:

- **Kind**: a top-level entity with its own API endpoint and a
  mutually-exclusive identity (Item, Vehicle, Commodity, and the WIP Mission).
  `Module:Entity/Data` probes each registered kind's identity endpoint and asks
  `matches(apiData)`; the first match wins. Every kind also declares a required
  `name` string (its canonical `result.kind`).
- **Chain link**: kinds extend a `p.parent` chain (Base → Item → subtype). Each
  link contributes infobox sections, structured data, and so on for the level it
  owns. Links merge root-to-leaf.
- **Facet**: a cross-cutting, additive aspect, detected by the presence of a
  data field (e.g. `consumable` on `apiData.food`) and independent of the primary
  kind. Every facet whose `matches(apiData)` is true contributes on top of the
  chain.
- **Editorial overlay**: an opt-in per kind (`editorialMode` + `getEditorialManifest`),
  the seam where editor-supplied wikitext values reconcile with API values, enabling
  planned/not-yet-in-game pages and manual overrides. See the editorial fork above.

Flow: `Data.get` → probe kinds → resolve subtype leaf → build the chain → (editorial
fork if no genuine record) → resolve typeInfo → resolve editorial fields → detect
facets → `Entity` renders chain sections + facet sections, stores chain + facet
structured data, and composes the short description.

Registration lives in **`Module:Entity/Registry`** (`kinds`, `facets`). Subtype leaves
are deliberately **not** registered there. Subtype dispatch is a kind-internal concern
owned by each kind's `resolveSubtype`. Both Item (via `itemSubtypeMapping`) and Vehicle
(Ship / GroundVehicle / Gravlev via `VEHICLE_FAMILY_MAP`) dispatch this way, sharing the
mechanical `token → module` lookup in **`Module:Entity/SubtypeResolver`**.

## Hook reference

Function hooks (validated by `Module:Entity/Contract.validate`) plus the two scalar
kind **fields** `name` / `editorialMode` (validated by `Contract.validateFields`):

| Hook / field | Signature | Role | Required | When called |
| --- | --- | --- | --- | --- |
| `name` | `string` | kind | **yes** | Canonical kind name, exposed as `Data.get().kind`. Non-empty + unique, enforced by the Registry conformance test. |
| `matches` | `(apiData) → boolean` | kind, facet | yes | Kind identity probe / facet detection. Must be nil-safe, strict boolean. |
| `getApiConfigs` | `() → EntityApiConfig[]` | kind (also any link) | yes (kind) | `[1]` is the kind's identity endpoint; extra configs fetched for the chain. |
| `resolveSubtype` | `(apiData, args) → module\|nil` | kind | no | Refine to a subtype leaf module (Item → Turret; Vehicle → Ship). `args` carries the curated `|family=` for editorial mode. |
| `enrich` | `(apiData, args) → apiData` | kind | no | Post-fetch mutation (e.g. Commodity attaches raw/refined + harvestable food). `args` is what lets a kind-declared page enrich with no identity record: Location looks the starmap record up by `\|starmapname=` / `\|name=` / the page title. |
| `getEditorialManifest` | `() → table` | kind | no | Per-kind editorial-field manifest; its presence opts the kind into the editorial layer. |
| `editorialMode` | `boolean\|nil` | kind | no | Opt-in: when true the kind renders from editorial args alone (`apiData = {}`) for planned / not-yet-in-game pages. |
| `getAcquisition` | `(apiData, args) → { summary, cards }\|nil` | kind | no | Acquisition payload for `{{Entity/Availability}}`: Buy/Rent/Loot/Craft/Pledge summary flags + terminal cards. Absent → no acquisition block. |
| `getTypeInfo` | `(apiData, args) → {name, category}\|nil` | chain link | no | Display subtitle + browse category, preferred over the type map. |
| `getSections` | `(apiData, args, resolved) → EntitySectionEntry[]` | chain link, facet | yes (facet) | Infobox sections, merged by `key`. `resolved` is the editorial view (nil-safe). |
| `getStructuredData` | `(apiData, args, resolved) → table` | chain link, facet | no | Flat key/value data persisted to SMW. |
| `getShortDescription` | `(apiData, args, typeInfo, prefix, resolved) → string` | chain link | no | Page short description (leaf-first wins). |
| `getShortDescriptionPrefix` | `(apiData, args) → string\|nil` | facet | no | Adjective composed into the kind's short description. |
| `getExternalSiteItems` | `(apiData, args) → EntityItemData[]` | chain link | no | External-site links in the infobox. |
| `getFooterButtons` | `(apiData, args) → table[]` | chain link | no | Footer action-button defs (`{ label, url, icon, class }`), rendered between the Galactapedia button and the page-supplied VerseGuide / Wiki API buttons (StarSystem: the RSI Starmap button). |
| `getMetadataItems` | `(apiData, args) → EntityItemData[]` | chain link | no | Extra rows appended to the Metadata section (StarSystem: the ARK starmap code). |
| `getSubtitle` | `(apiData, args) → string\|nil` | chain link | no | Header subtitle override (else the display type). |
| `getHeaderBadge` | `(apiData, args, resolved) → string\|nil` | chain link | no | Badge HTML composed into the image overlay (Vehicle: production-state badge). |
| `getCategories` | `(apiData, args, resolved, family) → string[]` | kind | no | Extra browse categories appended after the structural + manufacturer categories. |
| `parent` | `string\|nil` | chain link | no | Module path of the parent link. |

See `Module:Entity/Types` for the full LuaCATS interfaces and
`Module:Entity/Contract` for the validator the conformance test uses (`KIND` /
`FACET` / `CHAIN_LINK` hook specs and `KIND_FIELDS` for `name` / `editorialMode`).

## Which one am I adding?

- **New API endpoint / new top-level identity?** → a **kind**. Create a module
  with the required `name`, `matches`, `getApiConfigs` (the chain root,
  `parent = 'Entity/Base'`), add it to `Registry.kinds`.
- **A structural variant *within* one kind, tied to that kind's data** (e.g. a
  weapon vs a turret under Item, or a ship vs a ground vehicle under Vehicle)? → a
  **subtype** (chain link with `parent = 'Entity/<Kind>'`), wired through that kind's
  `resolveSubtype` (which derives a token and calls `SubtypeResolver.resolve`).
- **A cross-cutting aspect that can appear on more than one kind** (e.g.
  "consumable", "mineable")? → a **facet**. Create a module with `matches` +
  `getSections`, add it to `Registry.facets`.

**Prefer a facet for any new aspect**: it is additive, kind-independent, and
data-driven. Subtypes are the structural-refinement mechanism (the Food/Drink
subtypes were collapsed into the `consumable` facet); reach for a subtype only when
the variation is genuinely exclusive within a single kind.

## Recipes

When building a `getSections` / `getStructuredData` body, reach for
**`Module:Entity/SectionBuilder`** (`push` / `pushNonNil` / `section` / `build`). It
centralises the nil-collapsing row and drop-empty-section boilerplate nearly every
contributor repeats by hand, and is the standard the existing call sites use.

**Add a kind**
1. Create `Module:Entity/<Kind>` with `name`, `matches`, `getApiConfigs` (`[1]` =
   identity endpoint), `parent = 'Entity/Base'`, and any rendering hooks. Add
   `getAcquisition` if the kind should populate `{{Entity/Availability}}`; add
   `editorialMode` + `getEditorialManifest` if it should support planned/editorial
   pages.
2. Append `require('Module:Entity/<Kind>')` to `Registry.kinds` (mind probe
   order: cheapest/most-common first).
3. The conformance test (`Module:Entity/Registry/testcases`) now covers it; run
   it to confirm the wiring. A missing/blank `name` fails it.

**Add a facet**
1. Create `Module:Entity/Facet/<Name>` with `matches` (nil-safe) + `getSections`
   (and optionally `getStructuredData` / `getShortDescriptionPrefix`). Build rows
   with `Module:Entity/SectionBuilder`; shared display helpers live in
   `Module:Entity/Facet/Util`.
2. Append it to `Registry.facets`. Run the conformance test.

**Add an item subtype**
1. Create `Module:Entity/Item/<Subtype>` with `parent = 'Entity/Item'` and its
   rendering hooks (compose rows with `Module:Entity/SectionBuilder`).
2. Add a `<ApiType> = 'Entity/Item/<Subtype>'` entry to `itemSubtypeMapping` in
   `Module:Entity/Item` (dispatched on `apiData.type`).

**Add a vehicle family subtype**
1. Create `Module:Entity/Vehicle/<Family>` with `parent = 'Entity/Vehicle'`, a
   `p.family` token, and its rendering hooks.
2. Add a `<token> = 'Entity/Vehicle/<Family>'` entry to `VEHICLE_FAMILY_MAP` in
   `Module:Entity/Vehicle` (dispatched on the API family flag or curated `|family=`).

## Component index

A quick map to every piece of the system.

### Catalogs

- **Facet catalog** (all 22 facets, registration order, match conditions, section
  rows, SMW keys) →
  [Module:Entity/Registry](https://starcitizen.tools/Module:Entity/Registry)
- **Item subtype catalog** (all 24 subtype modules, API type keys, stat blocks, SMW
  keys) → [Module:Entity/Item](https://starcitizen.tools/Module:Entity/Item)
- **Vehicle family leaves** (Ship / GroundVehicle / Gravlev + the Vehicle/ section
  sub-builders) → [Module:Entity/Vehicle](https://starcitizen.tools/Module:Entity/Vehicle)

### Kinds

| Module | Role |
|---|---|
| [Module:Entity/Item](https://starcitizen.tools/Module:Entity/Item) | Item kind + subtype dispatch (`itemSubtypeMapping`); shared item helpers |
| [Module:Entity/Vehicle](https://starcitizen.tools/Module:Entity/Vehicle) | Vehicle kind orchestrator; family dispatch + the Vehicle/ section sub-builders (Overview, Capacity, Cost, Stats, Dimensions, Lore, Development) |
| [Module:Entity/Commodity](https://starcitizen.tools/Module:Entity/Commodity) | Commodity kind (raw/refined records via `enrich`) |
| [Module:Entity/Location](https://starcitizen.tools/Module:Entity/Location) | Location kind; dispatches to the StarSystem leaf (SolarSystem records, and the kind-declared default) or the JumpPoint leaf (Anomaly records named `… Jump Point`, admitted via the declared-kind trust path). `enrich` attaches the matching RSI starmap record: the star system by name, or the celestial object by starmap code for jump points. Opts into editorial mode for the lore systems that have no game record |
| [Module:Entity/Mission](https://starcitizen.tools/Module:Entity/Mission) | Mission kind (WIP) |

### Pipeline core modules

| Module | Role |
|---|---|
| [Module:Entity/Data](https://starcitizen.tools/Module:Entity/Data) | Single entry point for all sibling renderers; orchestrates the pipeline |
| [Module:Entity/Registry](https://starcitizen.tools/Module:Entity/Registry) | Declarative lists of all registered kinds and facets |
| [Module:Entity/Assembly](https://starcitizen.tools/Module:Entity/Assembly) | Chain construction (`buildChain`) and section/structured-data merging |
| [Module:Entity/Contract](https://starcitizen.tools/Module:Entity/Contract) | Role-spec tables (KIND / FACET / CHAIN_LINK + KIND_FIELDS) + `validate` / `validateFields` |
| [Module:Entity/TypeResolver](https://starcitizen.tools/Module:Entity/TypeResolver) | Display-type resolution via `classifications.json` → `types.json` → raw-type fallback |
| [Module:Entity/SubtypeResolver](https://starcitizen.tools/Module:Entity/SubtypeResolver) | Shared mechanical `token → leaf module` dispatch (used by Item and Vehicle) |
| [Module:Entity/Api](https://starcitizen.tools/Module:Entity/Api) | Apiunto I/O seam (`fetchApi` / `fetchAllApis`); only place `mw.ext.Apiunto` is called |
| [Module:Entity/StructuredData](https://starcitizen.tools/Module:Entity/StructuredData) | Backend-agnostic SMW write + `properties.json` registration check |

### Shared helpers

| Module | Role |
|---|---|
| [Module:Entity/SectionBuilder](https://starcitizen.tools/Module:Entity/SectionBuilder) | Section/row constructor every `getSections` reaches for (`push` / `pushNonNil` / `section` / `build`) |
| [Module:Entity/Editorial](https://starcitizen.tools/Module:Entity/Editorial) | Editor-vs-API reconciliation per manifest + the `view` (`:value(field, fallback)`) section builders read |
| [Module:Entity/Acquisition](https://starcitizen.tools/Module:Entity/Acquisition) | Logic behind the kinds' `getAcquisition` (flag resolution, UEX price math, terminal descriptions) |
| [Module:Entity/ProductionStatus](https://starcitizen.tools/Module:Entity/ProductionStatus) | Vehicle production-state badge / label / tooltip tiers |
| [Module:Entity/Facet/Util](https://starcitizen.tools/Module:Entity/Facet/Util) | Stateless display helpers shared across facets (units, ranges, damage types) |

### Sibling renderers

Consume `Module:Entity/Data` and render their own page sections off the same fetch
(they do **not** own page metadata; `Module:Entity` does):

- [Module:Entity/Availability](https://starcitizen.tools/Module:Entity/Availability)
  renders the `getAcquisition` payload (summary grid + terminal cards)
- [Module:Entity/Orders](https://starcitizen.tools/Module:Entity/Orders) /
  [Module:Entity/Rewards](https://starcitizen.tools/Module:Entity/Rewards) render Mission
  objectives and rewards
- Description, Related, Ports, UsedBy, Blueprints

A **Testing & API-drift** section covering the deploy-first test loop and the
deprecated-field handling table is planned for a later documentation phase.
