# Module:Entity/Related

Renders an entity's related entries as image card grids: set components first (helmet/torso/legs etc.), then cosmetic variants. Sibling renderer parallel to [Module:Entity/Availability](https://starcitizen.tools/Module:Entity/Availability) and [Module:Entity/Description](https://starcitizen.tools/Module:Entity/Description) — consumes [Module:Entity/Data](https://starcitizen.tools/Module:Entity/Data) so it shares Apiunto's cache with the Entity infobox and any other Entity-family template on the page.

Items only today (reads `apiData.related_items`, which only the items endpoint provides). The container always renders — non-item entities, API failures, and items with no set pieces or variants all fall back to a muted empty-state placeholder so the page layout stays stable.

## Usage

Invoked through [Template:Entity/Related](https://starcitizen.tools/Template:Entity/Related), not called directly from other Lua:

```wikitext
{{Entity/Related|uuid=80ee3b95-5665-4548-9e2d-d2067895c0ac}}
```

The `uuid` parameter falls back to the SMW UUID set by `Template:Entity` on a prior parse — so on a typical entity page the template is invoked bare:

```wikitext
{{Entity}}

== Related ==
{{Entity/Related}}
```

## API

### `p.main( frame )`

Entry point invoked from `Template:Entity/Related`.

Resolves the UUID from `frame.args.uuid`, the parent frame, or SMW (in that order), fetches related items via `Module:Entity/Data`, batches a single SMW query for the `Page Image` property across every referenced page, and renders up to two card grids: **Set pieces** then **Variants**. Includes its own `templatestyles` tag, so callers don't load styles separately.

Falls back to a muted empty-state placeholder ("No related items available from the API.") when the upstream fetch fails, the entity has no `related_items`, or both buckets are empty. The `templatestyles` tag still ships in this case so the placeholder's styles load.

## Data

Reads the `related_items` block from the merged Apiunto response. Shape:

```json
{
    "related_items": {
        "set_items": [
            { "name": "Helmet name", "uuid": "…", "type": "Char_Armor_Helmet" }
        ],
        "base_item": { "name": "Base item name", "uuid": "…", "variant_name": "Default" },
        "variant_items": [
            { "name": "Variant name", "uuid": "…", "variant_name": "Black" }
        ]
    }
}
```

| Field | Description |
|---|---|
| `set_items` | Other items that make up a wearable set. Rendered first, with the resolved type (e.g. `Helmet`) as a small kicker above the name. |
| `base_item` | The canonical base item for a variant family. Rendered at the top of the **Variants** grid. Filtered out when its UUID matches the queried entity (the only self-reference case the API exposes). |
| `variant_items` | Cosmetic variants of the base item. Rendered in API order, with `variant_name` as the primary label — falling back to `name` when the API doesn't expose a separate variant name. |

Display names for set-item types come from [Module:Entity/Item/types.json](https://starcitizen.tools/Module:Entity/Item/types.json) (keyed by the API type string). Unmapped types fall through to the raw API string so new types are still discoverable on-page.

Page titles and images are both resolved via a single `mw.smw.ask` query against the `uuid` SMW property (set on render by [Module:Entity/StructuredData](https://starcitizen.tools/Module:Entity/StructuredData)). The query matches both the canonical lowercase `uuid` and the legacy capitalized `UUID` so unmigrated pages still resolve. Results are filtered to mainspace, non-subobject pages so a stray UUID stored as a subobject or in a `User:` test page doesn't redirect the link off the canonical article; the SMW limit is over-fetched 5× to make sure the mainspace hit isn't truncated when a UUID also appears on a subobject. This decouples the link target from the API name — disambiguated page titles like `Hyperion (quantum drive)` link correctly while the card label keeps the friendly API name `Hyperion`. Items whose UUID matches no mainspace page (never rendered with `Template:Entity`, or property hasn't propagated yet) fall back to the API name for both link and image, with `Placeholderv2.png` for the missing image.

## CSS hooks

Styles live in `styles.css` (loaded via `templatestyles`). Skin or sibling-template overrides can target:

| Class | Purpose |
|---|---|
| `t-entity-related-grid` | The card grid container. Auto-fill columns at `minmax(120px, 1fr)`. |
| `t-entity-related-card` | One card. `position: relative` anchor for the fakelink. |
| `t-entity-related-card-link` | The transparent absolutely-positioned wikilink wrapper. Makes the whole card clickable around MediaWiki's sanitizer. |
| `t-entity-related-card-image` | Image container, fixed 160px height with object-cover. |
| `t-entity-related-card-label` | Bottom label group. |
| `t-entity-related-card-label-primary` | The prominent line (variant name or item name). Single-line + ellipsis. |
| `t-entity-related-card-label-secondary` | The small kicker above primary (resolved type for set components, empty for variants). Single-line + ellipsis. |
| `t-entity-related-empty` | The muted placeholder paragraph rendered in the empty state. |

## Architecture

```
Entity/Related/
├── Related.lua    # Main entry point
└── styles.css     # Component styles
```
