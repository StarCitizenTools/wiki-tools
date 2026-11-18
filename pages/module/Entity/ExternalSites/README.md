# Module:Entity/ExternalSites

The infobox's External sites section: one row per link, each with the site's logo and a tagline saying what the site is, split into official and community sources. The Star Citizen Wiki API is a button below it, visible while the section is collapsed.

Editors never invoke this module directly; it renders inside the infobox of [Template:Entity](https://starcitizen.tools/Template:Entity), [Template:Vehicle](https://starcitizen.tools/Template:Vehicle) and [Template:Location](https://starcitizen.tools/Template:Location), from the links each kind contributes through `getExternalSites` (the hook table is on [Module:Entity](https://starcitizen.tools/Module:Entity)).

## For module editors

### API

- `p.fromDefs(defs, lookup) → EntityExternalSite[]`: resolves a kind's `externalSites.json` against the values the kind looks up. A definition is `{ site, arg }`, whose lookup value is the URL or a list of URLs, or `{ site, format, data }`, whose lookup value is query-encoded into the format's one `%s`. An absent or empty value yields nothing.
- `p.build(entries) → section, buttons`: the collapsed External sites section and the label-less section of buttons after it, each `nil` when it would be empty.

### Extending

- **A site** goes in `sites.json`. Its position there is its display order within a group. `tagline` is the line under its name, the same on every page, so it says what the site is rather than what one page of it does; leave it out when the name already says it (Brochure, Trailer). `official` marks an RSI-run site. `button` names a brand block in [Module:ButtonLua/styles.css](https://starcitizen.tools/Module:ButtonLua/styles.css) (`wiki-api` for `t-button--wiki-api`) and turns the site into a branded button below the section instead of a row, which ignores `tagline` and `iconMask`. `icon` names a wiki file, `iconMask` renders that file in the text colour, for a single-colour file such as the black RSI and Galactapedia marks, and `iconSize` overrides the 24px logo size for a glyph that fills its box edge to edge (the Codex icons take 20px). Leave `icon` out until the file is uploaded: a missing file renders a red link.
- **A link** goes in the contributing kind's `externalSites.json`, or comes back from its `getExternalSites` when the URL needs computing (Mission's SCMDB link, the Location leaves' Starmap link).
- `tests/manifest.lua` fails on a link naming an unknown site, which the module would otherwise drop without a trace.

### Gotchas

- A URL is listed once, even when two chain links contribute it (`|verseguideurl=` and a body's computed VerseGuide link).
- A site linked more than once numbers its rows (Presentation 1, Presentation 2).
- A space in a URL is sent as `%20`, since a space ends the URL in external-link syntax.

### Styles

The classes live in [Module:Entity/styles.css](https://starcitizen.tools/Module:Entity/styles.css), which the infobox loads; the section content carries `Module:Icon/styles.css` for the single-colour logos. Each row's link stretches over the whole row through `a::before`, and the row's `::after` draws the arrow (two layers of one mask that trade places on hover), so neither pseudo-element is free for anything else.
