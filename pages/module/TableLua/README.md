# Module:TableLua

A Lua interface for building a sortable wiki table without writing wikitext table syntax, modeled after the Codex Table component: the caller passes a `props` table describing columns and rows, and gets back a `<table class="t-table wikitable">` with bundled TemplateStyles.

Required by [Module:Entity/Commodity/Mining](https://starcitizen.tools/Module:Entity/Commodity/Mining), [Module:Entity/Availability](https://starcitizen.tools/Module:Entity/Availability), [Module:Entity/Blueprints](https://starcitizen.tools/Module:Entity/Blueprints), [Module:Entity/Orders](https://starcitizen.tools/Module:Entity/Orders), [Module:Entity/Rewards](https://starcitizen.tools/Module:Entity/Rewards), and [Module:Entity/Related](https://starcitizen.tools/Module:Entity/Related); not invoked from templates.

## For module editors

### API

`p.render(props)` returns `<templatestyles>` + the rendered `<table>`.

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `caption` | `string` | Yes | | Accessible caption. |
| `hideCaption` | `boolean` | No | `false` | Suppress the `<caption>` entirely; nothing is exposed to assistive tech in its place. |
| `columns` | `TableColumn[]` | No | `{}` | `{ id, label?, textAlign? ('start'\|'center'\|'end'\|'number'), width?, minWidth?, allowSort? }`, in display order. `allowSort` only has an effect when explicitly `false` (marks the column `unsortable`); any other value is a no-op. |
| `data` | `TableRow[]` | No | `{}` | Rows: each an array of cell values, indices aligned 1:1 with `columns`. |
| `sort` | `table<column.id, 'asc'\|'desc'\|'none'>` | No | `{}` | Any entry adds the `sortable` class and triggers an in-Lua sort before render. |
| `class` | `string` | No | | Extra class on the root `<table>`. |
| `emptyState` | `string` | No | `'There is no data available'` | Single-cell row shown when `data` is empty. |

```lua
local TableLua = require( 'Module:TableLua' )
TableLua.render( {
	caption = 'Magazine capacities',
	columns = { { id = 'name', label = 'Magazine' }, { id = 'rounds', label = 'Rounds', textAlign = 'number' } },
	data = { { '[[Behring P4-AR]]', 30 }, { '[[Klaus & Werner Demeco]]', 80 } },
	sort = { rounds = 'desc' },
} )
```

### Gotchas

MediaWiki's `sortable` class only sorts on user click; modules render once on the server, so a `sort` entry triggers a manual `table.sort` for readers who don't run JavaScript (mobile, exports, search):

- A column's `textAlign = 'number'` only styles alignment; it plays no part in sorting. The comparator decides per cell: two Lua numbers compare numerically; two strings first strip HTML tags (`<...>`, not `[[...]]` wiki-link brackets) and extract the *first* number pattern each contains, comparing numerically when both extract to different values, else falling back to alphanumeric order on the stripped text. A page name with an embedded digit sorts on that digit: `'[[Behring P4-AR]]'` extracts `4`, not any numeric column value in the same row.
- `nil` cells sort first ascending, last descending.
- Multiple `sort` keys are honored in alphabetical order of column id, not insertion order.
