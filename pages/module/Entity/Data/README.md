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

1. **`probeKind`** resolves the UUID's kind. When the page also declares its kind — `|kind=` naming a registered kind, matched case-insensitively by `kindByName` — the declaration is trusted first: the declared kind's own primary endpoint is fetched directly and the probe below is skipped. This is what admits records whose API type a deliberately-narrow `matches()` will never claim (a jump point's location record reports type `Anomaly`, which `Location.matches` rejects by design). The trust is gated: the declaration holds only when the fetched record passes `kind.matches(data)` **or** the kind's `resolveSubtype(data, {})` resolves a leaf. The empty args table in that call is load-bearing — Location's `resolveSubtype` defaults kind-declared pages (real args carry `kind`) to its StarSystem leaf, which would accept *any* record — so the gate judges the record alone, and a vehicle uuid pasted into `{{Location}}` fails it. On gate failure (a fetch error included) the probe below runs unchanged; on success the declared kind's endpoint is marked fetched so step 4 doesn't request it again.

   Otherwise the resolver answers in a single request. `buildResolverConfig` composes the API's `search/<uuid>` endpoint — which answers with an HTTP redirect to the canonical typed record — carrying the union of every kind's primary query params (params survive the redirect; endpoints ignore includes they don't recognise, so the union is free). `identifyKind` then offers that one payload to every registered kind's `matches()`. Because all of them see the same payload, **each `matches()` must be positive and order-independent**; the registry order is not a tiebreaker here. The matched kind's own primary endpoint is marked fetched alongside the resolver's, so step 4 doesn't request it again.

   `probeKindByEndpoint` is the fallback, and is what the module did unconditionally before the resolver existed: it walks `registry.kinds` in registration order, fetching each kind's primary endpoint until one matches, at up to one request per kind. It runs only when the resolver produces no kind — an unknown UUID, a kind Entity doesn't model (the resolver also resolves blueprints and starmap locations), or a transient failure such as a rate-limit rejection on the throttled `search` endpoint. Errors on a *non-matching* kind are discarded there: the items endpoint rejecting a vehicle UUID is expected and does not set `hasApiError`. Only the matched kind's own fetch error is propagated.

2. **`resolveLeaf`** resolves the leaf module from the matched kind (or `nil`):
   - If the kind has `resolveSubtype`, calls `kind.resolveSubtype(apiData, args)` (the `args` let a kind resolve its sub-identity editorially, e.g. Vehicle reads `|family=` when the API family flags are absent). If it returns a module, that module is the leaf; if it returns `nil`, the kind itself is the leaf.
   - If there was no matched kind, falls back to `Module:Entity/Item`. A UUID that was provided but produced no match sets `hasApiError = true` at this step (a given-but-unmatched UUID indicates a genuine fetch problem).

3. **`Assembly.buildChain`** calls [Module:Entity/Assembly](https://starcitizen.tools/Module:Entity/Assembly) with the leaf module. Assembly walks the `p.parent` chain upward (leaf → … → Base) to produce the ordered `chain` array (root first, leaf last).

4. **`fetchChainExtras`** iterates every module in the chain and collects `getApiConfigs()` endpoints that were *not* already fetched during probing. Calls `api.fetchAllApis` for those configs and merges the results into `apiData`.

5. **`enrich`**: if the matched kind exposes an `enrich(apiData, args)` hook, calls it and replaces `apiData` with its return value. This is the kind's opportunity to post-process or normalise merged data before renderers see it, or to attach a secondary record the primary endpoint does not carry. `args` is passed so a kind can derive that lookup from the page itself rather than from the record — Location fetches the starmap star-system record by `|starmapname=`, the location record's name, `|name=`, or the page title, in that order. The same hook runs on the editorial fork (see below), where `apiData` is empty and `args` is the only input.

6. **`typeInfo` / `displayType` resolution** tries `leaf.getTypeInfo(apiData, args)` first. If that returns a result, `displayType` is set to `typeInfo.name`. If `getTypeInfo` is absent or returns `nil`, falls back to [Module:Entity/TypeResolver](https://starcitizen.tools/Module:Entity/TypeResolver)`.resolve(args.type or apiData.type, apiData.classification)`.

7. **editorial `resolve`**: if the matched kind exposes `getEditorialManifest()`, runs the manifest through [Module:Entity/Editorial](https://starcitizen.tools/Module:Entity/Editorial): `editorial.resolve(apiData, args, manifest)` merges API and `args` values into `resolved`, `editorial.toStructuredData(resolved, manifest)` projects them to SMW key/value pairs (`editorialData`), and `editorial.hasManualApiData(resolved)` flags whether an editor overrode an API-overlap field (`hasManualApiData`). Kinds with no manifest leave all three at their empty defaults (`{}`, `{}`, `false`).

8. **`getCategories` append**: if the matched kind exposes `getCategories(apiData, args, resolved, family)`, calls it for kind-contributed browse categories and merges them into `typeInfo.categories` (copying `typeInfo` first, since a `typeResolver` result may be frozen). The `resolved` and `family` arguments let a kind derive categories from editorial data and the leaf family.

9. **`detectFacets`** iterates `registry.facets` in registration order and appends every facet whose `facet.matches(apiData)` returns `true`. All matches are collected (no short-circuit); facets are additive. This runs last, as `p.get` builds its return table.

### Editorial mode (planned entities)

Between `fetchApiData` (steps 1–5) and `typeInfo` resolution, `p.get` checks whether a **genuine in-game record** came back, tested by `isGenuineRecord(apiData)`: `apiData.uuid` present and non-empty. This is deliberately *not* "the fetch returned something": the API can return a stub/partial for some in-concept entities, so presence-of-record is not enough.

When there is **no** genuine record **and** `args.kind` names a registered kind that opts in (`editorialMode = true`, looked up case-insensitively by `resolveEditorialKind`), `p.get` switches to **editorial mode**:

- the opted-in kind becomes `matchedKind`;
- `apiData` is reset to `{}` so the render is driven entirely by the editorial `resolved` layer;
- the chain is rebuilt from `kind.resolveSubtype(apiData, args)` (the kind resolves its sub-identity from args, such as Vehicle's `|family=`, or Location defaulting to its StarSystem leaf);
- the kind's `enrich(apiData, args)` hook then runs on that empty `apiData` (`runEditorialFork`), so a kind-declared page can still attach a secondary record keyed off the page rather than off a uuid. This is the entry path for the ~84 lore star systems that exist only in the RSI starmap: no location record, no uuid, yet the infobox fills from `apiData.starsystem`. A kind with no `enrich` is unaffected — `apiData` stays `{}`;
- `hasApiError` is forced `false` (a missing record is expected here, not an error);
- `unresolvedReference` is set `true` **iff** a `|uuid=` was provided: a planned page declares no uuid, so a present-but-unresolved uuid is a typo or not-yet-in-API reference worth flagging (`[[Category:Pages with an unresolved entity reference]]`, emitted by `Module:Entity/Categories`).

`args.kind` is consulted in exactly two places, both safe against a wrong declaration. With a uuid, `probeKind`'s declared-kind path (Flow step 1) trusts it behind the validity gate, which rejects any record the kind can neither match nor refine. Without a genuine record, it selects the editorial fork here, where `resolveEditorialKind` requires an opted-in registered kind. See [Module:Entity/Vehicle](https://starcitizen.tools/Module:Entity/Vehicle) and [Module:Entity/Location](https://starcitizen.tools/Module:Entity/Location) for the consumer side.

A kind-declared page also satisfies `Module:Entity`'s identity guard on its own: an entity is identifiable by a `uuid`, by a name (curated or from the record), **or** by a kind that claimed the page, which derives its identity from the page title. The guard tests `result.matchedKind`, not raw `args.kind`, so a misspelled kind still errors rather than rendering a title-only shell.

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
- A UUID was provided but neither the resolver nor the endpoint fallback matched a kind, **or**
- Any supplemental endpoint fetched by `fetchChainExtras` returned an error.

It is `false` when:
- No UUID was provided (nothing was fetched; not an error), **or**
- A kind probed and *rejected* an endpoint: the items endpoint rejecting a vehicle UUID is discarded before `hasApiError` can be set for it, **or**
- The resolver failed and the endpoint fallback then matched a kind. A rate-limited or unavailable `search` endpoint costs latency, not correctness.

Renderers use `hasApiError` to display an error notice instead of an empty infobox.

## Gotchas

**`p._internal` exports `detectFacets`, `resolveLeaf`, `isGenuineRecord`, `resolveEditorialKind`, `buildResolverConfig`, `identifyKind`, `kindByName`, and `runEditorialFork`.** `probeKind`, `probeKindByEndpoint`, `fetchChainExtras`, and `fetchApiData` are local functions with no test export; they are covered indirectly, through the suite's `p.get({})` calls (which take the no-uuid path and never fetch) and through the `p.get` trust-path tests, which stub `Module:Entity/Api.fetchApi` on the require-cached module table and assert on the endpoints requested. The editorial-mode dispatch glue inside `p.get` is exercised the same two ways: its constituent parts — `isGenuineRecord`, `resolveEditorialKind`, `resolveLeaf` arg-threading, and `runEditorialFork`'s enrich call — in isolation, and the dispatch itself through the stubbed-fetch gate-failure test (a uuid that resolves nothing on a kind-declared page lands in the fork). Behaviour against the live API remains browser-verified.

**The resolver depends on Apiunto following redirects.** `search/<uuid>` answers with a `302` to the typed record, so the `StarCitizenWikiAPI` source must set `followRedirects => true` in `$wgApiuntoSources` (Apiunto ≥ 3.1; MediaWiki's HTTP client does not follow redirects by default). Without it every resolver fetch returns the upstream's redirect *body*, `matches()` sees nothing, and every page silently falls back to `probeKindByEndpoint` — correct output at the old cost, which is why the regression is easy to miss. The unit suite cannot catch it: the test runner has no live API.

**Every `matches()` must be positive and order-independent.** The resolver hands one payload of unknown kind to all of them, so a catch-all test claims everything. `Module:Entity/Item` is the one to watch: items carry no kind flag, so it identifies on `class_name` (present on every item, absent from commodities, missions, blueprints and starmap locations) while excluding `is_vehicle` (vehicles carry `class_name` too). `Registry.kinds` order now governs only the `probeKindByEndpoint` fallback, where it is a fetch-cost optimisation — Item first because it dominates the page mix — and no longer a correctness guarantee.

**A given-but-unmatched UUID surfaces as `hasApiError = true`.** If a UUID is provided but every kind's `matches()` returns false (for example because the API is down or the item is unlisted), `resolveLeaf` falls back to `Module:Entity/Item` *and* sets `hasApiError`. The infobox renders with an error notice rather than silently producing an empty result. Pages without a UUID do not trigger this: `hasApiError` stays false.

**`resolveSubtype` returning `nil` silently falls back to the kind.** If a kind's `resolveSubtype` returns `nil` (unknown subtype), the kind itself becomes the leaf. This is intentional (the kind's own chain and sections still render), but it means a new subtype that the kind doesn't recognise will silently render as the base kind rather than emitting an error.

## Tests

`Data/testcases.lua` is a ScribuntoUnit suite exercising the module's pure logic through `p._internal`, plus the public `p.get` on the offline (no-uuid) path and — with `Module:Entity/Api.fetchApi` stubbed — the declared-kind trust path:

- `detectFacets`: matches a consumable facet when `apiData.food` is present, matches nothing on an empty table, and is nil-safe.
- `resolveLeaf`: uses the subtype returned by `resolveSubtype`; falls back to the kind when `resolveSubtype` returns `nil`; uses the kind directly when `resolveSubtype` is absent; returns `Module:Entity/Item` with `hasApiError = true` when no kind matched but a UUID was present (and `false` when none was); and threads `args` through to `resolveSubtype`.
- `isGenuineRecord`: true only when `apiData.uuid` is present and non-empty.
- `resolveEditorialKind`: resolves an opted-in kind by name (case-insensitively), and returns `nil` when `args.kind` is absent, unknown, or names a registered-but-not-opted-in kind.
- `kindByName`: case-insensitive registry lookup with no editorial gating (`'Commodity'` resolves here but not through `resolveEditorialKind`); `nil` for absent/unknown names.
- `runEditorialFork`: calls the declared kind's `enrich` with the parsed args and returns the enriched `apiData` plus the rebuilt chain; a kind with no `enrich` yields an empty `apiData`.
- `parseArgs`: strips empty strings, lets a direct frame arg win over a parent-frame arg, reads the SMW uuid when no `kind` is present, and *skips* the SMW uuid when `|kind=` is supplied (the editorial-mode guard).
- `p.get({})`: the no-uuid call returns the documented table shape, defaults `kind` to `'Item'`, leaves `apiData` empty with `hasApiError = false`, and exposes `family`/`matchedKind` as `nil`.
- the declared-kind trust path (via `p.get` with a stubbed `fetchApi` recording endpoints): a declared `Location` + uuid answering a SolarSystem-shaped record resolves the kind without the search resolver being fetched (lowercase `kind=location` included); a vehicle-shaped record fails the gate and falls through to the probe (search *is* fetched, the record is never adopted); a registry-injected stub kind whose `resolveSubtype` accepts only when `args.kind` is set fails the gate, pinning the empty-args contract; a second stub whose `matches()` is false but whose `resolveSubtype` admits on the record alone takes the trust path, pinning the gate's admission disjunct (the mechanism jump points ride); and a uuid without `|kind=` still takes the resolver path.

The suite is auto-discovered and run headless by the off-wiki runner (`mise run test`, a merge-blocking CI gate) against the real registry. No wiki deploy is required. The runner cannot reach a live API: fetch-dependent flows are unit-tested through the `fetchApi` stub seam where the suite covers them, and browser-verified against the live API beyond that.

## Architecture

```
Entity/
├── Data.lua          # parseArgs + p.get public API; buildResolverConfig/identifyKind/kindByName/
│                     #   probeKind/probeKindByEndpoint/resolveLeaf/fetchChainExtras/fetchApiData/
│                     #   resolveEditorialKind/runEditorialFork local
└── Data/
    └── testcases.lua # ScribuntoUnit suite (detectFacets, resolveLeaf, isGenuineRecord, resolveEditorialKind, runEditorialFork, parseArgs, p.get)
```

Unlike its sibling components (`Entity/Registry/Registry.lua`, `Entity/Api/Api.lua`, …), the module file lives at `Entity/Data.lua` rather than inside the `Entity/Data/` directory: that directory holds only the testcases subpage and this README.

`Data.lua` has five dependencies: [Module:Entity/Api](https://starcitizen.tools/Module:Entity/Api) (Apiunto I/O), [Module:Entity/Assembly](https://starcitizen.tools/Module:Entity/Assembly) (chain construction and section merging), [Module:Entity/Editorial](https://starcitizen.tools/Module:Entity/Editorial) (editorial-field resolution, SMW projection, and manual-override detection for planned pages), [Module:Entity/Registry](https://starcitizen.tools/Module:Entity/Registry) (the canonical kinds and facets lists), and [Module:Entity/TypeResolver](https://starcitizen.tools/Module:Entity/TypeResolver) (fallback display-type resolution from classification/type maps). It has no dependency on any renderer module: the data flow is strictly one-directional.
