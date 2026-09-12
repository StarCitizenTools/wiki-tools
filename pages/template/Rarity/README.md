# Template:Rarity

Shows an item's rarity tier as a small coloured badge. Use it inline wherever a rarity is named in prose, a table, or a list; item infoboxes get the same badge on their own.

## Usage

| Wikitext | Result |
|---|---|
| <syntaxhighlight inline lang="wikitext">{{Rarity\|Common}}</syntaxhighlight> | {{Rarity\|Common}} |
| <syntaxhighlight inline lang="wikitext">{{Rarity\|Uncommon}}</syntaxhighlight> | {{Rarity\|Uncommon}} |
| <syntaxhighlight inline lang="wikitext">{{Rarity\|Rare}}</syntaxhighlight> | {{Rarity\|Rare}} |
| <syntaxhighlight inline lang="wikitext">{{Rarity\|Epic}}</syntaxhighlight> | {{Rarity\|Epic}} |
| <syntaxhighlight inline lang="wikitext">{{Rarity\|Legendary}}</syntaxhighlight> | {{Rarity\|Legendary}} |

## Parameters

<!-- templatedata: suggestedvalues 1 = Common; Uncommon; Rare; Epic; Legendary -->

| Name | Label | Type | Required | Default | Description | Example | Aliases |
|------|-------|------|----------|---------|-------------|---------|---------|
| `1` | Rarity | string | Yes |  | The rarity tier: `Common`, `Uncommon`, `Rare`, `Epic`, or `Legendary`, in any case. | `Rare` | `rarity` |

## Behavior

- Matching is case-insensitive and ignores surrounding whitespace, so a value copied from the game data or the API can be passed as is.
- An empty or unrecognised value renders nothing at all, not an error, so a misspelt tier vanishes silently. A missing badge is the sign to check the spelling.
- When both `rarity=` and the positional value are given, `rarity=` wins.
- Colour is fixed per tier and follows the light or dark theme. There is no parameter for colour, icon, or link; for a badge with arbitrary text or styling use `{{Badge}}`.
- Pages built on `{{Entity}}` already show the badge among the infobox chips when the item has a rarity, so this template is for mentions elsewhere on a page.

## See also

- [Template:Badge](https://starcitizen.tools/Template:Badge), a general-purpose badge with free text, variants, and icons.
- [Module:Rarity](https://starcitizen.tools/Module:Rarity), the implementation and the per-tier palette.
