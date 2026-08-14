# Module:SystemMap

Backs <code><nowiki>{{System map}}</nowiki></code>. Renders one star system as a
horizontal orbit rail: the star or stars, the planets and belts orbiting them,
and the moons and rings orbiting those.

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
needs correcting — and run `mise run systemmap`. To correct a body, add it under
that system's `bodies` with the one key that is wrong: `page`, `label`, `icon`,
`iconRatio`, `after` (position a body the numeral rule cannot order — Delamar,
and most belts), `moonOf` (reparent, as Pyro IV under Pyro V), or `km`.

A star goes in a sibling `star` block rather than under `bodies` — Terra's
`"star": { "page": "Terra Nova" }` is the whole of it — and a second star in a
`companion` block beside it. Both take the same keys except `after` and `moonOf`,
which a body the planet rail does not hold has no use for, and their `km` is a
radius. Filing a star under `bodies` fails the build with
`overlay corrects …` instead of being ignored, so the mistake costs a run rather
than producing a wrong map; so does a `companion` block on a system that has one
star, and a `star` block on one of the two that have none.

Two more keys sit at the system level. `page` corrects the system's own article
title, which is otherwise `<upstream name> system` — Kyuk'ya needs it, because
upstream still carries the Perry Line name and calls the system `Kyuk'ya
(Indra)`. `companionShape` overrides how two stars are drawn, and should be left
alone: it is derived, and the next section says from what.

A top-level `exclude` list, a sibling of `systems`, drops matching bodies from
every system; `*` is its only wildcard. A pattern names a body the way the
overlay does — plainly, or in the type-qualified form two bodies sharing a name
need, as `Ellis XI (PLANET)`. The plain form drops both; the qualified form drops
one. It currently carries upstream's protoplanetary disk placeholders under both
spellings, RSI's and its typo, and the skeletal protoplanet upstream files under
the same designation as Ellis XI's cluster, which is the body that actually has
an article.

Everything else is derived, and `scripts/cmd/systemmap/README.md` documents the
rules. The two worth knowing here:

- **Orbital order comes from the Roman numeral that *ends* the designation**,
  not from `orbit_period`, which upstream leaves null for 195 of its 326
  planets. The rule reads the designation, not the body type, so a belt upstream
  designates after a planet is ordered like one: `Ellis XI` lands between
  Bombora and Judecca with no overlay entry at all, and `Odin I` behaves the
  same. Everything else needs an `after` — Delamar, and 67 of the 69 belts,
  `Hades IV split` and `Kallis V Accretion Disk` among them, because a numeral
  that is not the last word is not read.
- **A belt's designation is lower-cased after the system name** — upstream's
  `Stanton Belt Alpha` is stored as `Stanton belt alpha`. That is house style
  rather than a correction, so it is a derivation rule rather than one overlay
  entry per belt. A Roman numeral keeps its capitals, because that is an orbital
  slot. Upstream names 21 of its 69 belts, and a belt it *does* name (`Aaron
  Halo`, `Keeger Belt`) keeps that name verbatim in `label` and `page`: it is a
  proper noun, and lower-casing it would red-link the article. For an unnamed
  belt the label *is* the designation, so the rule reaches `label` and `page`
  too and all three agree, instead of storing the same string in two cases —
  48 belts across 30 systems once the rollout covers every one. The overlay
  still keys the body by upstream's spelling, not by the house-styled label.

## Two stars, and the two ways they sit

Five systems have a second star, and `systems.json` carries it in a `companion`
block next to `star`, with a `companionShape` saying how the two relate. Both
keys are absent for the other 85, which is what makes the addition invisible to
every page already published.

**The shape is derived from upstream's `parent_id`, not from a list**, because
upstream describes two genuinely different objects under one word:

| Shape | Systems | Upstream says | The rail draws |
| --- | --- | --- | --- |
| `nested` | Tyrol, Kyuk'ya | the companion is parented to the primary, and every body hangs off the primary too | the companion nested under the primary, where a moon goes |
| `paired` | Bacchus, Baker, Goss | neither star is parented, and both sit at the same distance from the barycentre | both stars sharing one rail slot, with the orbit line beginning at the pair |

Drawing the second the way the first is drawn would invent a hierarchy the data
denies. These are different systems, not one system with a missing field.

The system's own upstream `type` is **not** what decides it. That field reports
`BINARY` for four of the five and `SINGLE_STAR` for Tyrol, which has two stars;
counting the stars and reading `parent_id` is the only answer that holds.

Two things follow, and both are deliberate:

