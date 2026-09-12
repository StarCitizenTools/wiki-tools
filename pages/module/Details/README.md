# Module:Details

Wrapper for building a collapsible `<details>`/`<summary>` section, via [Extension:Details](https://www.mediawiki.org/wiki/Extension:Details), as wikitext rather than raw HTML tags (which MediaWiki's sanitizer would otherwise escape).

Required by [Module:CollapsibleCard](https://starcitizen.tools/Module:CollapsibleCard) and [Module:InfoboxLua/Components/Collapsible](https://starcitizen.tools/Module:InfoboxLua/Components/Collapsible); not invoked from templates.

## For module editors

### API

`p.getWikitext(data, frame?)` returns the rendered wikitext string.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `data.summary.content` | `string` | Yes | Label shown as the toggle. |
| `data.summary.class` | `string` | No | CSS class for the `<summary>` element. |
| `data.details.content` | `string` | Yes | Body content shown when expanded. |
| `data.details.class` | `string` | No | CSS class for the `<details>` element. |
| `data.details.open` | `boolean` | No | Starts expanded. Defaults to `true`. |
| `frame` | `mw.frame` | No | Defaults to the current frame. |

```lua
local Details = require( 'Module:Details' )

local wikitext = Details.getWikitext( {
	details = { content = 'Wikitext in the details element', open = false },
	summary = { content = 'Wikitext in the summary element' },
} )
```

### Gotchas

`Extension:Details`' `open` attribute is a string, not a boolean (`'yes'`/`'no'`); `getWikitext` does that conversion, so callers pass a real boolean (or omit it for the `true` default).
