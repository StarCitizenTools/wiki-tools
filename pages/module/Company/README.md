# Module:Company

Renders the company infobox via [Module:InfoboxLua](https://starcitizen.tools/Module:InfoboxLua) for manufacturers, component and weapon makers, and non-manufacturing companies alike. Standalone: driven entirely by manual parameters, with pure builder functions decoupled from `p.main` so another module could reuse the company facet directly.

Editors use this through `{{Company}}`; see [Template:Company](https://starcitizen.tools/Template:Company).

## For module editors

### API

Builder functions, all pure except `p.main`:

- `p.normalizeRace(race)`: trims, defaults to `"Human"`.
- `p.resolveCode(args)`: the manufacturer code for `args.name` via [Module:Manufacturers](https://starcitizen.tools/Module:Manufacturers).resolve; `nil` when unmatched.
- `p.raceLink(args)`: the Race cell: a link to the per-race companies category.
- `p.getHeader(args)`: `{ title, subtitle = "Company", image }` for InfoboxLua.
- `p.getContentSections(args)`: the unlabelled top group plus collapsible People/History/Relations sections; empty groups self-drop.
- `p.getMetadataSection`, `p.getExternalSitesSection`, `p.getFooterSection`: the collapsed Metadata (manufacturer code), External sites (portfolio link), and footer (Galactapedia button) sections; each `nil` when its source value is absent.
- `p.getSections(args)`: all sections, in render order.
- `p.getStructuredData(args)`: the [SMW](https://www.mediawiki.org/wiki/Extension:Semantic_MediaWiki) property table, built from `properties.json`.
- `p.getShortDescription(args)`, `p.getCategories(args)`: the short description and content category names.
- `p.main(frame)`: wikitext entry point.

**Data schema**: `properties.json` maps each SMW property to a source parameter and an optional `transform`: `page` (link target), `pageList` (semicolon-split link targets), `hqSystems` (last wikilink per `;`-segment), `textList` (semicolon-split, delinked, lcfirst). `Subject type` has no source: every Company page gets `Subject type = Company` unconditionally, so other modules can query `[[Subject type::Company]]` across kinds.

### Gotchas

- `textList` delinks before lowercasing the first character: `lcfirst` only touches the first character, and a wikilinked item starts with `[`, so lcfirst-then-delink would leave `[[Clothing]] manufacture` capitalised after its brackets are stripped, forking a duplicate value from the plain-text form.
- `resolveCode` takes no override argument by design: [Module:Manufacturers](https://starcitizen.tools/Module:Manufacturers) is the sole source of truth for the code.
- SMW writes and category additions are gated to the main namespace; a write failure is caught with `pcall` and reported as a tracking category rather than a script error.
