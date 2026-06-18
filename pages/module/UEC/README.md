# Module:UEC

Formats an in-game money value in [United Earth Credit](https://starcitizen.tools/United_Earth_Credit) (UEC): the UEC glyph followed by the amount with thousands separators. Built on [Module:IconText](https://starcitizen.tools/Module:IconText), with the icon in mask mode so it recolors with the surrounding text.

## Requirements

- [Module:IconText](https://starcitizen.tools/Module:IconText) — renders the icon and amount.
- [Module:Arguments](https://starcitizen.tools/Module:Arguments) — for the `#invoke` entry point.

## Usage

From wikitext, via the [Template:UEC](https://starcitizen.tools/Template:UEC) wrapper:

```wikitext
{{UEC|15000}}
```

Or call the module directly with `#invoke`, passing the amount as the first positional argument:

```wikitext
{{#invoke:UEC|main|15000}}
```

From another Lua module via the `_main` entry point:

```lua
local uec = require( 'Module:UEC' )

local html = uec._main( 15000 )
```

`_main` accepts a number or numeric string and returns the rendered string (the UEC icon followed by the formatted amount). It raises an error if the value is not numeric. The amount is formatted with the wiki content language's digit grouping, so `15000` becomes `15,000`.

For a price range, the `_range` entry point renders the glyph once followed by `min–max` (or a single value when the bounds are equal):

```lua
local uec = require( 'Module:UEC' )

local html = uec._range( 16160, 17010 ) -- → glyph + "16,160–17,010"
```

`_range` is meant for sibling modules — for example [Module:Entity/Availability](https://starcitizen.tools/Module:Entity/Availability) formats UEX price ranges with it. Both bounds must be numeric, otherwise it raises an error.

## Data Reference

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `1` | `number` | Yes | | The UEC amount, as a number or numeric string. Passed as the sole argument to `_main`. Rendered with thousands separators. |

## Examples

### Basic amount

```wikitext
{{#invoke:UEC|main|15000}}
```

### Large amount

```wikitext
{{#invoke:UEC|main|2750000}}
```

## Architecture

```
UEC/
└── UEC.lua    # parse + format the amount, delegating rendering to Module:IconText
```
