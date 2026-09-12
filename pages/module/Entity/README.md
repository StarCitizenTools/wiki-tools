# Module:Entity

Renders the entity infobox and owns an item, commodity, mission, vehicle, or location page's [SMW](https://www.mediawiki.org/wiki/Extension:Semantic_MediaWiki) data, short description, and categories from a single template invocation. Editors reach it through `{{Entity}}` and its `{{Vehicle}}`/`{{Location}}` facades; sibling templates share [Apiunto](https://www.mediawiki.org/wiki/Extension:Apiunto)'s cached data to render the rest of the page.

## For editors

Use `{{Entity}}` at the top of an item, commodity, or mission page; `{{Vehicle}}` for a ship, ground vehicle, or gravlev; `{{Location}}` for a star system or jump point. All three render through this module and write the page's SMW data, `SHORTDESC`, and categories.

Sibling templates share Apiunto's cached data; place them further down the page: [Template:Entity/Description](https://starcitizen.tools/Template:Entity/Description) (in-game description prose), [Template:Entity/Availability](https://starcitizen.tools/Template:Entity/Availability) (where to buy/rent/loot/craft it), [Template:Entity/Related](https://starcitizen.tools/Template:Entity/Related) (variants or cargo sizes), [Template:Entity/UsedBy](https://starcitizen.tools/Template:Entity/UsedBy) (vehicles that equip this item), [Template:Entity/Blueprints](https://starcitizen.tools/Template:Entity/Blueprints) (crafting recipes), and [Template:Entity/Ports](https://starcitizen.tools/Template:Entity/Ports) (hardpoint/port tree). On a Mission page, `{{Entity/Orders}}` and `{{Entity/Rewards}}` also store their SMW data.

## Index

### Templates

