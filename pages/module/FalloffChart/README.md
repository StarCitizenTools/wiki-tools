# Module:FalloffChart

Renders a **filled-area chart** of a piecewise curve: a label/value header above a
fixed-height plot whose area is clipped to the curve, with optional vertical
markers, a horizontal floor reference, axis end-labels, and a caption. It is the
2D sibling of [Module:MeterBar](https://starcitizen.tools/Module:MeterBar) and
[Module:RangeBar](https://starcitizen.tools/Module:RangeBar); the header style
matches both so charts and bars sit together in an infobox.

Domain-agnostic: the caller supplies the curve vertices and axis extents. The
first consumer is the weapon damage-falloff display in
[Module:Entity/Facet/DamageFalloff](https://starcitizen.tools/Module:Entity/Facet/DamageFalloff).

The filled area is drawn with a `clip-path` polygon (built from the vertices) and
all visuals use Citizen design tokens, so the output is theme-aware.

## Usage

```lua
local FalloffChart = require( 'Module:FalloffChart' )

local html = FalloffChart.render( {
	points = { { x = 0, y = 12 }, { x = 40, y = 12 }, { x = 80, y = 10 }, { x = 100, y = 10 } },
	domain = 100,
	yMax = 12,
	label = 'Damage falloff',
	value = '12 → 10',
	markers = { { at = 40, label = '40 m' }, { at = 80, label = 'floor 80 m' } },
	floor = 10,
	axisMin = '0 m',
	axisMax = '100 m',
	caption = 'Full ≤ 40 m · floor 10 at 80 m',
} )
```

`render` returns a string: a `<templatestyles>` tag for `Module:FalloffChart/styles.css`
followed by the chart markup, ready to drop into an infobox section `content`.
Returns `nil` when the input is unusable (fewer than two points, or a non-positive
`domain`/`yMax`).

## API

### `p.render( data )`

| Field | Type | Description |
|---|---|---|
| `points` | `{ {x, y}, … }` | Curve vertices, ascending by `x` (domain units). At least two. |
| `domain` | `number` | x-axis maximum (minimum is 0). |
| `yMax` | `number` | y-axis maximum (minimum is 0). |
| `label` | `string` | Header label, top-left. Optional. |
| `value` | `string` | Header value, top-right. Optional. |
| `markers` | `{ {at, label}, … }` | Vertical ticks at `x = at`. Optional. |
| `floor` | `number` | Horizontal reference line at this y value. Optional. |
| `axisMin` / `axisMax` | `string` | Axis end labels. Optional. |
| `caption` | `string` | Sub-caption line. Optional. |

The area is clipped to the polygon through the vertices down to the baseline.
