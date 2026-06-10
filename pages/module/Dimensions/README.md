# Module:Dimensions

Renders an isometric 3D diagram of an object's bounding box at honest scale:
measurement lines with end ticks on each axis, an optional reference object
(e.g. a human) standing on the same ground plane, and a footer bar with the
mass and the reference legend. Hovering the diagram rotates it to a top-down
plan view (pointer devices only; touch gets the static isometric view). The rotation animation is disabled for users with reduced-motion preferences.

The module emits a `<div class="t-dimensions">` with bundled TemplateStyles.
`transform-style: preserve-3d` is set inline from Lua because the
TemplateStyles sanitizer rejects it. CSS lives in [[Module:Dimensions/styles.css]] and is injected automatically.

## Usage

From Lua:

```lua
local dimensions = require( 'Module:Dimensions' )

local html = dimensions._main( {
    length = 18,
    width = 8,
    height = 4,
    mass = 25172,
    referenceType = 'human',
} )
-- html is nil when length/width/height are missing, non-numeric or <= 0
```

`_main` takes an optional second `frame` argument; when omitted it falls back to `mw.getCurrentFrame()`.

From wikitext:

```wikitext
{{#invoke:Dimensions|main|length=18|width=8|height=4|mass=25172|referenceType=human}}
```

## Parameters

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `length` | number (m) | yes | Object length; must be > 0 |
| `width` | number (m) | yes | Object width; must be > 0 |
| `height` | number (m) | yes | Object height; must be > 0 |
| `lengthAlt` | number (m) | no | Alternate length (e.g. retracted); shown as a subtle parenthetical, dropped when equal to `length` |
| `widthAlt` | number (m) | no | Alternate width |
| `heightAlt` | number (m) | no | Alternate height |
| `mass` | number (kg) | no | Shown in the footer bar, not on the geometry |
| `referenceType` | string | no | Key into the reference table; currently `human` (0.3 × 0.5 × 1.8 m) or `banana` (0.05 × 0.05 × 0.2 m, standing upright). Unknown values render no reference |

## Machine-readable output

The root element carries raw SI values (unformatted, dot-decimal):

- `data-length`, `data-width`, `data-height` — always
- `data-length-alt`, `data-width-alt`, `data-height-alt` — when the alternate renders
- `data-mass` — when mass was given
- `data-reference` — the reference type key, when a reference renders

A visually-hidden text summary of all values is included for screen readers;
the visual scene itself is `aria-hidden`.

## Adding a reference type

Add one entry to `REFERENCE_TYPES` in the module (dimensions in metres plus
a `legend` string). The cuboid, ground placement, dimension-line clearance
and footer legend all derive from it automatically.

```lua
REFERENCE_TYPES.crate = {
    length = 1.25,
    width = 1.25,
    height = 1.25,
    legend = 'Cargo crate · 1 SCU',
}
```

The root element also gets a `t-dimensions--ref-<type>` modifier class. To
recolor a type, override the reference color trio in the styles
(`--t-dimensions-ref-color`, `-light`, `-dark`); the cuboid faces and the
legend swatch both consume them, so one block recolors everything (see the
banana's yellow).

After extending the table, update [[Module:Dimensions/testcases]] accordingly.

## Consumers

`Module:Vehicle` and `Module:Item` call `_main` directly. The diagram falls
back to nothing (nil) on invalid input, letting callers render their plain
dimension tables instead.

## Architecture

```
Dimensions/
├── Dimensions.lua   # Module logic (validation, formatting, HTML assembly)
├── styles.css       # TemplateStyles (isometric geometry, lines, labels, footer)
└── testcases.lua    # ScribuntoUnit tests for the logic layer
```
