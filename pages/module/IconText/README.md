# Module:IconText

Renders an inline icon and text pair: a small icon followed by a text label, neither of which links anywhere. For an icon and label that both link to a page, use [Module:IconLink](https://starcitizen.tools/Module:IconLink) instead.

Editors use this through `{{IconText}}`; see [Template:IconText](https://starcitizen.tools/Template:IconText). Required directly by [Module:UEC](https://starcitizen.tools/Module:UEC), which renders the UEC glyph plus a formatted amount through it.

## For module editors

### API

- `p.main(frame)`: wikitext entry point; reads args via [Module:Arguments](https://starcitizen.tools/Module:Arguments) and calls `_main`.
- `p._main(args)`: pure Lua entry point, callable directly by another module. `args`: `icon` (required), `text` (required; also `args[1]`, the named form wins), `iconTitle` (hover tooltip and `alt` text), `size` (default `20px`), `mask` (boolean, via [Module:Yesno](https://starcitizen.tools/Module:Yesno)), `class`. Returns a string carrying its own and [Module:Icon](https://starcitizen.tools/Module:Icon)'s `<templatestyles>` tags. Raises an error if `icon` or `text` is missing.

### Styles

The icon carries the slot class `t-icon-text__icon`, which [Module:UEC](https://starcitizen.tools/Module:UEC)'s stylesheet targets directly (`.t-uec .t-icon-text__icon`) to force the icon to `1em` square instead of the module's `20px` default. Renaming this class breaks that override.
