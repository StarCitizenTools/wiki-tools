# Module:Company

Renders the company infobox via [Module:InfoboxLua](https://starcitizen.tools/Module:InfoboxLua). Covers all organizations that hold a manufacturer identity (ship builders, component makers, weapon manufacturers, security-force subsidiaries) as well as non-manufacturing companies. Standalone: driven entirely by manual template parameters with no API fetch. Pure builder functions are decoupled from `p.main` so a future organization or faction Entity can consume the company facet directly.

## Usage

Invoked through `Template:Company`:

```wikitext
{{#invoke:Company|main}}
```

The template passes its parameters to the module as `args`. The module emits the infobox HTML, sets `SHORTDESC`, writes SMW properties, and adds content categories (mainspace only).

### Parameters

| Parameter | Description |
|---|---|
| `image` | Infobox logo filename (without `File:` prefix). |
| `imagebg` | Logo background: `light` or `dark` for transparent-logo handling. |
| `name` | Company name. Falls back to the page title when absent. |
| `industry` | Industry or industries. Semicolon-separated; renders as a list when there are 2+. Wikilinks accepted. |
| `products` | Products or product categories. Semicolon-separated; renders as a list. Wikilinks accepted. |
| `race` | Species affiliation (e.g. `Human`, `Xi'an`). Defaults to `Human`. |
| `headquarters` | Headquarters location(s). Separate multiple HQs with `;` (each may contain comma-separated city/planet/system); renders as a list when there are 2+. |
| `areaserved` | Area served. Semicolon-separated; renders as a list. Wikilinks accepted; each item's link target stored to SMW as a Page. Fill only when narrower than the whole UEE (a bare `[[United Empire of Earth]]` carries no signal). |
| `keypeople` | Key people. Semicolon-separated; renders as a list. Display only, not stored to SMW. |
| `founder` | Founder(s). Semicolon-separated; renders as a list. Wikilinks accepted; link targets stored to SMW. |
| `founded` | Founding year (e.g. `2554`). The module renders it via `{{Start date and age}}`; SMW stores the clean year. |
| `fate` | Fate of the company. Display only, not stored to SMW. |
| `defunct` | Year or date the company became defunct. Display only, not stored to SMW. |
| `formerly` | Former name(s). Display only, not stored to SMW. |
| `predecessor` | Predecessor company or companies (e.g. the firms that merged to form it). Semicolon-separated; renders as a list. Wikilinks accepted; link targets stored to SMW. |
| `successor` | Successor company or companies. Semicolon-separated; renders as a list. Wikilinks accepted; link targets stored to SMW. |
| `parent` | Parent company. Wikilink accepted; the link target is stored to SMW. |
| `subsidiaries` | Subsidiary companies. Semicolon-separated wikilinks; renders as a list. Link targets stored to SMW. |
| `allies` | Allied organizations. Semicolon-separated; renders as a list. Display only, not stored to SMW. |
| `rivals` | Rival organizations. Semicolon-separated; renders as a list. Display only, not stored to SMW. |
| `galactapediaurl` | Full URL to the Galactapedia entry. Renders a Galactapedia button in the infobox footer via Module:ButtonLua. |
| `portfoliourl` | Full URL to the RSI portfolio page. Renders a collapsed "External sites" section with a Portfolio link. |

## Builder API

All functions except `p.main` are pure (no frame dependency) and can be called directly by other modules.

| Function | Description |
|---|---|
| `p.normalizeRace(race)` | Trims `race`; returns `"Human"` when absent or blank. |
| `p.resolveCode(args)` | Returns the manufacturer code by looking up `args.name` via `Module:Manufacturers` (the source of truth). Returns `nil` when the name matches no known manufacturer. There is no override parameter. |
| `p.raceLink(args)` | Returns the Race infobox cell as a wikilink to the per-race companies category (e.g. `[[:Category:Human companies|Human]]`). Always present. |
| `p.getHeader(args)` | Returns a `CompanyHeaderData` table `{ title, subtitle, image }` for InfoboxLua. `subtitle` is always `"Company"`. `image` is `nil` when no filename is supplied. `imagebg` maps `light`/`dark` to the appropriate `t-infobox-image--*` class. |
| `p.getContentSections(args)` | Returns the grouped content sections: an unlabelled top group (always inline) plus collapsible People / History / Relations. Multi-value fields (semicolon-separated) render as `Module:list` unbulleted lists when they have 2+ items. Empty groups self-drop. |
| `p.getMetadataSection(args)` | Returns the collapsed "Metadata" section holding the manufacturer code (an identifier, not descriptive content), or `nil` when no code resolves. |
| `p.getExternalSitesSection(args)` | Returns the collapsed "External sites" section containing the Portfolio link, or `nil` when `portfoliourl` is absent. |
| `p.getFooterSection(args)` | Returns the footer section with the Galactapedia button, or `nil` when `galactapediaurl` is absent. |
| `p.getSections(args)` | Assembles all sections: content groups, then metadata, then external sites, then footer. |
| `p.getStructuredData(args)` | Builds and returns the SMW property table from the properties manifest. |
| `p.getShortDescription(args)` | Returns the short description string (e.g. `"Human company in the aerospace industry"`). |
| `p.getCategories(args)` | Returns the content category names array (e.g. `{ "Companies", "Human companies" }`). |
| `p.main(frame)` | Wikitext entry point. Renders the infobox, calls `SHORTDESC`, writes SMW, and appends categories. |

## SMW

Properties are defined in `Module:Company/properties.json` and written via `mw.smw.set` in mainspace only.

| Property | SMW type | Source parameter | Notes |
|---|---|---|---|
| `Name` | Text | `name` | |
| `Industry` | Text | `industry` | Semicolon-split; each item lcfirst + delinked. `lcfirst` is a no-op when an item begins with a wikilink (`[`). |
| `Products` | Text | `products` | Same transform as Industry. |
| `Manufacturer code` | Text | (derived from `name`) | Resolved via `p.resolveCode` from Module:Manufacturers. Displayed in the collapsed Metadata section (an identifier, not descriptive content). |
| `Race` | Text | `race` | Defaults to `Human`. |
| `Headquarters` | Page | `headquarters` | One star system per HQ: the last wikilink of each `;`-separated HQ segment (convention "place, …, system"). |
| `Area served` | Page | `areaserved` | Semicolon-split; each item's link target stored (every served place, not collapsed to system). |
| `Founded` | Text | `founded` | The clean year passed by the editor (display is rendered via `{{Start date and age}}`, but SMW stores just the year). |
| `Founder` | Page | `founder` | Semicolon-split; link targets stored (not display labels). |
| `Parent company` | Page | `parent` | Link target stored. |
| `Subsidiaries` | Page | `subsidiaries` | Semicolon-split; link targets stored. |
| `Predecessor` | Page | `predecessor` | Semicolon-split; each item's link target stored (a merger can have several). |
| `Successor` | Page | `successor` | Semicolon-split; each item's link target stored. |

Display-only fields (`keypeople`, `fate`, `defunct`, `formerly`, `allies`, `rivals`) are intentionally absent from SMW.

**Page-type properties** (`Founder`, `Subsidiaries`, `Area served`, `Parent company`, `Predecessor`, `Successor`) extract the link target from wikilink markup: `[[Target|Label]]` stores `Target`, not `Label`. The list-valued ones (`Founder`, `Subsidiaries`, `Area served`, `Predecessor`, `Successor`) are semicolon-split into one value per item. `Headquarters` (also Page-type) stores one star system per HQ — the last wikilink of each `;`-separated segment — so each HQ's system is queryable (the free-form HQ string itself stays the display value). `Area served` differs from `Headquarters`: it stores **every** served place (each item's link target, not collapsed to the system), so station/city-level queries work; fill it only when narrower than the whole UEE.

