# Module:Entity

Renders the entity infobox and owns the page's metadata — SMW structured data,
short description, and categories — from a single `{{Entity}}` invocation. Sibling
renderers (Availability, Related, Ports, UsedBy, Description, Blueprints) consume
`Module:Entity/Data` and render their own page sections off the same fetch.

## Pipeline walkthrough

A single `{{Entity}}` invocation runs this sequence inside
[Module:Entity/Data](https://starcitizen.tools/Module:Entity/Data).get. Each step
feeds the next:

1. **Parse args** — `Data.parseArgs` merges direct `#invoke` args with parent-frame
   args and, when `uuid` is absent from both, reads the SMW-stored UUID via `#show`
   so sibling templates can omit it.

2. **Probe kinds** — iterates `Registry.kinds` (from
   [Module:Entity/Registry](https://starcitizen.tools/Module:Entity/Registry)) in
   registration order. For each kind, [Module:Entity/Api](https://starcitizen.tools/Module:Entity/Api)
   fetches the kind's primary endpoint and calls `kind.matches(apiData)`; the first
   true result wins and the loop short-circuits. Common-case Item is listed first, so
   most pages pay one fetch.

3. **Resolve subtype leaf** — if the matched kind exposes `resolveSubtype`, it is
   called now to refine the kind to a more-specific module (e.g. Item →
   WeaponGun). The returned module, or the kind itself, becomes the leaf. With no
   match, falls back to Item and sets `hasApiError = true`. Subtype dispatch for
   Item is a one-line table lookup in `itemSubtypeMapping` inside
   [Module:Entity/Item](https://starcitizen.tools/Module:Entity/Item).

4. **Build the chain** — [Module:Entity/Assembly](https://starcitizen.tools/Module:Entity/Assembly).buildChain
   walks the leaf's `p.parent` pointers upward to Base, then reverses to return
   `[Base, …, Leaf]` root-first.

5. **Fetch chain extras** — any `getApiConfigs` endpoint not already fetched during
   probing is collected from every chain link and fetched via
   [Module:Entity/Api](https://starcitizen.tools/Module:Entity/Api).fetchAllApis;
   results are merged into `apiData`.

6. **Enrich** — if the matched kind exposes an `enrich(apiData)` hook, it runs now
   to post-process or normalise the merged data (e.g. Commodity attaches raw/refined
   records).

7. **Resolve typeInfo / displayType** — the leaf's `getTypeInfo(apiData, args)` is
   tried first. On nil, [Module:Entity/TypeResolver](https://starcitizen.tools/Module:Entity/TypeResolver).resolve
   walks `classifications.json` (Ship.* prefix ladder) then `types.json` (raw `type`
   key) to produce the `{ name, category }` pair that becomes the infobox header
   label and the browse category.

8. **Detect facets** — iterates `Registry.facets` in registration order; every facet
   whose `matches(apiData)` is true is appended to the result list (no
   short-circuit; facets are additive). This runs last because it is independent of
   typeInfo.

[Module:Entity/Data](https://starcitizen.tools/Module:Entity/Data) then returns a
single result table to the caller. `Module:Entity` (the infobox renderer) iterates
the chain and facet lists — calling `getSections` and `getStructuredData` on each —
and passes the merged lists to
[Module:Entity/Assembly](https://starcitizen.tools/Module:Entity/Assembly).mergeSections
and `.mergeStructuredData`. It then hands off to `Module:Entity/Infobox`,
`Module:Entity/Categories`, and `Module:Entity/StructuredData` to write the page
metadata. See [Module:Entity/Data](https://starcitizen.tools/Module:Entity/Data) for
the full Flow section with edge-case semantics.

## Composition model

An entity page is assembled from three kinds of component:

- **Kind** — a top-level entity with its own API endpoint and a
  mutually-exclusive identity (Item, Vehicle, Commodity). `Module:Entity/Data`
  probes each registered kind's identity endpoint and asks `matches(apiData)`;
  the first match wins.
- **Chain link** — kinds extend a `p.parent` chain (Base → Item → subtype). Each
  link contributes infobox sections, structured data, and so on for the level it
  owns. Links merge root-to-leaf.
- **Facet** — a cross-cutting, additive aspect, detected by the presence of a
  data field (e.g. `consumable` on `apiData.food`) and independent of the primary
  kind. Every facet whose `matches(apiData)` is true contributes on top of the
  chain.

Flow: `Data.get` → probe kinds → resolve subtype leaf → build the chain →
detect facets → `Entity` renders chain sections + facet sections, stores chain +
facet structured data, and composes the short description.

Registration lives in **`Module:Entity/Registry`** (`kinds`, `facets`). Item
subtypes are kind-local in **`Module:Entity/Item`** (`itemSubtypeMapping`), since
only Item has subtypes and the kind owns its own `resolveSubtype`.

## Hook reference

| Hook | Signature | Role | Required | When called |
| --- | --- | --- | --- | --- |
| `matches` | `(apiData) → boolean` | kind, facet | yes | Kind identity probe / facet detection. Must be nil-safe, strict boolean. |
| `getApiConfigs` | `() → EntityApiConfig[]` | kind (also any link) | yes (kind) | `[1]` is the kind's identity endpoint; extra configs fetched for the chain. |
| `resolveSubtype` | `(apiData) → module\|nil` | kind | no | Refine to a subtype leaf module (e.g. Item → Turret). |
| `enrich` | `(apiData) → apiData` | kind | no | Post-fetch mutation (e.g. Commodity attaches raw/refined + harvestable food). |
| `getTypeInfo` | `(apiData) → {name, category}\|nil` | chain link | no | Display subtitle + browse category, preferred over the type map. |
| `getSections` | `(apiData, args) → EntitySectionEntry[]` | chain link, facet | yes (facet) | Infobox sections, merged by `key`. |
| `getStructuredData` | `(apiData, args) → table` | chain link, facet | no | Flat key/value data persisted to SMW. |
| `getShortDescription` | `(apiData, args, typeInfo, prefix) → string` | chain link | no | Page short description (leaf-first wins). |
| `getShortDescriptionPrefix` | `(apiData, args) → string\|nil` | facet | no | Adjective composed into the kind's short description. |
| `getExternalSiteItems` | `(apiData, args) → EntityItemData[]` | chain link | no | External-site links in the infobox. |
| `parent` | `string\|nil` | chain link | no | Module path of the parent link. |

See `Module:Entity/Types` for the full LuaCATS interfaces and
`Module:Entity/Contract` for the validator the conformance test uses.

## Which one am I adding?

- **New API endpoint / new top-level identity?** → a **kind**. Create a module
  with `matches` + `getApiConfigs` (the chain root, `parent = 'Entity/Base'`),
  add it to `Registry.kinds`.
- **A structural variant *within* one kind, tied to that kind's data** (e.g. a
  weapon vs a turret under Item)? → a **subtype** (chain link with
  `parent = 'Entity/Item'`), wired through that kind's `resolveSubtype` +
  `Item.itemSubtypeMapping`.
- **A cross-cutting aspect that can appear on more than one kind** (e.g.
  "consumable", "mineable")? → a **facet**. Create a module with `matches` +
  `getSections`, add it to `Registry.facets`.

**Prefer a facet for any new aspect** — it is additive, kind-independent, and
data-driven. Subtypes are the legacy structural-refinement mechanism (the
Food/Drink subtypes were collapsed into the `consumable` facet); reach for a
subtype only when the variation is genuinely exclusive within a single kind.

## Recipes

**Add a kind**
1. Create `Module:Entity/<Kind>` with `matches`, `getApiConfigs` (`[1]` =
   identity endpoint), `parent = 'Entity/Base'`, and any rendering hooks.
2. Append `require('Module:Entity/<Kind>')` to `Registry.kinds` (mind probe
   order — cheapest/most-common first).
3. The conformance test (`Module:Entity/Registry/testcases`) now covers it; run
   it to confirm the wiring.

**Add a facet**
1. Create `Module:Entity/Facet/<Name>` with `matches` (nil-safe) + `getSections`
   (and optionally `getStructuredData` / `getShortDescriptionPrefix`).
2. Append it to `Registry.facets`. Run the conformance test.

**Add an item subtype**
1. Create `Module:Entity/Item/<Subtype>` with `parent = 'Entity/Item'` and its
   rendering hooks.
2. Add a `<ApiType> = 'Entity/Item/<Subtype>'` entry to `itemSubtypeMapping` in
   `Module:Entity/Item`.

## Component index

A quick map to every piece of the system and its documentation.

### Catalogs

- **Facet catalog** (all 22 facets, registration order, match conditions, section
  rows, SMW keys) →
  [Module:Entity/Registry](https://starcitizen.tools/Module:Entity/Registry)
- **Subtype catalog** (all 24 subtype modules, API type keys, stat blocks, SMW keys)
  → [Module:Entity/Item](https://starcitizen.tools/Module:Entity/Item)

### Pipeline core modules

| Module | Role | Doc |
|---|---|---|
| [Module:Entity/Data](https://starcitizen.tools/Module:Entity/Data) | Single entry point for all sibling renderers; orchestrates the pipeline | [/doc](https://starcitizen.tools/Module:Entity/Data/doc) |
| [Module:Entity/Registry](https://starcitizen.tools/Module:Entity/Registry) | Declarative lists of all registered kinds and facets | [/doc](https://starcitizen.tools/Module:Entity/Registry/doc) |
| [Module:Entity/Assembly](https://starcitizen.tools/Module:Entity/Assembly) | Chain construction (`buildChain`) and section/structured-data merging | [/doc](https://starcitizen.tools/Module:Entity/Assembly/doc) |
| [Module:Entity/Contract](https://starcitizen.tools/Module:Entity/Contract) | Role-spec tables (KIND / FACET / CHAIN_LINK) + `validate` conformance function | [/doc](https://starcitizen.tools/Module:Entity/Contract/doc) |
| [Module:Entity/TypeResolver](https://starcitizen.tools/Module:Entity/TypeResolver) | Display-type resolution via `classifications.json` → `types.json` → raw-type fallback | [/doc](https://starcitizen.tools/Module:Entity/TypeResolver/doc) |
| [Module:Entity/Api](https://starcitizen.tools/Module:Entity/Api) | Apiunto I/O seam — `fetchApi` / `fetchAllApis`; only place `mw.ext.Apiunto` is called | [/doc](https://starcitizen.tools/Module:Entity/Api/doc) |
| [Module:Entity/Item](https://starcitizen.tools/Module:Entity/Item) | Item kind and subtype dispatch (`itemSubtypeMapping`); shared item helpers | [/doc](https://starcitizen.tools/Module:Entity/Item/doc) |

A **Testing & API-drift** section covering the deploy-first test loop, the two
tracking categories, and the deprecated-field handling table is planned for a later
documentation phase.
