# Module:FalloffChart

A filled-area chart of a piecewise curve (e.g. weapon damage over distance): a label/value header above a fixed-height plot, y-axis labels in a left gutter, and distance labels in an x-axis row beneath the plot. It is the 2D sibling of [Module:MeterBar](https://starcitizen.tools/Module:MeterBar) and [Module:RangeBar](https://starcitizen.tools/Module:RangeBar); the header style matches both so charts and bars sit together in an infobox.

Required by [Module:Entity/Facet/DamageFalloff](https://starcitizen.tools/Module:Entity/Facet/DamageFalloff); not invoked from templates.

## For module editors

### API

`p.render(data)` returns `<templatestyles>` + the chart markup, or `nil` when `points` has fewer than two entries or `domain`/`yMax` is missing or not positive.

| Field | Type | Description |
|---|---|---|
| `points` | `{ {x, y}, … }` | Curve vertices, ascending by `x`. At least two. |
| `domain` | `number` | x-axis maximum (minimum is 0). |
| `yMax` | `number` | y-axis maximum (minimum is 0). |
| `label` / `value` | `string` | Header label (top-left) / value (top-right). Optional. |
| `markers` | `{ {at, label}, … }` | Vertical tick lines at `x = at`; `label` (optional) shown in the x-axis row. |
| `floor` | `number` | Horizontal reference line at this y value. Optional. |
| `yTicks` | `{ {at, label}, … }` | y-axis labels (left gutter) + gridlines for interior ticks. Gutter width tracks the longest label, shifting the x-axis row's left margin to match. Optional. |
| `reach` | `{ at, label }` | Dashed reach marker: where the projectile dies before the scale ends. Optional. |
| `scaleMax` | `string` | Scale-max label at the right end of the x-axis row; dropped when a label already sits in the end-zone beside it. Optional. |
| `caption` | `string` | Sub-caption line below the chart. Optional. |
| `dataset` | `{ [key] = value, … }` | `data-*` attributes (key without the `data-` prefix) on the chart element, for optional client-side enhancement. Optional. |

### Gotchas

- The filled area is clipped to the polygon through the vertices down to the baseline at the *last point's* x, not a hard 100%: a curve that ends before the right edge (range- or scale-clipped) leaves the remaining width empty rather than closing with a dead triangle.
- x-axis labels (from `markers` + `reach` + `scaleMax`) place themselves to avoid overlap: one at or past 80% of the axis right-aligns on its tick (and `scaleMax`, which would sit beside it, is dropped); one closer than ~16% to its left neighbour left-aligns on its tick (growing clear); one at or near the left edge anchors there; the rest centre on their tick.
- The filled area and its top stroke are `clip-path: polygon(...)` shapes computed in Lua from the vertices (a shape CSS alone cannot derive), stashed whole in a custom property, and consumed as a bare `clip-path: var(...)` value, which passes the TemplateStyles sanitizer. The curve stroke is drawn last so it paints above the guideline layer (floor, gridlines, ticks).
