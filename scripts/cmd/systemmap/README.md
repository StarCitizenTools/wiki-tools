# systemmap

Rebuilds `Module:SystemMap/systems.json`, the orbit-rail data behind
`{{System map}}`, from the ARK Starmap plus `pages/module/SystemMap/overlay.json`.
See [`../../README.md`](../../README.md) for how to run it. This file covers what
is specific to this data, and what the Lua side does with it.

The wiki-facing documentation is deliberately thin: `pages/module/SystemMap/README.md`
and `pages/template/System map/README.md` are deployed as `/doc` pages and only
tell an editor that the file is generated, where to go instead, and how to read
the rail. Everything else about this pipeline lives here.

## Two inputs, because they fail differently

```
scripts/out/starmap.json              upstream mirror, gitignored, refetched
pages/module/SystemMap/overlay.json   editorial corrections, committed, hand-owned
        |
        v
pages/module/SystemMap/systems.json   committed, deployed via MCP
```

Upstream data goes stale and gets refetched. Editorial judgement has to survive
that refetch: which article a body links to, which planet is really a moon, and
the handful of belt placements where the wiki's own articles disagree with
upstream. Before this tool both lived in the same hand-edited file, so the
refetch would have overwritten the judgement.

The line between the two moves as the derivation gets better, and it moves one
way. Where a belt sits used to be judgement, written out 58 times; carrying
upstream's `distance` through the mirror derived 50 of those, leaving the eight
the data cannot settle. Deriving something the overlay was carrying is a
strictly better outcome than transcribing it again, because a derivation holds
for the systems nobody has looked at yet.

**The output is committed source, not a `scripts/out/` artifact.** It is 10 KB,
it is reviewed as a diff, and the overlay only means anything next to it.

## What reads the output

| Page | Responsibility |
| --- | --- |
| `Module:SystemMap` | Entry point. Argument parsing, page-existence annotation, tracking categories. Hands the rail to `Module:CollapsibleCard` for the card shell and collapse. |
| `Module:SystemMap/Data` | System-name resolution, glyph classification, model building, body-count summary. Pure. |
| `Module:SystemMap/Renderer` | Model to HTML, the rail only; the card supplies the header. Pure. |
| `Module:SystemMap/systems.json` | This tool's output: the bodies of every rolled-out system, in orbital order. |
| `Module:SystemMap/styles.css` | TemplateStyles. |

Two tables span the boundary and have to be changed on both sides at once:
`SUBTYPE_KIND` in `Data.lua` against `vocab.go`, and `SCALE_TIER` in `Data.lua`
against the tiers this tool writes.

## The overlay fails loudly

A correction keyed to a body that is not there **stops the build**:

```
error: system Stanton: overlay corrects "Arccorp", which is not a body in this
system (it may have been renamed upstream, excluded, or misspelled here)
```

That is the design. A correction that silently stops matching is exactly how the
work gets lost: upstream renames something, the entry quietly becomes a no-op,
and the map ships with a missing icon or a body in the wrong orbit. The same
applies to `after` and `moonOf` targets, to systems, and to unknown keys in the
overlay itself.

Exclusion patterns are the one exception. They are global while the output is
only the systems the overlay lists, so a pattern matching nothing is reported as
a note rather than an error.

## What is derived, and what is not

| Derived | From |
|---|---|
| Orbital order | upstream `distance`, which orders **siblings** (see below); the Roman numeral ending the designation where it cannot |
| Moon attachment | upstream `parent_id` |
| Tier | the upstream type: a belt is `tier: belt`, and a `SATELLITE` that reached the planet rail because upstream parents it to the star is `tier: moon` (see below) |
| The second star, and how it is drawn | upstream `parent_id` between the two stars (see below) |
| Page title | the body's name, first letter upper-cased; `<System> (star)` for the star of a **single**-star system; `<System> system` for the system |
| Label | the upstream name, or its designation when upstream gives it no name |
| Size in km | the upstream size, by tier (see below) |
| Subtype and star class | explicit tables in `vocab.go` |
| Belt casing | the system name, then lower case: the designation always, and `label`/`page` too when upstream names the belt nothing (see below) |
| `extents`, the disc scale | every body in the whole mirror, by tier (see below) |

