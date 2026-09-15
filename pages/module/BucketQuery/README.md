# Module:BucketQuery

Builds a [Bucket](https://www.mediawiki.org/wiki/Extension:Bucket) query from property names, and is the only module that knows which table and column each declared property lives in. Domain-agnostic: the manifests it searches are listed in `Module:BucketQuery/manifests.json`, so it names no domain of its own.

Editors reach it through `{{Data table}}`. Entity's own view of the store, including the current page's uuid and the uuid-to-page lookups, is [Module:Entity/Store](https://starcitizen.tools/Module:Entity/Store), which requires this module.

## For module editors

### API

- `resolve(displayName, kind)`: the bucket, field, type and repeated flag for a property, searching each registered manifest in order (the one listing `kind` under `%kinds` first, when `kind` is given). A property whose bucket depends on the kind (`Scm speed` lives in `vehicle_stats` for vehicles and `item_component` for items) returns nil without `kind`. The display name is the manifest key, so the underscored emitter-key spelling (`modifier_laser_instability`) does not resolve; `Modifier laser instability` does.
- `needsKind(displayName)`: true when the property's manifest bucket is keyed by kind, so `resolve()` needs one to return anything.
- `query(spec)`: `spec.columns` is a list of display names or `{ property, as }` (or `{ builtin = 'page_name', as }`); `spec.filters` is a list of `'Category:X'`, `{ property, value }`, `{ property, op, value }` or `{ any = { ... } }`; `spec.limit` defaults to 1000; `spec.kind` disambiguates cross-kind properties; `spec.primary` names the base table, defaulting to `entity`. Operators: `=` (default when only two elements are given), `!=`, `<`, `<=`, `>`, `>=`, and `+` (has a value, emits `Not({ selector, Null() })`). Returns rows keyed by `as` or the display name with typed values.

### Extending

Registering a domain is one edit to `Module:BucketQuery/manifests.json`. That same file is read by the `bucketschemas` generator that writes the `Bucket:` schema pages, so the module and the generator cannot disagree about which manifests exist. Adding a manifest to only one of them was possible before the registry and is the drift it exists to prevent.

Order in the registry matters only for a property name declared by more than one manifest, where the first wins.

### Gotchas

- **`primary` decides which rows can exist, so it is not editor-facing.** A filter on a joined bucket makes that join INNER, so a table whose subject is not an Entity page must set its own `primary`: rooting on `entity` silently returns only the rows that happen to have an `entity` row rather than failing. `{{Data table}}` exposes no parameter for it; a wrapping module passes it through `Module:DataGrid`'s options (see [Module:Maintenance](https://starcitizen.tools/Module:Maintenance), which roots on `maintenance`).
- `selectorFor` defaults its own `primary` rather than trusting the caller. A nil primary qualifies every selector (`entity.size` instead of `size`), which Bucket accepts and which then silently changes what a query returns.
- An unknown property is an error, not an empty column, so a renamed property fails the render where someone will see it.
- A relational operator (`<`, `<=`, `>`, `>=`) on a TEXT, PAGE or BOOLEAN property errors `BucketQuery: '<name>' is not numeric`; Bucket would otherwise coerce the comparison silently.
- `!=` on a repeated property errors `BucketQuery: '!=' cannot be applied to the repeated property '<name>'`: Bucket's `Not()` on a repeated field means "some element differs", so it would include a row that also holds the value. `Or` and equality remain the only comparisons used on repeated fields.
- An operator outside the list above errors `BucketQuery: unknown operator '<op>'`.
- Comparisons still coerce silently on the value: `> ''` on a numeric column matches every row, because the check above is on the property's declared type, not the filter value. Never pass an unset template argument into a relational filter.
- Resolves `mw.ext.bucket` when a query runs, because requiring the Bucket library returns a fresh, non-callable copy of it on the wiki.
- `query()` errors loudly on failure: a programming mistake should fail the render where someone will see it. Callers that must not red-error a page contain it themselves, each in a `pcall` at the call site: `Module:DataGrid`'s `runQuery`, `Module:Entity/Related`'s `queryVehicleVariants`, `Module:Navplate vehicles`' `getRows`, `Module:PledgeVehicleGrid`'s `main`, and `Module:Entity/Vehicle/ClassStats.cohortRows`, which returns nil, its documented "comparison unavailable" answer.
- `needsKind` only flags a property whose manifest *bucket* is keyed by kind: without `kind`, `Maximum temperature`, `Minimum temperature` and `Type` resolve Entity-first (`item_component`, `mission`), which seven live clothing tables rely on; a set table passes `kind = Wearable set` to reach `Module:WearableSet/properties.json`'s entries instead.
- The registry is read with `ipairs`, never `#` or `next()`: `mw.loadJsonData`'s tables break both.
