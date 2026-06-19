# Template:Manufacturer products

Renders a manufacturer's full product catalogue as an interactive, filterable browse table. A thin wrapper around [[Template:Data table]] scoped to the manufacturer's category, used on company and manufacturer pages.

## Usage

On a manufacturer page whose title matches its product category (the common case):

```wikitext
== Products ==
{{Manufacturer products}}
```

When the product category differs from the page title (disambiguated, abbreviated, or differently-cased pages, e.g. `ArcCorp (company)` → `ArcCorp`), pass the category explicitly:

```wikitext
== Products ==
{{Manufacturer products | ArcCorp}}
```

Backed by [[Template:Data table]] → [[Module:DataGrid]].

## Parameters

| Name | Type | Required | Default | Description | Example |
|------|------|----------|---------|-------------|---------|
| `1` | string | No | the page title | The manufacturer category whose member items are listed (without the `Category:` prefix). Override only when the category name differs from the page title. | `ArcCorp` |

## Notes

- Lists every page in the manufacturer's category, with the automatic page-image and page-name columns plus a filterable **Item type** column.
- The category defaults to the page title. Verify the category actually has members: a category with zero members renders an empty table, which usually means the category name differs from the page title and needs the override.

## See also

- [[Template:Data table]]
- [[Template:Company]]