`code` is never read at all: a body's identity is its upstream name, and its page
title is derived from that. That is what keeps RSI's typos (`PRYO.MOONS.VUUR`,
`PYRO.MOON.FAIRO`) out of the file, and what makes `NYX.ASTEROID.DELAMAR`
harmless: Delamar is upstream's own `PLANET` of subtype `Protoplanet`, which the
overlay places between Nyx II and Nyx III. That one asserts the wrong *type*
rather than merely misspelling a name.

### The overlay's keys

Everything the table does not derive is an overlay key.

Per body, under a system's `bodies`: `page`, `label`, `icon`, `iconRatio`,
`after` (position a body upstream's own `distance` cannot order — eight of them,
listed below), `moonOf` (reparent, as Pyro IV under Pyro V), and `km`.

A star is corrected in a sibling `star` block rather than under `bodies`.
Terra's `"star": { "page": "Terra Nova" }` is the whole of it, and a second star
goes in a `companion` block beside it. Both take the same keys except `after`
and `moonOf`, which a body that holds no slot on the planet rail has no use for,
and their `km` is a radius. Filing a star under `bodies` fails the build with
`overlay corrects …` instead of being ignored, so the mistake costs a run rather
than producing a wrong map. So does a `companion` block on a system with one
star, and a `star` block on one of the two systems that have none.

Per system: `page` corrects the system's own article title, which is otherwise
`<upstream name> system`. Kyuk'ya needs it, because upstream still carries the
Perry Line name and calls the system `Kyuk'ya (Indra)`. `companionShape`
overrides how two stars are drawn and should be left alone, since it is derived
(see below).

A top-level `exclude` list, a sibling of `systems`, drops matching bodies from
every system; `*` is its only wildcard. A pattern names a body the way the
overlay does: plainly, or in the type-qualified form two bodies sharing a name
need, as `Ellis XI (PLANET)`. The plain form drops both, the qualified form
drops one. It currently carries upstream's protoplanetary disk placeholders
under both spellings, RSI's and its typo, and the skeletal protoplanet upstream
files under the same designation as Ellis XI's cluster, which is the body that
actually has an article.

### Orbital order comes from `distance`, and `distance` is parent-relative

**This is the one thing to get right here.** Upstream measures a body's
`distance` from its **parent**, not from the star, so it orders **siblings** and
nothing else. Every figure is a real number in the same unit, so a rail sorted
across parents renders without complaint and is simply wrong — which is the
failure mode that looks most like success.

Upstream's own data proves the rule twice over:

- Sol's planets are AU from the Sun — Mercury 0.4667, Earth 1.0, Neptune 30.44 —
  because the Sun is what upstream parents them to.
- Sol's rings are *thousandths* of an AU by exactly the same rule: Rings of
  Uranus 0.000234, Jovian Rings 0.000819. Those are distances from Uranus and
  from Jupiter.
- Taranis' debris field is `0.3`, measured from **Taranis II**, which upstream
  parents it to. Sorted against Taranis I's 0.94 it would take the innermost slot
  on a rail whose planet sits 4.62 AU out.

So the generator compares two distances only where both bodies share a parent:
the star's own children on the rail, and one planet's moons inside its column.

`orbit_period` is still **not** used — upstream leaves it null for 195 of its 326
planets.

**Two groups, two decisions, each taken once.** The choice of key is made for the
whole rail, and again for each planet's column, rather than per body. "Closer to
the star" and "numbered earlier" are different questions, and a comparison
answering one for some pairs and the other for the rest is not a total order: the
result would depend on which pairs `sort` happened to compare. So a rail falls
back to the numeral in full if *any* body it has to order lacks a distance or is
measured from somewhere else. Bodies the overlay has anchored with `after` are
not consulted — their position comes from the anchor — which is what lets Taranis
and Kallis keep distance ordering on the rest of their rails.

