# Template:Entity/UsedBy

`{{Entity/UsedBy}}` renders the vehicles that have this item, typically a component such as a quantum drive, shield generator, or weapon, installed in their loadout, as a grid of image tiles. It is the inverse of `{{Entity/Related}}`: Related shows an item's own variants and set pieces, UsedBy shows the vehicles that use it.

## Usage

Explicit UUID:

```wikitext
{{Entity/UsedBy|uuid=08a5bfdb-1972-421f-83fe-be03b7ac5222}}
```

When `{{Entity}}` has been invoked earlier on the page, the UUID can be omitted; it falls back to the value stored in SMW on the current page:

```wikitext
{{Entity}}

== Used by ==
{{Entity/UsedBy}}
```

## Parameters

| Name | Label | Type | Required | Default | Description | Example |
|------|-------|------|----------|---------|-------------|---------|
| `uuid` | UUID | string | No | (falls back to SMW UUID on the current page) | UUID of the entity to render. Required if `{{Entity}}` hasn't been invoked. | `08a5bfdb-1972-421f-83fe-be03b7ac5222` |

## Behaviour

- Works for items only; commodities, vehicles, and missions render the muted placeholder instead, since only the items endpoint carries a `vehicles` include.
- Renders a single tile grid sorted by manufacturer code then by name, so vehicles from the same brand (e.g. all Anvil Hornets) cluster naturally without explicit subheadings.
- Each tile shows the vehicle's page image with the vehicle name overlaid at the bottom and the in-game role (e.g. `Medium Fighter`) as a small kicker above the name.
- Tile aspect ratio is `16 / 9` with a `200px` minimum tile width, wider than `{{Entity/Related}}`'s `3 / 4` portrait ratio, since vehicle hero shots are landscape and the wider floor keeps each tile tall enough for the name overlay to stay legible.
- Link target and image resolve through the SMW `uuid` property, so disambiguated titles (e.g. `Hyperion (quantum drive)` for a variant, or any vehicle whose API name collides with another article) link to the canonical article rather than the disambiguation page. A vehicle with no resolvable page falls back to a placeholder image.
- Empty state: when the upstream fetch fails, the entity isn't an item, or no vehicle equips it, the template renders a single muted line, "No vehicles known to use this item." The container always renders, so the page layout doesn't shift between items that have hosts and items that don't.

## See also

- [Template:Entity](https://starcitizen.tools/Template:Entity), the infobox that owns the page's SMW data, SHORTDESC, and categories; sets the uuid this template falls back to.
- [Template:Entity/Availability](https://starcitizen.tools/Template:Entity/Availability), sibling renderer for shop, loot, and pledge availability.
- [Template:Entity/Description](https://starcitizen.tools/Template:Entity/Description), sibling renderer for the in-game description.
- [Template:Entity/Related](https://starcitizen.tools/Template:Entity/Related), sibling renderer for variants and set components.
- [Module:Entity/UsedBy](https://starcitizen.tools/Module:Entity/UsedBy), the implementation.