**Industry and Products** are semicolon-split into individual SMW entries; each item is lcfirst + delinked (the display label is kept). When an item starts with a wikilink, `lcfirst` is a no-op (it sees `[` as the first character).

**Multi-value separator:** all multi-value fields use a semicolon (`;`), which avoids colliding with commas inside names, addresses, and link labels.

On SMW write failure the page is added to `Category:Pages with structured data errors`, consistent with Module:Entity/Categories.

## Dependencies

- [Module:InfoboxLua](https://starcitizen.tools/Module:InfoboxLua) — infobox rendering.
- [Module:Arguments](https://starcitizen.tools/Module:Arguments) — `args` extraction in `p.main`.
- [Module:Manufacturers](https://starcitizen.tools/Module:Manufacturers) — manufacturer code resolution from company name.
- [Module:ButtonLua](https://starcitizen.tools/Module:ButtonLua) — Galactapedia footer button.
- [Module:list](https://starcitizen.tools/Module:list) — unbulleted list rendering for multi-value fields (called directly, not via the template wrapper).
- SMW via `mw.smw.set` — structured data storage.

## Architecture

```
Company/
├── Company.lua        # Builder API + p.main entry point
├── properties.json    # SMW property manifest
├── styles.css         # TemplateStyles for t-company infobox
└── testcases.lua      # ScribuntoUnit test suite
```
