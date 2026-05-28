# Module:DataTableLua

Builds an interactive, filterable browse table for a category by wrapping the [Semantic MediaWiki](https://www.semantic-mediawiki.org/) `format=datatables` `#ask` query. Call sites (via [Template:Data table](https://starcitizen.tools/Template:Data_table)) pass only a category and a multi-line column list; every DataTables option is fixed here, and search-pane facet indices are computed automatically.

This is the query-backed, client-side-interactive counterpart to [Module:TableLua](https://starcitizen.tools/Module:TableLua), which renders a static `<table>` from data already held in a module. They share no code and serve different layers.

## Usage

Invoked through [Template:Data table](https://starcitizen.tools/Template:Data_table), which is a bare `{{#invoke:DataTableLua|main}}`. The module reads `category` and `columns` off the parent (template) frame via `Module:Arguments`, so the template passes no arguments explicitly.

The render order is always: page image (column 0), page name (column 1), then the editor's columns from index 2. A column flagged `filter` at list position `i` (1-based) becomes search-pane index `i + 1`.

## API

### `p.main( frame )`

Entry point for the template. Reads `category` and `columns` from the parent frame via `require('Module:Arguments').getArgs`, returns the `{{Datatable styles}}` load followed by the rendered DataTable. Returns an inline error string if `category` is blank or no columns parse.

### `p.parseColumns( raw )`

Parses the multi-line `columns` value into an ordered list of `DataTableColumn` tables.

- Splits on newlines; blank lines are dropped and each line is trimmed.
- Splits each line on `;`; the first clause is `property`, the rest are modifiers.
- Recognized modifiers: `label=X` → `label`, `size=X` → `size`, bare `filter` → `filter = true`. Unknown clauses are ignored.
- Lines whose property is empty are dropped.

`DataTableColumn` fields: `property` (string), `label?` (string), `size?` (string), `filter?` (boolean).

### `p.buildAskArgs( category, columns )`

Returns the ordered `#ask` argument list: the query condition `[[:+]] [[Category:…]]` (the `[[:+]]` restricts to the main namespace so File/Category pages in the category don't leak in as rows), the two lead printouts, one printout per column (`?Property[#size][=label]`), the fixed options, and a computed `datatables-searchPanes.columns=…` (omitted when no column has `filter`).

## What is fixed

`mainlabel=-`, `format=datatables`, `limit=1000`, and the `datatables-*` options (`pageLength=10`, `deferRender`, `responsive=false`, `scrollX`, `mark`, `searchPanes`, `searchPanes.initCollapsed`). These are intentionally not exposed; uniformity across browse tables is the point.

When a query matches nothing, DataTables renders its own "No data available in table" message (the SMW `default=` and `language.emptyTable` options are ignored by `format=datatables`, verified on-wiki).

## Testing

Unit tests at [Module:DataTableLua/testcases](https://starcitizen.tools/Module:DataTableLua/testcases) cover `parseColumns` (modifiers, spacing styles, blank lines, dropped empties, ordering) and `buildAskArgs` (category condition, lead printouts, printout formatting, fixed options, and facet-index parity with the original Personal weapon query). The rendering path (`p.render`) is not unit-tested, per project convention.

## Architecture

```
DataTableLua/
├── DataTableLua.lua   # parseColumns, buildAskArgs, render
└── testcases.lua      # ScribuntoUnit tests
```
