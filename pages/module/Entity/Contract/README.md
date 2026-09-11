# Module:Entity/Contract

The machine-checkable hook-set spec for a well-formed Entity component: per role (chain link, kind, facet), which hooks exist and which are required, checked by `p.validate` against a component module. It has no runtime role; `Entity.lua` never calls it while rendering a page.

Editors never invoke this module directly; it runs inside [Template:Entity](https://starcitizen.tools/Template:Entity), [Template:Vehicle](https://starcitizen.tools/Template:Vehicle) and [Template:Location](https://starcitizen.tools/Template:Location).

## For module editors

### API

- `p.validate(component, spec, options) → ok: boolean, errors: string[]`: checks each hook in `spec`. A required hook that's missing is an error; a present hook that isn't a function is an error. With `options.strict = true`, also flags any function-valued key on `component` that looks hook-shaped (`get*`, or exactly `matches`/`resolveSubtype`/`enrich`) but is in neither `spec` nor `p.ALL_HOOKS`, catching a misspelled optional hook.
- `p.validateFields(component, fieldSpec) → ok, errors`: the same shape for non-function scalar fields (`p.KIND_FIELDS`: `name`, `editorialMode`). Missing-when-required and a wrong `type()` are both errors.
- `p.CONTRIBUTOR` (alias `p.CHAIN_LINK`): the hook set any chain link may implement, all optional.
- `p.KIND_IDENTITY`: the hooks that make a component a kind. `matches` and `getApiConfigs` required, `resolveSubtype` optional.
- `p.KIND`: `CONTRIBUTOR` plus `KIND_IDENTITY` layered on top, so `getApiConfigs` is promoted from optional to required.
- `p.FACET`: `matches` and `getSections` required; `getStructuredData` and `getShortDescriptionPrefix` optional.
- `p.ALL_HOOKS`: the union of every hook name across `KIND`, `FACET`, and `CHAIN_LINK`; lets strict mode tell a real cross-role hook from a typo.

### Extending

A new **kind** must implement `matches(apiData) → boolean` (nil-safe, and must stand alone: the declared-`kind` gate can hand it a record belonging to a different kind) and `getApiConfigs() → EntityApiConfig[]` (`[1]` is the identity endpoint), plus a `name` string field; it may also implement `resolveSubtype(apiData, args) → module|nil`. A **facet** must implement `matches` and `getSections`. Any chain link, kind, subtype leaf, or Base, may additionally implement any `CONTRIBUTOR` hook (`getSections`, `getStructuredData`, `enrich`, `getCategories`, and the rest), all optional.

Conformance is enforced only at test time, by [Module:Entity/Registry/testcases](https://starcitizen.tools/Module:Entity/Registry/testcases), which runs `p.validate(component, spec, { strict = true })` and `p.validateFields` over every entry in `Registry.kinds` and `Registry.facets`. That suite runs under the merge-blocking `mise run test` gate.

### Gotchas

- "Required" is a contract concept, not a runtime one: `Entity.lua` guards every hook call with `if mod.x`, so a missing required hook silently no-ops on-wiki instead of erroring. The conformance test exists to catch that gap before merge.
- Strict-mode typo detection is a heuristic: it only flags names starting with `get`, or exactly `matches`/`resolveSubtype`/`enrich`. A misspelled hook outside that shape still slips through.
- The default (non-strict) `p.validate(component, spec)` call never checks for unknown or misspelled keys; only the Registry conformance test's `{ strict = true }` call catches a typo.
