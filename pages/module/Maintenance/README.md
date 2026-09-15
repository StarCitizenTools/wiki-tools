# Module:Maintenance

Records a page's maintenance flag in the `maintenance` [Bucket](https://www.mediawiki.org/wiki/Extension:Bucket) table and renders the report built from it. The banner templates own the box the reader sees; this module only stores what they were told and lists it back.

Editors never invoke it directly: [Template:Outdated](https://starcitizen.tools/Template:Outdated), [Template:Cleanup](https://starcitizen.tools/Template:Cleanup) and [Template:Delete](https://starcitizen.tools/Template:Delete) call it, and the report lives at [Star Citizen Wiki:Maintenance report](https://starcitizen.tools/Star_Citizen_Wiki:Maintenance_report).

## For module editors

### API

- `p.record(frame)`: stores the row for the current page and returns the empty string. Reads `status` (a key of `STATUSES`), `why` and `banner`.
- `p.buildRow(args) → table|nil`: the pure argument-to-row mapping, nil when `status` names none. Testable without a page or a Bucket.
- `p.report(frame)`: the report grid, [Module:DataGrid](https://starcitizen.tools/Module:DataGrid) with the base table overridden.

### Extending

Another banner template joins this table by calling `record` with its own `banner` and a `status` in `STATUSES`; no schema change is needed, because `banner` already distinguishes the writers. Adding a status means adding it to `STATUSES` first and to the banner second, so a page can never store a status the report has no wording for: an unknown `status` stores nothing at all.

`banner` has no default. A banner that does not name itself is a wiring mistake, and a row silently attributed to the wrong template is worse than a blank cell.

`{{Cleanup}}` and `{{Delete}}` take their reason as the positional `{{{1}}}` rather than `why=`. `{{Citation needed}}`, `{{Unconfirmed}}` and `{{Removed}}` are deliberately not wired: the first is an inline marker rather than a page-level task, and the other two describe content state rather than work to do.

### Gotchas

- **The report roots on `maintenance`, not `entity`.** Most tagged pages are not Entity pages: lore, concept and meta articles carry the bulk of the tags, and they have no `entity` row at all. A filter on a joined bucket makes that join INNER, so rooting on `entity` would silently drop them rather than erroring. Rooting on `maintenance` leaves `entity` a LEFT join, and a page with no Entity row still lists, falling back to its page name.
- Writes are main namespace only, matching [Module:Entity/StructuredData](https://starcitizen.tools/Module:Entity/StructuredData). A banner on a `/doc` or a sandbox is not a maintenance task anyone reports on, and its row would outlive the page.
- **One row per banner, not per page.** Each `record` call puts its own row, so a page carrying both {{Outdated}} and {{Cleanup}} lists twice, once per flag. That is the wanted behaviour for a worklist, and it is why `banner` is worth storing.
- A blank parameter is stored as nothing, not as an empty string: Bucket keeps `''` as a value, which then reads as "has a reason" to every query.
- A `<ref>` inside `why` reaches the module as the parser's strip marker, not the ref, so `clean` runs it through `mw.text.killMarkers`; a stored `UNIQ--ref-...-QINU` renders as literal garbage and can never resolve. That function is a PHP callback, so the runner config reproduces its `\127`-delimited semantics to keep the case testable.
- **The grid does not render wikitext.** A reason containing `[[Apollo]]` shows the brackets, because AG Grid takes cell values as data. [Module:DataGrid/Static](https://starcitizen.tools/Module:DataGrid/Static) would render it, at the cost of the column filters.
- A `<ref>` inside `why` reaches the module as the parser's strip marker, not the ref. `clean` removes it, because a stored `UNIQ--ref-...-QINU` renders as literal garbage and can never resolve. Matched by pattern rather than with `mw.text.killMarkers`, which is a PHP callback the offline runner cannot exercise.
- **The grid does not render wikitext.** A reason containing `[[Apollo]]` shows the brackets, because AG Grid takes cell values as data. [Module:DataGrid/Static](https://starcitizen.tools/Module:DataGrid/Static) would render it, at the cost of the column filters.
- `put` is wrapped in `pcall`, so a Bucket failure degrades to a banner with no row rather than taking the page down. A silently missing row therefore looks the same as an untagged page; see the write-permission note in [Module:Entity/StructuredData](https://starcitizen.tools/Module:Entity/StructuredData).
