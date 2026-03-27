# Module:Details

Wrapper for creating collapsible content sections using [Extension:Details](https://www.mediawiki.org/wiki/Extension:Details).

## Requirements
- [Extension:Details](https://www.mediawiki.org/wiki/Extension:Details)

## Usage

```lua
local Details = require( 'Module:Details' )

local wikitext = Details.getWikitext(
	{
		details = {
			content = 'Wikitext in the details element',
			class = 'details-class',
			open = false
		},
		summary = {
			content = 'Wikitext in the summary element',
			class = 'summary-class',
		}
	},
	frame
)
```

`getWikitext` returns a wikitext string that renders as a collapsible section.

### Parameters

| Parameter | Type | Required | Description |
|---|---|---|---|
| `data` | `table` | Yes | Content and options for the collapsible section. |
| `frame` | `table` | No | Frame object. Defaults to the current frame. |

#### `data.details`

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `content` | `string` | Yes | | Body content shown when expanded. |
| `class` | `string` | No | | CSS class for the details element. |
| `open` | `boolean` | No | `true` | Whether the section starts expanded. |

#### `data.summary`

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `content` | `string` | Yes | | Label shown as the toggle. |
| `class` | `string` | No | | CSS class for the summary element. |
