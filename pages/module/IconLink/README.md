# Module:IconLink

Renders an inline icon link: a small icon followed by a text label, where both the icon and the label link to the same wiki page. For an icon paired with plain, non-linking text, use [Module:IconText](https://starcitizen.tools/Module:IconText) instead.

Editors use this through `{{IconLink}}`; see [Template:IconLink](https://starcitizen.tools/Template:IconLink).

## For module editors

### API

- `p.main(frame)`: wikitext entry point; reads args via [Module:Arguments](https://starcitizen.tools/Module:Arguments) and calls `_main`.
- `p._main(args)`: pure Lua entry point, callable directly by another module. `args`: `icon` (required), `link` (required; also `args[1]`, the named form wins), `text` (defaults to `link`), `size` (default `20px`), `mask` (boolean, via [Module:Yesno](https://starcitizen.tools/Module:Yesno)), `class`. Returns a string carrying its own and [Module:Icon](https://starcitizen.tools/Module:Icon)'s `<templatestyles>` tags. Raises an error if `icon` is missing, or if no `link` (positional or named) is given.

### Gotchas

- The icon is delegated to Module:Icon with the slot class `t-icon-link__icon`; the label span carries `t-icon-link__text`. Neither class is targeted anywhere else in the repository, unlike `t-icon-text__icon` in Module:IconText.
- `text` falls back to `link`, not to the empty string, so an icon link with no `text=` still shows the page name rather than going blank.
