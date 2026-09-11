# Template:Boolean

Renders a tri-state boolean value as a machine-readable icon: a green check (yes), a grey cross (no), or an amber help glyph (unknown). Wraps [Module:Boolean](https://starcitizen.tools/Module:Boolean); see the module page for rendering details.

## Usage

```wikitext
{{Boolean|yes}}
{{Boolean|no}}
{{Boolean}}
```

## Parameters

<!-- templatedata: suggestedvalues 1 = yes; no -->

| Name | Label | Type | Required | Default | Description | Example |
|------|-------|------|----------|---------|-------------|---------|
| `1` | Value | string | No |  | The boolean value, normalised through [Module:Yesno](https://starcitizen.tools/Module:Yesno): `yes`/`1`/`true` and `no`/`0`/`false` in any case. Anything else renders the unknown glyph. | `yes` |

## Behavior

- The icon is machine-readable three ways: a `title` tooltip, a `data-state` (`yes`/`no`/`unknown`) attribute, and visually hidden text for screen readers.
- "No" renders grey, not red: the absence of a trait is neutral, not an error.
- An empty or omitted value renders the unknown glyph rather than an error.

## See also

- [Module:Boolean](https://starcitizen.tools/Module:Boolean), implementation.
- [Module:Yesno](https://starcitizen.tools/Module:Yesno), value normalisation.
