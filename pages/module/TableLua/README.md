# Module:TableLua

Lua interface for building a sortable wiki table without writing wikitext table syntax. Modeled after the [Codex Table component](https://doc.wikimedia.org/codex/latest/components/demos/table.html): the caller passes a `props` table describing columns and rows, and the module returns a `<table class="t-table wikitable">` with bundled TemplateStyles.

Use this when a module needs to emit a table from structured data (rows of mixed types, optional sort, optional column-level alignment) and you'd rather not concatenate `{| ... |}` strings by hand.

## Usage

```lua
local TableLua = require( 'Module:TableLua' )

local html = TableLua.render( {
    caption = 'Magazine capacities',
    columns = {
        { id = 'name',  label = 'Magazine',     allowSort = true },
        { id = 'rounds', label = 'Rounds',     textAlign = 'number', allowSort = true },
        { id = 'cost',   label = 'Cost (aUEC)', textAlign = 'number' },
    },
    data = {
        { '[[Behring P4-AR]]', 30, 1200 },
        { '[[Klaus & Werner Demeco]]', 80, 4500 },
        { '[[Apocalypse Arms Scourge]]', 1, 50000 },
    },
    sort = { rounds = 'desc' },
} )
```

`render` returns a string: a `<templatestyles>` tag for `Module:TableLua/styles.css` followed by the rendered `<table>`. Concatenate it directly into your module's output.

## API

### `p.render( props )`

Builds and returns the table.

| Parameter | Type | Description |
|---|---|---|
| `props` | `TableProps` | Table configuration. See fields below. |

#### `TableProps`

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `caption` | `string` | Yes | | Accessible caption shown above the table. |
| `hideCaption` | `boolean` | No | `false` | Suppress rendering of the `<caption>` element. The caption is still set for screen readers when supported. |
| `columns` | `TableColumn[]` | No | `{}` | Column definitions in display order. |
| `data` | `TableRow[]` | No | `{}` | Row data. Each row is an array whose indices align 1:1 with `columns`. |
| `sort` | `table<string, 'asc'\|'desc'\|'none'>` | No | `{}` | Map of `column.id` to sort direction. Presence of any entry adds the `sortable` class and triggers an in-Lua sort. |
| `class` | `string` | No | | Extra class appended to the root `<table>`. |
| `emptyState` | `string` | No | `'There is no data available'` | Message rendered as a single-cell row when `data` is empty. |

#### `TableColumn`

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `id` | `string` | Yes | | Stable identifier used by `sort`. |
| `label` | `string` | No | `''` | Header cell content. Wikitext is allowed. |
| `textAlign` | `'start'\|'center'\|'end'\|'number'` | No | `'start'` | Alignment class applied to the column's `<th>` and every `<td>` in the column. `'number'` aligns right and is intended for numeric columns. |
| `width` | `string` | No | | CSS `width` for the column header. Any valid CSS length. |
| `minWidth` | `string` | No | | CSS `min-width` for the column header. |
| `allowSort` | `boolean` | No | `true` | When `false`, marks the column as non-sortable (`unsortable` class). Has no effect unless the table is sortable. |

#### `TableRow`

A `TableRow` is an array of cell values. Strings are passed through as wikitext; numbers are rendered as-is. The array length should match `columns`; extra cells are still rendered but won't pick up column-level alignment.

## Sorting

MediaWiki's `sortable` class only sorts on user click — modules render once on the server, so server-side sort order matters when the page is read by anything that doesn't run JavaScript (mobile, exports, search). Setting any entry in `sort` triggers a manual `table.sort` over `data` before render:

- Numeric columns sort numerically. Strings that contain a number (even when wrapped in `[[link]]` or other HTML) are parsed for sorting; if both sides parse, numeric order wins.
- String columns fall back to alphanumeric order on the HTML-stripped text.
- `nil` cells sort first.
- Multiple sort keys are honored in alphabetical order of column id.

## Styles

CSS lives in [Module:TableLua/styles.css](https://starcitizen.tools/Module:TableLua/styles.css) and is bundled automatically. Only column alignment is themed; the base table appearance comes from `wikitable`.

## Architecture

```
TableLua/
├── TableLua.lua    # Render function, sort comparator
└── styles.css      # Column alignment classes
```
