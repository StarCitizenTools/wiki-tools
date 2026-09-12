# Template:Entity/Blueprints

Renders an item's crafting blueprints and dismantle returns, or, for a commodity, a card linking to the recipes that use it as an ingredient. Place it as body content further down the page, separate from the `{{Entity}}` infobox at the top.

## Usage

Explicit UUID:

```wikitext
{{Entity/Blueprints|uuid=80ee3b95-5665-4548-9e2d-d2067895c0ac}}
```

When `{{Entity}}` has been invoked earlier on the page, the UUID can be omitted; it falls back to the value a previous parse stored in [SMW](https://www.mediawiki.org/wiki/Extension:Semantic_MediaWiki) on the current page, so on a brand-new page it resolves only after the page has been saved and re-parsed (purged or re-saved):

```wikitext
{{Entity}}

== Blueprints ==
{{Entity/Blueprints}}
```

## Parameters

| Name | Label | Type | Required | Default | Description | Example |
|------|-------|------|----------|---------|-------------|---------|
| `uuid` | UUID | string | No | (falls back to the SMW uuid stored by a prior `{{Entity}}` parse) | UUID of the entity to render. Required if `{{Entity}}` hasn't been invoked. | `80ee3b95-5665-4548-9e2d-d2067895c0ac` |

## Behavior

- **Items** render two sections, Blueprints and Dismantle, each with one collapsible card per blueprint entry that has matching data (recipe aspects, or dismantle returns). Both section headings always render, even when both are empty.
- **Commodities** render neither section; instead a single card titled "Browse N recipes" (or "Browse 1 recipe") shows how many recipes use the commodity as an ingredient, with a button to the full filtered list, since a commodity can be an ingredient in far more recipes than an item's own blueprint list could usefully enumerate as cards. Three empty states cover it: no resolvable name shows "No crafting data available.", a failed count fetch shows "Crafting usage data unavailable.", and a genuine zero shows "Not used as an ingredient in any known crafting recipe."
- **Vehicles, missions, and locations** carry no blueprint data, so both sections still render, showing the item-worded empty-state text ("No blueprints found for this item." / "No dismantle returns for this item.") rather than being omitted.
- An upstream fetch failure shows "Blueprint data unavailable." / "Dismantle data unavailable." instead of the no-data message, so editors can tell an API outage from a genuinely blueprint-less entity.
- The Grade badge on a blueprint card falls back to `Grade 1` when the API entry carries no grade field.
- No parameter overrides the rendered data; there is nothing here for an editor to curate beyond `uuid`.

## See also

- [Template:Entity](https://starcitizen.tools/Template:Entity), the infobox that owns the page's SMW data, SHORTDESC, and categories; sets the uuid this template falls back to.
- [Template:Entity/Availability](https://starcitizen.tools/Template:Entity/Availability), sibling renderer for acquisition and shop data.
- [Template:Entity/Related](https://starcitizen.tools/Template:Entity/Related), sibling renderer for set components and cosmetic variants.
- [Module:Entity/Blueprints](https://starcitizen.tools/Module:Entity/Blueprints), the implementation.
