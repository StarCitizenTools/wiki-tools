# Module:RangeBar

A horizontal range bar: a label/value header above a fixed gradient axis with the active value band highlighted vividly, the rest dimmed and gap-separated so it reads as "this slice of the whole range," plus an optional reference tick marking a notable value (such as 0) as a bare line. The header matches [Module:MeterBar](https://starcitizen.tools/Module:MeterBar) so range bars and meter bars sit together consistently.

Required by [Module:Entity/Facet/Environment](https://starcitizen.tools/Module:Entity/Facet/Environment) and [Module:Entity/Vehicle/Stats/PercentileBar](https://starcitizen.tools/Module:Entity/Vehicle/Stats/PercentileBar); not invoked from templates.

## For module editors

### API

`p.render(data)` returns `<templatestyles>` + the bar HTML, or `nil` when a bound, `domain`, or `stops` is missing, or `domain.max` does not exceed `domain.min`.

| Field | Type | Description |
|---|---|---|
| `label` / `value` | `string` | Header label (top-left) / value (top-right). Must be a string; a non-string is silently dropped, not stringified. Header omitted when both are empty. |
| `min`, `max` | `number` | Active band bounds, domain units. Required; swapped if `min > max`. |
| `domain` | `{ min, max }` | The fixed axis extent. Required. |
| `stops` | `{ {at, color}, … }` | Gradient colour stops, ascending by `at`. At least two. Required. Each `color` must be a `#rrggbb` hex string: only the first six hex digits are read (an alpha suffix is dropped silently), and a shorter or non-hex value throws a Lua error the moment two stops need interpolating. |
| `tick` | `number` | Reference value drawn as a bare vertical line (no label). Optional. |
| `tickColor` | `string` | Tick line colour. Defaults to a dark translucent line. |
| `gap` | `number` | Gap (% of bar width) separating the band from the dim flanks. Defaults to `1.2`. |

### Gotchas

Values outside the domain clamp to the bar edges. Each segment's gradient is built across its own sub-range and includes any stop falling inside it, so the colour tracks the palette accurately even when the band spans a stop. The gradient is fixed hex, not Citizen theme tokens, by design, so a chosen palette looks identical in light and dark themes; only the header text uses theme tokens. Segment positions/gradients and the tick ride CSS custom properties the module sets; the stylesheet consumes them.
