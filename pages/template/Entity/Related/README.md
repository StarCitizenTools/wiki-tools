# Template:Entity/Related

Renders an item's set components and cosmetic variants as a grid of image cards, or, for a commodity, its cargo-box packaging sizes as a table. Place it as body content further down the page, separate from the `{{Entity}}` infobox at the top.

## Usage

Explicit UUID:

```wikitext
{{Entity/Related|uuid=80ee3b95-5665-4548-9e2d-d2067895c0ac}}
```

When `{{Entity}}` has been invoked earlier on the page, the UUID can be omitted; it falls back to the value a previous parse stored on the current page, so on a brand-new page it resolves only after the page has been saved and re-parsed (purged or re-saved):

```wikitext
{{Entity}}

== Related ==
{{Entity/Related}}
```

## Parameters

| Name | Label | Type | Required | Default | Description | Example |
|------|-------|------|----------|---------|-------------|---------|
| `uuid` | UUID | string | No | (falls back to the uuid stored by a prior `{{Entity}}` parse) | UUID of the entity to render. Required if `{{Entity}}` hasn't been invoked. | `80ee3b95-5665-4548-9e2d-d2067895c0ac` |

## Behavior

- **Items** render up to two tile grids in order: Set pieces (other items forming a wearable set) then Variants (cosmetic variants of the same base item). A grid is omitted when it is empty; if both are, it shows the placeholder "No related items." instead.
- **Commodities** render neither grid; instead a sortable Cargo variants table lists each SCU box size with its dimensions and mass, since cargo boxes share one image and have no wiki pages of their own. A box size outside the standard SCU ladder (0.125 through 32) still gets a row, but its Length/Width/Height cells render `-` instead of a dimension.
- **Vehicles** with an editorial series render a Variants tile grid of every vehicle in that series, the current one highlighted; a vehicle with no series, or alone in its series, shows the placeholder.
- **Missions and locations** have no related-items data and show the placeholder.
- An upstream fetch failure shows the warning "Couldn't load related items."
- The current page is filtered out of an item's Variants grid so an entity never links to itself; Set pieces need no such filter, since set components are always distinct items.
- A variant's size or grade only appears as a small caption above the name when it actually differs across the family; if every variant shares the same size and grade, the caption is omitted.
- Tile links and images resolve through the stored `uuid`, so a disambiguated title like `Hyperion (quantum drive)` links to the right article; an item with no resolvable page falls back to the API name for both link and image, with a placeholder image.

## See also

- [Template:Entity](https://starcitizen.tools/Template:Entity), the infobox that owns the page's structured data, SHORTDESC, and categories; sets the uuid this template falls back to.
- [Template:Entity/Availability](https://starcitizen.tools/Template:Entity/Availability), sibling renderer for shop, loot, and pledge availability.
- [Template:Entity/Description](https://starcitizen.tools/Template:Entity/Description), sibling renderer for the in-game description.
- [Module:Entity/Related](https://starcitizen.tools/Module:Entity/Related), the implementation.