**The Roman numeral is the fallback, and the tiebreak.** It still reads the
numeral that ends the designation, not the body type, so a belt upstream
designates after a planet is ordered like one. It fires in two places now:

- where a distance is missing. Upstream leaves 13 objects without one: five
  stars, six planetary rings, Tamsa's black hole, and Kallis' accretion disk.
- where two distances are equal. Upstream files real ties — Kilian's three
  Sisters all sit at 0.1, Croshaw IV shares 2.76 with both of its clusters, and
  Nyx's Delamar ties Glaciem Ring at 2.1. A body with a numeral sorts ahead of
  one without, which is what keeps Croshaw IV in front of its clusters.

A body with no derivable position and no `after` lands at the end of the rail,
where it is visible rather than wrong.

### The eight `after` entries left

Carrying `distance` through the mirror retired **50 of the overlay's 58** `after`
entries: they were transcribing a position upstream had all along. Stanton's
`Aaron Halo` needed one because the belt has no numeral; upstream has had it at
1.563, between Crusader's 1.28 and ArcCorp's 1.933, the whole time.

The eight that remain are the ones upstream's numbers cannot retire, and they
divide into three kinds. **An `after` that agrees with `distance` is redundant;
one that disagrees is a signal**, so the disagreements are recorded rather than
deleted.

| Entry | Why it stays |
|---|---|
| Taranis / `Taranis 2a Debris` → Taranis II | measured from Taranis II, and no numeral either, so nothing else can place it |
| Kallis / `Kallis V Accretion Disk` → Kallis V | upstream gives it no distance at all |
| Nyx / `Delamar` → Glaciem Ring | ties the belt at 2.1; upstream cannot separate them |
| Croshaw / `Icarus Cluster` → Croshaw IV | ties Daedalus Cluster at 2.76; upstream cannot separate them |
| **Sol / `Kuiper Belt` → Neptune** | **disagrees**: 45 puts the belt beyond Pluto's 39.5; the article puts it before |
| **Taranis / `Taranis Belt Alpha` → Taranis II** | **disagrees**: 2.15 puts it inside Taranis II's 4.62 |
| **Taranis / `Taranis Belt Beta` → Taranis III** | **disagrees**: 3.39 puts it inside Taranis II's 4.62 |
| **Kallis / `Kallis Belt Beta` → Kallis III** | **disagrees**: 1.27 puts it outside Kallis IV's 1.09 |

The four disagreements are all belt placements taken from the belt articles' own
prose, and all four are live questions rather than settled ones. Sol's is the
sharpest: both figures are real AU, the article's "beyond Neptune… contains
objects such as Pluto" is a real claim, and deleting that one overlay line is the
whole change if an editor decides upstream is right.

Tanga was the fifth, and is the one that was **taken**. Its belt sits at 3.31
against Tanga I's 7.632, making it the innermost body — which is what
[[Tanga belt alpha]] itself describes, as the remnants of the system's former
inner planets from before the star expanded. The `after: Tanga I` it used to
carry came from one sentence that contradicted the rest of its own article.

`TestOnlyEightAfterEntriesSurvive` pins that table. A ninth appearing after a
refetch is upstream having moved something, and wants reading rather than
deleting.

### A moon column reads outward too

The same rule runs one level down, on the moons of one planet, with the lettered
designation (`5a`, `5b`, `5c`) as the fallback. Rings still sort ahead of every
moon, decided by role rather than by distance — six of the eleven carry no
distance at all, and one falling to the end of a column would claim the opposite
of what a ring is.

