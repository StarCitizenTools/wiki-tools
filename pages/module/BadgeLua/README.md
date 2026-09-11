# Module:BadgeLua

Lua interface for an inline pill-shaped badge, with an optional icon, custom text color, and custom background. Suited to status tags, version markers, or any short metadata that should read as a distinct chip rather than plain text.

Editors use this through `{{Badge}}`; see [Template:Badge](https://starcitizen.tools/Template:Badge). Required directly by several rendering modules, including [Module:Rarity](https://starcitizen.tools/Module:Rarity), [Module:DietaryEffect](https://starcitizen.tools/Module:DietaryEffect), and [Module:Entity/ProductionStatus](https://starcitizen.tools/Module:Entity/ProductionStatus).

## For module editors

### API

- `p.render(props)`: builds and returns the badge markup plus its bundled `<templatestyles>` tags. `props`: `text` (required), `variant` (`error`/`success`/`warning`), `icon` (file name, rendered via [Module:Icon](https://starcitizen.tools/Module:Icon) at 16px), `mask` (render the icon as a `currentColor` mask instead of a thumbnail), `link` (wrap the whole pill in one anchor), `color`/`backgroundColor` (inline CSS overrides), `class`.
- `p.main(frame)`: wikitext entry point behind `{{Badge}}`. Reads args via [Module:Arguments](https://starcitizen.tools/Module:Arguments); the first positional argument becomes `text`, and `bg` is a shorthand for `backgroundColor` (an explicit `backgroundColor=` wins). `mask` is normalised through [Module:Yesno](https://starcitizen.tools/Module:Yesno).

### Gotchas

- An unrecognised `variant` is silently ignored, so a typo never emits a broken half-styled class.
- `color`/`backgroundColor` render as inline styles, so they win over the `variant` class for text and background color, but a variant's border color has no inline counterpart and stays whatever the class set.
- Icon's own `<templatestyles>` tag is appended only when `icon` is set, so a plain text badge doesn't load it unconditionally.
- `link` wraps the already-rendered pill string in `[[Target|…]]`; the `<templatestyles>` tags stay outside the link label.

### Styles

`.t-badge`, `.t-badge__icon`, and `.t-badge__text` are a contract other code targets directly rather than through `props`: [Module:Rarity](https://starcitizen.tools/Module:Rarity) and [Module:Entity/ProductionStatus](https://starcitizen.tools/Module:Entity/ProductionStatus) override the base look with higher-specificity selectors (`.t-badge.rarity-badge--*`), and the `aggridRenderers` gadget (`MediaWiki:Gadget-aggridRenderers.js`/`.css`) reconstructs the same class names in JS so an AG Grid badge cell matches a wikitext one. Renaming a class here breaks all of them silently.
