# Module:Boolean

Renders a tri-state boolean (true/false/nil) as a single machine-readable icon: a green check, a grey cross, or an amber help glyph. The single source of truth for the yes/no/unknown icon, color, and label, modeled on [Module:DietaryEffect](https://starcitizen.tools/Module:DietaryEffect).

Editors use this through `{{Boolean}}`; see [Template:Boolean](https://starcitizen.tools/Template:Boolean). Required directly by several Entity facets ([Module:Entity/Commodity](https://starcitizen.tools/Module:Entity/Commodity), [Module:Entity/Mission](https://starcitizen.tools/Module:Entity/Mission), [Module:Entity/Facet/Consumable](https://starcitizen.tools/Module:Entity/Facet/Consumable), among others) and by [Module:AGGridColumns](https://starcitizen.tools/Module:AGGridColumns)'s `boolean` column kind.

## For module editors

### API

- `p.classify(value)`: pure. Returns `{ state, icon, label }` for any value (never `nil`; unrecognised input resolves to the `unknown` state). `state` is `'yes'`, `'no'`, or `'unknown'`.
- `p.render(value)`: the icon-only inline markup (the infobox/wikitext face): a coloured `currentColor` mask via [Module:Icon](https://starcitizen.tools/Module:Icon), plus the `title`/`data-state`/hidden-text hooks. Returns a string carrying its own and Module:Icon's `<templatestyles>`.
- `p.gridClassify(value)`: `{ text, state, icon }` for the [AG Grid](https://www.mediawiki.org/wiki/Extension:AGGrid) path (`text` is the sort/set-filter key). Consumed by Module:AGGridColumns's `boolean` kind; mirrors `DietaryEffect.gridClassify`.
- `p.main(frame)`: wikitext entry point behind `{{Boolean}}`; the first positional argument is the value.

### Gotchas

- "No" is deliberately grey, not red: the absence of a trait is neutral, not an error, matching [Module:Entity/Availability](https://starcitizen.tools/Module:Entity/Availability)'s convention.
- Only `classify` and `gridClassify` carry unit tests; the rendered HTML (`render`) is verified by browser QA, per project convention.