- [Template:Entity](https://starcitizen.tools/Template:Entity): infobox + page metadata for items, commodities, missions
- [Template:Vehicle](https://starcitizen.tools/Template:Vehicle): `{{Entity}}` facade scoped to ships, ground vehicles, and gravlevs
- [Template:Location](https://starcitizen.tools/Template:Location): `{{Entity}}` facade scoped to star systems and jump points
- [Template:Entity/Availability](https://starcitizen.tools/Template:Entity/Availability): acquisition summary + terminal prices
- [Template:Entity/Blueprints](https://starcitizen.tools/Template:Entity/Blueprints): crafting blueprints and dismantle returns
- [Template:Entity/Description](https://starcitizen.tools/Template:Entity/Description): in-game description prose
- [Template:Entity/Ports](https://starcitizen.tools/Template:Entity/Ports): hardpoint/port tree
- [Template:Entity/Related](https://starcitizen.tools/Template:Entity/Related): variants or cargo-box sizes
- [Template:Entity/UsedBy](https://starcitizen.tools/Template:Entity/UsedBy): vehicles that equip this item

### Kinds and their leaves

- [Module:Entity/Item](https://starcitizen.tools/Module:Entity/Item): the Item kind + subtype dispatch (24 leaves under Item/)
- [Module:Entity/Vehicle](https://starcitizen.tools/Module:Entity/Vehicle): the Vehicle kind + family dispatch (Ship/GroundVehicle/Gravlev leaves; sub-builders under Vehicle/)
- [Module:Entity/Location](https://starcitizen.tools/Module:Entity/Location): the Location kind (StarSystem/JumpPoint leaves; helpers in Location/Util)
- [Module:Entity/Commodity](https://starcitizen.tools/Module:Entity/Commodity): the Commodity kind (raw/refined records via `enrich`; Mining/Records helpers)
- [Module:Entity/Mission](https://starcitizen.tools/Module:Entity/Mission): the Mission kind (WIP)

### Renderers

Consume `Module:Entity/Data` directly:

- [Module:Entity/Availability](https://starcitizen.tools/Module:Entity/Availability): implements `{{Entity/Availability}}`
- [Module:Entity/Blueprints](https://starcitizen.tools/Module:Entity/Blueprints): implements `{{Entity/Blueprints}}`
- [Module:Entity/Description](https://starcitizen.tools/Module:Entity/Description): implements `{{Entity/Description}}`
- [Module:Entity/Related](https://starcitizen.tools/Module:Entity/Related): implements `{{Entity/Related}}`
- [Module:Entity/UsedBy](https://starcitizen.tools/Module:Entity/UsedBy): implements `{{Entity/UsedBy}}`
- [Module:Entity/Ports](https://starcitizen.tools/Module:Entity/Ports): implements `{{Entity/Ports}}` (Categories/Pipeline/Render submodules)
- [Module:Entity/Orders](https://starcitizen.tools/Module:Entity/Orders): Mission hauling-order table; stores its own `orders` SMW data
- [Module:Entity/Rewards](https://starcitizen.tools/Module:Entity/Rewards): Mission reward items/blueprints; stores its own `rewards` SMW data

### Pipeline core

- [Module:Entity/Data](https://starcitizen.tools/Module:Entity/Data): the pipeline entry point every renderer calls
- [Module:Entity/Assembly](https://starcitizen.tools/Module:Entity/Assembly): chain construction + merge primitives
- [Module:Entity/Contract](https://starcitizen.tools/Module:Entity/Contract): the hook-set spec + conformance validator
- [Module:Entity/Registry](https://starcitizen.tools/Module:Entity/Registry): declarative list of every kind and facet
- [Module:Entity/Editorial](https://starcitizen.tools/Module:Entity/Editorial): reconciles editor vs API values
- [Module:Entity/Api](https://starcitizen.tools/Module:Entity/Api): the sole Apiunto I/O seam
- [Module:Entity/Base](https://starcitizen.tools/Module:Entity/Base): root chain link: name, uuid, manufacturer
- [Module:Entity/Infobox](https://starcitizen.tools/Module:Entity/Infobox): assembles and renders the infobox HTML
- [Module:Entity/Categories](https://starcitizen.tools/Module:Entity/Categories): derives browse categories + trailing wikitext
- [Module:Entity/StructuredData](https://starcitizen.tools/Module:Entity/StructuredData): backend-agnostic SMW write
- [Module:Entity/TypeResolver](https://starcitizen.tools/Module:Entity/TypeResolver): resolves display type + browse category
- [Module:Entity/SubtypeResolver](https://starcitizen.tools/Module:Entity/SubtypeResolver): shared token → leaf-module dispatch
- [Module:Entity/Types](https://starcitizen.tools/Module:Entity/Types): LuaCATS interfaces for every hook, kind, and facet

### Shared helpers

- [Module:Entity/SectionBuilder](https://starcitizen.tools/Module:Entity/SectionBuilder): the shared `getSections` row/section constructor
- [Module:Entity/Format](https://starcitizen.tools/Module:Entity/Format): shared number/list/external-link display helpers
- [Module:Entity/StatFormat](https://starcitizen.tools/Module:Entity/StatFormat): display-scale registry for bar/range stats
- [Module:Entity/Acquisition](https://starcitizen.tools/Module:Entity/Acquisition): logic behind the kinds' `getAcquisition`
- [Module:Entity/ProductionStatus](https://starcitizen.tools/Module:Entity/ProductionStatus): vehicle production-state badge
- [Module:Entity/PageResolver](https://starcitizen.tools/Module:Entity/PageResolver): resolves uuids to wiki pages via SMW
- [Module:Entity/Facet/Util](https://starcitizen.tools/Module:Entity/Facet/Util): shared facet display helpers (22 facet modules live under Facet/*)

## For module editors

### Pipeline

`Data.get`, called independently by every sibling renderer:

1. `parseArgs` merges `#invoke` args with the parent frame's; with neither `uuid` nor `kind` set, it reads the page's stored SMW uuid.
2. `probeKind` fetches a declared `kind`'s endpoint behind a `matches()` gate, or else walks `Registry.kinds` until one matches.
3. `resolveLeaf` refines a matched kind to a subtype leaf via `resolveSubtype`, or keeps the kind itself when no subtype resolves; Item is the fallback only when no kind matched at all.
4. `Assembly.buildChain` walks `p.parent` from the leaf to Base, root-first.
5. Any chain link's `getApiConfigs` endpoint not already fetched is collected, fetched, and merged into `apiData`.
6. Every chain link's `enrich(ctx)` runs root to leaf.
7. With no genuine record and an editorial-mode `kind` declared, `apiData` resets to `{}`; the leaf and chain re-resolve and `enrich` reruns from `args` alone, skipping only the identity fetch and chain extras.
8. `getTypeInfo` (leaf, else `TypeResolver`) resolves `typeInfo`; the merged `getEditorialManifest` drives `Editorial.resolve`; `getCategories` and facet detection (`Registry.facets`) run last.
9. Returns one result table (`chain`, `facets`, `typeInfo`, `resolved`, `ctx`, …) shared by every renderer.

`Entity.main`: parses args, calls `Data.get`, guards on `isIdentifiable` (a uuid, a name, curated or API, or a kind that claimed the page), renders the infobox, stores structured data to SMW, sets `SHORTDESC`, and appends tracking categories.

### Hooks

Identity-shaped hooks take no `ctx`; the rest take `EntityHookContext`. `*` marks a required hook ([Module:Entity/Contract](https://starcitizen.tools/Module:Entity/Contract)).

| Hook | Role | Signature | Merge policy | Consumer |
| --- | --- | --- | --- | --- |
| `matches` | kind*, facet* | `(apiData) → boolean` | identity | `Data` probe/facets |
| `resolveSubtype` | kind | `(apiData, args) → module\|nil` | identity | `Data.resolveLeaf` |
| `getApiConfigs` | kind*, link | `() → EntityApiConfig[]` | collected | `Data`/`Api.fetchAllApis` |
| `getEditorialManifest` | link | `() → table` | root-to-leaf, leaf wins | `Assembly.mergeEditorialManifests` |
| `enrich` | link | `(ctx) → table` | root-to-leaf | `Data.enrichChain` |
| `getSections` | link, facet* | `(ctx) → EntitySectionEntry[]` | additive by key | `Infobox` |
| `getStructuredData` | link, facet | `(ctx) → table` | root-to-leaf, facets, editorial; last wins | `Entity.storeStructuredData` |
| `getShortDescription` | link | `(ctx) → string` | leaf-first wins | `Entity.setShortDescription` |
| `getShortDescriptionPrefix` | facet | `(ctx) → string\|nil` | first non-nil wins | `Entity.setShortDescription` |
| `getExternalSiteItems` | link | `(ctx) → EntityItemData[]` | additive | `Infobox` |
| `getFooterButtons` | link | `(ctx) → table[]` | additive | `Infobox` |
| `getMetadataItems` | link | `(ctx) → EntityItemData[]` | additive | `Infobox` |
| `getCategories` | link | `(ctx) → string[]` | additive | `Data.get`/`Categories.build` |
| `getTypeInfo` | link | `(ctx) → table\|nil` | leaf only, else `TypeResolver` | `Data.get` |
| `getSubtitle` | link | `(ctx) → string\|nil` | leaf-first, skip empty | `Infobox` |
| `getHeaderBadge` | link | `(ctx) → string\|nil` | leaf-first, skip empty | `Infobox` |
| `getAcquisition` | link | `(ctx) → {summary,cards}\|nil` | leaf-first wins | `Entity/Availability` |
| `getRelated` | link | `(ctx) → EntityRelatedPayload\|nil` | leaf-first wins | `Entity/Related` |
| `getBlueprints` | link | `(ctx) → EntityBlueprintsPayload\|nil` | leaf-first wins | `Entity/Blueprints` |
| `getPorts` | link | `(ctx) → EntityPortsPayload\|nil` | leaf-first wins | `Entity/Ports` |

### Hook context

`EntityHookContext` fields are filled in pipeline order; a hook that runs early sees the later ones as `nil`.

| Field | Value | `nil` when |
| --- | --- | --- |
| `apiData` | merged API record (`{}` on the editorial fork) | never |
| `args` | parsed template args | never |
| `resolved` | editorial resolved fields (`{}` when the chain declares no manifest) | during `enrich` / `getTypeInfo` |
| `typeInfo` | `{ name, category, categories }` | during `enrich` / `getTypeInfo` / `getCategories` |
| `prefix` | facet adjective for the short description | every hook except `getShortDescription` |
| `kind`, `family` | canonical kind name; leaf family token | during `enrich` / `getTypeInfo` / `getCategories` |

### Adding a kind

1. Create a module with `name`, `matches`, `getApiConfigs` (`[1]` = identity endpoint), `parent = 'Entity/Base'`; add `editorialMode` + `getEditorialManifest` for planned-page support.
2. Append it to `Registry.kinds` (probe order: most-likely-first, Item first; `matches()` must stand alone).
3. See [Module:Entity/Contract](https://starcitizen.tools/Module:Entity/Contract) for the hook spec and [Module:Entity/Registry](https://starcitizen.tools/Module:Entity/Registry) for the conformance test.

### Adding a facet

1. Create `Module:Entity/Facet/<Name>` with a nil-safe `matches` + `getSections`.
2. Append it to `Registry.facets`; it runs additively regardless of the page's kind.
3. See [Module:Entity/Registry](https://starcitizen.tools/Module:Entity/Registry) and [Module:Entity/SectionBuilder](https://starcitizen.tools/Module:Entity/SectionBuilder) for the row-building helpers.

### Adding a subtype

1. Create a leaf with `parent = 'Entity/<Kind>'` and its rendering hooks.
2. Wire it through that kind's own `resolveSubtype`, a token → module map: Item's `itemSubtypeMapping`, Vehicle's `VEHICLE_FAMILY_MAP`, Location's family-token map.
3. See [Module:Entity/Item](https://starcitizen.tools/Module:Entity/Item), [Module:Entity/Vehicle](https://starcitizen.tools/Module:Entity/Vehicle), and [Module:Entity/SubtypeResolver](https://starcitizen.tools/Module:Entity/SubtypeResolver) for the shared token-lookup mechanics.

### Gotchas

- A nested `sections` entry (a subsection tab) takes a raw `{ label, items }` table with no `key`.
- `#` and `next()` are unsafe on a `mw.loadJsonData` fragment (Vehicle's editorial manifest is one); use `pairs`/`ipairs` or check `t[1] ~= nil`.
- A leaf-first-wins hook stops at the first link that *defines* it, even on a `nil` return; it does not fall through. Only `getSubtitle`/`getHeaderBadge` skip `nil`/empty and keep walking.
- `Registry.kinds` order is a probe-cost optimisation only: the declared-`kind` gate can hand any kind's `matches()` a foreign record, so `matches()` must reject on its own.
