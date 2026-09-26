# Module:CollapsibleCard

A [Module:CardLua](https://starcitizen.tools/Module:CardLua) card with a "summary line + expandable detail" shape: header (title + optional description), a collapsible body, and an optional footer that stays visible when collapsed. Falls back to a static card with no collapse affordance when `content` is nil or empty.

Required by [Module:SystemMap](https://starcitizen.tools/Module:SystemMap), [Module:Entity/Commodity/Mining](https://starcitizen.tools/Module:Entity/Commodity/Mining), [Module:Entity/Availability](https://starcitizen.tools/Module:Entity/Availability), [Module:Entity/Blueprints](https://starcitizen.tools/Module:Entity/Blueprints), [Module:Entity/Ports/Render](https://starcitizen.tools/Module:Entity/Ports/Render), and [Module:Entity/Related](https://starcitizen.tools/Module:Entity/Related); not invoked from templates.

## For module editors

### API

`p.render(props)` returns `<templatestyles>` + the card markup.

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `title` | `string` | Yes | | Header title. Wikitext allowed. |
| `description` | `string` | No | | Secondary line under the title. |
| `eyebrow` | `string` | No | | One line above the title naming the level above (e.g. "UEE space"). |
| `content` | `string` | No | | Body content. Nil/empty forces the static variant regardless of `collapsible`. |
| `footer` | `string` | No | | Attribution/metadata line, always visible, outside the `<details>` body. |
| `open` | `boolean` | No | `false` | Starts expanded. |
| `collapsible` | `boolean` | No | `true` | `false` forces the static variant even with `content`: the body still renders, always visible, just without a collapse toggle; it is not dropped. |
| `class` | `string` | No | | Extra class appended to the card root. |

### Gotchas

The collapsible variant composes [Module:Details](https://starcitizen.tools/Module:Details) (so the `<details>`/`<summary>` markup survives MediaWiki's sanitizer) with `CardLua.renderHeaderContent` in the summary and a chevron; the static variant uses `CardLua.renderHeader` directly, so its header carries no interactive class and gets no hover/active affordance. Both variants pass `footer` straight to `CardLua.render`, which places it outside the collapsible body, so it renders identically (and stays visible) in either case.

### Styles

[Module:CollapsibleCard/styles.css](https://starcitizen.tools/Module:CollapsibleCard/styles.css) adds only the collapse-specific styling (interactive header cursor/hover/active, chevron rotate-on-open); the card shell, header row, content border, and footer come from [Module:CardLua/styles.css](https://starcitizen.tools/Module:CardLua/styles.css), loaded by `CardLua.render`. The chevron uses the Citizen skin's `citizen-ui-icon mw-ui-icon-wikimedia-collapse` class.