The two keys disagree in exactly one column in the file, and upstream's numbers
are right. **Saturn's** letters run Titan, Rhea, Tethys, Dione, Iapetus, which is
fame order; its distances run Tethys, Dione, Rhea, Titan, Iapetus, which is the
real Saturnian system. The letters are outward for every system CIG invented and
only for those, which is why the fallback is a fallback.

An overlay `moonOf` is what makes the parent test necessary here: a body moved
under a planet it is not upstream-parented to brings a distance measured from
somewhere else, and the column falls back to the letters rather than guessing.
The one live reparenting agrees with upstream — Pyro IV is upstream-parented to
Pyro V, which is exactly why `moonOf` is right about it.

## Sizes are three different units

Measured against the hand-written file, not taken from its `%doc`:

| Tier | Upstream unit | Rule |
|---|---|---|
| Planet | km | x1 |
| Moon | thousands of km | x1000 |
| Star, size < 1000 | solar radii | x696340, rounded to whole km |
| Star, size >= 1000 | km | x1, rounded to whole km |
| Belt | 0 or null | omitted; belts render as a fixed band |
| Ring | 0 or null | omitted, by role rather than by what the field holds |

The star cutoff is not a close call: across all 93 stars the largest solar-radii
value is 13.91 and the smallest kilometre value is 6,260. Sol sits at exactly
1.000, which is what identifies the unit.

**The rule is applied by upstream type, not by rendered position.** Pyro IV is a
planet the overlay reparents as a moon of Pyro V; converting it by its rendered
tier would multiply a 3,214 km planet by a thousand.

A belt carries no `km` because of what a belt is, not because the field is
empty. Most belts do report `0` or `null`, but four do not, and two of those are
live: Sol's Kuiper Belt reports `99999999.99999999` and Taranis 2a debris `0.15`.
Both draw the same fixed band as every other belt.

Note that `km` is a diameter for planets and moons but a *radius* for stars,
since 696340 is the Sun's radius. That is harmless, because the disc scale is
rank-preserving within a tier and never compares across tiers, but it is why the
`%doc` does not call the column a diameter.

## Tiers, and what the file marks

Every body carries a `tier`. Five of them describe a body's place on the rail:
`star`, `planet`, `belt`, `moon` and `ring`. Three of those scale, the ones with
a disc; the other two are drawn at a fixed size.

Three more tiers exist only in the render model. They are layout rather than
classification, and each is measured and coloured at the tier of what the body
actually is:

| Render tier | Is | Measured at |
|---|---|---|
| `companion` | the second star of a nested pair | `star` |
| `paired` | **both** stars of a co-orbiting pair, since neither is subordinate | `star` |
| `rail-moon` | a moon holding a slot on the planet rail | `moon` |

`SCALE_TIER` in `Data.lua` is that mapping, and a missing entry fails silently
twice: a neutral `unknown` glyph, and the wrong tier's scale.

The file marks tiers by exception. `bodies` is everything orbiting the star, in
orbital order, and anything unmarked there is a planet; a belt carries
`tier: belt`, and a moon upstream parents to the star rather than to a planet
carries `tier: moon`. A planet's `moons` array works the same way one level
down: a ring carries `tier: ring`, and anything unmarked is a moon.

## Glyphs

Twenty-two planet subtypes share eleven glyph kinds. `SUBTYPE_KIND` in
`Data.lua` holds that table and `vocab.go` carries the matching one, so change
them together. The grouping is deliberate: a 6-24px disc cannot carry
twenty-two distinguishable colours.

Stars need no table. Their kind falls out of `'star-' .. lower(class)`, where
`class` is the spectral letter, or the word `degenerate` or `neutron` for the
two remnants. Only `Neutron` genuinely has no letter: upstream's white dwarf
subtype ends in one, `White Dwarf-Degenerate-A`, and it is filed as `degenerate`
anyway, because a main-sequence A colour would be the wrong claim about a
remnant. That is an editorial call, and the one Oberon's star renders under.
`class` is **optional**: Variable, Subgiant and the fifteen stars upstream
leaves unclassified carry none, the key is simply absent, and the kind falls
back to a plain `star`.

