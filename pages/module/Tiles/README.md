# Module:Tiles

Generic image-led grid renderer. Each tile is an image with optional primary/secondary labels overlaid at the bottom, and the entire tile is clickable via a fakelink (a transparent absolutely-positioned `[[Page|Text]]` wikilink — MediaWiki's sanitizer strips raw `<a>` tags, so anchors only exist when the parser generates them from wikitext).

Pure rendering: callers pass fully resolved rows (page, image, labels). Look-up concerns — SMW page resolution, API fetching — live in the caller. This keeps Tiles testable and reusable across unrelated callers; for example, [Module:Entity/Related](https://starcitizen.tools/Module:Entity/Related) resolves rows via the SMW `uuid` property while [Module:Entity/UsedBy](https://starcitizen.tools/Module:Entity/UsedBy) does the same against the vehicles endpoint.

## Usage

```lua
local Tiles = require( 'Module:Tiles' )

local html = Tiles.render( {
    rows = {
        {
            page = 'Hyperion (quantum drive)',
            linkLabel = 'Hyperion',
            image = 'Hyperion-QD.png',
            primary = 'Hyperion',
            secondary = 'Variant',
        },
        {
            page = 'Atlas (quantum drive)',
            linkLabel = 'Atlas',
            primary = 'Atlas',
            -- image omitted -> falls back to placeholderImage
        },
    },
    aspectRatio = '16 / 9',
    placeholderImage = 'Placeholderv2.png',
} )
```

`render` returns a string: a `<templatestyles>` tag for `Module:Tiles/styles.css` followed by the grid markup. Concatenate it directly into your module's output.

## API

### `p.render( props )`

Renders the grid.

#### `TilesProps`

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `rows` | `TilesRow[]` | Yes | | Rows to render, in order. |
| `aspectRatio` | `string` | No | `'1 / 1'` | CSS `aspect-ratio` value applied to every tile's image (e.g. `'16 / 9'` for landscape vehicle shots, `'3 / 4'` for portrait item renders). |
| `tileMinWidth` | `string` | No | `'120px'` | CSS length used as the `minmax(<min>, 1fr)` floor for the grid's auto-fill columns. Wider tiles wrap in fewer columns per row but stay legible at tall or landscape aspect ratios; combine with `aspectRatio` when changing tile shape (e.g. `'200px'` + `'16 / 9'` for vehicle hero shots). |
| `placeholderImage` | `string` | No | `'Placeholderv2.png'` | Image filename used when a row has no `image`. |
| `imageWidth` | `string` | No | `'320px'` | Thumbnail width hint passed to `[[File:…|<width>|link=]]`. Set larger when tiles render wider than ~320px in your layout to avoid blurring; smaller when wider just means more bandwidth. |

#### `TilesRow`

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `linkLabel` | `string` | Yes | | Accessible text for the wikilink. Screen readers announce this; sighted users see `primary`. Rows without a `linkLabel` are skipped. |
| `page` | `string` | No | `linkLabel` | Wiki page to link to. When omitted, the tile becomes a red link to the bare `linkLabel`. |
| `image` | `string` | No | `placeholderImage` | Image filename (without the `File:` prefix). |
| `primary` | `string` | No | | Prominent label at the bottom of the tile. Omit for an image-only tile. |
| `secondary` | `string` | No | | Smaller kicker rendered above `primary` (subtitle style). |

## Aspect ratio and tile width

Both `aspectRatio` and `tileMinWidth` are applied inline as CSS custom properties on the grid root, and the stylesheet consumes them via bare `var()` references. The grid's default declarations set `--t-tiles-aspect: 1 / 1` and `--t-tiles-columns: repeat(auto-fill, minmax(120px, 1fr))`, so omitting both produces square tiles in a fairly dense grid; passing either overrides the inherited custom property for that grid.

Two implementation quirks worth knowing for skin authors:

- The defaults live in separate custom-property declarations rather than `var(…, default)` because TemplateStyles' sanitizer rejects the fallback form on `aspect-ratio`.
- For `tileMinWidth` we assemble the entire `repeat(auto-fill, minmax(<min>, 1fr))` value in Lua and stash it in `--t-tiles-columns`, rather than exposing the bare `<min>` length and consuming it via `repeat(auto-fill, minmax(var(--t-tiles-min-width), 1fr))` — the sanitizer rejects nested `var()` inside `minmax()` at the property consumer, but accepts arbitrary tokens inside a custom-property declaration.

One inline style per grid is cheaper than per-tile, and per-section overrides are still possible by passing different values to multiple `render` calls.

Suggested combinations:

| Use case | `aspectRatio` | `tileMinWidth` |
|---|---|---|
| Square crops (default) | `'1 / 1'` | `'120px'` |
| Item renders (helmets, weapons, drives) | `'3 / 4'` (portrait) | `'120px'` |
| Vehicle hero shots | `'16 / 9'` or `'3 / 2'` (landscape) | `'200px'` or wider |

## CSS hooks

Styles live in `styles.css` (loaded via `templatestyles`). Skin or caller-side overrides can target:

| Class | Purpose |
|---|---|
| `t-tiles` | Grid container. Holds the `--t-tiles-aspect` and `--t-tiles-columns` custom properties; the latter holds the full `repeat(auto-fill, minmax(<min>, 1fr))` value. |
| `t-tiles__tile` | One tile. `position: relative` anchor for the fakelink. |
| `t-tiles__link` | Transparent absolutely-positioned wikilink wrapper. Makes the whole tile clickable around MediaWiki's sanitizer. |
| `t-tiles__image` | Image container with `aspect-ratio` driven by `--t-tiles-aspect`. |
| `t-tiles__label` | Bottom label group. |
| `t-tiles__primary` | Prominent line. Single-line + ellipsis. |
| `t-tiles__secondary` | Small kicker above primary. Single-line + ellipsis. |

## Architecture

```
Tiles/
├── Tiles.lua    # render(props), per-tile builder
└── styles.css   # Grid + tile layout, hover transitions
```
