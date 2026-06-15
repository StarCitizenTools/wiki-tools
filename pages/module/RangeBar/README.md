# Module:RangeBar

Renders a horizontal **range bar**: a label/value header above a fixed gradient axis with the active value band highlighted. The band is drawn vividly; the rest of the axis is dimmed and gap-separated, so the bar reads as "this slice of the whole range." An optional reference tick marks a notable value (such as 0) as a bare line.

The header (label on the left, value on the right) matches [Module:MeterBar](https://starcitizen.tools/Module:MeterBar) so range bars and meter bars sit together consistently — compose each as its own infobox item and the item list owns the spacing.

It is domain-agnostic — the caller supplies the header text, the axis extent, the gradient colour stops (in domain units), and the band — so the same primitive serves temperature ranges, operating bands, tolerances, or any "sub-range of a known scale" value. The first consumer is the armor/clothing temperature display in [Module:Entity/Facet/Environment](https://starcitizen.tools/Module:Entity/Facet/Environment).

The gradient is fixed hex (not theme tokens) by design, so a chosen palette looks identical in light and dark themes. The header text uses Citizen design tokens and stays theme-aware.

## Usage

```lua
local RangeBar = require( 'Module:RangeBar' )

local html = RangeBar.render( {
	label = 'Temperature',
	value = '−75 – 105 °C',
	min = -75,
	max = 105,
	domain = { min = -250, max = 250 },
	stops = {
		{ at = -250, color = '#2bd0e6' },
		{ at =    0, color = '#eef3f6' },
		{ at =  250, color = '#ff5630' },
	},
	tick = 0,
} )
```

`render` returns a string: a `<templatestyles>` tag for `Module:RangeBar/styles.css` followed by the bar markup. It is ready to drop into any wikitext or infobox section `content`.

## API

### `p.render( data )`

Returns the range bar HTML, or `nil` when the inputs are unusable (a missing bound, domain, or stop list, or an empty domain).

| Field | Type | Description |
|---|---|---|
| `label` | `string` | Header label, shown top-left (e.g. `Temperature`). Optional; the header is omitted when both `label` and `value` are empty. |
| `value` | `string` | Header value, shown top-right (e.g. the formatted range). Optional. |
| `min` | `number` | Active band lower bound, in domain units. Required. |
| `max` | `number` | Active band upper bound, in domain units. Required. (Swapped if `min > max`.) |
| `domain` | `table` | `{ min, max }` — the fixed axis extent. Required; `max` must exceed `min`. |
| `stops` | `table[]` | Gradient colour stops, ascending by `at`: `{ { at = <value>, color = '#rrggbb' }, ... }` (at least two). Required. |
| `tick` | `number` | Optional reference value drawn as a bare vertical line (no label). |
| `tickColor` | `string` | CSS colour for the tick line. Defaults to a dark translucent line, which reads against the light midtones reference points usually sit on. |
| `gap` | `number` | Gap, in percent of bar width, separating the band from the dim flanks. Defaults to `1.2`. |

Values outside the domain clamp to the bar edges. The gradient for each segment is built across its own sub-range and includes any stop that falls inside it, so the colour tracks the palette accurately even when the band spans a stop.

## Styles

The layout lives in [Module:RangeBar/styles.css](https://starcitizen.tools/Module:RangeBar/styles.css): a label/value header (`--font-size-small`, label `--color-subtle` / `--font-weight-medium`, value `--color-base`) above a 6px track with a 2px radius holding the gradient segments and a 1px tick line. Segment positions/gradients and the tick come from CSS custom properties the module sets; the stylesheet consumes them.

## Architecture

```
RangeBar/
├── RangeBar.lua    # gradient interpolation + header/bar layout
├── styles.css      # header, track, segment, and tick styles
└── testcases.lua   # unit tests for the pure helpers
```
