# Module:Entity/Data

Fetches and normalizes an entity's render data: parses wikitext args, probes the API for the matching kind, builds the type chain, runs enrich hooks, and resolves editorial fields and display type into one result table every sibling renderer shares.

Editors never invoke this module directly; it runs inside [Template:Entity](https://starcitizen.tools/Template:Entity), [Template:Vehicle](https://starcitizen.tools/Template:Vehicle) and [Template:Location](https://starcitizen.tools/Template:Location).

## For module editors

### API

- `p.parseArgs(frame) → args`: merges direct `#invoke` args over parent-frame (template call-site) args; empty strings become `nil`. Falls back to the page's SMW-stored `uuid` (namespace-prefixed off mainspace, e.g. `user_uuid` on `User:` pages) only when both `uuid` and `kind` are absent from the merged args, so a `|kind=`-declared page never resurrects a stale stored uuid.
- `p.get(args) → result`: the primary entry point; every sibling renderer calls it independently. See Extending for the pipeline and the result shape.

### Extending

`p.get` probes for a kind (a declared `|kind=` is trusted first, behind a `matches()` gate; otherwise it walks `Registry.kinds`, fetching each kind's primary endpoint until one matches), resolves a leaf via the kind's `resolveSubtype` (or falls back to `Module:Entity/Item` with no match), builds the chain, fetches any endpoints the chain still needs, and runs every chain link's `enrich(ctx)` root to leaf. When no genuine record came back (`apiData.uuid` absent) and `args.kind` names an opted-in (`editorialMode = true`) kind, it forks: `apiData` resets to `{}`, the chain rebuilds from `args` alone, and `enrich` reruns on the empty data. That is the editorial (planned-page) path.

`result` fields and what they feed:

| Field | Type | Feeds |
|---|---|---|
| `args` | table | the parsed args passed into `p.get` (same table as `ctx.args`); read directly by renderers that need a raw arg outside `apiData` |
| `apiData` | table | merged API record (`{}` on the editorial fork); read by every hook |
| `chain` | table[] | root-to-leaf module list; walked by `Assembly`'s merge/resolve primitives |
| `facets` | table[] | matched facet modules; additive `getSections`/`getStructuredData` |
| `typeInfo` / `displayType` | table\|nil / string\|nil | leaf `getTypeInfo` else `TypeResolver`; infobox header, SMW `subject_type` |
| `resolved` / `editorialData` / `hasManualApiData` | table / table / boolean | `Editorial.resolve` output; render display, SMW write, maintenance category |
| `hasApiError` | boolean | drives the `Pages with API errors` tracking category; the infobox never reads it, but Ports and Blueprints show an "unavailable" notice while Related falls back to its generic empty state |
| `unresolvedReference` | boolean | a `\|uuid=` given on an editorial-mode page failed to resolve; tracking category |
| `matchedKind` / `kind` / `family` | table\|nil / string / string\|nil | the resolved kind module, its canonical name, the leaf's family token |
| `ctx` | `EntityHookContext` | passed straight through to every hook call by every renderer |

### Gotchas

- `ctx` fields fill in pipeline order, so a hook that runs early (`enrich`, `getTypeInfo`) sees later fields as `nil`; see the Hook context table on [Module:Entity](https://starcitizen.tools/Module:Entity).
- The kind probe depends on the configured Apiunto source keeping redirect-following off: a foreign uuid that would redirect (a vehicle uuid fetched on the items endpoint) must fail the fetch rather than get cached under the wrong key.
- A kind's own probe failure only counts toward `hasApiError` when that kind is the one that ultimately matches; a non-matching kind's fetch error during the walk (e.g. the items endpoint rejecting a vehicle uuid) is discarded.
- A given uuid that matches no kind still resolves to `Module:Entity/Item` as the leaf, but sets `hasApiError = true`; a page without a uuid never triggers this.
- `resolveSubtype` returning `nil` silently falls back to the kind itself; a subtype the kind doesn't recognise renders as the base kind with no error.
- `Registry.kinds` order is a probe-cost optimisation only (Item first, since it dominates the page mix); the declared-`kind` gate can hand any kind's `matches()` a record belonging to a different kind, so every `matches()` must reject on its own regardless of order.
