# Module:MeterBar

Renders a single **labeled meter bar**: a label/value header (label left, value right) above a fill track scaled against a max. It is the single-bar, fill sibling of [Module:RangeBar](https://starcitizen.tools/Module:RangeBar) (which highlights a band on a gradient axis); both share the same header style.

Because each call renders exactly one bar, you compose several as separate infobox items and let the item list own the spacing — which keeps every row in a section spaced identically, rather than a multi-bar module managing its own internal gap. The first consumer is the radiation display in [Module:Entity/Facet/Environment](https://starcitizen.tools/Module:Entity/Facet/Environment).

The fill colour defaults to a single accent (`--color-progressive`); the value text is always `--color-base`. All visuals use Citizen design tokens, so the output is theme-aware.

## Usage

```lua
local MeterBar = require( 'Module:MeterBar' )

local html = MeterBar.render( {
	label = 'Radiation protection',
	value = 26800,
	max = 52800,
	text = '26,800 REM',
} )
```

`render` returns a string: a `<templatestyles>` tag for `Module:MeterBar/styles.css` followed by the bar markup. It is ready to drop into any wikitext or infobox section `content`.

## API

### `p.render( data )`

Returns the meter bar HTML.

| Field | Type | Description |
|---|---|---|
| `label` | `string` | Header label, shown top-left. |
| `value` | `number` | The numeric value; drives the fill and, by default, the displayed text. |
| `max` | `number` | Fill denominator. Defaults to `100`. |
| `text` | `string` | Header value text, shown top-right (e.g. `52,800 REM`). Defaults to the value. |
| `color` | `string` | CSS colour for the fill (a token string). Defaults to `--color-progressive`. |
| `title` | `string` | Full name surfaced as a hover tooltip on the bar. Optional. |

The fill is clamped to 0–100% of `value / max`.

## Styles

The layout lives in [Module:MeterBar/styles.css](https://starcitizen.tools/Module:MeterBar/styles.css): a label/value header (`--font-size-small`, label `--color-subtle` / `--font-weight-medium`, value `--color-base`) above a 4px track (`--color-surface-3`) holding the fill. The fill width and colour come from CSS custom properties (`--t-meter-bar-fill-width`, `--t-meter-bar-fill-color`) the module sets; the stylesheet consumes them.

## Architecture

```
MeterBar/
├── MeterBar.lua    # header + fill layout
├── styles.css      # header, track, and fill styles
└── testcases.lua   # unit tests for the pure helpers
```
