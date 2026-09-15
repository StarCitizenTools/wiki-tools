# Module:Entity/Store

Entity's own view of the [Bucket](https://www.mediawiki.org/wiki/Extension:Bucket) store: the current page's uuid, one stored value for the current page, and the uuid-to-page and page-to-summary lookups the Entity renderers need. Everything here roots on the `entity` bucket literally, which is what makes it Entity's rather than shared.

The generic layer, which table and column a property lives in and how a query is built from property names, is [Module:BucketQuery](https://starcitizen.tools/Module:BucketQuery).

## For module editors

### API

- `selfUuid()`: the uuid stored for the current page, nil until its first link update has run.
- `selfValue(displayName, kind)`: the current page's own stored value of one property, nil until its first link update has run.
- `resolveUuids(list)`: uuid to `{ page, image }` for any number of uuids, queried in batches of 50.
- `resolvePages(list)`: page title to `{ name, manufacturer, role, image }` for any number of titles, queried in batches of 50, `role` joined from `vehicle`. A Bucket failure on a batch is contained inside `resolvePages` itself (empty map for that batch), unlike `resolveUuids`, so the two vehicle-list readers that call it need no `pcall` of their own.
- `resolve`, `needsKind` and `query` are re-exported from `Module:BucketQuery` so Entity's own callers have one module to reach for.

### Extending

**A consumer that is not Entity code should require `Module:BucketQuery` directly** rather than reaching into this namespace. The re-exports exist for Entity's own modules, not as the front door for everyone: five non-Entity modules were requiring this one for a generic query before the split, which is what made an Entity submodule the de facto home of the shared query layer.

`Module:RentalVehicleGrid` is the one non-Entity consumer that still belongs here, because it calls `resolvePages` for an Entity vehicle summary rather than running a query of its own.

### Gotchas

- Every read here is guarded on the main namespace, or relies on the write-side rule that Bucket rows exist only for main-namespace pages. Without that guard a same-titled `Talk:`/`Template:` page would match the mainspace entity's row: `title.text` equals `page_name` only for namespace 0.
- `selfUuid()`, `selfValue()` and `resolvePages()` query Bucket directly rather than through `query()`, and each contains its own failure at the call site, since nil (or an empty map) is already its documented answer. `resolveUuids()` stays loud like `query()`; `Module:Entity/PageResolver.resolve()` contains it instead, returning an empty map.
- Resolves `mw.ext.bucket` when a query runs, because requiring the Bucket library returns a fresh, non-callable copy of it on the wiki.
