# Module:Entity/LocationNavigation

Backs [Template:Location navigation](https://starcitizen.tools/Template:Location_navigation); see it for usage.

## For module editors

### API

- `main(frame)`: the template entry point; `|page=` renders another page's panels.
- `render(subject)`: both panels for a page title, or `''`.
- `Model`: pure panel models (`bodyPanel`, `insidePanel`, `groups`, `families`, `lagrange`).
- `Gauge.row(row, disc, first)`: the positioned decoration for one row, for both variants.
- `Data`: `context(subject)` (the nearest body, walking stored `Parent` values) and `children(page)` (the `location` rows whose `Parent` is the page).

### Gotchas

- Body facts (label, designation, subtype, disc icon, moons in orbital order) come from `Module:SystemMap/systems.json` through `Module:SystemMap/Data.findBody`. A body page renamed on the wiki needs the system map's overlay corrected, as the map itself does.
- A sibling invocation cannot read the page's `{{Location}}` arguments. Every place fact is a stored [Bucket](https://www.mediawiki.org/wiki/Extension:Bucket) row, which exists only after the page's first link update, and a Bucket read registers no dependency. A migration therefore purges each page after saving it.
- Every body page lists every place on its body, so a body's page foot costs one link per place. That is bounded per body and comparable to the navplates it replaces.
- MediaWiki strips SVG, so each gauge arc is a large bordered circle clipped by its row's cell. `Gauge.lua` sets each element's geometry inline (left/top always, plus width, height or bottom wherever it computes one, e.g. an arc's radius, a moon's glyph size, the axis's bottom or height); the stylesheet owns borders and colours. The disc itself does not vary by row: it is a fixed 150px (wide) or 52px (narrow) wherever it appears. The diamond (8px) and the "≈" break (16px) are fixed sizes in the stylesheet and must match `Gauge.lua`'s `DIAMOND`/`BREAK` constants. Every element exists twice, `--wide` and `--narrow`, and the stylesheet shows one per breakpoint; `Gauge.GEOMETRY` holds both sets of numbers.
- Families are a name rule, not an argument: a shared stem plus a trailing code of capitals, digits and hyphens with a digit in it, or a shared capital prefix and a hyphen, with at least two members in one group.
