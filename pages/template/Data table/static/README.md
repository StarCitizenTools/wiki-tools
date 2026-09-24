# Template:Data table/static

Lists every page in a category or [Bucket](https://www.mediawiki.org/wiki/Extension:Bucket) property filter as a plain wikitable. It takes the same parameters as [Template:Data table](https://starcitizen.tools/Template:Data_table) and is the variant to use when every row has to be in the page itself.

## Usage

Write the call exactly as a `{{Data table}}` call; renaming the template is the whole difference.

```wikitext
{{Data table/static
| category = Wikelo ship contracts
| columns =
    Reputation min
    Orders
    Rewards
    Image
}}
```

`category`, `filter`, `kind` and the `columns` clause list are the ones [Template:Data table](https://starcitizen.tools/Template:Data_table) documents.

## Parameters

<!-- templatedata: format=block -->

| Name | Label | Type | Required | Default | Description | Example |
|------|-------|------|----------|---------|-------------|---------|
| `category` | Category | string | No |  | Category name(s) whose direct members are listed, without the `Category:` prefix; `A; B` for either. Provide this, `filter`, or both. | `Wikelo ship contracts` |
| `filter` | Filter | content | No |  | Extra row filters, one clause per line. | `Legality = Verified` |
| `kind` | Kind | string | No |  | Disambiguates a property stored in a different table per kind: `Vehicle`, `Item`, `Commodity`, `Location`, `Mission`, `Company` or `Wearable set`. | `Mission` |
| `columns` | Columns | content | Yes |  | One column per line: the property, then `;`-separated modifiers. | `Orders` |
| `sort` | Sort | string | No |  | Initial row order: a column's label or property, optionally followed by `asc` or `desc` (default `asc`); separate several with commas, first key first. | `Uec desc` |

## Behavior

- Every row is in the page, so browser find and printing reach the whole table, and a reader sorts it by clicking a column header.
- A value that carries wikitext is rendered, not escaped, so a contract line reads `50x [[Council Scrip]]` with the link on the item name.
- The page name is the first column, always present. Rows are listed by page title unless `sort` names columns.
- The page image is a column like any other: write `Image` in `columns` where the image belongs, usually last, and `label=` retitles it. A table that does not list it shows no image at all. That column does not sort, and its thumbnails line up against the column's right edge.
- A column shows what its property stores: a page property becomes a link (comma-separated links when it holds several), a repeated property one value per line, a number a grouped figure, a yes/no property the word Yes or No.
- The parameters that drive the interactive grid do nothing here and are ignored: `pinlead`, and the column modifiers `filter`, `eyebrow`, `group`, `kind`, `good`, `prefix`, `suffix`, `suffix1` and `size`. A page moves between the two templates by renaming the call, keeping its rows and columns but losing any decoration those modifiers carried, most visibly the nested header `group` gives the grid. The one column to change by hand is `Image`: [Template:Data table](https://starcitizen.tools/Template:Data_table) builds the image into its lead card and reports a column named after it as `duplicate column "Image"`, so drop that line when moving a table to the grid.
- A query returns at most 1000 rows, and the cap is silent.
- Up to 1000 rows load, with no pagination. Contract violations render as the inline errors [Template:Data table](https://starcitizen.tools/Template:Data_table) lists.

## See also

- [Template:Data table](https://starcitizen.tools/Template:Data_table), the interactive AG Grid version.
- [Module:DataGrid/Static](https://starcitizen.tools/Module:DataGrid/Static), implementation.
