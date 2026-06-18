# Module:IconLink

Renders an inline **icon link**: a small icon followed by a text label, where both the icon and the label link to the same wiki page. Suited to compact, scannable references — a ship with a thumbnail, a manufacturer with its logo, a location with a map pin — anywhere a plain wikilink reads better with a leading glyph.

For an icon paired with plain, non-linking text, use [Module:IconText](https://starcitizen.tools/Module:IconText) instead.

## Requirements

- [Module:Arguments](https://starcitizen.tools/Module:Arguments) — for the `#invoke` entry point.
- [TemplateStyles](https://www.mediawiki.org/wiki/Extension:TemplateStyles) — the module emits its own `Module:IconLink/styles.css`.

## Usage

From wikitext, via the [Template:IconLink](https://starcitizen.tools/Template:IconLink) wrapper:

```wikitext
{{IconLink|Aurora MR|icon=CdxIconArticle.svg}}
```

Or call the module directly with `#invoke`:

```wikitext
{{#invoke:IconLink|main|link=Aurora MR|icon=CdxIconArticle.svg|text=Aurora}}
```

From another Lua module via the `_main` entry point:

```lua
local iconLink = require( 'Module:IconLink' )

local html = iconLink._main( {
    icon = 'CdxIconArticle.svg',
    link = 'Aurora MR',
    text = 'Aurora',
} )
```

`_main` returns a string: a `<templatestyles>` tag for `Module:IconLink/styles.css` followed by the markup. It raises an error if `icon` is missing, or if no `link` (positional or named) is provided.

## Data Reference

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `icon` | `string` | Yes | | File name of the icon (without the `File:` prefix). Rendered with `class=metadata` and linked to the target page. |
| `link` | `string` | Yes | | Target wiki page. Also accepted as the first positional argument (`args[1]`); the named `link` wins if both are given. |
| `text` | `string` | No | (the link) | Visible label. Defaults to the link target. |
| `size` | `string` | No | `20px` | Icon size, as a MediaWiki image size (e.g. `16px`). |
| `mask` | `boolean` | No | `false` | Render the icon as a recolorable CSS mask (filled with `background-color: currentColor`) instead of an `<img>`, so it matches the linked text color. The masked icon stays linked to the target page. Best with a single-color icon. |
| `class` | `string` | No | | Extra CSS class appended to the root `<span>`. |

## Examples

### Icon link with default label

```wikitext
{{#invoke:IconLink|main|link=Aurora MR|icon=CdxIconArticle.svg}}
```

### Custom label and icon size

```wikitext
{{#invoke:IconLink|main|link=Stanton system|text=Stanton|icon=CdxIconMapPin.svg|size=16px}}
```

### Recolorable mask icon

```wikitext
{{#invoke:IconLink|main|link=Aurora MR|icon=CdxIconArticle.svg|mask=yes}}
```

## Architecture

```
IconLink/
├── IconLink.lua    # main entry point (main + _main) and rendering
└── styles.css      # inline-flex layout for the icon + text row
```
