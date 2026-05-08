# Module:BadgeLua

Lua interface for rendering an inline badge — a small pill-shaped label with optional icon, custom color, and custom background. Suited for status tags, version markers, faction labels, or any short metadata that should read as a distinct chip rather than plain text.

The module emits a `<span class="t-badge">` with bundled TemplateStyles. The icon (when supplied) is rendered as a `[[File:…]]` thumb sized at `16px`, marked with the `metadata` class to be excluded from the MediaWiki MultimediaViewer and stripped of its link target so the badge as a whole stays inert.

## Usage

```lua
local Badge = require( 'Module:BadgeLua' )

local html = Badge.render( {
    text = 'Deprecated',
    variant = 'warning',
} )
```

For one-off colors that don't fit a semantic variant, fall back to the raw color props:

```lua
local html = Badge.render( {
    text = 'New',
    icon = 'Sparkle.svg',
    color = '#fff',
    backgroundColor = '#2a6df4',
} )
```

From wikitext, invoke `main` directly:

```wikitext
{{#invoke:BadgeLua|main|text=New|icon=Sparkle.svg|backgroundColor=#2a6df4|color=#fff}}
```

`render` returns a string: a `<templatestyles>` tag for `Module:BadgeLua/styles.css` followed by the badge markup. Concatenate it directly into your module's output.

## API

### `p.render( props )`

Builds and returns the badge.

| Parameter | Type | Description |
|---|---|---|
| `props` | `BadgeProps` | Badge configuration. See fields below. |

#### `BadgeProps`

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `text` | `string` | Yes | | Badge label. Wikitext allowed. |
| `variant` | `'error'\|'success'\|'warning'` | No | | Semantic preset that themes the badge via Citizen design tokens. Unknown values are ignored. |
| `icon` | `string` | No | | File name (without the `File:` prefix) of an icon to render before the text at 16px. |
| `color` | `string` | No | | CSS color applied to the badge text. Any valid CSS color value. Overrides `variant` (rendered as inline style). |
| `backgroundColor` | `string` | No | | CSS background color applied to the badge. Any valid CSS color value. Overrides `variant` (rendered as inline style). |
| `class` | `string` | No | | Extra class appended to the badge root. |

### `p.main( frame )`

Wikitext entry point. Reads named arguments via [Module:Arguments](https://starcitizen.tools/Module:Arguments) and forwards them to `render`. The argument names match the `BadgeProps` fields above.

Two shorthand argument names are accepted for the most common props, so common cases stay terse in wikitext:

| Shorthand | Resolves to | Notes |
|---|---|---|
| `1` (positional) | `text` | First positional argument is treated as the badge label when `text=` is omitted. |
| `bg` | `backgroundColor` | Used when `backgroundColor=` is omitted. |

```wikitext
{{#invoke:BadgeLua|main|New|bg=#2a6df4|color=#fff}}
```

Explicit named arguments always win over their shorthands.

## Styles

CSS lives in [Module:BadgeLua/styles.css](https://starcitizen.tools/Module:BadgeLua/styles.css) and is bundled automatically. The badge uses Citizen skin design tokens (`--space-*`, `--color-surface-*`, `--color-emphasized`, `--border-*`, `--font-size-*`, `--font-weight-*`) so it inherits the site theme.

`color` and `backgroundColor` props override the token-derived defaults via inline styles, so they win against any class-based theming.

## Architecture

```
BadgeLua/
├── BadgeLua.lua    # Render function, icon helper
└── styles.css      # Badge layout + icon slot
```
