# Module:Entity/Editorial

The seam where a kind's **editor-supplied (wikitext) values** and its **API values**
reconcile, with provenance stamped on every field. Editor input wins (the API is
sometimes wrong), fills gaps the API does not model (concept ships), and every
hand-supplied value that overlaps an API field is recorded so it can be retired when
the API catches up.

Editorial is a pure transform: no `mw.ext.Apiunto`, no SMW reads, no globals beyond
`mw.text`. It is driven entirely by a **manifest** the consuming kind
declares. Today the single consumer is
[Module:Entity/Vehicle](https://starcitizen.tools/Module:Entity/Vehicle), wired in
through [Module:Entity/Data](https://starcitizen.tools/Module:Entity/Data)`.get`.

## Role in the pipeline

A kind opts in by exposing two things: `editorialMode = true` (a scalar field;
see [Module:Entity/Contract](https://starcitizen.tools/Module:Entity/Contract)) and a
`getEditorialManifest()` hook. During `Data.get`, when the matched kind has
`getEditorialManifest`, the orchestrator runs:

```lua
local manifest        = matchedKind.getEditorialManifest()
resolved              = editorial.resolve(apiData, args, manifest)   -- result.resolved
editorialData         = editorial.toStructuredData(resolved, manifest) -- → SMW write
hasManualApiData      = editorial.hasManualApiData(resolved)         -- maintenance flag
```

`resolved` is then threaded back to the kind's render hooks (`getSections`,
`getHeaderBadge`, `getCategories`, `formatShortDescription`), which read it through a
display **view** rather than poking at entry internals.

## The manifest

`getEditorialManifest()` returns a `field -> def` table. Vehicle loads its copy from
`Module:Entity/Vehicle/editorial.json`. Each `def`:

| Key | Required | Meaning |
|---|---|---|
| `arg` | yes | Template-arg name to read. A **list** (`["series", "model"]`) tries each alias in order; first non-empty wins (mirrors the legacy `[ARG_Series, ARG_Model]`). |
| `smw` | for storage | SMW property name `toStructuredData` projects the value onto. Declared in `Module:Entity/properties.json` (`modules: ["Vehicle"]`). |
| `apiPath` | no | Dotted path into `apiData` (`speed.scm` → `apiData.speed.scm`). **Presence makes the field an _overlap_ field**; absence makes it **pure-editorial** (the API does not model it). |
| `transform` | no | Coerces the raw arg: `number` (strips commas, `K`/`M` suffixes, trailing units: `"900K µSCU"` → `900000`), `text` (trim), `page` (link target: `[[A\|B]]` → `A`), `pageList` (semicolon-split → list of link targets). |
| `default` | no | Value used when the arg is absent/empty. |

Keys beginning with `%` are skipped (so the `%doc` key in the JSON is ignored).

## API

### `p.resolve(apiData, args, manifest) → resolved`

Produces `resolved`: `field -> { value, source, apiValue }`. A field is **omitted
entirely** when neither an editor value nor an API value is present. The `source`
records where `value` came from, with numeric-aware equality so a hand-typed `26,245`
matching API `26245` reads as `api`, not a correction.

| `source` | When | `value` |
|---|---|---|
| `editorial` | pure-editorial field (`apiPath` absent), editor supplied it | editor value |
| `fill` | overlap field, API value empty/absent, editor supplied it | editor value |
| `override` | overlap field, editor value differs from API | editor value (`apiValue` keeps the API's) |
| `api` | no editor value (or editor == API) | API value |

`fill` and `override` are the **audited** sources: a human supplied data the API
should own. `editorial` is never audited (the API was never expected to have it).

### `p.toStructuredData(resolved, manifest) → table`

Projects each resolved field onto its `def.smw` property, and appends
`['Manual API field']`, the list of field keys whose source is `fill` or `override`.
That SMW property (Text, multi-valued) drives the *Entities with manual API data*
maintenance category, so audited fields can be found and retired.

### `p.hasManualApiData(resolved) → boolean`

True when any field resolved to `fill` or `override`.

### `p.view(resolved) → view`

Wraps `resolved` once in a read-only display-merge view. Nil-safe: `view(nil)` behaves
like an empty set (the `getHeaderBadge` path may pass nil). Replaces the per-kind
`effective`/`editorialValue` helpers, which section builders read through:

- **`view:value(field [, fallback]) → any`** gives the resolved value when the field
  resolved (it already encodes override/fill/api), otherwise `fallback` (default nil). Pass
  the API value as `fallback` for overlap fields (`ed:value('scm_speed', apiData.speed.scm)`);
  omit it for pure-editorial fields. Returns the raw stored value; callers format it.
- **`view:source(field) → string|nil`** collapses the internal vocabulary to a
  display one: `api` and `override` pass through; `fill` and `editorial` both become
  `wiki` (editor-authored, nothing displaced); `nil` when the field did not resolve.

## Planned (editorial) entities

The same `resolved` layer lets a **not-yet-in-game** page render with no API record at
all. When `Data.get` finds no genuine record (no `apiData.uuid`) and `args.kind` names
an opted-in kind, it enters editorial mode: `matchedKind` becomes that kind, **`apiData`
is reset to `{}`**, and the leaf is rebuilt from `args` (Vehicle reads `|family=` →
ship / ground / gravlev). The render is then driven entirely by the editorial layer:
every `ed:value(field, apiData.x)` falls back to nil, so sections that are already
data-gated simply omit, and a planned page is a clean subset of an in-game one. See the
[Data editorial-mode section](https://starcitizen.tools/Module:Entity/Data) for the
dispatch.

### The stale-uuid guard

An editorial page declares its identity in wikitext (`|kind=Vehicle |family=ship`), so
it must **not** resurrect a stored uuid. `Data.parseArgs` only falls back to the
SMW-stored uuid when **both** `args.uuid` and `args.kind` are absent:

```lua
if not args.uuid and not args.kind then
    args.uuid = readSmwUuid(frame)
end
```

Without this guard (fixed in 059f417), a page that once held a placeholder uuid (an
all-zeros or legacy dev-stub value) would re-read it from SMW, defeat editorial mode,
and re-store the bad uuid. Separately, an editorial page that *does* pass a `|uuid=`
which fails to resolve is flagged via `result.unresolvedReference` (a tracking
category) rather than silently masquerading as planned.

## Gotchas

**Provenance vocabulary is two-layer.** `resolve` emits four sources
(`editorial`/`fill`/`api`/`override`); `view:source` collapses them to three
(`api`/`override`/`wiki`). Code that audits (`toStructuredData`, `hasManualApiData`)
reads the raw four; display code reads the collapsed three. Don't mix them.

**`smw` is only for storage.** A field with no `smw` still resolves and is readable via
`view:value`; it just is not persisted by `toStructuredData`.

**Empty `pageList` drops the field.** A `pageList` transform that yields an empty list
produces no entry, so `view:value` returns the fallback rather than an empty table.

## Tests

`Editorial/testcases.lua` is a self-contained ScribuntoUnit suite (a small fixture
manifest, no live API). It covers each source branch (api / fill / override /
editorial), the numeric-equality and unit-stripping behaviour of the `number`
transform, `page` extraction, arg-alias precedence, `toStructuredData` projection +
`Manual API field` flagging, and the full `view` surface (value, fallback, nil-safety,
source collapse). Run with `mise run test` (the merge-blocking gate); the runner
auto-discovers `Editorial/testcases.lua` with no registration.

## Architecture

```
Entity/Editorial/
├── Editorial.lua    # resolve / toStructuredData / hasManualApiData / view + View
└── testcases.lua    # ScribuntoUnit suite
```

`Editorial.lua` requires only `strict` and has no side effects on load. Every export is
a pure function over its arguments (no `mw.ext` calls, no SMW reads, no global state),
so it is cheap in tests and safe to require without load-order concerns. The manifest
(and the API/wikitext data) are supplied by the caller; Editorial knows nothing about
vehicles specifically.
