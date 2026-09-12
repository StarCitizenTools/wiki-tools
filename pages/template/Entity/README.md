# Template:Entity

Renders the infobox for an item, commodity, or mission, and writes the page's [SMW](https://www.mediawiki.org/wiki/Extension:Semantic_MediaWiki) data, short description, and categories. Place it at the top of the page, before any Entity-family body template.

## Usage

In-game entity, everything from the API:

```wikitext
{{Entity|uuid=80ee3b95-5665-4548-9e2d-d2067895c0ac}}
```

A sibling body template lower on the page can omit `uuid`, once the page has a prior parse to read: this invocation's write to SMW isn't visible until the page is saved and re-parsed. A brand-new page's first save has nothing stored yet, so give the sibling its own `uuid` too until then:

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
| `manufacturer` | Manufacturer | string | No | (API value) | Manufacturer override, as a code (e.g. `AEGS`) or a full name; wins over the API and drives the manufacturer browse category. | `AEGS` |
| `type` | Type | string | No | (resolved from the API record) | Overrides the resolved structural type; only takes effect when the leaf module has no `getTypeInfo` of its own (mainly items with no dedicated subtype module). | `Armor` |

## Behavior

- With no `uuid`, no `name`, and no matching `kind`, the module cannot identify the entity: it renders an error and adds the page to `Pages with Entity errors` instead of the infobox.
- Omitting `uuid` while `kind` is unset falls back to the uuid already stored in SMW on the page (set by an earlier `{{Entity}}` parse). Setting `kind` suppresses that fallback, so a kind-declared page needs its own `uuid` to resolve a genuine record.
- `kind` only renders a planned page when it names a kind that supports editorial mode, `Vehicle` or `Location`. On such a kind-declared page, a `uuid` that is supplied but fails to resolve is not treated as a planned page either: it adds the page to `Pages with an unresolved entity reference`. Without a declared `kind`, a `uuid` that fails to resolve instead adds the page to `Pages with API errors`.
- `{{Entity}}` writes the entity's own infobox data: the page's SMW structured data, `SHORTDESC`, and its categories. None of the six sibling body templates below write any of that themselves.
- A sibling's `uuid` fallback reads the value `{{Entity}}` stored in SMW on a prior parse, not the current one: on a brand-new page's first save, a sibling invoked without its own `uuid` won't resolve until the page is purged or re-saved.
- `{{Vehicle}}` and `{{Location}}` are thin facades that inject `|kind=` on your behalf; `{{Entity|kind=Vehicle|...}}` renders identically, but the facades also scope the VisualEditor form to that kind's own parameters.

## See also

- [Template:Vehicle](https://starcitizen.tools/Template:Vehicle) and [Template:Location](https://starcitizen.tools/Template:Location), the kind-scoped facades over this same module.
- [Template:Entity/Availability](https://starcitizen.tools/Template:Entity/Availability), [Template:Entity/Blueprints](https://starcitizen.tools/Template:Entity/Blueprints), [Template:Entity/Description](https://starcitizen.tools/Template:Entity/Description), [Template:Entity/Ports](https://starcitizen.tools/Template:Entity/Ports), [Template:Entity/Related](https://starcitizen.tools/Template:Entity/Related), [Template:Entity/UsedBy](https://starcitizen.tools/Template:Entity/UsedBy), the sibling body templates that read the uuid this template stores.
- [Module:Entity](https://starcitizen.tools/Module:Entity), the implementation and pipeline reference.
