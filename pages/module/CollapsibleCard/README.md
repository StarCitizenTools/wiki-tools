# Module:CollapsibleCard

Reusable card with a "summary line + expandable detail" shape. Renders a header (title + optional description), a collapsible body, and an optional footer that stays visible when the card is collapsed — useful for attribution or metadata that should always read.

Built on top of [Module:Details](https://starcitizen.tools/Module:Details) so the underlying `<details>`/`<summary>` markup survives MediaWiki's HTML sanitizer. When `content` is nil or empty, the card falls back to a static `<div>` with the same visual shell but no collapse affordance.

## Requirements

- [Extension:Details](https://www.mediawiki.org/wiki/Extension:Details)
- [Module:Details](https://starcitizen.tools/Module:Details)

## Usage

```lua
local CollapsibleCard = require( 'Module:CollapsibleCard' )

local html = CollapsibleCard.render( {
    title = 'Aegis Avenger Titan',
    description = 'Light freighter · 2 SCU',
    content = 'A multipurpose starter ship from [[Aegis Dynamics]]...',
    footer = 'Source: Star Citizen Wiki',
    open = false,
} )
```

`render` returns a string: a `<templatestyles>` tag for `Module:CollapsibleCard/styles.css` followed by the card markup. Concatenate it directly into your module's output.

## API

### `p.render( props )`

Builds and returns the card.

| Parameter | Type | Description |
|---|---|---|
| `props` | `CollapsibleCardProps` | Card configuration. See fields below. |

#### `CollapsibleCardProps`

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `title` | `string` | Yes | | Header title. Wikitext allowed. |
| `description` | `string` | No | | Secondary line under the title. Renders only when non-empty. |
| `content` | `string` | No | | Body content shown when expanded. When nil or empty, the card falls back to its static variant regardless of `collapsible`. |
| `footer` | `string` | No | | Attribution or metadata line. Always visible (sits outside the `<details>` body). Renders only when non-empty. |
| `open` | `boolean` | No | `false` | Whether the card starts expanded. |
| `collapsible` | `boolean` | No | `true` | When `false`, the card always renders as static even if `content` is provided. |
| `class` | `string` | No | | Extra class appended to the card root. |

## Variants

The module picks one of two layouts based on inputs:

- **Collapsible** — when `content` is non-empty and `collapsible` is not explicitly `false`. Header acts as the toggle; body is in a `<details>` so the disclosure works without JavaScript.
- **Static** — when `content` is nil/empty, or `collapsible` is `false`. Same visual shell, no toggle. The header drops its hover/active affordances so it reads as a plain notice rather than an interactive control.

The footer renders identically in both variants.

## Styles

CSS lives in [Module:CollapsibleCard/styles.css](https://starcitizen.tools/Module:CollapsibleCard/styles.css) and is bundled automatically. The card uses Citizen skin design tokens (`--space-*`, `--color-surface-*`, `--border-*`, `--font-size-*`) so it inherits the site theme.

The collapse chevron uses the `citizen-ui-icon mw-ui-icon-wikimedia-collapse` icon class from the [Citizen skin](https://starcitizen.tools/Citizen_(skin)); it animates on open via a CSS transform.

## Architecture

```
CollapsibleCard/
├── CollapsibleCard.lua    # Render function, variant selection
└── styles.css             # Card visuals + static-variant overrides
```
