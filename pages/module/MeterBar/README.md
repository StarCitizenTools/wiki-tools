# Module:MeterBar

A single labeled horizontal meter bar: a label/value header above a fill track scaled against a max. The single-bar, fill sibling of [Module:RangeBar](https://starcitizen.tools/Module:RangeBar) (which highlights a band on a gradient axis); both share the same header style, so compose several as separate infobox items and let the item list own the spacing.

Required by [Module:Entity/Facet/Environment](https://starcitizen.tools/Module:Entity/Facet/Environment) and [Module:Entity/Location/StarSystem](https://starcitizen.tools/Module:Entity/Location/StarSystem); not invoked from templates.

## For module editors

### API

`p.render(data)` returns `<templatestyles>` + the bar HTML.

| Field | Type | Description |
|---|---|---|
| `label` | `string` | Header label, top-left. Optional. |
| `value` | `number` | Drives the fill and, by default, the displayed text. |
| `max` | `number` | Fill denominator. Defaults to `100`. |
| `text` | `string` | Header value text, top-right (e.g. `52,800 REM`). Defaults to the value. |
| `color` | `string` | CSS colour for the fill (a token string). Defaults to `--color-progressive`. |
| `title` | `string` | Hover tooltip on the bar. Optional. |

### Gotchas

The fill is clamped to 0-100% of `value / max`; a non-positive `max` yields an empty fill rather than an error. Fill width and colour ride CSS custom properties (`--t-meter-bar-fill-width`, `--t-meter-bar-fill-color`) the module sets; the value text colour is always `--color-base`, not the fill colour.
