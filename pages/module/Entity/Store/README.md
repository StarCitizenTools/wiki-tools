# Module:Entity/Store

Query library for the Entity structured data stored in [Extension:Bucket](https://www.mediawiki.org/wiki/Extension:Bucket). It is the only module that knows which table and column a property lives in; every reader of Entity data (PageResolver, ClassStats, PledgeVehicleGrid, DataGrid, the uuid self-read) goes through it. Editors reach it only through `{{Data table}}`.

## For module editors

### API

- `resolve(displayName, kind)`: the bucket, field, type and repeated flag for a property, searching `Module:Entity/properties.json` then `Module:Company/properties.json` then `Module:WearableSet/properties.json` (the manifest listing `kind` under `%kinds` first, when `kind` is given). A property whose bucket depends on the kind (`Scm speed` lives in `vehicle_stats` for vehicles and `item_component` for items) returns nil without `kind`. The display name is the manifest key, so the underscored emitter-key spelling (`modifier_laser_instability`) does not resolve; `Modifier laser instability` does.
- `needsKind(displayName)`: true when the property's manifest bucket is keyed by kind, so `resolve()` needs one to return anything.
- `query(spec)`: `spec.columns` is a list of display names or `{ property, as }` (or `{ builtin = 'page_name', as }`); `spec.filters` is a list of `'Category:X'`, `{ property, value }`, `{ property, op, value }` or `{ any = { ... } }`; `spec.limit` defaults to 1000; `spec.kind` disambiguates cross-kind properties. A filter may name a property in any bucket: the bucket is joined (once) if no column already joined it, and the join becomes INNER, which is the has-a-value semantics a filter means. Operators: `=` (default when only two elements are given), `!=`, `<`, `<=`, `>`, `>=`, and `+` (has a value, emits `Not({ selector, Null() })`). Returns rows keyed by `as` or the display name with typed values.
- `selfUuid()`: the uuid stored for the current page, nil until its first link update has run.
- `selfValue(displayName, kind)`: the current page's own stored value of one property, nil until its first link update has run.
- `resolveUuids(list)`: uuid to `{ page, image }` for any number of uuids, queried in batches of 50.
- `resolvePages(list)`: page title to `{ name, manufacturer, role, image }` for any number of titles, queried in batches of 50, `role` joined from `vehicle`. A Bucket failure on a batch is contained inside `resolvePages` itself (empty map for that batch), unlike `resolveUuids`, so the two vehicle-list readers that call it need no `pcall` of their own.

### Gotchas

- An unknown property is an error, not an empty column, so a renamed property fails the render where someone will see it.
- A relational operator (`<`, `<=`, `>`, `>=`) on a TEXT, PAGE or BOOLEAN property errors `Store: '<name>' is not numeric`; Bucket would otherwise coerce the comparison silently.
- `!=` on a repeated property errors `Store: '!=' cannot be applied to the repeated property '<name>'`: Bucket's `Not()` on a repeated field means "some element differs", so it would include a row that also holds the value; that is why Store refuses it. `Or` and equality remain the only comparisons used on repeated fields.
- An operator outside the list above errors `Store: unknown operator '<op>'`.
- Comparisons still coerce silently on the value: `> ''` on a numeric column matches every row, because the check above is on the property's declared type, not the filter value. Never pass an unset template argument into a relational filter.
- Resolves `mw.ext.bucket` when a query runs, because `require('mw.ext.bucket')` returns a fresh, non-callable copy of the library on the wiki.
- `query()` errors loudly on failure: a programming mistake (unknown property) should fail the render where someone will see it. Its callers that must not red-error a page contain it themselves, each in a `pcall` at the call site: `Module:DataGrid`'s `runQuery`, `Module:Entity/Related`'s `queryVehicleVariants`, `Module:Navplate vehicles`' `getRows`, `Module:PledgeVehicleGrid`'s `main`, and `Module:Entity/Vehicle/ClassStats.cohortRows`, which returns nil, its documented "comparison unavailable" answer. `resolveUuids()` stays loud like `query()` for the same reason; `Module:Entity/PageResolver.resolve()` contains it instead, returning an empty map. `selfUuid()`, `selfValue()` and `resolvePages()` query Bucket directly rather than through `query()`, and each contains its own failure at the call site, since nil (or an empty map) is already its documented answer.
- `needsKind` only flags a property whose manifest *bucket* is keyed by kind: without `kind`, `Maximum temperature`, `Minimum temperature` and `Type` resolve Entity-first (`item_component`, `mission`), which seven live clothing tables rely on; a set table passes `kind = Wearable set` to reach `Module:WearableSet/properties.json`'s entries instead.
