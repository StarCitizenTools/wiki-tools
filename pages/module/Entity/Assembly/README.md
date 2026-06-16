# Module:Entity/Assembly

The pure composition primitives that turn a type chain into render-ready output. Assembly walks the `p.parent` chain from a resolved leaf module up to `Base`, returns it in root-first order, then collapses every link's contributions into the single section list and structured-data table the renderer consumes. All three functions are stateless and have no `mw` dependencies.

## Role in the pipeline

```
Data.get
  └─ fetchApiData
       └─ assembly.buildChain(leafMod)      ← chain: [Base, Item, ..., Leaf]
            ↓
       chain passed back to Data.get
            ↓
  Entity renderer calls getSections on each link
  → assembly.mergeSections(sectionsList)    ← one ordered list
  Entity renderer calls getStructuredData on each link
  → assembly.mergeStructuredData(dataList)  ← one flat table
            ↓
  Infobox render + SMW structured-data write
```

[Module:Entity/Data](https://starcitizen.tools/Module:Entity/Data) calls `buildChain` immediately after leaf resolution, inside `fetchApiData`. The resulting chain is stored on the result table returned by `p.get`, and [Module:Entity](https://starcitizen.tools/Module:Entity) iterates it to collect each link's `getSections` and `getStructuredData` output before passing those lists to the two merge functions.

## API

### `p.buildChain(leafModule) → table[]`

```lua
--- @param leafModule table The leaf type module (e.g. WeaponGun)
--- @return table[] List of modules from root (Base) to leaf (WeaponGun)
function p.buildChain(leafModule)
```

Follows `current.parent` from the leaf until a module has no `parent` field, accumulating the chain leaf-first, then reverses it to root-first order. Each `parent` value is passed verbatim to `require('Module:' .. current.parent)`.

### `p.mergeSections(sectionsList) → table[]`

```lua
--- @param sectionsList table[][] List of ordered section lists from each module in the chain
--- @return table[] Ordered list of merged sections
function p.mergeSections(sectionsList)
```

Merges an ordered list of section lists into a single ordered section list. Display order is determined by first appearance of each `key` across the input lists. See **Data** below for the section shape and merge semantics.

### `p.mergeStructuredData(dataList) → table`

```lua
--- @param dataList table[] List of structured data tables from each module in the chain
--- @return table Merged key-value table
function p.mergeStructuredData(dataList)
```

Merges an ordered list of flat key-value tables into one. On key collision, the last table to set a key wins.

## Data

### Chain shape

`buildChain` returns a plain array of module tables, ordered root to leaf — for a gun entity this is typically `[Base, Item, Component, WeaponGun]`. Each element is a live Lua module table (the value returned by `require`). [Module:Entity/Data](https://starcitizen.tools/Module:Entity/Data) stores this array on the result of `p.get` as `result.chain`.

### Section entry shape

Each entry in a section list is a table with a required `key` field plus display fields:

| Field | Type | Purpose |
|---|---|---|
| `key` | `string` | Merge identity — entries with the same key across links are merged |
| `label` | `string` | Display heading for the section |
| `collapsible` | `boolean` | Whether the section can be collapsed |
| `collapsed` | `boolean` | Initial collapsed state |
| `columns` | `any` | Column layout hint for multi-column sections |
| `class` | `string` | CSS class(es) applied to the section element |
| `content` | `any` | Custom HTML content (used instead of `items` for freeform sections) |
| `sections` | `table[]` | Nested sub-sections |
| `items` | `table[]` | Ordered list of infobox row items |

### `mergeSections` semantics

1. **First definition wins for metadata.** When two links declare a section with the same `key`, the first one's `label`, `collapsible`, `collapsed`, `columns`, `class`, `content`, and `sections` are kept; later definitions' metadata is silently discarded.
2. **Items are additive.** All `items` arrays across every occurrence of a `key` are concatenated in encounter order. Base's items appear before Item's, which appear before the leaf's.
3. **Empty sections are dropped.** After merging, any section that has no `items` (or a zero-length array), no `content`, and no `sections` is removed from the result entirely. This prevents stale scaffold sections — e.g. a `general` stub declared in `Base` that a more specific kind supersedes with a different key — from rendering as blank blocks.

### `mergeStructuredData` semantics

A plain left-to-right fold: each key-value pair in each table is written to the result. Later tables override earlier ones on collision, so leaf-module properties take precedence over base properties of the same name. The merge is shallow — nested tables are replaced wholesale, not deep-merged.

## Gotchas

**`buildChain` is unguarded.** The walk does `require('Module:' .. current.parent)` with no error handling. A typo in any module's `p.parent` string — or a deleted/renamed parent module — raises a Lua error at render time and crashes the entire infobox with no graceful fallback. There is no nil-check or pcall around the require. Verify the full parent chain exists on-wiki before deploying a new type module.

**Merge order is significant.** Both merges are order-dependent. `mergeSections` locks in display order and metadata on first encounter; items accumulate in chain order (root first). `mergeStructuredData` uses last-writer-wins. A leaf module's structured-data fields silently overwrite a base module's field of the same name — this is intentional for specialization, but it means base modules should not set fields the leaf is expected to own.

**`content` and `sections` are not merged.** For a given section `key`, only the first link's `content` and `sections` survive; later links cannot append to them. Only `items` is additive. If two links need to contribute freeform content under the same key, one of them needs a distinct key.

## Tests

`Assembly/testcases.lua` is a ScribuntoUnit suite covering all three exported functions. Because all three are pure — no `mw` calls, no global reads, no side effects — coverage is thorough:

- **`mergeSections`**: empty input; single module with one section; two modules merging onto the same key (items appended, first-metadata-wins confirmed); insertion order preserved across three modules with distinct keys; one module contributing multiple keys; a `content`-only section (no `items` key); a section whose `items` is an empty table (dropped entirely); a section kept when only `content` is present.
- **`mergeStructuredData`**: empty input; two tables combining disjoint keys; key collision where the later table overrides.
- **`buildChain`**: a single module with `parent = nil` returns a one-element chain.

Note that `buildChain` with a multi-hop parent chain cannot be tested in isolation without real on-wiki module paths — the test suite covers only the base case. Multi-hop behavior is exercised implicitly via the full Entity integration on live pages.

Tests run on-wiki via ScribuntoUnit. Deploy the module before running; they do not run in local CI.

## Architecture

```
Entity/Assembly/
├── Assembly.lua      # buildChain, mergeSections, mergeStructuredData
└── testcases.lua     # ScribuntoUnit suite (pure-function coverage)
```

`Assembly.lua` has no `mw` dependencies and no side effects on load. Its only runtime dependency is `require` for the parent-chain walk, which happens inside `buildChain` at call time, not at module load time. This makes it cheap to require from tests and safe to load before the `mw` global is available in a non-MediaWiki context (useful for future offline tooling).
