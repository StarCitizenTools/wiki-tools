# systemmap

Rebuilds `Module:SystemMap/systems.json` — the orbit-rail data behind
`{{System map}}` — from the ARK Starmap plus `pages/module/SystemMap/overlay.json`.
See [`../../README.md`](../../README.md) for how to run it; this file covers what
is specific to this data.

## Two inputs, because they fail differently

```
scripts/out/starmap.json              upstream mirror, gitignored, refetched
pages/module/SystemMap/overlay.json   editorial corrections, committed, hand-owned
        |
        v
pages/module/SystemMap/systems.json   committed, deployed via MCP
```

Upstream data goes stale and gets refetched. Editorial judgement — which article
a body links to, where a belt sits between planets, which planet is really a moon
— has to survive that refetch. Before this tool both lived in the same
hand-edited file, so the refetch would have overwritten the judgement.

**The output is committed source, not a `scripts/out/` artifact.** It is 10 KB,
it is reviewed as a diff, and the overlay only means anything next to it.

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

Exclusion patterns are the one exception — they are global while the output is
only the systems the overlay lists, so a pattern matching nothing is reported as
a note rather than an error.

## What is derived, and what is not

| Derived | From |
|---|---|
| Orbital order | the Roman numeral ending the upstream designation |
| Moon attachment | upstream `parent_id` |
| Page title | the body's name, first letter upper-cased; `<System> (star)` for stars; `<System> system` for the system |
| Label | the upstream name, or its designation when upstream gives it no name |
| Size in km | the upstream size, by tier (see below) |
| Subtype and star class | explicit tables in `vocab.go` |
| Belt designation casing | the system name, then lower case (see below) |
| `extents`, the disc scale | every body in the whole mirror, by tier (see below) |

Everything else is an overlay key: `page`, `label`, `icon`, `iconRatio`,
`after`, `moonOf`, `km`.

`orbit_period` is **not** used. Upstream leaves it null for 195 of its 326
planets, while 320 carry a Roman numeral, and planets are numbered outward from
the star by convention. Sorting Stanton by numeral reproduces
Hurston → Crusader → ArcCorp → microTech exactly. A body with no numeral (every
belt, and Delamar) has no derivable position and takes one from `after`; without
it, it lands at the end of the rail, where it is visible rather than wrong.

## Sizes are three different units

Measured against the hand-written file, not taken from its `%doc`:

| Tier | Upstream unit | Rule |
|---|---|---|
| Planet | km | x1 |
| Moon | thousands of km | x1000 |
| Star, size < 1000 | solar radii | x696340, rounded to whole km |
| Star, size >= 1000 | km | x1, rounded to whole km |
| Belt | 0 or null | omitted; belts render as a fixed band |

The star cutoff is not a close call: across all 93 stars the largest solar-radii
value is 13.91 and the smallest kilometre value is 6,260. Sol sits at exactly
1.000, which is what identifies the unit.

**The rule is applied by upstream type, not by rendered position.** Pyro IV is a
planet the overlay reparents as a moon of Pyro V; converting it by its rendered
tier would multiply a 3,214 km planet by a thousand.

Note that `km` is a diameter for planets and moons but a *radius* for stars,
since 696340 is the Sun's radius. That is harmless — the disc scale is
rank-preserving within a tier and never compares across tiers — but it is why
the `%doc` does not call the column a diameter.

## A belt's designation is lower-cased after the system name

Upstream writes `Stanton Belt Alpha`; the page says `Stanton belt alpha`. That is
house style for common nouns, not a judgement about any particular belt, so it is
derived here rather than written into the overlay 69 more times.

The rule anchors on the system name instead of a word count, because the name is
not always one word — `Ē'aluth (Eealus) Belt Alpha` and `Ail'ka Belt Alpha` are
both real designations. Two things are left alone:

- **Roman numerals.** `Ellis XI`, `Odin I`, `Hades IV split` and `Kallis V
  Accretion Disk` are designated after a planet, and that numeral is an orbital
  slot — capitals everywhere else in the file (`Stanton I`, `Pyro V`).
- **Designations with no system prefix.** The sixteen `Rings of <planet>` belts
  and Sol's `Jovian Rings`. There is nothing to anchor to, and guessing which
  word is a proper noun would be worse than doing nothing.

Belts only. A planet's `Stanton IV` is stored exactly as upstream writes it.

Four of these were hand-edited on the wiki before this tool existed (rev 374302,
`Fix casing`) and the edit never reached git. The acceptance test now gates on
the live page for that reason; see `internal/systemmap/testdata/README.md`.

## Adding a system

1. Add its name to `systems` in the overlay, in the position it should appear.
   An empty entry is valid and means nothing needed correcting.
2. Run `mise run systemmap` and read the diff.
3. Place the belts with `after`, from the belt articles' own prose. Upstream
   cannot supply this for any of its 80 belts, and it is the main per-system
   cost.
4. Check the star's page title. `<System> (star)` is the convention, but Terra's
   star is `Terra Nova`.
5. Add the system to `internal/systemmap/testdata/starmap.json`, or the
   reproduction test will fail. See the README there.

Every subtype and star class upstream ships is already mapped, so a new system
needs no code change unless CIG adds a vocabulary term.

## Disc sizes are anchored to the whole dataset

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

- every upstream body, by its upstream type — the stable half;
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
  reach past them.
- A refetch that finds a new upstream extreme *does* move the scale, once,
  everywhere. That is a real visual change and worth a look in a browser;
  `mise run systemmap:diff` reports it as its own line.