- **A nested companion keeps star-tier sizing.** Tyrol B renders at 22.8px in the
  row where moons are 6-14px, with a star's spectral glyph. It is a star; drawn
  on the moon scale it would read as an absurd moon. `SCALE_TIER` in `Data.lua`
  is what maps the layout tier back to the tier it is measured and classified at,
  and missing that mapping fails silently twice — an `unknown` glyph and the 30px
  star cap.
- **The you-are-here marker lands on the individual star, never on the pair.**
  Bacchus A and Bacchus B are separate articles, and a reader on either has to be
  able to find themselves, so a paired slot holds two independently markable
  `<li>`s rather than one merged `A · B` label. It is also what lets each keep its
  own `data-kind`: Bacchus A is a G-type and B a K-type.

No companion carries a body anywhere in the dataset, which is what lets the rail
hang everything off the primary. That is upstream data rather than a law, so the
generator checks it and refuses to build a system that breaks it instead of
drawing the body as an orbit of the pair.

## A system with no star

Two systems — Tamsa and Min — have no star at all upstream, and both carry
planets; Min carries four moons as well. Neither is rolled out, but nothing in
the model assumes a head: `star` is an optional key, the rail simply starts at
the first planet, and adding either is a data change rather than a code change.

What a head-less system does *not* get is a `star` block. There is no body for it
to correct, so the generator refuses the build rather than discarding it —
`overlay corrects the star, but upstream files 0 stars here`. That check is
separate from the `companion` one because these two systems are the first that
can reach the correction code with no primary at all; before they built, a `star`
block could not miss.

## Tiers, and where a ring goes

Every body carries a `tier`. Five of them describe a body's place on the rail —
`star`, `planet`, `belt`, `moon`, `ring` — and three of those scale: star, planet
and moon, the ones with a disc. The other two are drawn at a fixed size, as
below. Two more, `companion` and `paired`, exist only in the render model: they are
layout, not classification, and both are measured and coloured at the `star`
tier. `companion` is the second star of a nested pair. `paired` is worn by
**both** stars of a co-orbiting pair, since neither is subordinate — that is the
whole claim the shape makes.

`bodies` is everything orbiting the star, in orbital order, and one marker
separates its two kinds: a belt carries `tier: belt`, and anything unmarked there
is a planet. A planet's `moons` array works the same way one level down: a ring
carries `tier: ring`, and anything unmarked there is a moon.

Belts carry no `km`, and the tier is what decides that, not the data: a belt is a
region rather than a body, so the generator drops the size whatever upstream
reports and the belt renders as a fixed speckled band rather than a scaled disc.
Most belts do report `0` or `null` — but four do not, and two of those are live:
Sol's Kuiper Belt reports `99999999.99999999` and Taranis 2a debris `0.15`, and
both draw the same band as the rest. An empty field is not the reason.