Belts and rings short-circuit ahead of all of it and take their own kinds, so a
ring can never fall through to the moon disc and draw itself as the thing it
orbits alongside.

An unrecognised subtype renders a neutral grey disc rather than erroring, so an
upstream addition cannot break a published rail. It does block the build,
though: the generator refuses an unknown planet or star subtype outright
(`unknown planet subtype …`), so a system containing one cannot be regenerated
until the Go table has it too. Adding a subtype is a two-file job, not a styling
touch-up.

Subtype is never printed as text. It exists purely to pick the glyph, so a gas
giant reads as a banded amber disc and an ice giant as a banded cyan one, while
the card header describes the system by its contents instead, which a reader
cannot get from the picture at a glance.

## A belt's designation is lower-cased after the system name

Upstream writes `Stanton Belt Alpha`; the page says `Stanton belt alpha`. That is
house style for common nouns, not a judgement about any particular belt, so it is
derived here rather than written into the overlay 69 more times.

The rule anchors on the system name instead of a word count, because the name is
not always one word: `Ē'aluth (Eealus) Belt Alpha` and `Ail'ka Belt Alpha` are
both real designations. Two things are left alone:

- **Roman numerals.** `Ellis XI`, `Odin I`, `Hades IV split` and `Kallis V
  Accretion Disk` are designated after a planet, and that numeral is an orbital
  slot, capitalised everywhere else in the file (`Stanton I`, `Pyro V`).
- **Designations with no system prefix.** The nine `Rings of <planet>`
  designations, Stanton's `Ring of Yela` and Sol's `Jovian Rings`. There is
  nothing to anchor to, and guessing which word is a proper noun would be worse
  than doing nothing.

Belts only. A planet's `Stanton IV` is stored exactly as upstream writes it.

### It reaches `label` and `page` when upstream names the belt nothing

Upstream files 80 belt-shaped bodies, eleven of which are Planetary Rings and not
belts at all here (see below). Of the 69 that remain it names 21; the other 48,
across 30 systems, reach the output with no name at all. For those the key falls
back to the designation, so `label`, and `page` derived from it, *are* that
designation. The rule therefore applies to all three, and they agree.

Recasing only the designation would store one string in two cases: the rail would
print `Bacchus belt alpha` as a second line under `Bacchus Belt Alpha`, and `page`
would point at a title the wiki is turning into a redirect as those articles move
to sentence case.

A belt upstream **does** name keeps that name verbatim in `label` and `page`:
`Aaron Halo`, `Keeger Belt`, `Marisol Belt`, `Henge Cluster`, `Akiro Cluster`,
`Glaciem Ring`. It is a proper noun, not a description; lower-casing it would look
wrong and would red-link the article. Only its designation is house style, and the
two lines then say different things, which is what the rail prints both for.

Those six were every belt in the five systems live when the rule widened, which
is why reaching `label` and `page` changed nothing already published.

An overlay `label` is judgement and is stored exactly as written, capitals
included. It is the escape hatch for a belt whose article really is titled in
Title Case.

**The overlay key stays upstream's spelling.** An unnamed belt is keyed
`Gurzil Belt Alpha` even though the rail reads `Gurzil belt alpha`: the key is the
body's identity across a refetch, not a display string, and deriving it from the
house-styled label would make every correction depend on a rule that is allowed
to change. Keying the label you see fails the build rather than silently doing
nothing.

Four belt designations were hand-edited on the wiki before this tool existed (rev
374302, `Fix casing`) and the edit never reached git. The acceptance test now
gates on the live page for that reason; see
`internal/systemmap/testdata/README.md`.

## A second star, and which of two shapes it takes

Upstream has 93 stars across 90 systems. Five systems have two, none has three,
83 have one, and two, Min and Tamsa, have none at all.

Which star is the primary and how the pair is drawn are both derived from
`parent_id`:

