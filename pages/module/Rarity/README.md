# Module:Rarity

Renders an item rarity tier — Common, Uncommon, Rare, Epic, or Legendary — as a coloured badge via [Module:BadgeLua](https://starcitizen.tools/Module:BadgeLua). Reusable from other modules and from wikitext / `{{Rarity}}`, so the same chip can sit in an infobox, a table cell, or inline in prose.

The lookup is case-insensitive and trims whitespace; an empty or unknown rarity produces nothing (nil from `badge`, an empty string from `main`), so callers can pass the raw API value without guarding it.

## Usage

```lua
local Rarity = require( 'Module:Rarity' )
local html = Rarity.badge( 'Rare' )   -- nil for unknown / empty
```

From wikitext:

```wikitext
{{#invoke:Rarity|main|Epic}}
{{Rarity|Legendary}}
```

`badge` returns a string: a `<templatestyles>` tag for `Module:Rarity/styles.css` followed by the BadgeLua badge markup.

## API

### `p.badge( rarity )`

Returns the rarity badge for a tier string, or `nil` for an empty / unknown value.

| Parameter | Type | Description |
|---|---|---|
| `rarity` | `string` | Rarity tier (any case): `Common`, `Uncommon`, `Rare`, `Epic`, `Legendary`. |

### `p.main( frame )`

Wikitext entry point. Reads the rarity from the first positional argument or `rarity=` (via [Module:Arguments](https://starcitizen.tools/Module:Arguments), so `{{Rarity|Rare}}` works through the template). Returns an empty string for an unknown rarity.

## Styles

The palette lives in [Module:Rarity/styles.css](https://starcitizen.tools/Module:Rarity/styles.css): hardcoded and theme-aware via `light-dark( oklch(), oklch() )`, tinted (strong text + subtle background + mid border) to match the contrast of the BadgeLua `success` / `warning` variants. Each tier uses a `.t-badge.rarity-badge--<tier>` selector so it overrides the BadgeLua base regardless of stylesheet order.

## Architecture

```
Rarity/
├── Rarity.lua    # tier → label + class mapping, delegates rendering to BadgeLua
└── styles.css    # per-tier colour palette (theme-aware oklch)
```
