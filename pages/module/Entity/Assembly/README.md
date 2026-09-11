# Module:Entity/Assembly

The pure composition primitives that turn a resolved type chain into render-ready output: chain construction, additive merges for sections and structured data, leaf-first resolution for single-value fields, and editorial-manifest merging. Every function is stateless.

Editors never invoke this module directly; it runs inside [Template:Entity](https://starcitizen.tools/Template:Entity), [Template:Vehicle](https://starcitizen.tools/Template:Vehicle) and [Template:Location](https://starcitizen.tools/Template:Location).

## For module editors

### API

- `p.buildChain(leafModule) → table[]`: walks `leafModule.parent` (each a `require('Module:' .. parent)` path) up to the module with no `parent`, then returns the chain root-first (Base first, leaf last).
- `p.mergeSections(sectionsList) → table[]`: merges ordered section lists from every chain link into one list. First-seen metadata (`label`, `collapsible`, `collapsed`, `columns`, `class`, `content`, `sections`) wins per `key`, `items` arrays concatenate across links in encounter order, and a section left with no `items`, `content`, or `sections` after merging is dropped.
- `p.mergeStructuredData(dataList) → table`: flat left-to-right fold over key-value tables; later tables override earlier ones on key collision. The merge is shallow: a nested table value is replaced wholesale, not deep-merged.
- `p.callHook(mod, hookName, ctx) → any`: calls `mod[hookName](ctx)` with no existence check. The caller must guard first, since a defined hook returning `nil` is a real answer.
- `p.resolveMostSpecific(chain, hookName, accept, ctx) → any`: walks the chain leaf-first and returns the first link's result `accept` admits. `accept = nil` (default) takes the first *defining* link's result unconditionally, even a `nil` one.
- `p.acceptNonEmpty(result) → boolean`: rejects `nil`/`''`, the standard `accept` predicate for optional override-style hooks (subtitle, header badge).
- `p.collect(chain, hookName, ctx) → any[]`: additive counterpart to `resolveMostSpecific`. Calls every defining link root to leaf and concatenates each table result; a link without the hook, or whose result isn't a table, contributes nothing.
- `p.mergeEditorialManifests(chain) → table|nil`: folds every link's `getEditorialManifest()` fragment root to leaf, leaf field winning on collision. Fragments are copied shallowly, since a `mw.loadJsonData` fragment (Vehicle's) is read-only and nothing writes into it. Returns `nil`, not `{}`, when no link defines a manifest, the signal that a page has no editorial layer at all.

### Gotchas

- `buildChain` is unguarded: a typo'd or deleted `parent` string raises a Lua error at render time with no fallback.
- `mergeSections` order matters twice over: first-seen metadata wins per key, but `items` accumulate root to leaf regardless of which link's metadata won.
- Only `items` is additive in `mergeSections`; `content` and `sections` are frozen at first definition, so two links can't both append freeform content under the same key.
