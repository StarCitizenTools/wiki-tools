# Module:DietaryEffect

Classifies the dietary effects carried by food, drink, and edible commodities into beneficial (green, up arrow), detrimental (red, down arrow), or neutral (`None` and anything unrecognised, grey, no arrow), and renders them as [Module:BadgeLua](https://starcitizen.tools/Module:BadgeLua) badges. The single source of truth for effect polarity and the correct effect page.

Required by [Module:Entity/Facet/Consumable](https://starcitizen.tools/Module:Entity/Facet/Consumable) (the consumable infobox row) and [Module:DataGrid](https://starcitizen.tools/Module:DataGrid) (its `kind=effect` column); not invoked from templates.

## For module editors

### API

- `p.classify(name) → { polarity, page, label }|nil`: `polarity` is `'positive'`, `'negative'`, or `'neutral'`; `page` is the wiki page to link (`nil` for `None`); `label` is the canonical display spelling. `nil` when the value is unrecognised.
- `p.renderBadge(name)`: one badge string for an effect value. Known effects link their canonical page; `None` renders as an unlinked badge (no `page` to link to), not plain text. An unrecognised effect renders as a neutral badge linking to its own name; a redlink is the normal signal to create the page.
- `p.renderBadges(effects)`: a wrapping row (`<div class="t-dietary-effects">`) of one badge per effect, or `nil` when the list is empty.
- `p.gridClassify(name) → { text, variant?, icon?, href? }`: the same polarity/page/label choices as `renderBadge`, shaped for [Module:AGGridColumns](https://starcitizen.tools/Module:AGGridColumns)' `badgeList` kind (`icon` a file name, `href` a page title, both resolved by the kind itself).

```lua
local DietaryEffect = require( 'Module:DietaryEffect' )
DietaryEffect.classify( 'Hypermetabolic' )
--> { polarity = 'negative', page = 'Hyper-metabolic', label = 'Hyper-Metabolic' }
```

### Gotchas

The API sends effect values whose spelling and casing do not always match their wiki page, and two stray redirects point at the wrong page, so lookups are normalised (trimmed, lower-cased, spaces and hyphens stripped) against a table carrying the canonical page and label:

- `Cognitive Boosting` → [Cognitive boosting](https://starcitizen.tools/Cognitive_boosting), `Cognitive Impairment` → [Cognitive impairing](https://starcitizen.tools/Cognitive_impairing)
- `Hyper-Metabolic` / `Hypermetabolic` → [Hyper-metabolic](https://starcitizen.tools/Hyper-metabolic); `Hypo-Metabolic` / `Hypometabolic` → [Hypo-metabolic](https://starcitizen.tools/Hypo-metabolic)
- `Healing` redirects to [Medical](https://starcitizen.tools/Medical) (wrong); the dietary effect lives at [Healing (dietary effect)](https://starcitizen.tools/Healing_(dietary_effect))
- `Hypometabolic` redirects to [Hyper-metabolic](https://starcitizen.tools/Hyper-metabolic) (wrong)
