# Module:Tiles

A generic image-led grid renderer: each tile is an image with optional primary/secondary labels overlaid at the bottom, and the whole tile is clickable via a fakelink (a transparent absolutely-positioned `[[Page|Text]]` wikilink; MediaWiki's sanitizer strips raw `<a>` tags, so anchors only exist when the parser generates them from wikitext). Pure rendering: callers pass fully resolved rows, so lookup concerns ([SMW](https://www.mediawiki.org/wiki/Extension:Semantic_MediaWiki) resolution, API fetching) stay in the caller.

Required by [Module:Entity/Related](https://starcitizen.tools/Module:Entity/Related) and [Module:Entity/UsedBy](https://starcitizen.tools/Module:Entity/UsedBy); not invoked from templates.

## For module editors

### API

`p.render(props)` returns `<templatestyles>` + the grid markup.

| Field | Type | Default | Description |
|---|---|---|---|
| `rows` | `TilesRow[]` | | Required. Rows to render, in order. |
| `aspectRatio` | `string` | `'1 / 1'` | CSS `aspect-ratio` for every tile's image (e.g. `'16 / 9'` landscape, `'3 / 4'` portrait). |
| `tileMinWidth` | `string` | `'120px'` | `minmax(<min>, 1fr)` floor for the grid's auto-fill columns; pair a wider value with a landscape `aspectRatio`. |
| `placeholderImage` | `string` | `'Placeholderv2.png'` | Used when a row has no `image`. |
| `imageWidth` | `string` | `'320px'` | Thumbnail width hint passed to `[[File:…\|<width>\|link=]]`. |

**TilesRow**: `linkLabel` (required accessible text; a row without one is skipped, since there is no label to build a sanitizer-safe wikilink from), `page?` (falls back to `linkLabel`, rendering a red link to the bare name), `image?` (falls back to `placeholderImage`), `primary?` (prominent label), `secondary?` (kicker above `primary`).

### Gotchas

- A tile's image always carries `class=notpageimage`: a tile always shows some OTHER page's picture, so [PageImages](https://www.mediawiki.org/wiki/Extension:PageImages) must never score it as the current page's own image.
- `aspectRatio` and `tileMinWidth` ride CSS custom properties (`--t-tiles-aspect`, `--t-tiles-columns`) set inline on the grid root; the stylesheet's own defaults live in separate declarations rather than `var(…, default)`, because the sanitizer rejects that fallback form on `aspect-ratio`. `tileMinWidth` is assembled into the full `repeat(auto-fill, minmax(<min>, 1fr))` value in Lua, because the sanitizer rejects `var()` nested inside `minmax()` at the property consumer but accepts arbitrary tokens inside a custom-property declaration.

### Styles

Consumer-targetable classes: `t-tiles` (grid root, holds the two custom properties above), `t-tiles__tile` (one tile, `position: relative` anchor for the fakelink), `t-tiles__link` (the transparent absolutely-positioned wikilink wrapper), `t-tiles__image`, `t-tiles__label`, `t-tiles__primary` / `t-tiles__secondary` (both single-line with ellipsis).
