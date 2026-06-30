# Module:Entity/Data

The data provider for the Entity infobox system. Every sibling renderer (`{{Entity}}`, `{{Entity/Availability}}`, `{{Entity/Ports}}`, `{{Entity/Related}}`, `{{Entity/UsedBy}}`, `{{Entity/Description}}`, `{{Entity/Blueprints}}`) calls `Data.get` to obtain one normalized result: parsed wikitext args, merged API data, the resolved module chain, matched facets, and display-type metadata.

The module is **stateless** across `#invoke` calls: no module-level state persists between page parses. Each sibling template calls `Data.get` independently, with no coordination or shared mutable state; repeated calls within the same parse stay cheap by riding the Apiunto HTTP cache.

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

`Data.get` is the single seam between the wikitext template layer and the rendering modules. Renderers do not talk to [Module:Entity/Api](https://starcitizen.tools/Module:Entity/Api), [Module:Entity/Registry](https://starcitizen.tools/Module:Entity/Registry), or [Module:Entity/Assembly](https://starcitizen.tools/Module:Entity/Assembly) directly; they consume the result table that `Data.get` returns.

## API

### `p.parseArgs(frame) → args`

Merges `frame.args` with parent-frame args (the template's call site). Empty strings are normalised to `nil`. The result is a plain table keyed by argument name. See [Data](#data) for the `uuid` fallback behaviour.

### `p.get(args) → result`

Primary entry point for sibling renderers. Takes the `args` table returned by `p.parseArgs` and returns:

```lua
{
    args        = table,        -- the parsed wikitext args passed in
    kind        = string,       -- canonical kind name from the matched kind's p.name
                                --   (Item/Vehicle/Commodity/Mission); 'Item' when no kind
                                --   matched, mirroring resolveLeaf's fallback. Sibling
                                --   renderers branch on this instead of re-deriving from apiData.
    apiData     = table,        -- merged API response (empty table when no uuid or all fetches fail)
    chain       = table[],      -- module chain from root to leaf, as built by Assembly.buildChain
    facets      = table[],      -- facet modules whose matches(apiData) returned true
    typeInfo    = table|nil,    -- { name, category, … } from leaf.getTypeInfo or TypeResolver.resolve
    displayType = string|nil,   -- typeInfo.name convenience alias; nil when type is unknown
    hasApiError = boolean,      -- true when any load-bearing fetch failed (see Data section for semantics)
    resolved          = table,    -- editorial fields resolved by Module:Entity/Editorial ({} when the kind has no manifest)
    editorialData     = table,    -- editorial values projected to SMW key/value pairs
    hasManualApiData  = boolean,  -- an editor overrode/filled an overlap (apiPath) field → maintenance category
    unresolvedReference = boolean, -- a uuid was provided but resolved to no genuine record (editorial-mode safety)
    matchedKind       = table|nil, -- the matched kind module itself (the same identity `kind` names),
                                   --   or nil when nothing matched (Item fallback, where kind == 'Item').
                                   --   In editorial mode this is the opted-in kind. Renderers that need
                                   --   the module (not just its name) read this; `kind` is the string form.
    family            = string|nil, -- the leaf module's declared `family` (e.g. a Vehicle family);
                                   --   nil when the leaf declares none.
}
```

## Flow

`p.get` calls `fetchApiData` and then resolves `typeInfo`/`displayType`. The full ordered sequence is:

1. **`probeKind`** iterates `registry.kinds` in registration order. For each kind, it fetches its primary API endpoint (the first config returned by `kind.getApiConfigs()`). If `kind.matches(data)` is true, that kind wins and the loop short-circuits; later kinds are never fetched. Probe errors on a *non-matching* kind are discarded: a 404 on the items endpoint for a vehicle UUID is expected and does not set `hasApiError`. Only the matched kind's own fetch error is propagated.

2. **`resolveLeaf`** resolves the leaf module from the matched kind (or `nil`):
   - If the kind has `resolveSubtype`, calls `kind.resolveSubtype(apiData, args)` (the `args` let a kind resolve its sub-identity editorially, e.g. Vehicle reads `|family=` when the API family flags are absent). If it returns a module, that module is the leaf; if it returns `nil`, the kind itself is the leaf.
   - If there was no matched kind, falls back to `Module:Entity/Item`. A UUID that was provided but produced no match sets `hasApiError = true` at this step (a given-but-unmatched UUID indicates a genuine fetch problem).

3. **`Assembly.buildChain`** calls [Module:Entity/Assembly](https://starcitizen.tools/Module:Entity/Assembly) with the leaf module. Assembly walks the `p.parent` chain upward (leaf → … → Base) to produce the ordered `chain` array (root first, leaf last).

4. **`fetchChainExtras`** iterates every module in the chain and collects `getApiConfigs()` endpoints that were *not* already fetched during probing. Calls `api.fetchAllApis` for those configs and merges the results into `apiData`.

5. **`enrich`**: if the matched kind exposes an `enrich(apiData)` hook, calls it and replaces `apiData` with its return value. This is the kind's opportunity to post-process or normalise merged data before renderers see it.

6. **`typeInfo` / `displayType` resolution** tries `leaf.getTypeInfo(apiData, args)` first. If that returns a result, `displayType` is set to `typeInfo.name`. If `getTypeInfo` is absent or returns `nil`, falls back to [Module:Entity/TypeResolver](https://starcitizen.tools/Module:Entity/TypeResolver)`.resolve(args.type or apiData.type, apiData.classification)`.

7. **editorial `resolve`**: if the matched kind exposes `getEditorialManifest()`, runs the manifest through [Module:Entity/Editorial](https://starcitizen.tools/Module:Entity/Editorial): `editorial.resolve(apiData, args, manifest)` merges API and `args` values into `resolved`, `editorial.toStructuredData(resolved, manifest)` projects them to SMW key/value pairs (`editorialData`), and `editorial.hasManualApiData(resolved)` flags whether an editor overrode an API-overlap field (`hasManualApiData`). Kinds with no manifest leave all three at their empty defaults (`{}`, `{}`, `false`).

8. **`getCategories` append**: if the matched kind exposes `getCategories(apiData, args, resolved, family)`, calls it for kind-contributed browse categories and merges them into `typeInfo.categories` (copying `typeInfo` first, since a `typeResolver` result may be frozen). The `resolved` and `family` arguments let a kind derive categories from editorial data and the leaf family.

9. **`detectFacets`** iterates `registry.facets` in registration order and appends every facet whose `facet.matches(apiData)` returns `true`. All matches are collected (no short-circuit); facets are additive. This runs last, as `p.get` builds its return table.

### Editorial mode (planned entities)

Between `fetchApiData` (steps 1–5) and `typeInfo` resolution, `p.get` checks whether a **genuine in-game record** came back, tested by `isGenuineRecord(apiData)`: `apiData.uuid` present and non-empty. This is deliberately *not* "the fetch returned something": the API can return a stub/partial for some in-concept entities, so presence-of-record is not enough.

When there is **no** genuine record **and** `args.kind` names a registered kind that opts in (`editorialMode = true`, looked up case-insensitively by `resolveEditorialKind`), `p.get` switches to **editorial mode**:

- the opted-in kind becomes `matchedKind`;
- `apiData` is reset to `{}` so the render is driven entirely by the editorial `resolved` layer;
- the chain is rebuilt from `kind.resolveSubtype(apiData, args)` (the kind resolves its sub-identity from args, such as Vehicle's `|family=`);
- `hasApiError` is forced `false` (a missing record is expected here, not an error);
- `unresolvedReference` is set `true` **iff** a `|uuid=` was provided: a planned page declares no uuid, so a present-but-unresolved uuid is a typo or not-yet-in-API reference worth flagging (`[[Category:Pages with an unresolved entity reference]]`, emitted by `Module:Entity/Categories`).

`args.kind` is consulted **only** when there is no genuine record, so an in-game page's API-matched kind always wins and `|kind=`/`|family=` are harmless no-ops once a uuid resolves. See [Module:Entity/Vehicle](https://starcitizen.tools/Module:Entity/Vehicle) for the consumer side.

## Data

### `parseArgs` argument merging

`parseArgs` merges in two passes: direct frame args first, then parent-frame args for any key not already set. This means an argument supplied directly to `#invoke` takes precedence over one supplied at the template call site. Empty strings (`""`) are treated as absent in both passes: they become `nil` in the result table.

### UUID fallback via SMW

When `uuid` is absent from both frame and parent-frame args after merging **and** no explicit `kind` was supplied, `parseArgs` calls `#show` on the current page to read the SMW-stored `uuid` property (with a fallback to the legacy `UUID` property for pages not yet re-rendered). This means sibling templates (`{{Entity/Availability}}`, `{{Entity/Ports}}`, etc.) can be transcluded without an explicit `uuid` argument as long as `{{Entity}}` was invoked earlier on the same page (it writes the UUID to SMW during its own parse).

The `not args.kind` half of that guard keeps editorial mode working. A planned page declares its identity with `|kind=` and carries no real uuid, so `parseArgs` must *not* resurrect a stale or placeholder SMW uuid (an all-zeros dev-stub, or a legacy value left by an earlier render). Doing so would re-engage in-game mode and re-store the bad uuid, defeating editorial mode. So supplying `|kind=` deliberately suppresses the SMW-uuid fallback.

The SMW read is namespace-aware: on non-mainspace pages (e.g. `User:` or `Module:` sandboxes), the property name is prefixed with the lowercased namespace (`user_uuid`, `module_uuid`) so test pages do not pollute canonical SMW queries.

### `hasApiError` semantics

`hasApiError` is `true` when:
- The matched kind's primary endpoint returned an error, **or**
- A UUID was provided but no kind matched it (signalling an unexpected 404 across all probed endpoints), **or**
- Any supplemental endpoint fetched by `fetchChainExtras` returned an error.

It is `false` when:
- No UUID was provided (nothing was fetched; not an error), **or**
- A kind probed and *rejected* an endpoint: the items endpoint returning 404 for a vehicle UUID is discarded before `hasApiError` can be set for it.

Renderers use `hasApiError` to display an error notice instead of an empty infobox.

## Gotchas

**`p._internal` exports `detectFacets`, `resolveLeaf`, `isGenuineRecord`, and `resolveEditorialKind`.** `probeKind`, `fetchChainExtras`, and `fetchApiData` are local functions with no test export; they are covered only indirectly, through the suite's `p.get({})` calls (which take the no-uuid path and never fetch). The editorial-mode dispatch glue inside `p.get` (the genuine-record branch on a real API miss) is browser-verified, not unit-tested (the runner has no live API), but its constituent predicates (`isGenuineRecord`, `resolveEditorialKind`, `resolveLeaf` arg-threading) are unit-tested in isolation.

**Item-first registry probe is load-bearing external behaviour.** `Registry.kinds` registers `Module:Entity/Item` first deliberately: it matches the majority of pages, so the common case pays one fetch and short-circuits. This relies on Apiunto *not* following the items→vehicles HTTP 302 redirect: if Apiunto transparently followed redirects, a vehicle UUID would match Item and be misclassified. The probe order and Apiunto's redirect behaviour are therefore coupled; changing either without the other will silently misroute vehicle entities.

**A given-but-unmatched UUID surfaces as `hasApiError = true`.** If a UUID is provided but every kind's `matches()` returns false (for example because the API is down or the item is unlisted), `resolveLeaf` falls back to `Module:Entity/Item` *and* sets `hasApiError`. The infobox renders with an error notice rather than silently producing an empty result. Pages without a UUID do not trigger this: `hasApiError` stays false.

**`resolveSubtype` returning `nil` silently falls back to the kind.** If a kind's `resolveSubtype` returns `nil` (unknown subtype), the kind itself becomes the leaf. This is intentional (the kind's own chain and sections still render), but it means a new subtype that the kind doesn't recognise will silently render as the base kind rather than emitting an error.

## Tests

`Data/testcases.lua` is a ScribuntoUnit suite exercising the module's pure logic through `p._internal`, plus the offline (no-uuid) path of the public `p.get`:

- `detectFacets`: matches a consumable facet when `apiData.food` is present, matches nothing on an empty table, and is nil-safe.
- `resolveLeaf`: uses the subtype returned by `resolveSubtype`; falls back to the kind when `resolveSubtype` returns `nil`; uses the kind directly when `resolveSubtype` is absent; returns `Module:Entity/Item` with `hasApiError = true` when no kind matched but a UUID was present (and `false` when none was); and threads `args` through to `resolveSubtype`.
- `isGenuineRecord`: true only when `apiData.uuid` is present and non-empty.
- `resolveEditorialKind`: resolves an opted-in kind by name (case-insensitively), and returns `nil` when `args.kind` is absent, unknown, or names a registered-but-not-opted-in kind.
- `parseArgs`: strips empty strings, lets a direct frame arg win over a parent-frame arg, reads the SMW uuid when no `kind` is present, and *skips* the SMW uuid when `|kind=` is supplied (the editorial-mode guard).
- `p.get({})`: the no-uuid call returns the documented table shape, defaults `kind` to `'Item'`, leaves `apiData` empty with `hasApiError = false`, and exposes `family`/`matchedKind` as `nil`.

The suite is auto-discovered and run headless by the off-wiki runner (`mise run test`, a merge-blocking CI gate) against the real registry. No wiki deploy is required. The runner cannot reach a live API, so anything that depends on a real fetch (the editorial-mode dispatch on an API hit, chain extras, `enrich`) is browser-verified instead.

## Architecture

```
Entity/
├── Data.lua          # parseArgs + p.get public API; probeKind/resolveLeaf/fetchChainExtras/fetchApiData local
└── Data/
    └── testcases.lua # ScribuntoUnit suite (detectFacets, resolveLeaf, isGenuineRecord, resolveEditorialKind, parseArgs, p.get)
```

Unlike its sibling components (`Entity/Registry/Registry.lua`, `Entity/Api/Api.lua`, …), the module file lives at `Entity/Data.lua` rather than inside the `Entity/Data/` directory: that directory holds only the testcases subpage and this README.

`Data.lua` has five dependencies: [Module:Entity/Api](https://starcitizen.tools/Module:Entity/Api) (Apiunto I/O), [Module:Entity/Assembly](https://starcitizen.tools/Module:Entity/Assembly) (chain construction and section merging), [Module:Entity/Editorial](https://starcitizen.tools/Module:Entity/Editorial) (editorial-field resolution, SMW projection, and manual-override detection for planned pages), [Module:Entity/Registry](https://starcitizen.tools/Module:Entity/Registry) (the canonical kinds and facets lists), and [Module:Entity/TypeResolver](https://starcitizen.tools/Module:Entity/TypeResolver) (fallback display-type resolution from classification/type maps). It has no dependency on any renderer module: the data flow is strictly one-directional.
