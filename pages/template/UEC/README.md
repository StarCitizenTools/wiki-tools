# Template:UEC

Formats an in-game money value in United Earth Credit (UEC): the UEC glyph followed by the amount with thousands separators. Wraps [Module:UEC](https://starcitizen.tools/Module:UEC); see [United Earth Credit](https://starcitizen.tools/United_Earth_Credit) for the in-universe currency.

## Usage

Pass the amount as the first positional argument.

| Wikitext | Result |
|---|---|
| <syntaxhighlight inline lang="wikitext">{{UEC\|15000}}</syntaxhighlight> | {{UEC\|15000}} |
| <syntaxhighlight inline lang="wikitext">{{UEC\|2750000}}</syntaxhighlight> | {{UEC\|2750000}} |
| <syntaxhighlight inline lang="wikitext">{{UEC\|50}}</syntaxhighlight> | {{UEC\|50}} |

## Parameters

| Name | Label | Type | Required | Default | Description | Example |
|------|-------|------|----------|---------|-------------|---------|
| `1` | Amount | number | Yes |  | The UEC amount. Rendered with thousands separators (e.g. `15,000`). | `15000` |

## Behavior

- The amount is formatted with the wiki content language's digit grouping, so `15000` renders as `15,000`.
- The leading icon (`Sc-icon-uec.svg`) is drawn in mask mode, so it takes on the color of the surrounding text (matching links, headings, and so on).
- A non-numeric value raises a script error.

## See also

- [Module:UEC](https://starcitizen.tools/Module:UEC) — implementation.
- [United Earth Credit](https://starcitizen.tools/United_Earth_Credit) — the in-universe currency.
