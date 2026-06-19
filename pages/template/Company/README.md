# Template:Company

Renders a company infobox for organizations in the Star Citizen universe, including manufacturers, component makers, weapon manufacturers, and non-manufacturing companies. The infobox displays the company logo, key descriptive fields, and collapsible sections for people, history, and corporate relations. It also sets the page short description, writes structured data via SMW, and adds content categories (mainspace only).

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

Backed by [[Module:Company]].

## Parameters

| Name | Type | Required | Default | Description | Example |
|------|------|----------|---------|-------------|---------|
| `image` | wiki-file-name | No | | Infobox logo filename, without the `File:` prefix. | `Aegis-Dynamics-Logo.png` |
| `imagebg` | string | No | | Logo background hint for transparent logos: `light` or `dark`. | `light` |
| `name` | line | No | (falls back to the page title) | Company name shown in the infobox title. When omitted, the page title is used. | `Aegis Dynamics` |
| `industry` | string | No | | Industry or industries. Semicolon-separated; renders as a list. Wikilinks accepted. | `[[Spacecraft]] manufacturing` |
| `products` | string | No | | Products or product categories. Semicolon-separated; renders as a list. Wikilinks accepted. | `[[Fighter]]s; [[Capital ship]]s` |
| `race` | string | No | `Human` | Species affiliation of the company. | `Human` |
| `headquarters` | string | No | | Headquarters location(s). Separate multiple HQs with `;`; each as "place, …, system" (the last link of each is stored as that HQ's system). Renders as a list. | `[[Lorville]], [[Hurston]]; [[Area18]], [[ArcCorp]]` |
| `areaserved` | string | No | | Area served. Semicolon-separated; renders as a list. Wikilinks accepted; each item's link target is stored to SMW as a Page (every served place). Fill only when narrower than the whole UEE, a bare `[[United Empire of Earth]]` carries no signal. | `[[Lorville]]; [[Hurston]]` |
| `keypeople` | string | No | | Key people. Semicolon-separated; renders as a list. Display only; not stored to SMW. | `[[John Donahue]] (CEO)` |
| `founder` | string | No | | Founder(s). Semicolon-separated; renders as a list. Wikilinks accepted; link targets stored to SMW. | `[[Aaron Sykes]]` |
| `founded` | string | No | | Founding year (clean). The module renders it via `{{Start date and age}}`; SMW stores just the year. | `2755` |
| `fate` | string | No | | Fate of the company. Display only; not stored to SMW. | `Nationalized` |
| `defunct` | string | No | | Year or date the company became defunct. Display only; not stored to SMW. | `2792` |
| `formerly` | string | No | | Former name(s). Display only; not stored to SMW. | `Roberts Space Industries` |
| `predecessor` | string | No | | Predecessor company. Wikilink accepted; the link target is stored to SMW. | `[[Aegis Corp]]` |
| `successor` | string | No | | Successor company. Wikilink accepted; the link target is stored to SMW. | `[[New Aegis]]` |
| `parent` | string | No | | Parent company. Wikilink accepted; the link target is stored to SMW. | `[[Shubin Interstellar]]` |
| `subsidiaries` | string | No | | Subsidiary companies. Semicolon-separated wikilinks; renders as a list. Link targets stored to SMW. | `[[Consolidated Outland]]` |
| `allies` | string | No | | Allied organizations. Semicolon-separated; renders as a list. Display only; not stored to SMW. | `[[Hurston Dynamics]]` |
| `rivals` | string | No | | Rival organizations. Semicolon-separated; renders as a list. Display only; not stored to SMW. | `[[Anvil Aerospace]]` |
| `galactapediaurl` | url | No | | Full URL to the Galactapedia entry. Renders a Galactapedia button in the infobox footer. | `https://robertsspaceindustries.com/galactapedia/article/rQk5lnqbbB-aegis-dynamics` |
| `portfoliourl` | url | No | | Full URL to the RSI portfolio page. Renders a collapsed External sites section with a Portfolio link. | `https://robertsspaceindustries.com/portfolio/aegis-dynamics` |

## See also

- [[Module:Company]]
