# Module:Icon

Renders a single inline icon, either as a rasterised `[[File:]]` thumbnail or as a CSS mask filled with `currentColor` (so it recolours with the surrounding text). Optionally linked. The shared icon primitive behind [Module:IconText](https://starcitizen.tools/Module:IconText), [Module:IconLink](https://starcitizen.tools/Module:IconLink), and [Module:BadgeLua](https://starcitizen.tools/Module:BadgeLua).

## Usage

```lua
local Icon = require( 'Module:Icon' )

-- a recolourable mask icon, sized to the text, no link
Icon.render( { icon = 'CdxIconArrowUp.svg', size = '16px', mask = true } )

-- a plain thumbnail linked to a page
Icon.render( { icon = 'Sc-icon-uec.svg', link = 'United Earth Credit' } )
```

From wikitext:

```wikitext
{{#invoke:Icon|main|icon=CdxIconArrowUp.svg|mask=yes|size=16px}}
```

## Templatestyles contract

`render` returns **markup only** — no `<templatestyles>`. Callers must load `Module:Icon/styles.css` themselves (the consumers above do). This keeps the style tag out of any wikilink label when a caller wraps the icon in a link of its own (e.g. BadgeLua's whole-pill link). The wikitext entry point `main` does emit the stylesheet, since it returns a standalone value.

## API

### `p.render( props )`

Returns the icon markup string.

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `icon` | `string` | Yes | | File name (without the `File:` prefix). |
| `size` | `string` | No | `20px` | CSS length for width and height. |
| `mask` | `boolean` | No | `false` | Render as a `currentColor` mask instead of a thumbnail. |
| `link` | `string` | No | | Link target; empty/nil leaves the icon unlinked. |
| `title` | `string` | No | | Tooltip / caption. |
| `class` | `string` | No | | Extra class(es) on the icon element. Consumers pass their own slot class (e.g. `t-icon-text__icon`) so existing selectors keep working. |

The icon element always carries the base class `t-icon`, plus `t-icon--mask` in mask mode.

### `p.main( frame )`

Wikitext entry point. Reads named arguments (and positional `1` as `icon`), emits `Module:Icon/styles.css`, and forwards to `render`. `mask` accepts any [Yesno](https://starcitizen.tools/Module:Yesno) truthy value.

## Requirements

- [Module:Yesno](https://starcitizen.tools/Module:Yesno) — boolean coercion for the `mask` argument.
- A CORS-clean media host for mask mode (the SVG is used as a CSS `mask-image`).

## Architecture

```
Icon/
├── Icon.lua     # render (thumb | mask, optional link), main
└── styles.css   # .t-icon + .t-icon--mask
```
