# Template:Entity/Related

Renders an entity's set components and cosmetic variants as a grid of image cards. Designed to sit further down an entity page as body content, separate from the [Template:Entity](https://starcitizen.tools/Template:Entity) infobox at the top. Reads the same upstream API data via Module:Entity/Data, so the cache is shared with any other Entity-family template on the page.

Items only today — the related-items data comes from the items endpoint. Non-item entities, API failures, and items with no set pieces or variants all render a muted "No related items available from the API." placeholder so the page layout stays stable.

## Usage

Explicit UUID:

```wikitext
{{Entity/Related|uuid=80ee3b95-5665-4548-9e2d-d2067895c0ac}}
```

When `Template:Entity` has been invoked earlier on the page, the UUID can be omitted — it falls back to the value stored in SMW on the current page:

```wikitext
{{Entity}}

== Related ==
{{Entity/Related}}
```

## Parameters

| Name | Label | Type | Required | Default | Description | Example |
|------|-------|------|----------|---------|-------------|---------|
| `uuid` | UUID | string | No | (falls back to SMW UUID on the current page) | UUID of the entity to render. If omitted, defaults to the UUID stored in SMW (set by Template:Entity on a prior parse). Required if Template:Entity hasn't been invoked. | `80ee3b95-5665-4548-9e2d-d2067895c0ac` |

## Behavior

- Renders up to two card grids in this order: **Set pieces** (other items that make up a wearable set, e.g. helmet/torso/legs) and **Variants** (cosmetic variants of the same base item, e.g. different colorways).
- Each card shows the item's page image (resolved via the SMW `Page Image` property in a single batched query) with the item name overlaid at the bottom. Variant cards add the variant differentiator (e.g. `Black`, or `(base)` when the base item has no variant name) as the primary label; set cards add the resolved type (e.g. `Helmet`) as a small kicker above the name.
- The whole card is clickable. MediaWiki's sanitizer strips raw `<a>` tags, so the card uses a "fakelink": a transparent absolutely-positioned `[[Page|Page]]` wikilink wrapper that stretches to fill the card.
- The current page is filtered out of the variants list so the entity never links to itself. Set components are always distinct items, so no self-reference check is needed there.
- Items without a `Page Image` SMW value fall back to `Placeholderv2.png` so the grid layout stays stable.
- Empty state: when the upstream fetch fails, the entity has no `related_items`, or both buckets are empty, the template renders a single muted line: "No related items available from the API." The container always renders, so the page layout doesn't shift between entities that have related items and entities that don't.

## See also

- [Template:Entity](https://starcitizen.tools/Template:Entity) — the main entity infobox; sets the SMW UUID this template falls back to.
- [Template:Entity/Availability](https://starcitizen.tools/Template:Entity/Availability) — sibling renderer for shop/loot/pledge availability.
- [Template:Entity/Description](https://starcitizen.tools/Template:Entity/Description) — sibling renderer for the in-game description.
- [Module:Entity/Related](https://starcitizen.tools/Module:Entity/Related) — implementation.
