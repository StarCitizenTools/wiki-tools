# Template:Data table

Renders an interactive, filterable browse table for every page in a category or [SMW](https://www.mediawiki.org/wiki/Extension:Semantic_MediaWiki) condition. Wraps [Module:DataGrid](https://starcitizen.tools/Module:DataGrid); see the module page for details.

## Usage

Use it on an overview page (e.g. Personal weapon) to list a category's members; declare only the data columns, since the lead card (image + name) is automatic.

```wikitext
{{Data table
| category = Personal weapons
| columns =
    Size ; filter
    Subtype ; label=Type ; filter
    Manufacturer ; filter
    Damage
}}
```

Each non-blank line in `columns` is one column. The first `;`-separated clause is the [SMW property](https://starcitizen.tools/Special:Properties) to show; the rest are modifiers:

| Modifier | Effect |
|---|---|
| `label=X` | Column header and result-row key (default: the property name). |
| `filter` | Checkbox set filter for the column. |
| `eyebrow` | Show the value as a secondary label on the lead card instead of its own column; several compose into one `·`-joined line, in order. |
| `kind=effect\|bar\|boolean` | Force a rendering: [Module:DietaryEffect](https://starcitizen.tools/Module:DietaryEffect) badges, a magnitude bar, or a [Module:Boolean](https://starcitizen.tools/Module:Boolean) icon; other values ignored. `good=higher\|lower` sets a bar's better direction. |
| `group=X` | Header this column nests under; only consecutive same-group columns nest together. |
| `prefix=X` / `suffix=X` / `suffix1=X` | For `eyebrow`: prefix text (`S1`), suffix unit (`5 charges`), singular suffix for `1` (`1 charge`). |

`size=X` is accepted but unused. Spacing around `;` is optional.

## Parameters

<!-- templatedata: format=block -->

| Name | Label | Type | Required | Default | Description | Example |
|------|-------|------|----------|---------|-------------|---------|
| `category` | Category | string | No |  | Category whose member pages are listed, without the `Category:` prefix; provide this, `conditions`, or both. | `Personal weapons` |
| `columns` | Columns | content | Yes |  | One column per line: the property, then `;`-separated modifiers (see Usage). | `Size ; filter` |
| `conditions` | Conditions | string | No |  | Extra raw SMW conditions, appended to `category` or used alone. | `[[Manufacturer::ArcCorp]]` |
| `pinlead` | Pin lead | boolean | No | `false` | Pin the lead card (page image and name) left while data columns scroll. | `yes` |

## Behavior

- The page image and name form one lead card, always first and unremovable.
- No pagination: up to 1000 rows load into one scrolling, searchable grid; `filter` columns add a checkbox filter.
- A column auto-detects as a list if any value is multi-valued, or as page links only if every value is a wikilink; `kind=` overrides.
- Duplicate `label=`s, a missing `columns`, or neither `category` nor `conditions` render an inline error; a query matching nothing renders an empty grid, not an error.
- The query is restricted to the main namespace, so File/Category pages never leak in.
- Every grid gets a toolbar button that reopens it in a window-filling modal, keeping filter and sort state.

## See also

- [Module:DataGrid](https://starcitizen.tools/Module:DataGrid), implementation.
- [Module:TableLua](https://starcitizen.tools/Module:TableLua): a static table from module data, no query or interactivity.
