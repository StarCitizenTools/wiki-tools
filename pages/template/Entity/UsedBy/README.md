# Template:Entity/UsedBy

Renders the list of vehicles that have this item (typically a vehicle component such as a quantum drive, shield generator, or weapon) installed in their loadout, as a grid of image tiles. Inverse of [Template:Entity/Related](https://starcitizen.tools/Template:Entity/Related): Related shows variants and set pieces of an item, UsedBy shows the hosts that equip it. Reads the same upstream API data via Module:Entity/Data, so the cache is shared with any other Entity-family template on the page.

Items only today — the vehicles data comes from the items endpoint. Non-item entities, API failures, and items not used by any vehicle all render a muted "No vehicles known to use this item." placeholder so the page layout stays stable.

## Usage

Explicit UUID:

```wikitext
{{Entity/UsedBy|uuid=08a5bfdb-1972-421f-83fe-be03b7ac5222}}
```

When `Template:Entity` has been invoked earlier on the page, the UUID can be omitted — it falls back to the value stored in SMW on the current page:

```wikitext
{{Entity}}

== Used by ==
{{Entity/UsedBy}}
```

## Parameters

| Name | Label | Type | Required | Default | Description | Example |
|------|-------|------|----------|---------|-------------|---------|
| `uuid` | UUID | string | No | (falls back to SMW UUID on the current page) | UUID of the entity to render. If omitted, defaults to the UUID stored in SMW (set by Template:Entity on a prior parse). Required if Template:Entity hasn't been invoked. | `08a5bfdb-1972-421f-83fe-be03b7ac5222` |

## Behavior

- Renders a single tile grid sorted by manufacturer code then by name, so vehicles from the same brand (e.g. all Anvil Hornets) cluster naturally without needing explicit sub-headings.
- Each tile shows the vehicle's page image (resolved via the SMW `Page Image` property) with the vehicle name overlaid at the bottom and the in-game role (e.g. `Medium Fighter`) as a small kicker above the name.
- Tile aspect ratio is `16 / 9` with a `200px` minimum tile width — vehicle hero shots are landscape, so widening the auto-fill floor keeps each tile tall enough for the name overlay to stay legible. Related uses the narrower `3 / 4` ratio with the default `120px` floor for portrait item renders.
- The whole tile is clickable. MediaWiki's sanitizer strips raw `<a>` tags, so each tile uses a "fakelink": a transparent absolutely-positioned `[[Page|Page]]` wikilink wrapper that stretches to fill the tile.
- Link target is resolved via the SMW `uuid` property so disambiguated wiki titles (e.g. `Hyperion (quantum drive)` for variants in the Related template, or any vehicle whose API name collides with another article) link to the canonical article rather than the disambiguation hit.
- Vehicles without a `Page Image` SMW value fall back to the Tiles placeholder so the grid layout stays stable.
- Empty state: when the upstream fetch fails, the entity isn't an item, or no vehicles equip it, the template renders a single muted line: "No vehicles known to use this item." The container always renders, so the page layout doesn't shift between items that have hosts and items that don't.

## See also

- [Template:Entity](https://starcitizen.tools/Template:Entity) — the main entity infobox; sets the SMW UUID this template falls back to.
- [Template:Entity/Availability](https://starcitizen.tools/Template:Entity/Availability) — sibling renderer for shop/loot/pledge availability.
- [Template:Entity/Description](https://starcitizen.tools/Template:Entity/Description) — sibling renderer for the in-game description.
- [Template:Entity/Related](https://starcitizen.tools/Template:Entity/Related) — sibling renderer for variants and set components.
- [Module:Entity/UsedBy](https://starcitizen.tools/Module:Entity/UsedBy) — implementation.
