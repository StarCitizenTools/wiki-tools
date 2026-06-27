# Template:Boolean

Renders a tri-state boolean as a machine-readable icon: a green check (yes), a
grey cross (no), or an amber help glyph (unknown). The icon-only face of
[Module:Boolean](https://starcitizen.tools/Module:Boolean); the value is
normalised through [Module:Yesno](https://starcitizen.tools/Module:Yesno), so
`yes`/`1`/`true` and `no`/`0`/`false` all work. Anything unrecognised (or an
empty value) renders the unknown glyph.

Machine-readable three ways: a `title` tooltip, a `data-state`
(`yes`/`no`/`unknown`) attribute, and visually-hidden text for screen readers.

## Usage

<syntaxhighlight lang="wikitext">
{{Boolean|yes}}
{{Boolean|no}}
{{Boolean}}
</syntaxhighlight>

<templatedata>
{
	"description": "Renders a tri-state boolean (yes / no / unknown) as a machine-readable icon.",
	"params": {
		"1": {
			"label": "Value",
			"description": "The boolean value. yes/1/true, no/0/false; empty or unrecognised renders the unknown glyph.",
			"type": "string",
			"required": false
		}
	}
}
</templatedata>