| `parent_id` | Shape | Systems |
|---|---|---|
| one star parented to the other | `nested`, and the parented one is the companion | Tyrol, Kyuk'ya |
| neither parented | `paired`, no primary; file order is the designation's | Bacchus, Baker, Goss |

The distinction is real rather than a rendering preference. In both nested
systems every planet, belt and moon is *also* parented to the primary, so the
hierarchy is upstream's. In all three paired systems both stars sit at the same
distance from the barycentre (Bacchus A and B are both `0.0735`), and no body is
parented to either. Drawing a co-orbiting pair as a hierarchy would invent a
centre the data denies.

**The system's own `type` field is not consulted.** It says `BINARY` for four of
the five and `SINGLE_STAR` for Tyrol, which has two stars. Counting the stars is
the only reliable answer, and a test pins that.

Two derivations change when there are two stars, and neither touches a
single-star system:

- **The star's page title.** `<System> (star)` exists to disambiguate a star
  whose designation is just the system name. A binary's stars are already
  designated apart, and the convention's title does not exist on the wiki for any
  of the five: `Tyrol (star)` is a red link while `Tyrol A` and `Tyrol B` are
  articles. So a star sharing its system with another takes its own key as its
  title, like every other body.
- **A `companion` block in the overlay** corrects the second star, with the same
  keys `star` takes. Filing one on a system with a single star fails the build,
  the way any other correction that reaches nothing does.

`resolveStars` refuses three arrangements outright rather than guessing: three or
more stars, two stars each parented to the other, and a star parented to
something that is not the other star. It also refuses a system where any body is
parented to the companion. No companion carries a body anywhere in the dataset
today, and one that did would otherwise be drawn as orbiting the pair.

### What the rail does with the two shapes

The shapes are drawn differently, which is the point of deriving them. A
`nested` companion is placed under the primary, in the slot a moon takes:
`Data.lua` puts it in the star's `moons` list, so it comes out of the same
machinery every moon does. A `paired` pair shares one rail slot at the head, so
the orbit line, drawn on the rail's direct children, begins at the pair rather
than at either star.

- **A nested companion keeps star-tier sizing.** Tyrol B renders at 22.8px in the
  row where moons are 6-14px, with a star's spectral glyph. It is a star; drawn
  on the moon scale it would read as an absurd moon. This is what the `companion`
  entry in `SCALE_TIER` is for, and missing it fails silently twice, with an
  `unknown` glyph and the 30px star cap.
- **The you-are-here marker lands on the individual star, never on the pair.**
  Bacchus A and Bacchus B are separate articles, and a reader on either has to be
  able to find themselves, so a paired slot holds two independently markable
  `<li>` elements rather than one merged `A · B` label. It is also what lets each
  keep its own `data-kind`: Bacchus A is a G-type and B a K-type.

## A system with no star

Only one of the two starless systems is genuinely head-less, and only that one is
in the file.

Min still carries planets and moons, so the generator builds it with the `star`
key simply absent rather than refusing. `resolveStars` returns nothing and the
rail draws no head, which is the picture Min's own article describes: "its main
focus is not a star but, instead, a rogue gas giant with four orbiting moons".
Nothing in the model assumes a head, so adding Min was a data change rather than
a code change.

A head-less system takes no `star` block in the overlay. There is no body for it
to correct, so the generator refuses the build rather than discarding the entry:
`overlay corrects the star, but upstream files 0 stars here`. That check is
separate from the `companion` one because Min is the first system that can reach
the correction code with no primary at all; before it built, a `star` block could
not miss.

Tamsa is the one that looks the same and is not. Upstream files a head for it,
`TAMSA.STAR.TAMSA`, with both planets parented to it, but types it `BLACKHOLE`,
which is not a type the rail can draw, so it was dropped the way a jump point is.
That produced two planets orbiting nothing, on a system whose article opens "two
planets in orbit around a black hole" and whose head has an article of its own at
`Tamsa (black hole)`. Nothing would have reported it either:
`Category:Pages with a broken system map link` is built by walking the bodies in
the model, and this body never reached the model.

