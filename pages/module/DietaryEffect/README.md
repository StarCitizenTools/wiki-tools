# Module:DietaryEffect

Classifies the dietary effects carried by food, drink, and edible commodities and renders them as coloured [Module:BadgeLua](https://starcitizen.tools/Module:BadgeLua) badges:

- **Beneficial** effects → green badge with an up arrow (`CdxIconArrowUp.svg`)
- **Detrimental** effects → red badge with a down arrow (`CdxIconArrowDown.svg`)
- **`None`** and anything unrecognised → neutral grey badge, no arrow

It is the single source of truth for effect polarity and the correct effect page, shared by the consumable infobox ([Module:Entity/Facet/Consumable](https://starcitizen.tools/Module:Entity/Facet/Consumable)) and the dietary-effect data tables.

## Why a lookup table

The API sends effect values whose spelling and casing do not always match their wiki page, and two stray redirects point at the wrong page:

- `Cognitive Boosting` → [[Cognitive boosting]], `Cognitive Impairment` → [[Cognitive impairing]]
- `Hyper-Metabolic` / `Hypermetabolic` → [[Hyper-metabolic]]; `Hypo-Metabolic` / `Hypometabolic` → [[Hypo-metabolic]]
- `Healing` redirects to [[Medical]] (wrong); the dietary effect lives at [[Healing (dietary effect)]]
- `Hypometabolic` redirects to [[Hyper-metabolic]] (wrong)

Lookups are normalised (trimmed, lower-cased, spaces and hyphens stripped) so every spelling resolves to one entry that carries the canonical page and a canonical display label.

## API

### `p.classify(name)`

Returns the classification table `{ polarity, page, label }` for an effect value, or `nil` when unrecognised. `polarity` is `'positive'`, `'negative'`, or `'neutral'`; `page` is the wiki page to link (`nil` for `None`); `label` is the canonical display spelling.

```lua
local DietaryEffect = require( 'Module:DietaryEffect' )
DietaryEffect.classify( 'Hypermetabolic' )
--> { polarity = 'negative', page = 'Hyper-metabolic', label = 'Hyper-Metabolic' }
```

### `p.renderBadge(name)`

Returns one badge string for an effect value. Known effects link to their canonical page (neutral `None` is plain text); an unrecognised effect renders as a neutral badge linking to its own name (a redlink is the normal signal to create the page).

### `p.renderBadges(effects)`

Returns a wrapping row (`<div class="t-dietary-effects">`, styled by `Module:DietaryEffect/styles.css`) of one badge per effect, or `nil` when the list is empty. This is what the consumable infobox row uses.

```lua
DietaryEffect.renderBadges( { 'Energizing', 'Hyper-Metabolic' } )
```

## Architecture

```
DietaryEffect/
├── DietaryEffect.lua   # classification map, classify / renderBadge / renderBadges
├── styles.css          # .t-dietary-effects flex-wrap layout
└── testcases.lua       # ScribuntoUnit tests for classify
```

Per project convention only the classification logic (`classify`) is unit-tested; the rendering paths are verified by browser QA.
