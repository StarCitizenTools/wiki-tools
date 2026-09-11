# Module:Icon

Renders a single inline icon, either as a rasterised `[[File:]]` thumbnail or as a CSS mask filled with `currentColor` (so it recolours with the surrounding text). Optionally linked.

Required by [Module:BadgeLua](https://starcitizen.tools/Module:BadgeLua), [Module:Boolean](https://starcitizen.tools/Module:Boolean), [Module:IconText](https://starcitizen.tools/Module:IconText), [Module:IconLink](https://starcitizen.tools/Module:IconLink), and [Module:AGGridColumns](https://starcitizen.tools/Module:AGGridColumns)' `Kind/BadgeList` and `Kind/Boolean`; not invoked from templates.

## For module editors

### API

`p.render(props)` returns markup only, no `<templatestyles>` (see Styles below).

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `icon` | `string` | Yes | | File name (without the `File:` prefix). |
| `size` | `string` | No | `20px` | Mode-dependent: with `mask` a CSS length for width and height (`1em` works); otherwise a MediaWiki image size passed into `[[File:…]]` (`x16px` works, `1em` does not). |
| `mask` | `boolean` | No | `false` | Render as a `currentColor` mask instead of a thumbnail. |
| `link` | `string` | No | | Link target; empty/nil leaves the icon unlinked. |
| `title` | `string` | No | | Tooltip / caption. |
| `class` | `string` | No | | Extra class(es), appended after the base `t-icon` (+ `t-icon--mask` in mask mode). |

`p.src(icon)` resolves an icon file name to its plain (entity-decoded) URL, for a caller that paints its own mask client-side, e.g. an AG Grid badge cell whose `iconSrc` is read into a CSS custom property by JavaScript rather than an HTML style attribute.

`p.main(frame)` is the `#invoke` entry point: reads named arguments (and positional `1` as `icon`; `title` also accepts `iconTitle`), emits [Module:Icon/styles.css](https://starcitizen.tools/Module:Icon/styles.css), and forwards to `render`. `mask` accepts any [Module:Yesno](https://starcitizen.tools/Module:Yesno) truthy value.

### Gotchas

- Mask mode's `mask-image` fetch is constrained by the wiki's enforced CSP `default-src`, not by CORS: the file URL must resolve to a host that policy allows, regardless of cross-origin headers.
- The `nowiki` `filepath` parser function HTML-entity-encodes `:` as `&#58;`; a browser decodes that inside an HTML `style` attribute (the server-rendered mask) but not when a script assigns it to a CSS custom property, which is why `p.src` decodes it back to plain text for client-side callers.
- Thumbnail mode always prepends `class=metadata` to the `[[File:...]]` markup, ahead of `t-icon`.

### Styles

`render` returns markup only, no `<templatestyles>`: callers must load [Module:Icon/styles.css](https://starcitizen.tools/Module:Icon/styles.css) themselves. This keeps the style tag out of any wikilink label when a caller wraps the icon in a link of its own (e.g. BadgeLua's whole-pill link). `p.main` (the wikitext entry point) does emit the stylesheet, since it returns a standalone value.