So that system is **refused**, not built headless: see `typeBlackHole` in
`internal/systemmap/vocab.go`, and Tamsa is not listed in the overlay. Rolling it
out means giving `BLACKHOLE` a kind in `vocab.go`, `SUBTYPE_KIND` in `Data.lua`
and a disc in `styles.css`, and it needs a decision the data does not supply:
upstream reports no `size` for it, so it has no diameter to scale. An overlay
`star` block cannot stand in for any of that.

## A moon with no planet to nest under

`moonParent` attaches a `SATELLITE` to the planet upstream gives as its
`parent_id`. One body in all 90 systems has no such planet: Odin's Gainey, which
upstream parents to the **star**. It stays on the planet rail rather than being
dropped or forced under an unrelated planet, but it is still a moon, and the file
says so with `tier: moon`.

The marker exists because position is otherwise read as nature. The top level of
`bodies` means "planet" by omission, so without it Gainey was a planet to
everything downstream: `Data.summarise` called Odin a four-planet system when it
has three planets and two moons, `discSize` scaled a 1,789 km body against the
planet range, and `glyphKind` returned the neutral `unknown` disc, because only
planets and stars carry the subtype a colour is keyed off. `Module:SystemMap`
lays it out as a rail column and takes everything else about it from the moon
tier.

This costs nothing on a published page, which is the reason it could be fixed
rather than deferred: 1,789 km is inside the recorded moon range (44.6-3,214) as
well as the planet one, so no live disc moves. `extents` has always measured this
body at the moon tier, by its upstream type; the two passes simply disagreed.

## A planetary ring nests where a moon nests

Upstream types its eleven rings `ASTEROID_BELT`, the same as the regions on the
planet rail, and only the subtype `Planetary Ring` separates them. That type is
misleading: a ring orbits a planet, not a star, and drawing it out on the rail
would put it in an orbital slot.

So a ring is written into its planet's `moons` array, marked `tier: ring`. The
rail nests exactly one level and that is the level, which is the whole reason
this needs no new structure. A ring is emphatically **not** a moon, though, so it
carries its own glyph kind and `Module:SystemMap/styles.css` draws it as a flat
speckled band rather than a disc. It sorts ahead of its planet's moons, because
the moon column reads outward from the planet and a ring is inside them, and
`Data.lua` counts it separately: Sol reads `9 planets, 19 moons, 4 rings,
2 belts`.

Ten of the eleven orbit a planet and render, once their system is rolled out. The
eleventh, Stanton's `Ring of Yela`, orbits a **moon**, and a ring of a moon would
need a second level of nesting for one body in all 90 systems. It is dropped,
which is also the honest answer for it: it has no article under any title, so
there would be nothing to link even with somewhere to put it.

Two rules follow, and both are about pages that are already published:

- **A ring carries no `km`, decided by its role and not by its size field.**
  All eleven report 0 or null today, so the data cannot distinguish "a ring has
  no diameter" from "this field is empty", and a size that slipped through would
  be measured at the moon tier and resize every moon on every live page.
- **`extents` ignores rings in both passes.** The upstream pass skips them by
  subtype rather than relying on their type being one the tier map misses.

The belt casing rule does not reach them: every ring designation is either
`Rings of <planet>` or Sol's `Jovian Rings`, neither of which starts with the
system name, and the planet in that name is a proper noun.

## Adding a system

1. Add its name to `systems` in the overlay, in the position it should appear.
   An empty entry is valid and means nothing needed correcting.
2. Run `mise run systemmap` and read the diff.
3. Read where the belts landed. Upstream's `distance` places 62 of the 69, so
   this is no longer the per-system cost it was — but check each against the
   belt article's own prose, and write an `after` only where the two genuinely
   disagree. Four such disagreements exist today and all four are recorded above.
