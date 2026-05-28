# Template:Data table

Renders an interactive, filterable browse table for every page in a category. Wraps [Module:DataTableLua](https://starcitizen.tools/Module:DataTableLua); see the module page for query and rendering details.

Use it on overview pages (e.g. Personal weapon) to list every member of a category with a sortable, searchable, paginated table backed by [Semantic MediaWiki](https://www.semantic-mediawiki.org/) data. A page image and the page name are added automatically as the first two columns; you only declare the data columns.

## Usage

```wikitext
{{Data table
| category = Personal weapons
| columns =
    Size ; filter
    Subtype ; label=Type ; filter
    Class ; filter
    Ammo ; filter
    Effective range
    Maximum range ; label=Max range
    Muzzle velocity
    Damage
    Manufacturer ; filter
    Is item base variant ; label=Base variant ; filter
}}
```

Each non-blank line in `columns` is one column. The first `;`-separated clause is the [SMW property](https://starcitizen.tools/Special:Properties) to show; the remaining clauses are modifiers:

| Modifier | Effect |
|---|---|
| `label=X` | Override the column header (default: the property name). |
| `filter` | Give the column a search-pane filter. |
| `size=100px` | Format hint for image-valued properties. |

Spacing around `;` is optional: `Size ; filter`, `Size; filter`, and `Size;filter` are equivalent.

## Parameters

<!-- templatedata: format=block -->

| Name | Label | Type | Required | Default | Description | Example |
|------|-------|------|----------|---------|-------------|---------|
| `category` | Category | string | Yes |  | Category whose member pages are listed. Do not include the `Category:` prefix. | `Personal weapons` |
| `columns` | Columns | content | Yes |  | One column per line. First clause is the SMW property; add `; label=X`, `; filter`, or `; size=X` modifiers. | `Size ; filter` |

## Behavior

- The page image (100px) and page name are always the first two columns and cannot be removed; you do not list them in `columns`.
- All DataTables options (pagination at 10 rows, search panes, deferred render, horizontal scroll, highlight) are fixed by the module, so every browse table behaves identically.
- Search-pane column indices are computed automatically from which columns carry `filter`. Reordering, adding, or removing columns never breaks the filters.
- A query that matches nothing shows DataTables' built-in "No data available in table" message.

## See also

- [Module:DataTableLua](https://starcitizen.tools/Module:DataTableLua) — implementation.
- [Module:TableLua](https://starcitizen.tools/Module:TableLua) — a different layer: renders a static table from data already in a module, with no query or client-side interactivity.
