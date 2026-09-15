# Module:DataGrid/Static

Renders a [Module:BucketQuery](https://starcitizen.tools/Module:BucketQuery) query as a plain wikitable, on the argument grammar [Module:DataGrid](https://starcitizen.tools/Module:DataGrid) defines for its AG Grid.

Editors use this through `{{Data table/static}}`; see [Template:Data table/static](https://starcitizen.tools/Template:Data_table/static).

## For module editors

### API

- `p.main(frame)`: the only entry point. Resolves the arguments with `DataGrid.resolveArgs` under `leadImage = false`, queries with `DataGrid.runQuery`, orders rows with `DataGrid.sortRows`, and returns the table behind the stylesheet load.

### Gotchas

- Choose this over the grid when every row has to be in the parser output. [Extension:AGGrid](https://www.mediawiki.org/wiki/Extension:AGGrid) mounts each grid on an `IntersectionObserver` and virtualises its rows, so browser find reaches only the grids a reader has scrolled to and only the rows currently in the DOM.
- The page name is the only lead column. The page image is an ordinary editor column, in the position and under the label the call gives it, and a table that does not name it renders no image and does not fetch one. `leadImage = false` on `DataGrid.resolveArgs` is what frees the `Image` alias for that column; the grid, whose lead card is the image, keeps it reserved.
- The image column is found by the bucket and field it resolves to (`entity.image`), not by the property name, so a relabelled column still renders as a thumbnail. It gets the `t-datagrid-static__image` cell class and an `unsortable` header, since sorting on image markup means nothing.
- Cells are classified from `Store.resolve(property, kind).type` rather than from their values, mirroring the grid's column dispatch: PAGE becomes a wikilink (comma-separated when repeated), a repeated non-PAGE property one value per line, INTEGER and DOUBLE a grouped number, BOOLEAN the word Yes or No, and anything else the stored value verbatim so the parser renders the wikitext inside it. Yes and No are words rather than the grid's icon for the same reason the table is static: an icon is not text a reader can search for.
- The grid-only parameters are accepted and ignored: `pinlead`, and the column modifiers `filter`, `eyebrow`, `group`, `kind`, `good`, `prefix`, `suffix`, `suffix1` and `size`. An `eyebrow` column renders as an ordinary column, and `sort` still refuses to name one, since `parseSort` skips eyebrow columns. Renaming a call between the two templates therefore keeps its rows and columns but drops any decoration those modifiers carried, most visibly `group`, whose nested header the grid renders and this module does not.
- A query returns at most 1000 rows, inherited from `Module:DataGrid`'s spec and enforced in `Module:BucketQuery`. The cap is silent, and a missing row is this module's whole failure mode, so a category approaching it needs splitting or filtering.
- `sort` orders the rows the parser emits instead of setting an initial grid sort; MediaWiki's sortable-table script leaves the served order alone until a reader clicks a header.
- Every failure message comes from `DataGrid.resolveArgs`, so the two templates report the same contract violations in the same words, each under its own module name.

### Styles

`styles.css` is scoped to the `t-datagrid-static` wrapper: it caps row thumbnails at 200px and right-aligns the image column through the `t-datagrid-static__image` class the module puts on that column's cells.
