# Template:Company

Renders a company infobox for organizations in the Star Citizen universe: manufacturers, component and weapon makers, and non-manufacturing companies alike. Place it at the top of a company or manufacturer page.

## Usage

```wikitext
{{Company
| image           = Aegis Dynamics logo.png
| name            = Aegis Dynamics
| industry        = [[Spacecraft]] manufacturing
| products        = [[Fighter]]s; [[Capital ship]]s
| race            = Human
| galactapediaurl = https://robertsspaceindustries.com/galactapedia/article/rQk5lnqbbB-aegis-dynamics
| portfoliourl    = https://robertsspaceindustries.com/portfolio/aegis-dynamics
}}
```

## Parameters

| Name | Type | Required | Default | Description | Example |
|------|------|----------|---------|-------------|---------|
| `image` | wiki-file-name | No | | Infobox logo filename, without the `File:` prefix. | `Aegis-Dynamics-Logo.png` |
| `imagebg` | string | No | | Logo background hint for transparent logos: `light` or `dark`. | `light` |
| `name` | line | No | (page title, infobox title only) | Company name; the SMW `Name` property and manufacturer-code lookup get no fallback. | `Aegis Dynamics` |
| `industry` | string | No | | Industry or industries (SMW). | `[[Spacecraft]] manufacturing` |
| `products` | string | No | | Products or product categories (SMW). | `[[Fighter]]s; [[Capital ship]]s` |
| `race` | string | No | `Human` | Species affiliation (SMW). | `Human` |
| `headquarters` | string | No | | Headquarters location(s), as "place, …, system" (SMW). | `[[Lorville]], [[Hurston]]; [[Area18]], [[ArcCorp]]` |
| `areaserved` | string | No | | Area served, narrower than the whole UEE (SMW). | `[[Lorville]]; [[Hurston]]` |
| `keypeople` | string | No | | Key people; display only. | `[[John Donahue]] (CEO)` |
| `founder` | string | No | | Founder(s) (SMW). | `[[Aaron Sykes]]` |
| `founded` | string | No | | Founding year (SMW). | `2755` |
| `fate` | string | No | | Fate of the company; display only. | `Nationalized` |
| `defunct` | string | No | | Year or date the company became defunct; display only. | `2792` |
| `formerly` | string | No | | Former name(s); display only. | `Roberts Space Industries` |
| `predecessor` | string | No | | Predecessor company or companies (SMW). | `[[Aegis Macrocomputing]]; [[Dynamic Production Systems]]` |
| `successor` | string | No | | Successor company or companies (SMW). | `[[New Aegis]]` |
| `parent` | string | No | | Parent company (SMW). | `[[Shubin Interstellar]]` |
| `subsidiaries` | string | No | | Subsidiary companies (SMW). | `[[Consolidated Outland]]` |
| `allies` | string | No | | Allied organizations; display only. | `[[Hurston Dynamics]]` |
| `rivals` | string | No | | Rival organizations; display only. | `[[Anvil Aerospace]]` |
| `galactapediaurl` | url | No | | Galactapedia entry URL; renders a footer button. | `https://robertsspaceindustries.com/galactapedia/article/rQk5lnqbbB-aegis-dynamics` |
| `portfoliourl` | url | No | | RSI portfolio page URL; renders a collapsed External sites section. | `https://robertsspaceindustries.com/portfolio/aegis-dynamics` |

## Behavior

- Every list-type field above (`industry`, `products`, `headquarters`, `areaserved`, `keypeople`, `founder`, `predecessor`, `successor`, `subsidiaries`, `allies`, `rivals`) is `;`-separated; two or more items render as an unbulleted list with a hanging indent, a single item renders plain.
- `headquarters` stores one star system per HQ to [SMW](https://www.mediawiki.org/wiki/Extension:Semantic_MediaWiki): the last wikilink in each `;`-separated segment ("place, …, system"). `areaserved` stores every place's own link target instead; fill it only when narrower than the whole UEE (a bare `[[United Empire of Earth]]` carries no signal).
- There is no manufacturer-code parameter: the code is looked up from `name` against the manufacturer registry and shown in a collapsed Metadata section.
- `founded` is stored to SMW exactly as typed; only the infobox display branches, rendering a bare year through `{{Start date and age}}`, else showing it as-is.
- `keypeople`, `fate`, `defunct`, `formerly`, `allies`, and `rivals` are display-only and never reach SMW.
- A wikilinked `industry`/`products` item and its plain-text equivalent normalise to the same stored value.
- A failed SMW write adds the page to `Category:Pages with structured data errors` instead of raising an error.
- SMW writes and content categories are gated to the main namespace, so `/doc` and sandbox pages stay clean.

## See also

- [Module:Company](https://starcitizen.tools/Module:Company), implementation.
- [Module:Manufacturers](https://starcitizen.tools/Module:Manufacturers), the manufacturer code registry.
