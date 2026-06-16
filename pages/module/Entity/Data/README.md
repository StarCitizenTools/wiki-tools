# Module:Entity/Data

The data provider for the Entity infobox system. Every sibling renderer — `{{Entity}}`, `{{Entity/Availability}}`, `{{Entity/Ports}}`, `{{Entity/Related}}`, `{{Entity/UsedBy}}`, `{{Entity/Description}}`, `{{Entity/Blueprints}}` — calls `Data.get` to obtain a single normalized result: parsed wikitext args, merged API data, the resolved module chain, matched facets, and display-type metadata.

The module is **stateless** across `#invoke` calls. No module-level state persists between page parses; repeated calls within the same parse rely on the Apiunto HTTP cache to stay cheap, so each sibling template can call `Data.get` independently without any coordination or shared mutable state.

## Role in the pipeline

```
{{Entity}} ──────────────────────────────────────────────────────────────┐
{{Entity/Availability}} ──────────────────────────────────────────────┐  │
{{Entity/Ports}} ──────────────────────────────────────────────────┐  │  │
{{Entity/Description}} ─────────────────────────────────────────┐  │  │  │
(… other sibling templates …)                                    │  │  │  │
                                                                 ↓  ↓  ↓  ↓
                                                            Entity/Data.get
                                                                    │
                              ┌─────────────────────────────────────┤
                              ↓                                     ↓
                         Entity/Registry                       Entity/Api
                    (kinds + facets lists)           (Apiunto fetch + merge)
                              │
                 ┌────────────┼────────────┐
                 ↓            ↓            ↓
           kind.matches  Assembly.buildChain  TypeResolver.resolve
```

