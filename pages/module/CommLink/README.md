# Module:CommLink

Renders a Comm-Link page's rehosting notice, previous/next bar, infobox, categories and SEO metadata, and stores each Comm-Link in the `comm_link` [Bucket](https://www.mediawiki.org/wiki/Extension:Bucket) table for the previous and next Comm-Link of a series and for Comm-Link lists.

Editors use it through [Template:Infobox commlink](https://starcitizen.tools/Template:Infobox_commlink) on every Comm-Link page and [Template:Comm-Link list](https://starcitizen.tools/Template:Comm-Link_list).

## For module editors

### API

- `p.main(frame)`: `{{Infobox commlink}}`'s entry point. Stores the page's row, sets its `#seo` metadata, and renders the rehosting notice ([Module:Mbox](https://starcitizen.tools/Module:Mbox)), the previous/next bar, the infobox ([Module:InfoboxLua](https://starcitizen.tools/Module:InfoboxLua)) and the categories; the page shows them in that order.
- `p.list(frame)`: `{{Comm-Link list}}`'s entry point, [Module:DataGrid](https://starcitizen.tools/Module:DataGrid) rooted on `comm_link`.
- `p.readArgs`, `p.normaliseDate`, `p.rsiId`, `p.row`, `p.put`, `p.seriesRows`, `p.orderSeries`, `p.neighbours`, `p.prevnextArgs`, `p.noticeText`, `p.infoboxData`, `p.categories` and `p.seoArgs` are the pieces those are built from, exported for the ScribuntoUnit suite.

### Extending

`properties.json` declares the table: each column's Bucket type, and the property names `{{Comm-Link list}}` filters and shows. It is registered in [Module:BucketQuery](https://starcitizen.tools/Module:BucketQuery)'s `manifests.json` and generates `Bucket:Comm link`. A new column needs its manifest entry and `mise run bucket:schemas`, the field written in `p.row` (and in `TEXT_PARAMS` when it comes from a new argument), and a purge with `forcelinkupdate` of every Comm-Link page to fill it. Deploy the manifest page before the registry lists it.

### Gotchas

- **A neighbour is read, not tracked.** Bucket registers no page dependency, so a Comm-Link shows the neighbours stored when it was last parsed. Creating a Comm-Link, changing its date or series, or deleting or moving one does not refresh its neighbours; purge the Comm-Links on either side of it (in the old series too when the series changed).
- The page's own stored row is never used. `seriesRows` replaces it with one built from the page's arguments, so a page is placed by its current date even before its row is written.
- The series is ordered in Lua, not by Bucket: a row without a date or number must sort last, and Bucket takes one `orderBy`.
- A row reaches Bucket on link update, not on save. After an edit through the API, `action=purge` with `forcelinkupdate` writes it.
