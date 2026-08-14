# Module:SystemMap

Backs <code><nowiki>{{System map}}</nowiki></code>. Renders the star, planet and
moon hierarchy of one star system as a horizontal orbit rail.

## Structure

| Page | Responsibility |
| --- | --- |
| `Module:SystemMap` | Entry point. Argument parsing, page-existence annotation, tracking categories. Hands the rail to [[Module:CollapsibleCard]] for the card shell and collapse. |
| `Module:SystemMap/Data` | System-name resolution, glyph classification, model building, body-count summary. Pure. |
| `Module:SystemMap/Renderer` | Model to HTML — the rail only; the card supplies the header. Pure. |
| `Module:SystemMap/systems.json` | The bodies of every rolled-out system, in orbital order. **Generated** — see below. |
| `Module:SystemMap/styles.css` | TemplateStyles. |

## Adding a body or a system

**Do not edit `systems.json` on the wiki.** It is a build artifact, and a hand
edit is lost the next time anybody regenerates. The generator and its inputs live
in the [wiki-tools repository](https://github.com/StarCitizenTools/wiki-tools):

```
scripts/out/starmap.json              upstream ARK Starmap mirror (gitignored)
pages/module/SystemMap/overlay.json   hand-owned corrections (committed)
        |
        v  mise run systemmap
pages/module/SystemMap/systems.json   committed, then deployed via MCP
```

The split is the point. Upstream data goes stale and gets refetched; editorial
judgement has to survive that refetch, so it lives in `overlay.json` instead of
in the file the refetch overwrites. A correction keyed to a body that no longer
exists **fails the build** rather than being ignored, because a silently dropped
correction is exactly how this work gets lost.

To add a system, list it in `overlay.json` — an empty entry is enough if nothing
needs correcting — and run `mise run systemmap`. To correct a body, add the one
key that is wrong: `page`, `label`, `icon`, `iconRatio`, `after` (position a body
upstream cannot order — every belt, and Delamar), `moonOf` (reparent, as Pyro IV
under Pyro V), or `km`.

Everything else is derived, and `scripts/cmd/systemmap/README.md` documents the
rules. The two worth knowing here:

- **Orbital order comes from the Roman numeral in the designation**, not from
  `orbit_period`, which upstream leaves null for 195 of its 326 planets. A body
  with no numeral needs an `after`.
- **A belt's designation is lower-cased after the system name** — upstream's
  `Stanton Belt Alpha` is stored as `Stanton belt alpha`. That is house style
  rather than a correction, so it is a derivation rule and not four overlay
  entries. A Roman numeral keeps its capitals, because that is an orbital slot.
  Upstream names 21 of its 80 belts; for the 48 unnamed ones that reach the
  file, the rule reaches their `label` and `page` too, since all three derive
  from that one designation — so they agree instead of storing the same string
  in two cases. A belt upstream *does* name (`Aaron Halo`, `Keeger Belt`) keeps
  that name verbatim in `label` and `page`: it is a proper noun, and
  lower-casing it would red-link the article. The overlay still keys the body by
  upstream's spelling, not by the house-styled label.

A belt is marked `tier: belt`; anything unmarked is a planet. Belts carry no
`km`: upstream reports their size as `0` or `null`, and a belt has no meaningful
diameter, so they render as a fixed speckled band rather than a scaled disc.

Twenty-two planet subtypes share eleven glyph kinds — `SUBTYPE_KIND` in
`Data.lua` holds that table, and the generator carries the matching one, so
change them together. Stars need no table: their kind falls out of
`'star-' .. lower(class)`, where `class` is the spectral letter, or the word
`degenerate` / `neutron` for the two remnants that have none. `class` is
**optional**: Variable, Subgiant and the fifteen stars upstream leaves
unclassified carry none, the key is simply absent, and the kind falls back to a
plain `star`. A subtype with no kind renders a neutral grey disc rather than
erroring, so adding one is a styling task, not a blocker. The grouping is deliberate: a 6-24px disc cannot carry
twenty-two distinguishable colours.

**Subtype is never printed as text** — it exists purely to pick the glyph, so a
gas giant reads as a banded amber disc and an ice giant as a banded cyan one.
The card header instead describes the system by its contents ("4 planets, 12
moons"), which the reader cannot get from the picture at a glance.

## Scale is schematic, deliberately

Left to right is true orbital order, but **disc size is a three-tier convention
and carries no measurement**. Please do not "correct" it.

Within a tier the mapping is logarithmic between that tier's smallest and largest
body: rank-preserving, not proportional. Pyro V is 6.6x Hurston by diameter and
renders about 1.4x. A linear map would put the smallest planet at 0.05px.

Gas and ice giants are therefore distinguished by banding rather than by
diameter, which is also all the upstream data supports: its `size` field is
incoherent across tiers (the Stanton star is `1.2` while Pyro's is `571000.44`),
and `orbit_period` is null for every Stanton moon.

### The scale is anchored, so it never moves

`systems.json` records an `extents` block: the smallest and largest `km` per
tier, measured across **all 90 upstream systems**, unioned with whatever the file
itself renders. `Data.lua` uses it when present and falls back to measuring the
file when it is absent.

That block is what stops a rollout batch resizing discs on pages that are already
live. While the extents were measured from the file, every system added rescaled
every published page: adding Terra and Castra alone moved Nyx's star from 30.0px
to 24.3px, and finishing the rollout would have moved it again to 26.4px. Nobody
would have noticed, because nothing errors.

Two consequences worth keeping in mind:

- **Do not hand-trim `extents` to the systems in the file.** It is meant to reach
  past them; a body outside its tier's range is clamped to the tier cap, which
  draws two different sizes identically.
- The union is not tidiness. Upstream types Pyro IV a planet and the overlay
  renders it as a moon; measured by upstream type alone the moon tier stops at
  1,789 km and Pyro IV, at 3,214 km, falls outside its own scale.

## What the corrections buy

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

The generator has its own suite in `scripts/internal/systemmap` (`cd scripts &&
go test ./...`), including the acceptance gate: regenerating must reproduce
Stanton, Pyro and Nyx exactly as the wiki currently serves them.
