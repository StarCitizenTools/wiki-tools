# Module:InfoboxLua

Data-driven infobox system. Pass a Lua table describing your infobox and get back rendered HTML with collapsible sections, tabbed content, and multi-column layouts.

## Requirements

- [Extension:Details](https://www.mediawiki.org/wiki/Extension:Details)
- [Extension:TabberNeue](https://www.mediawiki.org/wiki/Extension:TabberNeue)
- [Module:Details](https://starcitizen.tools/Module:Details)

## Usage

```lua
local infobox = require( 'Module:InfoboxLua' )

function p.main( frame )
    local args = require( 'Module:Arguments' ).getArgs( frame )

    return infobox.render( {
        title = args.title,
        subtitle = args.subtitle,
        image = args.image,
        sections = {
            {
                label = 'Overview',
                items = {
                    { label = 'Manufacturer', content = args.manufacturer },
                    { label = 'Role', content = args.role },
                }
            },
            {
                label = 'Specifications',
                collapsible = true,
                columns = 3,
                items = {
                    { label = 'Crew', content = args.crew },
                    { label = 'Cargo', content = args.cargo },
                    { label = 'Stowage', content = args.stowage },
                }
            }
        }
    } )
end
```

`render` returns an HTML string with `<templatestyles>` included.

## Data Reference

### Infobox

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `title` | `string` | Yes | | Infobox title. |
| `subtitle` | `string` | No | | Subtitle below the title. |
| `image` | `string` or `table` | No | Placeholder | Single image. Pass a filename string or an Image table. |
| `images` | `table` | No | | Multiple images, rendered as tabs. Array of Image tables. |
| `summary` | `string` | No | `"Quick facts: <title>"` | Toggle label for the collapsible infobox wrapper. |
| `sections` | `table` | No | | Array of Section tables. |
| `class` | `string` | No | | CSS class on the infobox container. |
| `css` | `table` | No | | Inline CSS as `{ property = value }` pairs. |

### Section

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `label` | `string` | No | | Section heading. |
| `content` | `string` | No | | Wikitext content. |
| `items` | `table` | No | | Array of Item tables. |
| `sections` | `table` | No | | Nested sections, rendered as tabs. |
| `columns` | `number` | No | `1` | Number of columns for items. |
| `collapsible` | `boolean` | No | `false` | Make section collapsible. |
| `collapsed` | `boolean` | No | `false` | Start collapsed. Requires `collapsible = true`. |
| `class` | `string` | No | | CSS class on the section container. |

### Item

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `content` | `string` | Yes | | Item content (wikitext). |
| `label` | `string` | No | | Label displayed beside the content. |
| `class` | `string` | No | | CSS class on the item container. |

### Image

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `src` | `string` | Yes | | Image filename. |
| `overlay` | `string` | No | | Wikitext overlay on the image. |
| `label` | `string` | No | | Tab label when using multiple images. |
| `size` | `number` | No | `400` | Image width in pixels. |
| `class` | `string` | No | | CSS class on the image. |

## Examples

### Tabbed content

Nested sections automatically render as tabs:

```lua
{
    label = 'Cost',
    sections = {
        { label = 'Universe', items = { ... } },
        { label = 'Pledge', items = { ... } }
    }
}
```

### Collapsible sections

```lua
{
    label = 'Specifications',
    collapsible = true,
    collapsed = false,
    items = { ... }
}
```

### Multi-column layout

```lua
{
    label = 'Capacity',
    columns = 3,
    items = {
        { label = 'Crew', content = '1' },
        { label = 'Cargo', content = '0 SCU' },
        { label = 'Stowage', content = '1,300 KµSCU' }
    }
}
```

## Architecture

```
InfoboxLua/
├── InfoboxLua.lua           # Main entry point
├── styles.css               # Component styles
├── Types.lua                # Type definitions and schemas
├── Util.lua                 # Validation and helper functions
└── Components/
    ├── Header.lua           # Header component
    ├── Section.lua          # Section component
    ├── Item.lua             # Item component
    ├── Item/Card.lua        # Card item component
    └── Collapsible.lua      # Collapsible component
```
