# Template:Entity/Description

Renders an entity's in-game description as a quoted block, with the API capture version printed below. Place it as body prose further down the page, separate from the `{{Entity}}` infobox at the top.

## Usage

Explicit UUID:

```wikitext
{{Entity/Description|uuid=80ee3b95-5665-4548-9e2d-d2067895c0ac}}
```

When `{{Entity}}` has been invoked earlier on the page, the UUID can be omitted; it falls back to the value a previous parse stored in [SMW](https://www.mediawiki.org/wiki/Extension:Semantic_MediaWiki) on the current page, so on a brand-new page it resolves only after the page has been saved and re-parsed (purged or re-saved):

```wikitext
{{Entity}}

== Description ==
{{Entity/Description}}
```

## Parameters

| Name | Label | Type | Required | Default | Description | Example |
|------|-------|------|----------|---------|-------------|---------|
| `uuid` | UUID | string | No | (falls back to the SMW uuid stored by a prior `{{Entity}}` parse) | UUID of the entity to render. Required if `{{Entity}}` hasn't been invoked. | `80ee3b95-5665-4548-9e2d-d2067895c0ac` |

## Behavior

- The container always renders, so the page layout stays stable. When the API returns no description, a "No description available from the API." placeholder is shown in a muted style instead of the quote.
- Some in-game descriptions carry coloured emphasis spans; these are preserved in the rendered quote, not stripped.
- The version line below the quote is the [Apiunto](https://www.mediawiki.org/wiki/Extension:Apiunto) `version` field, useful for cross-referencing which in-game build the description was captured from.

## See also

- [Template:Entity](https://starcitizen.tools/Template:Entity), the infobox that owns the page's SMW data, SHORTDESC, and categories; sets the uuid this template falls back to.
- [Template:Entity/Availability](https://starcitizen.tools/Template:Entity/Availability), sibling renderer for shop, loot, and pledge availability.
- [Template:Entity/Related](https://starcitizen.tools/Template:Entity/Related), sibling renderer for variants and set components.
- [Module:Entity/Description](https://starcitizen.tools/Module:Entity/Description), the implementation.
