# Template:Manufacturer products

Renders a manufacturer's full product catalogue as an interactive, filterable browse table. A thin wrapper around [[Template:Data table]] scoped to the manufacturer's `Manufacturer` property, used on company and manufacturer pages.

## Usage

On a manufacturer page whose title matches its manufacturer name (the common case):

```wikitext
== Products ==
{{Manufacturer products}}
```

When the manufacturer name differs from the page title (disambiguated, abbreviated, or differently-cased pages, e.g. `ArcCorp (company)` → `ArcCorp`), pass the manufacturer explicitly:

```wikitext
== Products ==
{{Manufacturer products | ArcCorp}}
```

Backed by [[Template:Data table]] → [[Module:DataGrid]].

## Parameters

| Name | Type | Required | Default | Description | Example |
|------|------|----------|---------|-------------|---------|
| `1` | string | No | the page title | The manufacturer whose products are listed, matched against the `Manufacturer` SMW property (the manufacturer's full name, e.g. `ArcCorp`). Override only when the manufacturer name differs from the page title. | `ArcCorp` |

## Notes

- Queries the `Manufacturer` property (`[[Manufacturer::…]]`), not the manufacturer category. The category collects everything tagged to the company (locations, lore, people, concept art) alongside its products; the property is set only on the company's actual products, so the table lists products and nothing else.
- Lists every product whose `Manufacturer` property matches, with the automatic page-image and page-name columns plus a filterable **Item type** column.
- The manufacturer defaults to the page title. An empty table usually means the manufacturer name differs from the page title (use the override) — the `Manufacturer` property stores the manufacturer's full name, e.g. `Aegis Dynamics`, not its code (`AEGS`).

## See also

- [[Template:Data table]]
- [[Template:Company]]
