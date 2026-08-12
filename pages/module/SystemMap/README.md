# Module:SystemMap

Backs <code><nowiki>{{System map}}</nowiki></code>. Renders the star, planet and
moon hierarchy of one star system as a horizontal orbit rail.

## Structure

| Page | Responsibility |
| --- | --- |
| `Module:SystemMap` | Entry point. Argument parsing, page-existence annotation, tracking categories. Hands the rail to [[Module:CollapsibleCard]] for the card shell and collapse. |
| `Module:SystemMap/Data` | System-name resolution, glyph classification, model building, body-count summary. Pure. |
| `Module:SystemMap/Renderer` | Model to HTML — the rail only; the card supplies the header. Pure. |
| `Module:SystemMap/systems.json` | The 35 bodies, in orbital order. |
| `Module:SystemMap/styles.css` | TemplateStyles. |

## Adding a body or a system

Edit `Module:SystemMap/systems.json`. The `bodies` array is everything orbiting
the star — planets and asteroid belts together — and **array order is orbital
order**. There is no sort key, so a body is placed by where you put it.

A belt is marked `tier: belt`; anything unmarked is a planet. Belts carry no
`km`: upstream reports their size as `0` or `null`, and a belt has no meaningful
diameter, so they render as a fixed speckled band rather than a scaled disc.
Two of the four have no `orbit_period` upstream either — Aaron Halo and the
Akiro Cluster are placed from the wiki's own prose ("between Crusader and
ArcCorp", "at Pyro I's L3 Lagrangian").

Each body needs `page` (the wiki title, with the first letter capitalised as
MediaWiki stores it) and `label` (the display name, which may differ in case,
such as `MicroTech (planet)` displayed as `microTech`). Planets also need
`designation` and `subtype`; moons take an optional `subtype` when they are not
a plain rocky moon.

Recognised subtypes are Super-Earth, Gas giant, Ice giant, Smog planet,
Protoplanet and Terrestrial rocky. An unrecognised subtype renders a neutral
grey disc rather than erroring, so adding a new one is a styling task, not a
blocker.

**Subtype is never printed as text** — it exists purely to pick the glyph, so a
gas giant reads as a banded amber disc and an ice giant as a banded cyan one.
The card header instead describes the system by its contents ("4 planets, 12
moons"), which the reader cannot get from the picture at a glance.

## Scale is schematic, deliberately

Left to right is true orbital order, but **disc size is a three-tier convention
and carries no measurement**. Please do not "correct" it.

The upstream RSI starmap data cannot support anything better. Its `size` field
is incoherent across tiers: the Stanton star is `1.2` while Pyro's is
`571000.44`; Hurston is `11853` while its moons are between `0.4` and `0.9`.
Its `orbit_period` is null for every Stanton moon. Gas and ice giants are
therefore distinguished by banding rather than by diameter.

## Why the data lives here

`systems.json` was seeded once from `Module:Starmap/starmap.json` and is
hand-owned from then on. That buys three corrections to upstream data:

- **Pyro IV** is the outermost moon of Pyro V, not a planet, which matches both
  the starmap parent relationship and the wiki's own prose.
- **Delamar** is a protoplanet between Nyx II and Nyx III, though its starmap
  code still says `NYX.ASTEROID.DELAMAR`.
- RSI's code typos (`PRYO.MOONS.VUUR`, `PYRO.MOON.FAIRO`) never enter the system
  because this file keys on page titles instead.

The cost is that page moves do not self-heal; `Category:Pages with a broken
system map link` surfaces them.

## Tests

`Module:SystemMap/testcases`. Run locally with `mise run test:lua:unit SystemMap`.
