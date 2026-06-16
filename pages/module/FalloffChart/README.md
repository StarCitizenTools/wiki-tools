# Module:FalloffChart

Renders a **filled-area chart** of a piecewise curve: a label/value header above a
fixed-height plot whose area is clipped to the curve. The y-axis labels sit in a
gutter to the left of the plot (auto-sized to the longest label, right-aligned and
flush to the container edge); the distance labels sit in an x-axis row beneath the
plot, placed to avoid overlap. Optional vertical markers, a horizontal floor
reference, a reach marker, and a caption complete it. It is the 2D sibling of
[Module:MeterBar](https://starcitizen.tools/Module:MeterBar) and
[Module:RangeBar](https://starcitizen.tools/Module:RangeBar); the header style
matches both so charts and bars sit together in an infobox.

Domain-agnostic: the caller supplies the curve vertices and axis extents. The
first consumer is the weapon damage-falloff display in
[Module:Entity/Facet/DamageFalloff](https://starcitizen.tools/Module:Entity/Facet/DamageFalloff).

The filled area and its top stroke are drawn with `clip-path` polygons (built from
the vertices) stashed in custom properties and consumed bare (TemplateStyles-safe);
all visuals use Citizen design tokens, so the output is theme-aware. The curve
stroke paints above the guideline layer (floor, gridlines, ticks).

## Usage

```lua
local FalloffChart = require( 'Module:FalloffChart' )

local html = FalloffChart.render( {
	points = { { x = 0, y = 12 }, { x = 40, y = 12 }, { x = 80, y = 10 }, { x = 330, y = 10 } },
	domain = 330,
	yMax = 50,
	label = 'Damage falloff',
	value = '12 → 10',
	markers = { { at = 40, label = '40 m' }, { at = 80, label = '80 m' } },
	floor = 10,
	yTicks = { { at = 0, label = '0' }, { at = 25, label = '25' }, { at = 50, label = '50' } },
	scaleMax = '330 m',
	dataset = { ['falloff-alpha'] = 12, ['falloff-min-dist'] = 40 },
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
| `markers` | `{ {at, label}, … }` | Vertical tick lines at `x = at`; `label` (optional) is shown in the x-axis row. |
| `floor` | `number` | Horizontal reference line at this y value. Optional. |
| `yTicks` | `{ {at, label}, … }` | y-axis labels (left gutter) + gridlines for interior ticks. Optional. |
| `reach` | `{ at, label }` | Reach marker — a dashed line where the projectile dies before the scale ends. Optional. |
| `scaleMax` | `string` | Scale-max label at the right end of the x-axis row. Dropped automatically when a marker label already sits in the right end-zone. Optional. |
| `caption` | `string` | Sub-caption line below the chart. Optional. |
| `dataset` | `{ [key] = value, … }` | `data-*` attributes (key without the `data-` prefix) on the chart element, for optional client-side enhancement. Optional. |

The area is clipped to the polygon through the vertices down to the baseline; a
curve that ends before the right edge leaves the remaining width empty.

## x-axis label placement

Distance labels (from `markers` + `reach` + `scaleMax`) are placed to avoid
overlap: a label in the right end-zone (≥ 80%) right-aligns on its tick (and the
`scaleMax`, which would sit beside it, is dropped); a label closer than ~16% to its
left neighbour left-aligns on its tick (growing clear); a label at the left edge
anchors there; the rest centre on their tick. `0` is implicit at the left edge.
