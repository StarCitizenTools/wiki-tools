# Module:ButtonLua

Renders a [Codex](https://doc.wikimedia.org/codex/latest/components/demos/button.html) button as a link. Pass a Lua table of props and get back a fake-button link with optional icon, action, weight, and size variants.

## Requirements

- [Codex](https://www.mediawiki.org/wiki/Codex) styles, provided by the [Citizen skin](https://www.mediawiki.org/wiki/Skin:Citizen) (the module emits `cdx-button` classes rather than loading its own styles).
- [Module:Arguments](https://starcitizen.tools/Module:Arguments) (for the `#invoke` entry point).

## Usage

```lua
local button = require( 'Module:ButtonLua' )

function p.main( frame )
    local args = require( 'Module:Arguments' ).getArgs( frame )

    return button.render( {
        label = 'View on Galactapedia',
        url = 'https://robertsspaceindustries.com/galactapedia',
        action = 'progressive',
        weight = 'primary',
        icon = 'Link.svg',
    } )
end
```

Or directly from wikitext via the `main` entry point:

```wikitext
{{#invoke:ButtonLua|main|label=Buy now|link=Aurora MR|weight=primary}}
```

`render` returns an HTML string with `<templatestyles>` included. One of `link` or `url` is required; the module raises an error if neither is provided.

## Data Reference

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `label` | `string` | Yes | | Button text. Used as the `aria-label` when `iconOnly` is set. |
| `link` | `string` | Yes\* | | Internal wiki page to link to, rendered as a wikilink. |
| `url` | `string` | Yes\* | | External URL to link to, rendered as an external link. |
| `action` | `string` | No | `default` | Visual style: `default`, `progressive`, or `destructive`. |
| `weight` | `string` | No | `normal` | Visual weight: `normal` or `primary`. |
| `size` | `string` | No | `medium` | Button size: `small`, `medium`, or `large`. |
| `icon` | `string` | No | | Icon file name. Injected as a CSS background image (MediaWiki disallows `<img>` inside `<a>`). |
| `iconOnly` | `boolean` | No | `false` | Show only the icon and hide the label. Requires `icon`; `label` becomes the accessible name. |
| `disabled` | `boolean` | No | `false` | Render in a disabled style. |
| `class` | `string` | No | | Additional CSS class on the button. |

\* Provide exactly one of `link` or `url`.

## Examples

### Internal link button

```lua
button.render( {
    label = 'Aurora MR',
    link = 'Aurora MR',
} )
```

### External link with icon

```lua
button.render( {
    label = 'Pledge store',
    url = 'https://robertsspaceindustries.com/pledge',
    action = 'progressive',
    weight = 'primary',
    icon = 'OcShoppingCart.svg',
} )
```

### Icon-only button

```lua
button.render( {
    label = 'Edit',
    link = 'Special:EditPage',
    icon = 'OcPencil.svg',
    iconOnly = true,
    size = 'small',
} )
```

## Architecture

```
ButtonLua/
├── ButtonLua.lua    # Main entry point (render + #invoke main)
└── styles.css       # Icon background + Codex icon size overrides
```
