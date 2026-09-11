# Template:Entity

`{{Entity}}` renders the infobox for an item, commodity, or mission, and writes the page's SMW data, short description, and categories. Place it at the top of the page, before any Entity-family body template.

## Usage

In-game entity, everything from the API:

```wikitext
{{Entity|uuid=80ee3b95-5665-4548-9e2d-d2067895c0ac}}
```

Followed by a sibling body template lower on the page; the sibling reuses the uuid this invocation stores in SMW:

```wikitext
{{Entity|uuid=80ee3b95-5665-4548-9e2d-d2067895c0ac}}

== Description ==
{{Entity/Description}}
```

## Parameters

| Name | Label | Type | Required | Default | Description | Example |
|------|-------|------|----------|---------|-------------|---------|
| `uuid` | UUID | string | No | (falls back to the page's stored SMW uuid, unless `kind` is set) | Entity UUID from the game data API. | `80ee3b95-5665-4548-9e2d-d2067895c0ac` |
| `name` | Name | string | No | (API name, else the page title) | Display-name override for the infobox title; also the entity's name on a kind-declared page with no uuid. | `Hyperion` |
| `kind` | Kind | string | No | (none) | Declares the page's kind for a planned entity with no uuid. Set for you by the `{{Vehicle}}` / `{{Location}}` facades; typed directly here only for a kind that supports it. | `Vehicle` |

## Behaviour

- With no `uuid`, no `name`, and no matching `kind`, the module cannot identify the entity: it renders an error and adds the page to `Pages with Entity errors` instead of the infobox.
- Omitting `uuid` while `kind` is unset falls back to the uuid already stored in SMW on the page (set by an earlier `{{Entity}}` parse). Setting `kind` suppresses that fallback, so a kind-declared page needs its own `uuid` to resolve a genuine record.
- `kind` only renders a planned page when it names a kind that supports editorial mode, `Vehicle` or `Location` today. A `uuid` that is supplied but fails to resolve is not treated as a planned page either: it adds the page to `Pages with an unresolved entity reference` instead.
- `{{Entity}}` is the only Entity-family template that writes the page's SMW structured data, sets `SHORTDESC`, and appends the entity's categories. Invoke it once, before any sibling body template, so those templates' `uuid` fallback has something to read.
- `{{Vehicle}}` and `{{Location}}` are thin facades that inject `|kind=` on your behalf; `{{Entity|kind=Vehicle|...}}` renders identically, but the facades also scope the VisualEditor form to that kind's own parameters.

## See also

- [Template:Vehicle](https://starcitizen.tools/Template:Vehicle) and [Template:Location](https://starcitizen.tools/Template:Location), the kind-scoped facades over this same module.
- [Template:Entity/Availability](https://starcitizen.tools/Template:Entity/Availability), [Template:Entity/Blueprints](https://starcitizen.tools/Template:Entity/Blueprints), [Template:Entity/Description](https://starcitizen.tools/Template:Entity/Description), [Template:Entity/Related](https://starcitizen.tools/Template:Entity/Related), [Template:Entity/UsedBy](https://starcitizen.tools/Template:Entity/UsedBy), the sibling body templates that read the uuid this template stores.
- [Module:Entity](https://starcitizen.tools/Module:Entity), the implementation and pipeline reference.
