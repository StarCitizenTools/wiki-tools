# Module:IconText

Renders an inline **icon and text** pair: a small icon followed by a text label, neither of which links anywhere. The icon is inert decoration (rendered with an empty `link=`) and the label is plain text. Suited to compact inline metadata — a clock beside a duration, a map pin beside a location, a status glyph beside a label.

For an icon and label that both link to a page, use [Module:IconLink](https://starcitizen.tools/Module:IconLink) instead.

## Requirements

- [Module:Arguments](https://starcitizen.tools/Module:Arguments) — for the `#invoke` entry point.
- [TemplateStyles](https://www.mediawiki.org/wiki/Extension:TemplateStyles) — the module emits its own `Module:IconText/styles.css`.

## Usage

From wikitext, via the [Template:IconText](https://starcitizen.tools/Template:IconText) wrapper:

```wikitext
{{IconText|5 minutes|icon=CdxIconClock.svg}}
```

Or call the module directly with `#invoke`:

```wikitext
{{#invoke:IconText|main|icon=CdxIconClock.svg|text=5 minutes}}
```

From another Lua module via the `_main` entry point:

```lua
local iconText = require( 'Module:IconText' )

local html = iconText._main( {
    icon = 'CdxIconClock.svg',
    text = '5 minutes',
} )
```

`_main` returns a string: a `<templatestyles>` tag for `Module:IconText/styles.css` followed by the markup. It raises an error if `icon` or `text` is missing.

## Data Reference

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `icon` | `string` | Yes | | File name of the icon (without the `File:` prefix). Rendered with `class=metadata` and no link. |
| `text` | `string` | Yes | | Visible label. Also accepted as the first positional argument (`args[1]`); the named `text` wins if both are given. |
| `iconTitle` | `string` | No | | Tooltip shown when hovering the icon; also used as the icon's `alt` text. When omitted, the icon is purely decorative with no tooltip. |
| `size` | `string` | No | `20px` | Icon size, as a MediaWiki image size (e.g. `16px`). |
| `mask` | `boolean` | No | `false` | Render the icon as a recolorable CSS mask (filled with `background-color: currentColor`) instead of an `<img>`, so it matches the surrounding text color. Best with a single-color icon. |
| `class` | `string` | No | | Extra CSS class appended to the root `<span>`. |

## Examples

### Duration label

```wikitext
{{#invoke:IconText|main|icon=CdxIconClock.svg|text=5 minutes}}
```

### Location label at a smaller size

```wikitext
{{#invoke:IconText|main|icon=CdxIconMapPin.svg|text=Stanton|size=16px}}
```

### Icon with a hover tooltip

```wikitext
{{#invoke:IconText|main|icon=CdxIconClock.svg|text=5 minutes|iconTitle=Estimated time}}
```

### Recolorable mask icon

```wikitext
{{#invoke:IconText|main|icon=CdxIconClock.svg|text=5 minutes|mask=yes}}
```

## Architecture

```
IconText/
├── IconText.lua    # main entry point (main + _main) and rendering
└── styles.css      # inline-flex layout for the icon + text row
```