`Data.get` is the single seam between the wikitext template layer and the rendering modules. Renderers do not talk to [Module:Entity/Api](https://starcitizen.tools/Module:Entity/Api), [Module:Entity/Registry](https://starcitizen.tools/Module:Entity/Registry), or [Module:Entity/Assembly](https://starcitizen.tools/Module:Entity/Assembly) directly — they consume the result table that `Data.get` returns.

## API

### `p.parseArgs(frame) → args`

Merges `frame.args` with parent-frame args (the template's call site). Empty strings are normalised to `nil`. The result is a plain table keyed by argument name. See [Data](#data) for the `uuid` fallback behaviour.

### `p.get(args) → result`

Primary entry point for sibling renderers. Takes the `args` table returned by `p.parseArgs` and returns:

```lua
{
    args        = table,        -- the parsed wikitext args passed in
    apiData     = table,        -- merged API response (empty table when no uuid or all fetches fail)
    chain       = table[],      -- module chain from root to leaf, as built by Assembly.buildChain
    facets      = table[],      -- facet modules whose matches(apiData) returned true
    typeInfo    = table|nil,    -- { name, category, … } from leaf.getTypeInfo or TypeResolver.resolve
    displayType = string|nil,   -- typeInfo.name convenience alias; nil when type is unknown
    hasApiError = boolean,      -- true when any load-bearing fetch failed (see Data section for semantics)
}
```

## Flow

`p.get` calls `fetchApiData` and then resolves `typeInfo`/`displayType`. The full ordered sequence is:

1. **`probeKind`** — iterates `registry.kinds` in registration order. For each kind, fetches its primary API endpoint (the first config returned by `kind.getApiConfigs()`). If `kind.matches(data)` is true, that kind wins and the loop short-circuits; later kinds are never fetched. Probe errors on a *non-matching* kind are discarded — a 404 on the items endpoint for a vehicle UUID is expected and does not set `hasApiError`. Only the matched kind's own fetch error is propagated.

2. **`resolveLeaf`** — given the matched kind (or `nil`), resolves the leaf module:
   - If the kind has `resolveSubtype`, calls `kind.resolveSubtype(apiData)`. If it returns a module, that module is the leaf; if it returns `nil`, the kind itself is the leaf.
   - If there was no matched kind, falls back to `Module:Entity/Item`. A UUID that was provided but produced no match sets `hasApiError = true` at this step (a given-but-unmatched UUID indicates a genuine fetch problem).

3. **`Assembly.buildChain`** — calls [Module:Entity/Assembly](https://starcitizen.tools/Module:Entity/Assembly) with the leaf module. Assembly walks the `p.parent` chain upward (leaf → … → Base) to produce the ordered `chain` array (root first, leaf last).

4. **`fetchChainExtras`** — iterates every module in the chain and collects `getApiConfigs()` endpoints that were *not* already fetched during probing. Calls `api.fetchAllApis` for those configs and merges the results into `apiData`.

5. **`enrich`** — if the matched kind exposes an `enrich(apiData)` hook, calls it and replaces `apiData` with its return value. This is the kind's opportunity to post-process or normalise merged data before renderers see it.

6. **`detectFacets`** — iterates `registry.facets` in registration order. Every facet whose `facet.matches(apiData)` returns `true` is appended to `facets`. All matching facets are collected (no short-circuit); facets are additive.

7. **`typeInfo` / `displayType` resolution** — tries `leaf.getTypeInfo(apiData, args)` first. If that returns a result, `displayType` is set to `typeInfo.name`. If `getTypeInfo` is absent or returns `nil`, falls back to [Module:Entity/TypeResolver](https://starcitizen.tools/Module:Entity/TypeResolver)`.resolve(args.type or apiData.type, apiData.classification)`.

## Data

### `parseArgs` argument merging

`parseArgs` merges in two passes: direct frame args first, then parent-frame args for any key not already set. This means an argument supplied directly to `#invoke` takes precedence over one supplied at the template call site. Empty strings (`""`) are treated as absent in both passes — they become `nil` in the result table.

### UUID fallback via SMW

When `uuid` is absent from both frame and parent-frame args after merging, `parseArgs` calls `#show` on the current page to read the SMW-stored `uuid` property (with a fallback to the legacy `UUID` property for pages not yet re-rendered). This means sibling templates — `{{Entity/Availability}}`, `{{Entity/Ports}}`, etc. — can be transcluded without an explicit `uuid` argument as long as `{{Entity}}` was invoked earlier on the same page (it writes the UUID to SMW during its own parse).

The SMW read is namespace-aware: on non-mainspace pages (e.g. `User:` or `Module:` sandboxes), the property name is prefixed with the lowercased namespace (`user_uuid`, `module_uuid`) so test pages do not pollute canonical SMW queries.

### `hasApiError` semantics

`hasApiError` is `true` when:
- The matched kind's primary endpoint returned an error, **or**
- A UUID was provided but no kind matched it (signalling an unexpected 404 across all probed endpoints), **or**
- Any supplemental endpoint fetched by `fetchChainExtras` returned an error.

It is `false` when:
- No UUID was provided (nothing was fetched; not an error), **or**
- A kind probed and *rejected* an endpoint — e.g. the items endpoint returning 404 for a vehicle UUID is discarded before `hasApiError` can be set for it.

Renderers use `hasApiError` to display an error notice instead of an empty infobox.

## Gotchas

**Only `detectFacets` and `resolveLeaf` are test-exported.** `p._internal` exposes exactly these two functions. `probeKind`, `fetchChainExtras`, and `fetchApiData` are local functions with no test export; they are covered only indirectly through `p.get` integration tests if any are written.

**Item-first registry probe is load-bearing external behaviour.** `Registry.kinds` registers `Module:Entity/Item` first deliberately — it matches the majority of pages, so the common case pays one fetch and short-circuits. This relies on Apiunto *not* following the items→vehicles HTTP 302 redirect: if Apiunto transparently followed redirects, a vehicle UUID would match Item and be misclassified. The probe order and Apiunto's redirect behaviour are therefore coupled; changing either without the other will silently misroute vehicle entities.

**A given-but-unmatched UUID surfaces as `hasApiError = true`.** If a UUID is provided but every kind's `matches()` returns false (for example because the API is down or the item is unlisted), `resolveLeaf` falls back to `Module:Entity/Item` *and* sets `hasApiError`. The infobox renders with an error notice rather than silently producing an empty result. Pages without a UUID do not trigger this — `hasApiError` stays false.

**`resolveSubtype` returning `nil` silently falls back to the kind.** If a kind's `resolveSubtype` returns `nil` (unknown sub-type), the kind itself becomes the leaf. This is intentional — the kind's own chain and sections still render — but it means a new sub-type that the kind doesn't recognise will silently render as the base kind rather than emitting an error.

## Tests

`Data/testcases.lua` covers `detectFacets` and `resolveLeaf` via `p._internal`, exercising:

- `detectFacets` matches a consumable facet when `apiData.food` is present, matches nothing on an empty table, and is nil-safe.
- `resolveLeaf` uses the subtype returned by `resolveSubtype`; falls back to the kind when `resolveSubtype` returns `nil`; uses the kind directly when `resolveSubtype` is absent; returns `Module:Entity/Item` with `hasApiError = true` when no kind matched but a UUID was present; returns Item with `hasApiError = false` when no UUID was provided.

Tests run against the real registry on-wiki via ScribuntoUnit. Deploy the module before running them — they do not execute in local CI.

## Architecture

```
Entity/Data/
├── Data.lua          # parseArgs + p.get public API; probeKind/resolveLeaf/fetchChainExtras/fetchApiData local
└── testcases.lua     # ScribuntoUnit suite for detectFacets + resolveLeaf
```

`Data.lua` has four dependencies: [Module:Entity/Api](https://starcitizen.tools/Module:Entity/Api) (Apiunto I/O), [Module:Entity/Assembly](https://starcitizen.tools/Module:Entity/Assembly) (chain construction and section merging), [Module:Entity/Registry](https://starcitizen.tools/Module:Entity/Registry) (the canonical kinds and facets lists), and [Module:Entity/TypeResolver](https://starcitizen.tools/Module:Entity/TypeResolver) (fallback display-type resolution from classification/type maps). It has no dependency on any renderer module — the data flow is strictly one-directional.
