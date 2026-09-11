# Module:Entity/Editorial

Reconciles a kind's editor-supplied wikitext values against its API values per a declared manifest, stamping provenance on every field so a human override can be found and retired once the API catches up.

Editors never invoke this module directly; it runs inside [Template:Entity](https://starcitizen.tools/Template:Entity), [Template:Vehicle](https://starcitizen.tools/Template:Vehicle) and [Template:Location](https://starcitizen.tools/Template:Location).

## For module editors

### API

- `p.resolve(apiData, args, manifest) → resolved`: produces `field -> { value, source, apiValue }`; a field is omitted entirely when neither an editor value nor an API value is present. `source` is `editorial` (no `apiPath`, editor-only field), `fill` (API value empty, editor supplied one), `override` (editor value differs from a present API value), or `api` (no editor value, or the two match numerically).
- `p.rawArg(args, def) → any|nil`: the raw editor value for one manifest field. Tries `def.arg`'s alias(es) in order, first non-empty (trimmed) wins; `def.default` is NOT applied. Exists for callers that must read an arg before `resolve` has run (a leaf's `enrich`, `getTypeInfo`).
- `p.toStructuredData(resolved, manifest) → table`: projects each resolved field onto `def.smw`, and appends `Manual API field`, the list of field keys whose source is `fill`/`override`.
- `p.hasManualApiData(resolved) → boolean`: true when any field resolved to `fill` or `override`.
- `p.view(resolved) → view`: wraps `resolved` (nil-safe) in a read-only display object. `view:value(field, fallback)` returns the resolved value or `fallback`; `view:source(field)` collapses the four internal sources to `api`/`override`/`wiki` (`fill` and `editorial` both read as `wiki`).
- `p.toSmwValue(value) → any`: strips parser strip-markers, rendered HTML, wiki-link markup and stray non-breaking spaces from a string value before it's stored; non-strings pass through untouched. Public because a leaf storing a field itself (no `smw` manifest key) needs the same projection.

### Extending

A manifest is `field -> def`:

| Key | Required | Meaning |
|---|---|---|
| `arg` | yes | template-arg name, or a list of aliases tried in order, first non-empty wins |
| `smw` | for storage | SMW property `toStructuredData` projects the value onto; a field with no `smw` still resolves but isn't persisted |
| `apiPath` | no | dotted path into `apiData`; presence makes the field an *overlap* field, absence makes it pure-editorial |
| `transform` | no | `number` (strips commas/`K`/`M`/trailing units), `text` (trim), `page` (link target), `pageList` (semicolon-split link targets) |
| `default` | no | value used when the arg is absent or empty |

A key beginning with `%` is skipped. A kind opts into the editorial layer by declaring `editorialMode = true` ([Module:Entity/Contract](https://starcitizen.tools/Module:Entity/Contract)) and a `getEditorialManifest()` hook; [Module:Entity/Data](https://starcitizen.tools/Module:Entity/Data) merges every chain link's manifest fragment root to leaf, leaf field winning on collision, before calling `resolve`.

### Gotchas

- Provenance is two-layer: `resolve` emits four sources (`editorial`/`fill`/`api`/`override`); `view:source` collapses them to three. Code that audits (`toStructuredData`, `hasManualApiData`) reads the raw four; display code reads the collapsed three.
- An unparseable editor value (a `transform` that returns `nil`) is treated as absent, not as the raw string, so it falls through to the API value instead of displacing it with an unformattable one.
- A `pageList` transform yielding an empty list drops the field entirely; `view:value` then returns the fallback.
- `Module:Entity/Data`'s SMW-uuid fallback is suppressed whenever `args.kind` is set, specifically so an editorial page's stale or placeholder stored uuid can't resurrect and defeat editorial mode.
