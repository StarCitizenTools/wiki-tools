# Module:Entity/SectionBuilder

The shared constructor for the section tables that every Entity `getSections()` returns. Each type module and facet in the chain produces an ordered list of *sections* (the labelled blocks of the infobox); SectionBuilder centralises the boilerplate nearly all of them otherwise repeat by hand: collapsing missing item rows, dropping sections that ended up empty, and assembling the final list without a stray `nil` truncating it. It is a small, pure, `mw`-free primitive (a peer of [Module:Entity/Assembly](https://starcitizen.tools/Module:Entity/Assembly)) required by roughly 45 producers across `Entity/Item`, `Entity/Facet`, and `Entity/Vehicle`.

Using it, a `getSections` collapses to:

```lua
local sectionBuilder = require('Module:Entity/SectionBuilder')

function p.getSections(apiData, args)
    local items = {}
    sectionBuilder.push(items, 'Health', durability.health and format.formatNum(durability.health))
    sectionBuilder.push(items, 'Resistance', formatResistance(durability.resistance))
    return sectionBuilder.build(sectionBuilder.section({
        key = 'component', label = 'Component', collapsible = true, collapsed = true, items = items,
    }))
end
```

## Role in the pipeline

```
type module / facet getSections(apiData, args, resolved)
  ├─ push / pushNonNil  → accumulate { label, content } item rows
  ├─ section(cfg)       → wrap rows into one section, or nil if empty
  └─ build(...)         → collect the non-nil sections into the return list
       ↓
  assembly.mergeSections(sectionsList)   ← merges every link's list by key
       ↓
  Entity renderer → infobox
```

SectionBuilder is the **producer-side** primitive. It only shapes the table one link returns. The cross-link merge (concatenating items under a shared `key`, first-metadata-wins, dropping sections that are still empty after merging) is [Module:Entity/Assembly](https://starcitizen.tools/Module:Entity/Assembly)'s `mergeSections`, which consumes the lists `build` produces. The two agree on the same section/item shape (see **Data**).

## API

### `p.push(items, label, content) → items`

```lua
--- @param items EntityItemData[]  the row accumulator
--- @param label string
--- @param content any
--- @return EntityItemData[] items
function p.push(items, label, content)
```

Appends a `{ label = label, content = content }` row to `items`, **but only when `content` is present (non-nil and not `''`)**. This is the nil/empty collapse most `getSections` would otherwise write by hand. `false` and `0` are real values and are kept; only `nil` and `''` are treated as "missing". Returns `items` for chaining.

### `p.pushNonNil(items, label, content) → items`

```lua
--- @param items EntityItemData[]  the row accumulator
--- @param label string
--- @param content any
--- @return EntityItemData[] items
function p.pushNonNil(items, label, content)
```

Like `push`, but collapses on `nil` **only; an empty-string `content` is KEPT**. Use it when `content` is already formatted and `''` is a value you still want to display. The canonical case is `format.formatNum(src)`: `formatNum(nil)` is `nil` and `formatNum(non-nil)` is a (possibly empty) string, so `pushNonNil(items, label, format.formatNum(src))` exactly reproduces a hand-written `if src ~= nil then insert(formatNum(src)) end`. Plain `push` would wrongly drop the row whenever the formatter returns `''`. Returns `items`.

See **Gotchas**: choosing the wrong one of these two is the most common SectionBuilder mistake.

### `p.section(cfg) → EntitySectionEntry | nil`

```lua
--- @param cfg EntitySectionEntry
--- @return EntitySectionEntry|nil  nil when the section carries no payload
function p.section(cfg)
```

Builds one section from a config table, or returns **`nil` when it carries no payload**: no item rows, no sub-sections, and no `content` (an empty-string `content` does not count). Returning `nil` lets `build` drop the section, matching the `if #items == 0 then return {} end` guard the producers used to write by hand. A section is considered to have a payload when **any** of:

- `cfg.items` is a non-empty array (`items[1] ~= nil`), or
- `cfg.sections` is a non-empty array (`sections[1] ~= nil`), or
- `cfg.content` is non-nil and not `''`.

When it does, `section` copies through `key`, `label`, `items`, `sections`, `content`, `collapsible`, `collapsed`, `class`, and `columns`. Unset fields stay `nil`, so the result is byte-for-byte the table a hand-build would have produced.

### `p.build(...) → EntitySectionEntry[]`

```lua
--- @param ... EntitySectionEntry|nil
--- @return EntitySectionEntry[]
function p.build(...)
```

Collects the non-`nil` arguments into the ordered list `getSections` returns. **Pass each section (or `nil`) as a separate vararg argument, not as an array literal.** Varargs are used precisely so that an interspersed `nil` (from a `section` that dropped itself) does not truncate the list the way `{ a, nil, b }` would. An all-`nil` call (or no args) yields `{}`, the "nothing to show" return.

## Data

### Section entry shape (what `getSections` returns)

`build` returns an array of section entries. Each entry is an [`EntitySectionEntry`](https://starcitizen.tools/Module:Entity/Types) and carries `key`/`label` metadata plus **exactly one** payload:

| Field | Type | Purpose |
|---|---|---|
| `key` | `string` | Merge identity: entries with the same `key` across the type chain are merged by Assembly |
| `label` | `string` \| nil | Display heading for the section |
| `collapsible` | `boolean` \| nil | Whether the section can be collapsed |
| `collapsed` | `boolean` \| nil | Initial collapsed state |
| `columns` | `number` \| nil | Number of columns for the items grid |
| `class` | `string` \| nil | Extra CSS class on the section element |
| `items` | `EntityItemData[]` \| nil | **Payload A**, the common case: a list of label/content rows |
| `sections` | `EntitySectionEntry[]` \| nil | **Payload B**, nested sub-sections (tabbed groups, e.g. Dimensions, Stats, Cost) |
| `content` | `any` \| nil | **Payload C**, a single pre-rendered blob carried on the section itself |

### Item row shape

Each element of `items` is an [`EntityItemData`](https://starcitizen.tools/Module:Entity/Types):

| Field | Type | Purpose |
|---|---|---|
| `label` | `string` \| nil | Row label |
| `content` | `string` \| nil | Display value |
| `class` | `string` \| nil | CSS class on the row (e.g. `t-infobox-item--block` for a full-width block row) |

`push`/`pushNonNil` only ever set `label` and `content`. A row that needs a `class` (a full-width chart or tile block, say) is appended to `items` directly rather than via the push helpers. See `Entity/Facet/Armor` and `Entity/Facet/DamageFalloff`.

### Choosing the payload

A section uses one payload, not a mix:

- **`items`**: the default. Build it with `push`/`pushNonNil`, pass it as `cfg.items`.
- **`sections`**: for tabbed sub-sections. Each sub-section is itself a `{ label, content }` (or `{ label, items }`) table; see `Entity/Vehicle/Stats`, `Entity/Vehicle/Cost`, and `Entity/Facet/Dimensions`.
- **`content`**: one freeform pre-rendered blob, when the whole section is custom HTML.

## Building a section in `getSections` (minimal example)

```lua
local format = require('Module:Entity/Format')
local sectionBuilder = require('Module:Entity/SectionBuilder')

--- @param apiData table
--- @param args table
--- @return EntitySectionEntry[]
function p.getSections(apiData, args)
    local cooler = apiData.cooler or {}

    local items = {}
    -- formatNum returns nil for nil but a (possibly '') string for a present
    -- source, and that '' should still render -> pushNonNil (push would drop it).
    sectionBuilder.pushNonNil(items, 'Cooling rate', format.formatNum(cooler.cooling_rate))
    -- a plain optional string: collapse both nil and '' -> push.
    sectionBuilder.push(items, 'Grade', cooler.grade)

    -- section() returns nil if `items` ended up empty, and build() drops that
    -- nil, so an entity with no cooler data contributes no section at all.
    return sectionBuilder.build(sectionBuilder.section({
        key = 'cooler',
        label = 'Cooler',
        collapsible = true,
        collapsed = true,
        items = items,
    }))
end
```

## Gotchas

**`push` vs `pushNonNil`: the trap.** `push` drops both `nil` **and** `''`; `pushNonNil` drops `nil` only and **keeps `''`**. The danger is `push` with a formatter that can legitimately return `''` for a *present* source. The recurring example is `format.formatNum`, which returns `nil` for `nil` but the stringified value (possibly `''`) for anything non-nil. If you write `push(items, 'X', format.formatNum(src))`, then whenever `src` is present but stringifies to `''` the row is **silently collapsed**; the value vanishes with no error. That is exactly the case `pushNonNil` exists for. Rule of thumb: if you guard the source yourself (`src and format(src)`), `push` is fine; if you hand the helper a formatter's already-`''`-capable output and a present source must always show, use `pushNonNil`.

| | drops `nil` | drops `''` | keeps `false` / `0` |
|---|---|---|---|
| `push` | yes | **yes** | yes |
| `pushNonNil` | yes | **no** | yes |

**`section()` returns `nil`, not an empty table.** An empty `items` (or `items = {}`), no `sections`, and an absent or `''` `content` all make `section` return `nil`. Always wrap the call in `build(...)` (which filters the `nil` out); never index the result of `section` directly, and never put a bare `section(...)` into an array literal (see below).

**Pass sections to `build` as separate varargs.** `build(a, b, c)` is correct; `build({ a, b, c })` is not: it wraps your list in another list. The vararg form is deliberate so a dropped (`nil`) section does not truncate the list the way `{ a, nil, b }` would in Lua. For a single conditional section, the idiom `cond and sectionBuilder.section({...}) or nil` passed straight into `build` is fine.

**One payload per section.** `items`, `sections`, and `content` are mutually exclusive in practice: Assembly merges only `items` additively across the chain; `content` and `sections` survive only from the first link to declare a given `key`. If two links need to contribute under one heading, use `items`, or give them distinct keys. See the Assembly README's merge semantics.

## Tests

`SectionBuilder/testcases.lua` is a ScribuntoUnit suite. Because all four functions are pure (no `mw` calls, no globals, no side effects), coverage is exhaustive:

- **`push`**: appends present content; skips `nil`; skips `''`; keeps `false` and `0`; returns `items` for chaining.
- **`pushNonNil`**: keeps `''` (the defining difference from `push`); skips `nil`; keeps a value and chains.
- **`section`**: returns `nil` for an empty-items / no-payload / `''`-content config; builds from `items`, from `sections`, and from `content`; passes an item-level `class` through; passes `columns` through; confirms unset payload fields stay `nil`.
- **`build`**: filters interspersed `nil`s without truncating; all-`nil` (and no-arg) yields `{}`; a single section yields a one-element list.

The suite runs in local CI via `mise run test` (the off-wiki ScribuntoUnit runner) and is a merge-blocking gate.

## Architecture

```
Entity/SectionBuilder/
├── SectionBuilder.lua   # push, pushNonNil, section, build
└── testcases.lua        # ScribuntoUnit suite (pure-function coverage)
```

`SectionBuilder.lua` has no `mw` dependencies and no side effects on load: it is a leaf primitive that producers require, never the other way round. The section/item shape it emits is the contract it shares with [Module:Entity/Assembly](https://starcitizen.tools/Module:Entity/Assembly) (`mergeSections`) and [Module:Entity/Types](https://starcitizen.tools/Module:Entity/Types) (`EntitySectionEntry`, `EntityItemData`).
