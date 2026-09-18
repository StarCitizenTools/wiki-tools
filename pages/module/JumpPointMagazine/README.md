# Module:JumpPointMagazine

Renders the infobox on a Jump Point magazine issue page, records the issue in the `jump_point_issue` [Bucket](https://www.mediawiki.org/wiki/Extension:Bucket) table, and lists those rows back as the per-volume tables on Jump Point (magazine).

Editors reach the infobox through `{{JumpPointMagazine}}` and the tables through `{{#invoke:JumpPointMagazine|table}}`; only Jump Point (magazine) calls the second.

## For module editors

### API

- `p.main(frame)`: the infobox. Reads the `{{JumpPointMagazine}}` arguments, renders through [Module:InfoboxNeue](https://starcitizen.tools/Module:InfoboxNeue), stores the row, and appends the issue's categories.
- `p.table(frame)`: one volume's table. Delegates to [Module:DataGrid/Static](https://starcitizen.tools/Module:DataGrid/Static) with `primary` set to this module's bucket, and takes that module's arguments unchanged.
- `p.buildRow(args)`: the stored row from a set of infobox arguments, pure so the mapping is testable without a page.

### Extending

`properties.json` is the source of truth for the table: it declares each column's Bucket type and is what makes a property nameable in a `columns` or `filter` line. It is registered in [Module:BucketQuery](https://starcitizen.tools/Module:BucketQuery)'s `manifests.json`, and the same file generates `Bucket:Jump point issue`, so a new column is one edit here plus `mise run bucket:schemas`, never a hand-written schema page.

### Gotchas

- `p.table` exists because issue pages hold no Entity row. Calling `{{Data table/static}}` directly would root the query on the `entity` bucket and return nothing, with no error and no empty-table message.
- The property names all carry the `Jump Point ` prefix. Module:BucketQuery resolves every registered manifest from one flat namespace, so a bare `Title`, `Pages` or `Published` would collide with another domain's.
- `publication_year` stores the volume as the word the categories use (`Four`), not a numeral and not the calendar year, because `p.main` builds `Category:Jump Point Year <value>` from the same argument. A numeral there silently creates a category no table queries.
- A row reaches Bucket on link update, not on save, so an issue page edited through the API needs `action=purge` with `forcelinkupdate` before its row exists. A volume whose table renders short is almost always this rather than a query fault.
- Volumes Twelve and Thirteen are hand-written wikitables on Jump Point (magazine), not calls to `p.table`. All but one of those issues have no page to carry an infobox, so there is no row to query; they are not an oversight to convert.