**A planetary ring sits in its planet's `moons` array, marked `tier: ring`.**
The rail nests exactly one level, and that level is where a ring belongs — but a
ring is not a moon, so it takes its own glyph kind and is drawn as a flat band
rather than a disc, and the header counts it apart ("9 planets, 19 moons, 4
rings, 2 belts" for Sol). It sorts ahead of its planet's moons, because the moon
column reads outward from the planet and a ring is inside them.

Two rules follow from a ring not being a body, and both exist to protect pages
that are already published:

- **It carries no `km`, decided by its role rather than by its size field.**
  Upstream reports `0` or `null` for every ring it has, so the data cannot tell
  "a ring has no diameter" apart from "this field is empty", and the generator
  therefore drops the size for a ring the way it does for a belt.
- **It is kept out of the disc scale in both passes** — the upstream measurement
  and the emitted file's. A ring that acquired a size would otherwise be measured
  at the moon tier and resize every moon on every published page.

Which rings render is decided by what they orbit. Ten of the eleven rings
upstream has orbit a **planet**, and those are the ones the rail can draw; six
of them do today — Sol's four, Ellis's one and Kyuk'ya's one — the other four
being in systems the rollout has not reached yet. The eleventh, Stanton's `Ring of Yela`, orbits a
**moon**: drawing it would need a second level of nesting, which the rail does
not have, for one body in all 90 systems — and it has no article under any title
to link either. It is dropped.

## Glyphs

Twenty-two planet subtypes share eleven glyph kinds — `SUBTYPE_KIND` in
`Data.lua` holds that table, and the generator carries the matching one, so
change them together. Stars need no table: their kind falls out of
`'star-' .. lower(class)`, where `class` is the spectral letter, or the word
`degenerate` / `neutron` for the two remnants. Only `Neutron` genuinely has no
letter: upstream's white dwarf subtype ends in one, `White Dwarf-Degenerate-A`,
and it is filed as `degenerate` anyway because a main-sequence A colour would be
the wrong claim about a remnant — an editorial call, and the one Oberon's star
renders under. `class` is **optional**: Variable, Subgiant and the fifteen stars
upstream leaves unclassified carry none, the key is simply absent, and the kind
falls back to a plain `star`. Belts and rings short-circuit ahead of all of it and take their own
kinds, so a ring can never fall through to the moon disc and draw itself as the
thing it orbits alongside. A subtype with no kind renders a neutral grey disc
rather than erroring, so an upstream addition cannot break a published rail — but
it does block the build. The generator refuses an unrecognised planet or star
subtype outright (`unknown planet subtype …`), so a system containing one cannot
be regenerated until the Go table has it too: adding a subtype is a two-file job,
not a styling touch-up. The grouping is deliberate: a 6-24px disc cannot carry
twenty-two distinguishable colours.

**Subtype is never printed as text** — it exists purely to pick the glyph, so a
gas giant reads as a banded amber disc and an ice giant as a banded cyan one.
The card header instead describes the system by its contents ("4 planets, 12
moons, 1 belt" for Stanton), which the reader cannot get from the picture at a
glance.

## Scale is schematic, deliberately

Left to right is true orbital order, but **disc size is a three-tier convention
and carries no measurement**. Please do not "correct" it.

Within a tier the mapping is logarithmic between that tier's smallest and largest
body: rank-preserving, not proportional. Pyro V is 6.6x Hurston by diameter and
renders about 1.3x. A linear map would put the smallest planet at well under a
tenth of a pixel.

Gas and ice giants are therefore distinguished by banding rather than by
diameter, which is also all the upstream data supports: its `size` field is
incoherent across tiers (the Stanton star is `1.2` while Pyro's is `571000.44`),
and `orbit_period` is null for every Stanton moon.

Belts and rings are outside this entirely. Neither scales, neither carries a
`km`, and both are drawn at a fixed size.

### The scale is anchored, so it never moves

`systems.json` records an `extents` block: the smallest and largest `km` per
tier, measured across **all 90 upstream systems**, unioned with whatever the file
itself renders. `Data.lua` uses it when present and falls back to measuring the
file when it is absent.

That block is what stops a rollout batch resizing discs on pages that are already
live. While the extents were measured from the file, every system added rescaled
every published page: adding Terra and Castra alone moved Nyx's star from 30.0px
to 24.3px, and a finished rollout would have moved it again, to 26.4px. Nobody
would have noticed, because nothing errors.

Two consequences worth keeping in mind:

- **Do not hand-trim `extents` to the systems in the file.** It is meant to reach
  past them; a body outside its tier's range is clamped to whichever end it fell
  past — the tier floor below, the tier cap above — which draws two different
  sizes identically.
- The union is not tidiness. Upstream types Pyro IV a planet and the overlay
  renders it as a moon; measured by upstream type alone the moon tier stops at
  1,789 km and Pyro IV, at 3,214 km, falls outside its own scale.

## What the corrections buy

- **Pyro IV** is the outermost moon of Pyro V, not a planet, which matches both
  the starmap parent relationship and the wiki's own prose.
- **Delamar** is a protoplanet between Nyx II and Nyx III, though its starmap
  code still says `NYX.ASTEROID.DELAMAR`.
- RSI's code typos (`PRYO.MOONS.VUUR`, `PYRO.MOON.FAIRO`) never enter the system
  because the generator never reads `code` at all: a body's identity is its
  upstream name, and its page title is derived from that.

The cost is that a page move does not self-heal. `systems.json` stores titles
directly, so a moved article has to be fixed in the overlay and regenerated;
`Category:Pages with a broken system map link` is where it surfaces, alongside
the bodies nobody has written up yet. That category is mostly a content backlog
rather than a fault report — [[Template:System map]] documents how to read it.

## Tests

`Module:SystemMap/testcases`. Run locally with `mise run test:lua:unit SystemMap`.

The generator has its own suite in `scripts/internal/systemmap` (`cd scripts &&
go test ./...`), including the acceptance gate: regenerating must reproduce every
system captured in `internal/systemmap/testdata/systems.live.json` exactly as the
wiki serves it. The capture is taken from the wiki after a batch is deployed, and
widened rather than reset, so the gate only ever grows — but it therefore lags
the rollout by a batch. It currently holds Stanton, Pyro, Nyx, Terra and Castra.
Anything shipped since is checked only against the committed `systems.json`,
which cannot see a hand edit made on the wiki, so re-capture after deploying.
