# Module:Entity/SectionBuilder

The shared constructor for the section tables every Entity `getSections()` returns: collapses missing item rows, drops sections that end up empty, and assembles the final list without a stray `nil` truncating it.

Editors never invoke this module directly; it runs inside [Template:Entity](https://starcitizen.tools/Template:Entity), [Template:Vehicle](https://starcitizen.tools/Template:Vehicle) and [Template:Location](https://starcitizen.tools/Template:Location).

## For module editors

### API

- `p.push(items, label, content) → items`: appends `{ label, content }` when `content` is present and not `''`; drops both `nil` and `''`. `false` and `0` are kept.
- `p.pushNonNil(items, label, content) → items`: like `push`, but keeps `''`, dropping only `nil`. Use when `content` already went through a formatter (e.g. `format.formatNum`) that can legitimately return `''` for a present source, so the row must still appear.
- `p.section(cfg) → EntitySectionEntry|nil`: builds one section from `cfg` (`key`, `label`, one of `items` / `sections` / `content`, plus `collapsible` / `collapsed` / `class` / `columns`), or returns `nil` when it carries no payload: an empty `items`, no `sections`, and `content` absent or `''`.
- `p.build(...) → EntitySectionEntry[]`: collects the non-`nil` varargs into the list `getSections` returns. Pass each section as a separate argument, not as an array literal: varargs exist specifically so an interspersed `nil` does not truncate the list.

A section carries exactly one payload: `items` (the common case, a row list), `sections` (nested sub-sections, a tabbed group), or `content` (one pre-rendered blob). [Module:Entity/Assembly](https://starcitizen.tools/Module:Entity/Assembly)'s `mergeSections` merges only `items` additively across the chain; `content` and `sections` survive only from the first chain link or facet to declare a given key.

### Gotchas

- `push` drops a `''` content; `pushNonNil` keeps it. Handing `push` a formatter's output that can legitimately be `''` for a present source silently drops the row with no error, which is exactly the case `pushNonNil` exists for.
- `section()` returns `nil`, never an empty table, so its result must go through `build(...)`; indexing it directly assumes it isn't `nil`.
- `build(a, b, c)` is correct; `build({ a, b, c })` wraps the whole list in another list and breaks the merge.
