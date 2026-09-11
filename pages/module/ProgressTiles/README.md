# Module:ProgressTiles

A reusable row of square ring-gauge tiles: each tile draws a value as a progress arc around a square frame (scaled against `max`), with the value in the centre and an optional label below. Domain-agnostic: the caller supplies the value, label, and arc colour per tile, so it serves armour resistances, ship stats, ratings, or any set of related values.

Required by [Module:Entity/Facet/Armor](https://starcitizen.tools/Module:Entity/Facet/Armor), [Module:Entity/Vehicle/Stats](https://starcitizen.tools/Module:Entity/Vehicle/Stats), and [Module:Entity/Vehicle/Stats/Overview](https://starcitizen.tools/Module:Entity/Vehicle/Stats/Overview); not invoked from templates.

## For module editors

### API

`p.render(data)` returns `<templatestyles>` + the tile row.

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `tiles` | `ProgressTile[]` | Yes | | The tiles to render, left to right. |
| `max` | `number` | No | `100` | Fill denominator shared by every tile. |

**ProgressTile**: `value` (required, drives the arc and, by default, the displayed text), `label?` (below the tile), `title?` (hover tooltip), `color?` (default `--color-progressive`; the value text stays `--color-base` regardless), `text?` (overrides the displayed text), `tooltip?` (rich HTML content; wraps the gauge with [Module:FloatingUI](https://starcitizen.tools/Module:FloatingUI) when non-empty).

`p.heatmap(value, max, thresholds?)`: maps a value to a Citizen status colour token, weak `--color-error` / mid `--color-warning` / strong `--color-success`, banded by fraction of `max` (default thirds; `thresholds = { weakMax, midMax }` as fractions retunes it). `max` here is its own parameter, defaulting to `100` independently of any `render` call's `data.max`.

### Gotchas

[Module:FloatingUI](https://starcitizen.tools/Module:FloatingUI) is required lazily, only when a tile sets `tooltip`, so the common tooltip-less path carries no dependency on it; `render` also emits `FloatingUI.load(frame)` in that case, which is required once per page for the tooltip to actually float.

### Styles

The per-tile arc (a conic-gradient of colour + fill) rides a CSS custom property (`--t-progress-tiles-ring`) the module sets; [Module:ProgressTiles/styles.css](https://starcitizen.tools/Module:ProgressTiles/styles.css) consumes it and is bundled automatically.
