# Module:Entity

Renders the entity infobox and owns the page's metadata (SMW structured data,
short description, and categories) from a single `{{Entity}}` invocation. Sibling
renderers (Availability, Related, Ports, UsedBy, Description, Blueprints, and the
Mission-only Orders / Rewards) consume `Module:Entity/Data` and render their own
page sections off the same fetch. Each sibling renderer resolves its own payload
hook leaf-first over result.chain (getAcquisition, getRelated, getBlueprints,
getPorts) and never branches on result.kind.

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

2. **Probe kinds**: when the page declares `|kind=` alongside a uuid (the
   `{{Vehicle}}` and `{{Location}}` facades inject it), the declared kind's own
   endpoint is fetched directly, behind a validity gate — the declaration holds
   only when `matches(data)` accepts the record. A kind claims exactly the records
   it can render (Location's `matches` accepts SolarSystem records and jump-point
   gates directly, both of which resolve a leaf); see
   [Module:Entity/Data](https://starcitizen.tools/Module:Entity/Data)'s Flow for the
   gate semantics. Otherwise the probe fetches each kind's primary endpoint in
   `Registry.kinds` order (from
   [Module:Entity/Registry](https://starcitizen.tools/Module:Entity/Registry)),
   first `matches()` winning. Every fetch targets a kind's typed endpoint, so one
   record lands on one Apiunto cache key however the page is invoked; the API's
   `search/<uuid>` resolver is deliberately not used. With no uuid, nothing is
   probed (see the editorial fork below).

3. **Resolve subtype leaf**: if the matched kind exposes `resolveSubtype(apiData,
   args)`, it is called now to refine the kind to a more-specific leaf module. The
   mechanical lookup is shared: Item, Vehicle and Location each derive a family
   token and pass it to [Module:Entity/SubtypeResolver](https://starcitizen.tools/Module:Entity/SubtypeResolver).resolve(token,
   map). Item dispatches on `apiData.type` (`itemSubtypeMapping`, e.g. `WeaponGun`);
   Vehicle dispatches on the record's family flags, falling back to the curated
   `|family=` (`SubtypeResolver.familyArg`) in editorial mode (`VEHICLE_FAMILY_MAP`
   → Ship / GroundVehicle / Gravlev); Location dispatches on the record's family
   (SolarSystem / jump-point gate), else `|family=` when it names a mapped family,
   else its `defaultFamily` (`starsystem`) on a kind-declared record-less page.
   With no subtype match the kind module itself stays the leaf (Item stays Item,
   Vehicle stays Vehicle). Separately, when **no kind** matched back in step 2, the
   leaf falls back to Item, flagged `hasApiError` only when a uuid was supplied but
   resolved to nothing.

4. **Build the chain**: [Module:Entity/Assembly](https://starcitizen.tools/Module:Entity/Assembly).buildChain
   walks the leaf's `p.parent` pointers upward to Base, then reverses to return
   `[Base, …, Leaf]` root-first.

5. **Fetch chain extras**: any `getApiConfigs` endpoint not already fetched during
   probing is collected from every chain link and fetched via
   [Module:Entity/Api](https://starcitizen.tools/Module:Entity/Api).fetchAllApis;
   results are merged into `apiData`.

6. **Enrich**: every chain link's `enrich(apiData, args)` hook, where present, runs
   now root to leaf, each link receiving the previous link's result — post-processing
   or normalising the merged data, or attaching a secondary record the primary
   endpoint does not carry (Commodity's kind-level `enrich` attaches raw/refined
   records; the StarSystem leaf attaches the RSI starmap star-system record, looked
   up by name; the JumpPoint leaf attaches the starmap celestial object, keyed by
   `|starmapcode=`). The same hooks also run on the editorial fork, where `apiData`
   starts empty and `args` is the only input — that is how a kind-declared lore page
   with no uuid still fills its infobox.

7. **Resolve typeInfo / displayType**: the leaf's `getTypeInfo(apiData, args)` is
   tried first. On nil, [Module:Entity/TypeResolver](https://starcitizen.tools/Module:Entity/TypeResolver).resolve
   walks `classifications.json` (Ship.* prefix ladder) then `types.json` (raw `type`
   key) to produce the `{ name, category }` pair that becomes the infobox header
   label and the browse category. `typeInfo.name` is the page's most-specific
   structural type; `Module:Entity` also persists it as the queryable **Subject
   type** SMW property, distinct from the coarse `result.kind` (Item / Vehicle / …).

8. **Resolve editorial fields**: when any chain link exposes
   `getEditorialManifest()`, the fragments are merged root to leaf
   (`Assembly.mergeEditorialManifests`, leaf keys winning) into one manifest, then
   [Module:Entity/Editorial](https://starcitizen.tools/Module:Entity/Editorial).resolve(apiData,
   args, manifest) reconciles editor-supplied values against the API per the
   manifest (editor input wins, fills gaps the API lacks, records every manual value
   for later retirement). It yields `resolved` (field → `{ value, source, apiValue }`,
   read by section builders through `Editorial.view(resolved):value(field, fallback)`),
   the SMW projection `editorialData`, and `hasManualApiData`.

9. **Append categories**: every chain link's `getCategories(apiData, args, resolved)`,
   where present, is collected root to leaf (`Assembly.collect`) and the results are
   appended to the structural + manufacturer categories. A leaf reads its own
   `family` token directly rather than receiving it as a parameter.

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
StarSystem leaf), rebuilds the chain, and then runs the rebuilt chain's
`enrich(apiData, args)` hooks on that empty payload. The rest of the pipeline runs
unchanged, so such a page is a clean data-gated subset.

What fills it depends on the chain. No Vehicle chain link implements `enrich`, so a
concept ship renders purely from the `resolved` editorial layer — this is how
not-yet-in-game vehicles render before they exist in the API. Location's StarSystem
leaf does: a lore star system with no uuid still fetches its RSI starmap record by
page title through the rebuilt chain's `enrich` and renders real affiliation, size,
sensor and object-count data alongside the editorial fields.

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
- **Chain link (contributor)**: every link of the `p.parent` chain (Base → kind →
  leaf) implements the same optional hook set; a kind adds only identity (`name`,
  `matches`, `getApiConfigs`, `resolveSubtype`). Each hook has one merge policy,
  applied by `Module:Entity/Data`: additive (sections, structured data, categories,
  external sites, metadata rows, footer buttons), root-to-leaf (enrich, editorial
  manifest), or leaf-first-wins (type info, short description, subtitle, header
  badge, acquisition). A leaf therefore owns everything specific to it — the kind
  never re-dispatches on the leaf.
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
owned by each kind's `resolveSubtype`. Item (via `itemSubtypeMapping`), Vehicle
(Ship / GroundVehicle / Gravlev via `VEHICLE_FAMILY_MAP`), and Location (StarSystem /
JumpPoint via its own family-token map) all dispatch this way, sharing the mechanical
`token → module` lookup in **`Module:Entity/SubtypeResolver`**.

## Hook reference

Function hooks (validated by `Module:Entity/Contract.validate`) plus the two scalar
kind **fields** `name` / `editorialMode` (validated by `Contract.validateFields`):

| Hook / field | Signature | Role | Required | When called |
| --- | --- | --- | --- | --- |
| `name` | `string` | kind | **yes** | Canonical kind name, exposed as `Data.get().kind`. Non-empty + unique, enforced by the Registry conformance test. |
| `matches` | `(apiData) → boolean` | kind, facet | yes | Kind identity probe / facet detection. Must be nil-safe, strict boolean. |
| `getApiConfigs` | `() → EntityApiConfig[]` | kind (also any link) | yes (kind) | `[1]` is the kind's identity endpoint; extra configs fetched for the chain. |
| `resolveSubtype` | `(apiData, args) → module\|nil` | kind | no | Refine to a subtype leaf: the record's family token first (Item: `apiData.type`; Vehicle: the `is_*` flags; Location: SolarSystem / jump-point gate), else the curated `\|family=` (`SubtypeResolver.familyArg`), else the kind's `defaultFamily` on a kind-declared record-less page. |
| `family` / `defaultFamily` | `string\|nil` | leaf / kind | no | A leaf's family token (`ship`, `jumppoint`, …), the same string its kind's map dispatches on and a page's `\|family=` may name. `defaultFamily` on a kind names the leaf a kind-declared page with no record resolves to (Location: `starsystem`). |
| `enrich` | `(apiData, args) → apiData` | chain link | no | Post-fetch mutation, run on every link **root to leaf** after the chain's endpoints are fetched (Commodity merges raw/refined; the StarSystem leaf attaches the starmap system by name, the JumpPoint leaf the celestial object by `\|starmapcode=`). Also runs on the editorial fork with an empty `apiData`. |
| `getEditorialManifest` | `() → table` | chain link | no | Manifest fragment; fragments **merge root to leaf, leaf keys win**. Any link defining one opts the page into the editorial layer. |
| `editorialMode` | `boolean\|nil` | kind | no | Opt-in: when true the kind renders from editorial args alone (`apiData = {}`) for planned / not-yet-in-game pages. |
| `getAcquisition` | `(apiData, args) → { summary, cards }\|nil` | chain link | no | Acquisition payload for `{{Entity/Availability}}`, **leaf-first wins**. Absent on every link → no acquisition block. |
| `getRelated` | `(apiData, args) → { items }\|{ cargo }\|nil` | chain link | no | Payload for `{{Entity/Related}}`, **leaf-first wins**. Base returns the record's `related_items` (tiles); Commodity returns cargo-box rows (table). |
| `getBlueprints` | `(apiData, args) → { blueprints }\|{ ingredient }\|nil` | chain link | no | Payload for `{{Entity/Blueprints}}`, **leaf-first wins**. Base returns the record's `blueprint` list; Commodity returns `{ ingredient = { name } }` (used-in card). |
| `getPorts` | `(apiData, args) → { ports, narrowChildren? }\|nil` | chain link | no | Payload for `{{Entity/Ports}}`, **leaf-first wins**. Base returns the record's `ports` tree; Vehicle adds `narrowChildren = true`. |
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
| `getCategories` | `(apiData, args, resolved) → string[]` | chain link | no | Extra browse categories, **collected from every link** and appended after the structural + manufacturer categories (Vehicle: state / series / career; Ship: size + `Pledge ships`). |
| `parent` | `string\|nil` | chain link | no | Module path of the parent link. |

See `Module:Entity/Types` for the full LuaCATS interfaces and
`Module:Entity/Contract` for the validator the conformance test uses
(`CONTRIBUTOR`, `KIND` = `KIND_IDENTITY` ∪ `CONTRIBUTOR`, `FACET`, and
`KIND_FIELDS` for `name` / `editorialMode`; `CHAIN_LINK` is `CONTRIBUTOR`'s
older name).

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
3. Family-specific categories go in the leaf's own `getCategories`; the kind keeps
   only family-independent ones.

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
| [Module:Entity/Location](https://starcitizen.tools/Module:Entity/Location) | Location kind; dispatches to the StarSystem leaf (SolarSystem records, and the kind-declared default) or the JumpPoint leaf (jump-point gates: `JumpPoint`-typed records, or `Anomaly` records named `… Jump Point`, which `matches` claims directly). Each leaf's `enrich` attaches its starmap record through `Module:Entity/Location/Util`'s `attachStarsystem` / `attachCelestialObject`: the star system by name, or the celestial object by starmap code for jump points. Opts into editorial mode for the lore systems that have no game record |
| [Module:Entity/Mission](https://starcitizen.tools/Module:Entity/Mission) | Mission kind (WIP) |

### Pipeline core modules

| Module | Role |
|---|---|
| [Module:Entity/Data](https://starcitizen.tools/Module:Entity/Data) | Single entry point for all sibling renderers; orchestrates the pipeline |
| [Module:Entity/Registry](https://starcitizen.tools/Module:Entity/Registry) | Declarative lists of all registered kinds and facets |
| [Module:Entity/Assembly](https://starcitizen.tools/Module:Entity/Assembly) | Chain construction (`buildChain`) and section/structured-data merging |
| [Module:Entity/Contract](https://starcitizen.tools/Module:Entity/Contract) | Role-spec tables (CONTRIBUTOR, KIND = KIND_IDENTITY ∪ CONTRIBUTOR, FACET + KIND_FIELDS) + `validate` / `validateFields` |
| [Module:Entity/TypeResolver](https://starcitizen.tools/Module:Entity/TypeResolver) | Display-type resolution via `classifications.json` → `types.json` → raw-type fallback |
| [Module:Entity/SubtypeResolver](https://starcitizen.tools/Module:Entity/SubtypeResolver) | Shared mechanical `token → leaf module` dispatch (used by Item, Vehicle and Location) |
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
| [Module:Entity/Location/Util](https://starcitizen.tools/Module:Entity/Location/Util) | The Location leaves' shared helpers: starmap vocabulary (affiliations, system types), system-name helpers, and the `attachStarsystem` / `attachCelestialObject` bridges |

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
