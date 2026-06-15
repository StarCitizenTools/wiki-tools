# Module:RangeBar

Renders a horizontal **range bar**: an active value band highlighted on a fixed gradient axis. The band is drawn vividly; the rest of the axis is dimmed and gap-separated, so the bar reads as "this slice of the whole range." An optional reference tick marks a notable value (such as 0).

The two band-edge labels sit just *outside* the band (the lower value's right edge at the band start, the upper value's left edge at the band end), so they never collide however narrow the band; each clamps to the bar edge if it would overflow. The tick gets its own label only when it has room to clear both edge labels.

It is domain-agnostic — the caller supplies the axis extent, the gradient colour stops (in domain units), the band, and a label formatter — so the same primitive serves temperature ranges, operating bands, tolerances, or any "sub-range of a known scale" value. The first consumer is the armor/clothing temperature display in [Module:Entity/Facet/Environment](https://starcitizen.tools/Module:Entity/Facet/Environment).

The gradient is fixed hex (not theme tokens) by design, so a chosen palette looks identical in light and dark themes. The labels use Citizen design tokens and stay theme-aware.

## Usage

```lua
local RangeBar = require( 'Module:RangeBar' )

local html = RangeBar.render( {
	min = -77,
	max = 107,
	domain = { min = -250, max = 250 },
	stops = {
		{ at = -250, color = '#2bd0e6' },
		{ at =    0, color = '#eef3f6' },
		{ at =  250, color = '#ff5630' },
	},
	tick = 0,
	format = function ( v )
		return ( v < 0 and '−' .. -v or v ) .. ' °C'
	end,
	formatTick = function ( v )
		return v < 0 and '−' .. -v or tostring( v )
	end,
} )
```

`render` returns a string: a `<templatestyles>` tag for `Module:RangeBar/styles.css` followed by the bar markup. It is ready to drop into any wikitext or infobox section `content`.

## API

### `p.render( data )`

Returns the range bar HTML, or `nil` when the inputs are unusable (a missing bound, domain, or stop list, or an empty domain).

| Field | Type | Description |
|---|---|---|
| `min` | `number` | Active band lower bound, in domain units. Required. |
| `max` | `number` | Active band upper bound, in domain units. Required. (Swapped if `min > max`.) |
| `domain` | `table` | `{ min, max }` — the fixed axis extent. Required; `max` must exceed `min`. |
| `stops` | `table[]` | Gradient colour stops, ascending by `at`: `{ { at = <value>, color = '#rrggbb' }, ... }` (at least two). Required. |
| `tick` | `number` | Optional reference value drawn as a vertical line. Its label is shown only when it clears both band-edge labels and does not coincide with an endpoint; the line itself is always drawn. |
| `tickColor` | `string` | CSS colour for the tick line. Defaults to a dark translucent line, which reads against the light midtones reference points usually sit on. |
| `gap` | `number` | Gap, in percent of bar width, separating the band from the dim flanks. Defaults to `1.2`. |
| `format` | `function` | `function( value ) -> string` applied to the band-edge labels. Defaults to `tostring`. |
| `formatTick` | `function` | `function( value ) -> string` applied to the tick label. Defaults to `format`. Use it to keep the tick terse (e.g. `0` rather than `0 °C`). |

Values outside the domain clamp to the bar edges. The gradient for each segment is built across its own sub-range and includes any stop that falls inside it, so the colour tracks the palette accurately even when the band spans a stop.

## Styles

The layout lives in [Module:RangeBar/styles.css](https://starcitizen.tools/Module:RangeBar/styles.css): a 6px track with a 2px radius, absolutely-positioned gradient segments, a 1px tick, and a label row using `--font-size-small` / `--line-height-small` / `--color-emphasized` (band edges) and `--color-subtle` (tick). Segment gradients, the tick colour, and the per-label horizontal anchoring are set inline by the module.

## Architecture

```
RangeBar/
├── RangeBar.lua    # gradient interpolation + bar/label layout
├── styles.css      # track, segment, tick, and label styles
└── testcases.lua   # unit tests for the pure helpers
```
