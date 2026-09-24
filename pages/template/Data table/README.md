# Template:Data table

Renders an interactive, filterable browse table for every page in a category or [Bucket](https://www.mediawiki.org/wiki/Extension:Bucket) property filter. Wraps [Module:DataGrid](https://starcitizen.tools/Module:DataGrid); see the module page for details.

## Usage

Use it on an overview page (e.g. Personal weapon) to list a category's members; declare only the data columns, since the lead card (image + name) is automatic.

```wikitext
{{Data table
| category = Personal weapons
| columns =
    Weapon class ; filter
    Size ; filter
    Manufacturer ; filter
    Damage
}}
```

Each non-blank line in `columns` is one column. The first `;`-separated clause is the property to show; the rest are modifiers:

| Modifier | Effect |
|---|---|
| `label=X` | Column header and result-row key (default: the property name). |
| `filter` | Checkbox set filter for the column. |
| `eyebrow` | Show the value as a secondary label on the lead card instead of its own column; several compose into one `·`-joined line, in order. |
| `kind=effect\|bar\|boolean` | Force a rendering: [Module:DietaryEffect](https://starcitizen.tools/Module:DietaryEffect) badges, a magnitude bar, or a [Module:Boolean](https://starcitizen.tools/Module:Boolean) icon; other values ignored. `good=higher\|lower` sets a bar's better direction. |
| `group=X` | Header this column nests under; only consecutive same-group columns nest together. |
| `prefix=X` / `suffix=X` / `suffix1=X` | For `eyebrow`: prefix text (`S1`), suffix unit (`5 charges`), singular suffix for `1` (`1 charge`). |

`size=X` is accepted but unused. Spacing around `;` is optional.

`category` and `filter` narrow which pages appear; give one, or both together (`filter` then narrows the same category).

- `category`: one or more names, without the `Category:` prefix, separated by `;` for "either" (`||` also works, from an editor's `{{!}}{{!}}`); membership must be direct (no subcategory depth, no `|+depth=` modifier).
- `filter`: one clause per non-blank line, matching one of:

| Clause | Matches |
|---|---|
| `Property = Value` | equals `Value` |
| `Property = A; B` | equals `A` or `B` (`\|\|` also works) |
| `Property != Value` | not `Value` |
| `Property = +` | has any value |
| `Property < Number`, `<=`, `>`, `>=` | numeric comparison (the property must be a number) |

A `[[Target|Display]]` value strips to `Target`. Because `;` separates alternatives, a value that itself contains a semicolon cannot be expressed in a `filter` line or in `category`.

Add `kind` (`Vehicle`, `Item`, `Commodity`, `Location`, `Mission`, `Company` or `Wearable set`) only when a property named in `columns` or `filter` is stored in a different table per kind; the error message names the property and says so when it applies.

## Parameters

<!-- templatedata: format=block -->

| Name | Label | Type | Required | Default | Description | Example |
|------|-------|------|----------|---------|-------------|---------|
| `category` | Category | string | No |  | Category name(s) whose direct members are listed, without the `Category:` prefix; `A; B` for either. Provide this, `filter`, or both. | `Personal weapons` |
| `filter` | Filter | content | No |  | Extra row filters, one clause per line (see Usage). | `Manufacturer = Aegis Dynamics` |
| `kind` | Kind | string | No |  | Disambiguates a property stored in a different table per kind: `Vehicle`, `Item`, `Commodity`, `Location`, `Mission`, `Company` or `Wearable set`. | `Vehicle` |
| `columns` | Columns | content | Yes |  | One column per line: the property, then `;`-separated modifiers (see Usage). | `Size ; filter` |
| `pinlead` | Pin lead | boolean | No | `false` | Pin the lead card (page image and name) left while data columns scroll. | `yes` |
| `sort` | Sort | string | No |  | Initial sort: a column's label or property, optionally followed by `asc` or `desc` (default `asc`); separate several with commas, first key first. | `Damage desc` |

## Behavior

- The page image and name form one lead card, always first and unremovable; a page whose stored name differs from its title (e.g. Dragonfly Black) shows the stored name while the card still links the page itself.
- No pagination: up to 1000 rows load into one scrolling, searchable grid; `filter` columns add a checkbox filter.
- Rows are listed by page title unless `sort` chooses columns.
- `sort` sets the grid's initial sort on one or more `columns` entries (`Property`, `Property desc`, or `Status desc, Release date desc`, where the second key orders rows tied on the first) instead of leaving the grid unsorted; an unrecognized column name or direction, or a column named twice, renders as an inline error naming it.
- A column's rendering comes from its property's stored type, not its values: a page property becomes a link (a link list when repeated); a repeated non-page property becomes a value list; a number becomes a numeric column; a yes/no property becomes an icon; `kind=` overrides.
- `Maximum temperature`, `Minimum temperature` and `Type` are stored per kind but resolve to the item and mission tables without `kind`, so a wearable-set table must pass `kind = Wearable set` or those columns come back empty.
- Only main-namespace pages ever have data to show, so File/Category pages never leak in as rows.
- Every contract violation renders as an inline error naming the offender, instead of an empty or wrong table:
  - `"conditions" is not supported; use "filter" (see Template:Data table)`: the free-form condition string an older call used is not accepted; write the same clause as a `filter` line instead.
  - `provide "category" or "filter"`: neither was given.
  - `unknown kind "X"`: `kind` is not one of the seven values above.
  - `category "X": use plain names separated by ";"; membership is direct only`, when a `category` part carries a `|` or `+depth` modifier.
  - `filter line "X" is not Property = Value, Property = A; B, Property != Value, Property = + or Property <op> Number`: a `filter` line matched none of the forms above.
  - `unknown property 'X'`: a property named in `columns` or `filter` does not exist.
  - `"X" lives in a different table per kind; add kind= (Vehicle, Item, Commodity, Location, Mission, Company or Wearable set)`: no `kind` was given.
  - `"X" is not stored for kind Y`: `kind` was given, but `X` is not stored under it.
  - `"X" is not numeric; <op> needs a number column`: a relational `filter` clause (`<`, `<=`, `>`, `>=`) named a non-numeric property.
  - `"X" is a list; != cannot be applied`: a `!=` `filter` clause named a repeated property.
  - `no columns defined`: `columns` is empty.
  - `duplicate column "X"`: two columns, or a column and the lead card, share an alias.
- `the query could not be run: X`: a Bucket infrastructure failure (rate limit, timeout), not a contract violation in this call. It is the one inline error on this page that is not the editor's own mistake.
- A query matching nothing renders an empty grid, not an error.
- Every grid gets a toolbar button that reopens it in a window-filling modal, keeping filter and sort state.

## See also

- [Template:Data table/static](https://starcitizen.tools/Template:Data_table/static): the same query and columns as a plain wikitable, for a page where every row has to be findable in the page itself.
- [Module:DataGrid](https://starcitizen.tools/Module:DataGrid), implementation.
- [Module:TableLua](https://starcitizen.tools/Module:TableLua): a static table from module data, no query or interactivity.
