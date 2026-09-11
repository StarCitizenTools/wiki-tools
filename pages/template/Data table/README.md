# Template:Data table

Renders an interactive, filterable browse table for every page in a category or SMW condition. Wraps [Module:DataGrid](https://starcitizen.tools/Module:DataGrid); see the module page for query and rendering details.

Use it on overview pages to list every member of a category in a sortable, searchable table backed by [Semantic MediaWiki](https://www.semantic-mediawiki.org/) data. A page image and page name are automatic first two columns; you declare only the data columns.

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

Each non-blank line in `columns` is one column. The first `;`-separated clause is the [SMW property](https://starcitizen.tools/Special:Properties) to show; the rest are modifiers:

| Modifier | Effect |
|---|---|
| `label=X` | Column header and result-row key (default: the property name). |
| `filter` | Checkbox set filter for the column. |
| `eyebrow` | Show the value as a secondary label on the lead card instead of its own column (at most one). |
| `kind=effect\|bar\|boolean` | Force a rendering: [Module:DietaryEffect](https://starcitizen.tools/Module:DietaryEffect) badges, a magnitude bar, or a [Module:Boolean](https://starcitizen.tools/Module:Boolean) icon; other values ignored. `good=higher\|lower` sets a bar's better direction. |
| `group=X` | Header this column nests under. |
| `prefix=X` / `suffix=X` / `suffix1=X` | For `eyebrow`: prefix text (`S1`), suffix unit (`5 charges`), singular suffix for `1` (`1 charge`). |

`size=X` is accepted but unused. Spacing around `;` is optional.

## Parameters

<!-- templatedata: format=block -->

| Name | Label | Type | Required | Default | Description | Example |
|------|-------|------|----------|---------|-------------|---------|
| `category` | Category | string | No |  | Category whose member pages are listed, without the `Category:` prefix. Provide this, `conditions`, or both. | `Personal weapons` |
| `columns` | Columns | content | Yes |  | One column per line: the SMW property, then `;`-separated modifiers (see Usage). | `Size ; filter` |
| `conditions` | Conditions | string | No |  | Extra raw SMW conditions, appended to the category condition or used alone. | `[[Manufacturer::ArcCorp]]` |
| `pinlead` | Pin lead | boolean | No | `false` | Pin the page-image/name column left while data columns scroll. | `yes` |

## Behavior

- The page image and page name are always the first two columns and cannot be removed.
- No pagination: rows load into one scrolling grid, searchable above and, on `filter` columns, checkbox-filterable.
- Values are auto-detected as links or comma-separated lists; `kind=` is only needed to force a different rendering.
- Duplicate `label=`s, a missing `columns`, or neither `category` nor `conditions` render an inline error, not a silently empty table.
- A query that matches nothing renders an empty grid, not an error.

## See also

- [Module:DataGrid](https://starcitizen.tools/Module:DataGrid), implementation.
- [Module:TableLua](https://starcitizen.tools/Module:TableLua), a static table from data already in a module: no query, no client-side interactivity.
