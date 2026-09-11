# Module:Rarity

Renders an item rarity tier (Common, Uncommon, Rare, Epic, or Legendary) as a coloured [Module:BadgeLua](https://starcitizen.tools/Module:BadgeLua) badge. The lookup is case-insensitive and trims whitespace; an empty or unknown rarity produces nothing (`nil` from `badge`, an empty string from `main`), so callers can pass the raw API value without guarding it.

Editors use this through `{{Rarity}}` (`{{#invoke:Rarity|main}}`, not mirrored in this repository). Also required directly by [Module:Entity/Infobox](https://starcitizen.tools/Module:Entity/Infobox).

## For module editors

### API

`p.badge(rarity)` returns a string (`<templatestyles>` + the BadgeLua markup) for a tier name in any case, or `nil` for an empty/unknown value.

`p.main(frame)` is the `#invoke` entry point: reads the rarity from the first positional argument or `rarity=` (via [Module:Arguments](https://starcitizen.tools/Module:Arguments)), returning an empty string for an unknown rarity.

```lua
local Rarity = require( 'Module:Rarity' )
Rarity.badge( 'Rare' )   -- nil for unknown / empty
```

### Styles

[Module:Rarity/styles.css](https://starcitizen.tools/Module:Rarity/styles.css): hardcoded, theme-aware via `light-dark(oklch(), oklch())`, tinted (strong text, subtle background, mid border) to match the contrast of BadgeLua's `success`/`warning` variants. Each tier uses a `.t-badge.rarity-badge--<tier>` selector so it outweighs the BadgeLua base regardless of stylesheet order.
