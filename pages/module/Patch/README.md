# Module:Patch

Renders a game update page's status bar and page metadata, and stores the update in the `patch` [Bucket](https://www.mediawiki.org/wiki/Extension:Bucket) table that update pages read for their neighbours' release dates.

Editors use it through [Template:Patch](https://starcitizen.tools/Template:Patch) on each `Update:` page and [Template:Patch list](https://starcitizen.tools/Template:Patch_list) on [Patch notes](https://starcitizen.tools/Patch_notes).

## For module editors

### API

- `p.main(frame)`: `{{Patch}}`'s entry point. Reads the parent frame's arguments, stores the row, sets the short description and SEO metadata, and returns the previous/next bar followed by the category link, interlanguage links and styles tag.
- `p.list(frame)`: `{{Patch list}}`'s entry point, [Module:DataGrid](https://starcitizen.tools/Module:DataGrid) rooted on `patch`.
- `p.readArgs`, `p.status`, `p.statusText`, `p.description`, `p.shortDescription`, `p.category`, `p.row`, `p.neighbourTitle`, `p.neighbourDates`, `p.dateFor` and `p.store` are the pieces `main` is built from, exported for the ScribuntoUnit suite.

### Gotchas

- **A neighbour's date is read, not tracked.** Bucket registers no page dependency, so an update page shows its neighbours' release dates as of its own last parse. Saving an update page does not refresh its neighbours; purge them.
- `prev` and `next` always resolve in the `Update:` namespace, so a neighbour whose page is outside it is never found.
- Rows are read with a direct `mw.ext.bucket` query rather than [Module:BucketQuery](https://starcitizen.tools/Module:BucketQuery), which would load and link every registered manifest on each update page.
- The list roots on `patch` because update pages have no `entity` row: a filter on a joined bucket makes that join INNER, so rooting on `entity` would list nothing.
