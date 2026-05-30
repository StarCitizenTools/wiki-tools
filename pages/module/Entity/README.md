# Module:Entity

Renders the entity infobox and owns page metadata (SMW structured data,
short description, categories) from a single `{{Entity}}` invocation. Sibling
renderers (Availability, Related, Ports, UsedBy, Description, Blueprints) consume
`Module:Entity/Data` and render their own page sections.

## Composition model

An entity page is assembled from three kinds of component:

- **Kind** — a top-level entity with its own API endpoint and a
  mutually-exclusive identity (Item, Vehicle, Commodity). `Module:Entity/Data`
  probes each registered kind's identity endpoint and asks `matches(apiData)`;
  first match wins.
- **Chain link** — kinds extend a `p.parent` chain (Base → Item → subtype). Each
  link contributes infobox sections / structured data / etc. for the level it
  owns. Links are merged root-to-leaf.
- **Facet** — a cross-cutting, additive aspect detected by the presence of a
  data field (e.g. `consumable` on `apiData.food`), independent of the primary
  kind. Every facet whose `matches(apiData)` is true contributes, on top of the
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

Prefer a **facet** for any new aspect: it is additive, kind-independent, and
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
