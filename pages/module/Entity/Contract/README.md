# Module:Entity/Contract

The machine-checkable spec for what a well-formed Entity component looks like. For each role — KIND, FACET, CHAIN_LINK — it declares which lifecycle hooks exist and whether each is required or optional, then exposes `p.validate` so a conformance test can reject a mis-wired component before it ever reaches the rendering pipeline.

**Contract has no runtime role.** It is a contributor-facing guardrail that runs in the [Module:Entity/Registry](https://starcitizen.tools/Module:Entity/Registry) conformance test, never during infobox rendering. For the prose contract and a description of what each hook *does*, see [Module:Entity](https://starcitizen.tools/Module:Entity).

## Role in the pipeline

```
[contributor adds kind/facet] → Registry → Registry/testcases
                                                  ↓
                                           Contract.validate
                                                  ↓
                                      pass → rendering pipeline
                                      fail → ScribuntoUnit error
```

Contract lives entirely outside the render path. `Module:Entity` guards every hook call with `if mod.x` at runtime, so a missing or misnamed hook silently no-ops in production. The Contract module exists precisely to catch those silent failures at test time — a mis-wired kind or facet fails a unit test rather than rendering nothing on-wiki with no error.

## API

### Role-spec tables

Three exported tables encode the contract for each role. Each key is a hook name; the value is `true` (required) or `false` (optional).

`p.KIND` is the most complex role — a top-level entity with its own API endpoint, probed by `matches`:

```lua
p.KIND = {
    matches        = true,   -- required: kind identity probe
    getApiConfigs  = true,   -- required: identity endpoint + supplemental configs
    resolveSubtype = false,
    enrich         = false,
    getTypeInfo    = false,
    getSections    = false,
    getStructuredData     = false,
    getShortDescription   = false,
    getExternalSiteItems  = false,
}
```

`p.FACET` and `p.CHAIN_LINK` follow the same `hook = required?` shape. The full required/optional split for all three roles is in the table below.

### `p.validate(component, spec) → ok, errors`

```lua
--- @param component table The module to check
--- @param spec table<string, boolean> A role spec (p.KIND / p.FACET / p.CHAIN_LINK)
--- @return boolean ok True when there are no errors
--- @return string[] errors Human-readable messages (empty when ok)
function p.validate(component, spec)
```

Iterates the spec and checks:

1. If `component` is not a table, returns `false` immediately with a single message (`"component is not a table (got <type>)"`).
2. For each hook in the spec: if the hook is absent and required → error `"missing required hook: <hook>"`; if the hook is present but not a function → error `"hook is not a function: <hook> (got <type>)"`.
3. Returns `(#errors == 0, errors)`.

Unknown keys on `component` are not inspected — `validate` only walks the spec's keys (see Gotchas).

## Data

Required (`true`) and optional (`false`) hooks per role:

| Hook | KIND | FACET | CHAIN_LINK |
|---|---|---|---|
| `matches` | **required** | **required** | — |
| `getApiConfigs` | **required** | — | optional |
| `getSections` | optional | **required** | optional |
| `resolveSubtype` | optional | — | — |
| `enrich` | optional | — | — |
| `getTypeInfo` | optional | — | optional |
| `getStructuredData` | optional | optional | optional |
| `getShortDescription` | optional | — | optional |
| `getShortDescriptionPrefix` | — | optional | — |
| `getExternalSiteItems` | optional | — | optional |

A "—" cell means the hook is not part of that role's spec at all — it is neither required nor validated.

## Gotchas

**"Required" means inert, not crash.** The word "required" here is a contract concept, not a runtime one. `Entity.lua` guards every hook with `if mod.x` before calling it, so a missing required hook silently does nothing in production. The conformance gate exists to surface those silent failures before deploy — a kind without `getApiConfigs` will never resolve its API data; a facet without `getSections` will never render anything. Neither will throw; both are bugs.

**Misspelled optional hooks are not caught.** `validate` only iterates the spec's keys, so it never sees a typo'd export. If a component exports `getSectionsn` instead of `getSections`, the validator ignores the unknown key and returns `ok = true` — from its view, `getSections` is optional and absent, which is valid. Only required hooks are protected from this class of typo; for optional ones, the author's only signal is noticing that their section never renders.

**The contract is deliberately stricter than the runtime.** A facet with no `getSections` would not crash `Entity.lua`, but it would contribute nothing — a wiring bug masquerading as a missing feature. The contract treats that as a failure so contributors catch the gap at test time.

## Tests

**`Contract/testcases.lua`** is a self-contained ScribuntoUnit suite covering:

- A valid kind (both required hooks present) → passes.
- A kind missing `getApiConfigs` → fails with an error mentioning that hook.
- A hook present but not a function (`getApiConfigs = 'nope'`) → fails.
- An optional hook absent → passes.
- A valid facet (both required hooks present) → passes.
- A facet missing `getSections` → fails.
- A non-table component (`nil`) → fails with a single message.

**[Module:Entity/Registry/testcases](https://starcitizen.tools/Module:Entity/Registry/testcases)** uses `Contract.validate` as the conformance gate over the live registry. It calls `Contract.validate(kind, Contract.KIND)` for every entry in `Registry.kinds` and `Contract.validate(facet, Contract.FACET)` for every entry in `Registry.facets`. This means adding a new kind or facet to the Registry automatically extends contract coverage — if it's missing a required hook, the Registry test suite catches it without any change to the test file.

Both suites run on-wiki via ScribuntoUnit. Deploy the module before running tests; they do not run in local CI.

## Architecture

```
Entity/Contract/
├── Contract.lua       # role-spec tables + p.validate
└── testcases.lua      # ScribuntoUnit suite for Contract.validate itself
```

`Contract.lua` has no dependencies (no `require` besides `strict`) and no side effects on load — the spec tables are plain Lua values. The validator is a pure function — no `mw` calls, no global reads — so it is cheap to call in tests and safe to require from any module without load-order concerns.