4. Check the star's page title. `<System> (star)` is the convention for a system
   with one star, but Terra's star is `Terra Nova`; a binary's stars take their
   own designations, `Tyrol A` and `Tyrol B`.
5. Verify every title the run emits against the wiki with `redirects=1`, and
   **compare the redirect target** rather than only asking whether the page
   exists. A redirect passes an existence probe while pointing somewhere else:
   `Charon` resolves to `Charon system`, and `Kyuk'ya Belt Alpha` to
   `Kyuk'ya belt alpha`.
6. Add the system to `internal/systemmap/testdata/starmap.json`, or the
   reproduction test will fail. See the README there.

Every subtype and star class upstream ships is already mapped, so a new system
needs no code change unless CIG adds a vocabulary term.

Titles are stored rather than looked up, so this does not self-heal: a moved
article has to be corrected in the overlay and regenerated.
`Category:Pages with a broken system map link` is where that surfaces on the
wiki, alongside the bodies nobody has written up yet, so the category is mostly a
content backlog rather than a fault report.

## Disc sizes are schematic, and anchored

**Disc size carries no measurement.** Within a tier the mapping is logarithmic
between that tier's smallest and largest body: rank-preserving, not proportional.
Pyro V is 6.6x Hurston by diameter and renders about 1.3x. A linear map would put
the smallest planet at well under a tenth of a pixel. Gas and ice giants are
therefore distinguished by banding rather than by diameter, which is also all the
upstream data supports: `size` is incoherent across tiers (the Stanton star is
`1.2` while Pyro's is `571000.44`), and `orbit_period` is null for every Stanton
moon. Belts and rings sit outside this entirely, at a fixed size.

`Module:SystemMap/Data.lua` scales each disc against the largest and smallest
body of its tier, so a body is the same size whichever map it appears on. Those
bounds are written into `systems.json` as an `extents` block, computed here
across **all 90 upstream systems** rather than across the handful the file
renders.

That is what makes the sizes stable. While `Data.lua` measured the file itself,
every rollout batch resized the discs on every page already published: adding
Terra and Castra alone moved Nyx's star from 30.0px to 24.3px, and finishing the
rollout would have moved it again to 26.4px. Nothing errored and no test failed.

The block is the **union** of two measurements, and both are needed:

- every upstream body, by its upstream type, which is the stable half;
- every body this file writes, by the tier it renders at.

The second is not tidiness. The moon maximum across all 90 systems is 1,789 km
(Gainey), while Pyro IV sits in the file as a moon at 3,214 km, because upstream
types it a planet and the overlay reparents it. Without the union it would be
outside its own scale.

`Data.lua` falls back to measuring the file when the key is absent, so an older
copy still renders, and clamps anything outside the range to the tier's cap.

Consequences for a rollout:

- **Adding a system no longer rescales the live pages.** That was the point.
- **Do not hand-trim `extents` to the systems in the file.** It is meant to
  reach past them. A body outside its tier's range is clamped to whichever end it
  fell past, the tier floor below or the tier cap above, which draws two
  different sizes identically.
- A refetch that finds a new upstream extreme *does* move the scale, once,
  everywhere. That is a real visual change and worth a look in a browser;
  `mise run systemmap:diff` reports it as its own line.

## Tests

`cd scripts && go test ./...` runs this package's suite in
`internal/systemmap`, including the acceptance gate: regenerating must reproduce
every system captured in `internal/systemmap/testdata/systems.live.json` exactly
as the wiki serves it. The capture is widened rather than reset, so the gate only
ever grows, but it therefore lags the rollout: anything shipped since the last
capture is checked only against the committed `systems.json`, which cannot see a
hand edit made on the wiki. Re-capture after deploying.
`internal/systemmap/testdata/README.md` covers the fixtures and how to refresh
them.

The Lua side has its own suite at `Module:SystemMap/testcases`, run locally with
`mise run test:lua:unit SystemMap`.
