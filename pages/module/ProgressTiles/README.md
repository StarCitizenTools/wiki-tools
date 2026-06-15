# Module:ProgressTiles

A reusable row of square ring-gauge tiles. Each tile draws a value as a progress arc around a square frame (scaled against `max`), with the value in the centre and an optional label below. Domain-agnostic: it knows nothing about what the numbers mean — the caller supplies the value, label, and arc colour per tile, so it serves armour resistances, ship stats, ratings, or any set of related values.

The renderer is intentionally "dumb" (it draws what it's given). The optional `heatmap` helper maps a value to a Citizen status token (error / warning / success) for callers that want a weak→strong colour signal; others pass a fixed accent or per-tile colours. All visuals use Citizen design tokens, so output is theme-aware.

## Usage

```lua
local ProgressTiles = require( 'Module:ProgressTiles' )

local html = ProgressTiles.render( {
    max = 100,
    tiles = {
        { value = 40, label = 'PHY', title = 'Physical', color = ProgressTiles.heatmap( 40, 100 ) },
        { value = 60, label = 'STN', title = 'Stun',     color = 'var(--color-progressive)' },
    },
} )
```

`render` returns a string: a `<templatestyles>` tag for `Module:ProgressTiles/styles.css` followed by the tile row. Concatenate it into your module's output, or use it as the `content` of an infobox section.

## API

### `p.render( data )`

Builds and returns the tile row.

#### `data`

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `tiles` | `ProgressTile[]` | Yes | | The tiles to render, left to right. |
| `max` | `number` | No | `100` | Fill denominator shared by every tile. |

#### `ProgressTile`

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `value` | `number` | Yes | | Drives the fill (`value / max`) and, by default, the displayed text. |
| `label` | `string` | No | | Short label shown below the tile. |
| `title` | `string` | No | | Full name surfaced as a hover tooltip. |
| `color` | `string` | No | `var(--color-progressive)` | CSS colour for the arc. Any valid CSS colour. The value text is always `--color-base` for legibility. |
| `text` | `string` | No | the value | Overrides the displayed text (e.g. `"40%"`). |

### `p.heatmap( value, max, thresholds )`

Optional helper. Maps a value to a Citizen status colour token: weak → `--color-error`, mid → `--color-warning`, strong → `--color-success`. Banding is by fraction of `max` (default thirds); pass `thresholds` = `{ weakMax, midMax }` as fractions to retune (e.g. `{ 0.2, 0.45 }`).

## Styles

CSS lives in [Module:ProgressTiles/styles.css](https://starcitizen.tools/Module:ProgressTiles/styles.css) and is bundled automatically. It uses Citizen skin design tokens (`--color-*`, `--space-*`, `--font-size-*`, `--font-weight-*`, `--border-radius-*`) so it inherits the site theme. The per-tile arc (a conic-gradient of colour + fill) comes from a CSS custom property (`--t-progress-tiles-ring`) the module sets; the stylesheet consumes it. The value text is `--color-base`.

## Architecture

```
ProgressTiles/
├── ProgressTiles.lua   # render() + heatmap() helper
└── styles.css          # tile layout (flex row, square gauge, ring, value, label)
```
