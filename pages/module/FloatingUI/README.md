# Module:FloatingUI

A Lua interface to [Extension:FloatingUI](https://www.mediawiki.org/wiki/Extension:FloatingUI)'s `{{#floatingui:}}` parser function: wraps a reference element so hovering or focusing it opens a floating content panel beside it. The extension is explicitly experimental (per the module's own source comment) and not considered production-ready.

Required by [Module:ProgressTiles](https://starcitizen.tools/Module:ProgressTiles); not invoked from templates.

## For module editors

### API

- `p.render(reference, content, inline?)`: wikitext wrapping `reference` (a `<div>`, or `<span>` when `inline` is `true`) with a floating panel holding `content`. Returns `''` only when `reference` or `content` is `nil` (an empty string is truthy in Lua, so it doesn't trigger this); an empty `reference` still renders (an empty reference element), but an empty `content` renders with no floating panel at all, since `getContentHtml` treats `''` the same as `nil` (see below): nothing to hover.
- `p.load(frame?)`: `<templatestyles>` for [Module:FloatingUI/styles.css](https://starcitizen.tools/Module:FloatingUI/styles.css) plus the `{{#floatingui:}}` call that loads the extension's JS library. Must run once per page for any `render` output on that page to actually float; `render` alone emits only markup, not the library.
- `p.getContentHtml(content, htmlTag?)`: the content-panel `mw.html` node `render` wraps around `content`; `nil` when `content` is `nil` or `''`.
- `p.renderSection(data)`: a structured panel section (`label?`, `data?`, `desc?`, an inline `span` instead of `div` when `inline = true`, `col = 2` for a two-column grid; any other `col` value emits a class with no matching CSS rule). Returns `''` for a `nil`, non-table, or empty `data`. Not currently called by any module in this repo.

### Gotchas

`load` and `render` are independent: calling `render` without `load` (once, anywhere on the page) produces static markup with no floating behaviour. [Module:ProgressTiles](https://starcitizen.tools/Module:ProgressTiles) requires this module lazily, only when a tile actually sets a `tooltip`, so the common tooltip-less path carries no dependency on it.
