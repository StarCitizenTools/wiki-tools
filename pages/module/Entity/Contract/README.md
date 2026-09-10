# Module:Entity/Contract

The machine-checkable spec for what a well-formed Entity component looks like. It declares the shared **contributor** hook set every chain link may implement (`CONTRIBUTOR`, aliased `CHAIN_LINK`), the extra **identity** hooks that make a component a kind (`KIND_IDENTITY`), the kind role that is their union (`KIND`), and the facet role (`FACET`) — which hooks exist per role and whether each is required or optional — then exposes `p.validate` (and `p.validateFields`) so a conformance test can reject a mis-wired component before it is merged.

**Contract has no runtime role.** It is a contributor-facing guardrail. Its only callers are the conformance tests, [Module:Entity/Registry/testcases](https://starcitizen.tools/Module:Entity/Registry/testcases) and Contract's own `testcases.lua`, both of which run under the merge-blocking `mise run test` gate. `Module:Entity` never calls `Contract.validate` during infobox rendering. For the prose contract and a description of what each hook *does*, see [Module:Entity](https://starcitizen.tools/Module:Entity) and the `EntityKind` / `EntityFacet` / `EntityChainLink` classes in `Module:Entity/Types`.

## Role in the pipeline

```
[contributor adds / edits a kind or facet]
            │
            ▼
   Module:Entity/Registry            (registers it)
            │
            ▼
   Registry/testcases  ──calls──▶  Contract.validate(component, spec, { strict = true })
   (mise run test)                  Contract.validateFields(kind, KIND_FIELDS)
            │
   pass ────┴──── fail → ScribuntoUnit error, merge blocked
            │
            ▼
   component is wired into the render pipeline
   (Entity.lua walks the chain; Contract is NOT consulted here)
```

Contract lives entirely outside the render path. `Entity.lua` guards every hook call with `if mod.x` at runtime, so a missing or misnamed hook silently no-ops in production. The Contract module exists precisely to catch those silent failures at test time: a mis-wired kind or facet fails a unit test rather than rendering nothing on-wiki with no error.

## Contract as interface: what a new kind must implement

The full `p.KIND` spec is large, but it is built from two smaller pieces. `p.CONTRIBUTOR` is the hook set **every** chain link — Base, a kind, or a subtype leaf — may implement; every hook in it is optional, and a link implements only what it adds. `p.KIND_IDENTITY` is the small interface that makes a component a kind at all — an [ISP](https://en.wikipedia.org/wiki/Interface_segregation_principle)-style narrowing to just the identity/dispatch hooks a kind author has to think about. `p.KIND` is the union of the two: every `CONTRIBUTOR` hook plus `KIND_IDENTITY`'s, with `KIND_IDENTITY`'s requiredness winning on the one hook both name (`getApiConfigs`).

**A new kind MUST implement** (the two required members of `KIND_IDENTITY`):

| Hook | Signature | Role |
|---|---|---|
| `matches` | `fun(apiData: table\|nil): boolean` | Strict, nil-safe identity predicate: true when this kind owns the page's API record. |
| `getApiConfigs` | `fun(): EntityApiConfig[]` | `[1]` is the identity probe endpoint; the rest are supplemental fetches. |

It must also declare a `name` field (checked via `KIND_FIELDS`, below).

**A kind MAY implement** the one remaining identity hook:

| Hook | Signature | Role |
|---|---|---|
| `resolveSubtype` | `fun(apiData, args): table\|nil` | Refine to a subtype leaf module, or `nil`: the record's family token first, else the curated `\|family=` (`SubtypeResolver.familyArg`), else the kind's `defaultFamily` on a kind-declared record-less page. |

Beyond identity, a kind is also the root of its own chain, so `p.KIND` additionally accepts every `CONTRIBUTOR` hook — `getSections`, `getStructuredData`, `getShortDescription`, `getExternalSiteItems`, `getFooterButtons`, `getMetadataItems`, `getTypeInfo`, `getSubtitle`, `getHeaderBadge`, `enrich`, `getEditorialManifest`, `getCategories`, `getAcquisition` — every one of them optional, and every one of them just as implementable by a subtype leaf further down the same chain: a leaf's `enrich`, `getCategories`, or `getEditorialManifest` merges with its kind's contribution per the policy `Module:Entity/Data` applies (see [Module:Entity](https://starcitizen.tools/Module:Entity)). See the [Data](#data) table for the complete split and the hook notes below it.

## API

### Role-spec tables

Four exported tables encode the contract — three specs plus one alias. Each key is a hook name; the value is `true` (required) or `false` (optional).

`p.CONTRIBUTOR` is the hook set every chain link may implement, every hook optional:

```lua
p.CONTRIBUTOR = {
    getSections = false,
    getStructuredData = false,
    getShortDescription = false,
    getExternalSiteItems = false,
    getFooterButtons = false,
    getMetadataItems = false,
    getTypeInfo = false,
    getApiConfigs = false,
    getSubtitle = false,
    getHeaderBadge = false,
    enrich = false,
    getEditorialManifest = false,
    getCategories = false,
    getAcquisition = false,
}
```

`p.CHAIN_LINK` is `p.CONTRIBUTOR` under its older name, kept so existing callers keep validating against the same table.

`p.KIND_IDENTITY` is the small interface that makes a component a kind:

```lua
p.KIND_IDENTITY = {
    matches = true,
    getApiConfigs = true,
    resolveSubtype = false,
}
```

`p.KIND` is built from the two: every `CONTRIBUTOR` hook, then `KIND_IDENTITY`'s hooks layered on top so `matches` and `resolveSubtype` are added and `getApiConfigs` is promoted from optional to required. `p.FACET` (`matches` + `getSections` required) follows the same `hook = required?` shape independently. The full split for all roles is in the [Data](#data) table.

One derived export supports the rest of the module:

- **`p.ALL_HOOKS`**: the union of every hook name across `KIND`, `FACET` and `CHAIN_LINK`, built on load. Used by `validate`'s strict pass to tell a misspelled hook apart from one that is simply valid in a different role.

### `p.validate(component, spec, options) → ok, errors`

```lua
--- @param component table The module to check
--- @param spec table<string, boolean> A role spec (p.KIND / p.FACET / p.CHAIN_LINK)
--- @param options nil|{ strict: boolean } When strict, also flag hook-shaped keys not in any spec
--- @return boolean ok True when there are no errors
--- @return string[] errors Human-readable messages (empty when ok)
function p.validate(component, spec, options)
```

Walks the spec and checks:

1. If `component` is not a table, returns `false` immediately with a single message (`"component is not a table (got <type>)"`).
2. For each hook in the spec: if the hook is absent and required → `"missing required hook: <hook>"`; if the hook is present but not a function → `"hook is not a function: <hook> (got <type>)"`.
3. **If `options.strict`** (off by default): additionally iterate the *component's* keys and flag each function-valued key that is **not** in this `spec`, **not** in `p.ALL_HOOKS`, and whose name *looks like a hook* (starts with `get`, or is exactly `matches` / `resolveSubtype` / `enrich`) → `"unknown hook (typo?): <key>"`. This is what catches a misspelled optional hook such as `getSectionsn`. A real hook borrowed from another role (e.g. a kind that also defines the FACET-only `getShortDescriptionPrefix`) is in `p.ALL_HOOKS`, so it is allowed.
4. Returns `(#errors == 0, errors)`.

Without `strict`, unknown keys on `component` are not inspected: `validate` only walks the spec's keys (the byte-identical pre-strict behavior). The Registry conformance gate always passes `{ strict = true }`; see [Gotchas](#gotchas).

The strict pass is a *heuristic*: it only fires on hook-shaped names, so a typo that does not start with `get` and is not one of the three named probes (e.g. a misspelled `matche`) still slips through.

### `p.KIND_FIELDS` + `p.validateFields(component, fieldSpec) → ok, errors`

`validate` type-checks every spec key as a *function*, so a kind's non-function scalar fields cannot live in `p.KIND`. They live in `p.KIND_FIELDS` and are checked by `p.validateFields`:

```lua
p.KIND_FIELDS = {
    name          = { type = 'string',  required = true  },  -- canonical kind name (Data.get().result.kind)
    editorialMode = { type = 'boolean', required = false },  -- opt in to editorial-mode rendering
}
```

`validateFields` mirrors `validate`'s shape (non-table guard, per-field loop): a required field that is absent → `"missing required field: <field>"`; a present field whose `type()` ≠ the declared type → `"field has wrong type: <field> (expected <type>, got <type>)"`. The [Registry conformance test](https://starcitizen.tools/Module:Entity/Registry) runs it over every kind alongside `validate`, so a mistyped `editorialMode` (or a missing `name`) fails a unit test. `name`'s additional non-empty + uniqueness guarantee is enforced separately by `testAllKindsDeclareName`.

**`editorialMode`** is the opt-in for a kind to render from editorial args alone (`apiData = {}`) when there is no genuine API record, a planned / not-yet-in-game page (see [Module:Entity/Data](https://starcitizen.tools/Module:Entity/Data)). Only `Vehicle` sets it today. It is distinct from the `getEditorialManifest` hook, which declares *which* editorial fields a kind exposes.

## Data

Required (`true`) and optional (`false`) hooks per role:

| Hook | KIND | FACET | CHAIN_LINK |
|---|---|---|---|
| `matches` | **required** | **required** | — |
| `getApiConfigs` | **required** | — | optional |
| `getSections` | optional | **required** | optional |
| `getStructuredData` | optional | optional | optional |
| `getShortDescription` | optional | — | optional |
| `getShortDescriptionPrefix` | — | optional | — |
| `getExternalSiteItems` | optional | — | optional |
| `getFooterButtons` | optional | — | optional |
| `getMetadataItems` | optional | — | optional |
| `getTypeInfo` | optional | — | optional |
| `getSubtitle` | optional | — | optional |
| `getHeaderBadge` | optional | — | optional |
| `resolveSubtype` | optional | — | — |
| `enrich` | optional | — | optional |
| `getEditorialManifest` | optional | — | optional |
| `getCategories` | optional | — | optional |
| `getAcquisition` | optional | — | optional |

A "—" cell means the hook is not part of that role's spec at all: it is neither required nor validated. `CHAIN_LINK` is `CONTRIBUTOR`'s older name, so its column is that spec: `matches` (required) and `resolveSubtype` (optional) are `KIND_IDENTITY`-only and so read "—" for `CHAIN_LINK`; every other `KIND` hook is a `CONTRIBUTOR` hook and so is available, optionally, to any chain link.

What each of these `CONTRIBUTOR` hooks contributes, and the merge policy `Module:Entity/Data` applies when more than one chain link implements it (see `Module:Entity/Types` for full signatures — every hook below is a `CONTRIBUTOR` hook, so a subtype leaf may implement it just as a kind can):

- **`getEditorialManifest() → table`**: editorial-field manifest fragment (`field → { arg, smw, apiPath?, transform?, default? }`); fragments merge root to leaf, leaf keys winning (`Assembly.mergeEditorialManifests`). Any link defining one opts the page into the editorial layer.
- **`enrich(apiData, args) → apiData`**: post-fetch mutation, run on every link root to leaf, each receiving the previous link's result. A leaf typically attaches the secondary record only it renders (e.g. the StarSystem leaf the starmap system, the JumpPoint leaf the celestial object).
- **`getCategories(apiData, args, resolved) → string[]`**: extra browse categories, collected from every link (`Assembly.collect`) and appended after the structural + manufacturer categories.
- **`getAcquisition(apiData, args) → { summary, cards }|nil`**: acquisition data for `{{Entity/Availability}}`, resolved leaf-first over the chain (`Assembly.resolveMostSpecific`). Absent on every link → no acquisition block. Consumed by `Module:Entity/Availability`.
- **`getSubtitle(apiData, args) → string|nil`**: header subtitle override (else the display type), leaf-first wins. Composed by `Module:Entity/Infobox`.
- **`getHeaderBadge(apiData, args, resolved) → string|nil`**: header badge HTML composed into the image overlay, leaf-first wins. Composed by `Module:Entity/Infobox`.

## Gotchas

**"Required" means inert, not crash.** The word "required" here is a contract concept, not a runtime one. `Entity.lua` guards every hook with `if mod.x` before calling it, so a missing required hook silently does nothing in production. The conformance gate exists to surface those silent failures before merge: a kind without `getApiConfigs` will never resolve its API data; a facet without `getSections` will never render anything. Neither will throw; both are bugs.

**Misspelled optional hooks are caught by the strict-mode tests, not at render time.** A typo like `getSectionsn` for `getSections` is *not* a runtime gate: Contract is never consulted while a page renders, so at render time the typo just produces a silently missing section. It **is**, however, caught by the strict-mode conformance tests: `Registry/testcases` calls `Contract.validate(component, spec, { strict = true })` over every registered kind and facet, and strict mode flags any hook-shaped function key that is not a real hook (`"unknown hook (typo?): getSectionsn"`). Because those tests run under the merge-blocking `mise run test` gate, the typo fails CI before it can be merged. (The default 2-arg `validate`, used nowhere in this codebase except the un-strict unit tests, would still pass such a typo; only the strict path catches it.)

**The contract is deliberately stricter than the runtime.** A facet with no `getSections` would not crash `Entity.lua`, but it would contribute nothing: a wiring bug masquerading as a missing feature. The contract treats that as a failure so contributors catch the gap at test time.

## Tests

**`Contract/testcases.lua`** is a self-contained ScribuntoUnit suite (19 tests) covering:

- `validate` core: a valid kind, a kind missing `getApiConfigs`, a non-function hook (`getApiConfigs = 'nope'`), an optional hook absent, a valid facet, a facet missing `getSections`, and a non-table component (`nil`).
- `validateFields`: required field present / missing, wrong-type field, optional field absent, non-table component.
- The `CONTRIBUTOR` / `KIND_IDENTITY` split: `KIND` type-checks a `CONTRIBUTOR` hook (e.g. `getFooterButtons`, `getMetadataItems`) when a kind implements it directly, not only the identity ones (`testKindTypeChecksChainContributorHooks`); `KIND` is a superset of `CHAIN_LINK`, asserted as a property over every `CHAIN_LINK` key rather than a hard-coded pair (`testKindIsSupersetOfChainLink`); `CHAIN_LINK` type-checks any promoted contributor hook a leaf implements — `enrich`, `getEditorialManifest`, `getCategories`, `getAcquisition` (`testChainLinkTypeChecksPromotedHooks`); and `KIND` is exactly `KIND_IDENTITY` plus every `CONTRIBUTOR` hook (`testKindIsIdentityPlusContributor`).
- Strict mode: `testValidateStrictFlagsTypoHook` (a `getSectionsn` typo is flagged), `testValidateStrictAllowsRealHookFromOtherRole` (a real cross-role hook is allowed), and `testValidateDefaultUnchanged` (the same typo passes without `{ strict = true }`).

**[Module:Entity/Registry/testcases](https://starcitizen.tools/Module:Entity/Registry/testcases)** uses `Contract.validate(component, spec, { strict = true })` (and `validateFields`) as the conformance gate over the live registry: every entry in `Registry.kinds` and `Registry.facets`. Adding a new kind or facet automatically extends contract coverage: a missing required hook, a misspelled optional hook, or a mistyped `name`/`editorialMode` is caught with no change to the test file.

Both suites are auto-discovered by the headless runner (every `pages/module/**/testcases.lua`) and run via `mise run test`, a merge-blocking local gate, not on-wiki only. The Contract suite is pure logic, so it runs locally with no live store; the Registry suite additionally exercises the real `Registry` tables. On-wiki ScribuntoUnit still surfaces both via the documentation template.

## Architecture

```
Entity/Contract/
├── Contract.lua       # role-spec tables + validate / validateFields
└── testcases.lua      # ScribuntoUnit suite for the validators themselves
```

`Contract.lua` has no dependencies (no `require` besides `strict`) and no side effects on load: the spec tables are plain Lua values and `p.ALL_HOOKS` is built once from them. Both validators are pure functions (no `mw` calls, no global reads), so they are cheap to call in tests and safe to require from any module without load-order concerns.
