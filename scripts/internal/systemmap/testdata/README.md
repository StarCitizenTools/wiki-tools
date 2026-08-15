# testdata

`starmap.json` is a cut of a real `cmd/starmap` run, seventy-six systems wide.
The fixture holds every system `overlay.json` lists, because a system in the
overlay that is missing here fails `TestReproducesTheCommittedFile`, plus two the
overlay deliberately does not list: Gurzil, whose placeholders the exclusion
patterns are tested against, and Tamsa, which a test builds to check that it is
*refused*.

The table below is not a manifest — it is the reason each system earns its place
in a fixture meant to stay readable. The rows are the ones that pin a distinct
behaviour; the forty-two that only pin "the derivation is right for an ordinary
system" share the last two rows rather than taking one each.

| System | Why it is here |
|---|---|
| Stanton | live on the wiki; the reproduction gate. Also the only system whose Planetary Ring orbits a moon (`Ring of Yela`) and so must **not** render, plus jump points, landing zones and stations that must not reach the rail |
| Pyro | live; the `moonOf` reparenting (Pyro IV under Pyro V) and two `iconRatio` corrections. Also the first of the four distance ties: Pyro I and Akiro Cluster both sit at 0.553, and the mirror files the cluster first |
| Nyx | live; `after` chained onto another `after` (Delamar behind Glaciem Ring), and the only planet with no Roman numeral |
| Terra | live; four planets, four moons, two belts, and the star whose page title breaks the convention |
| Castra | live; the smallest system that renders |
| Gurzil | the nine `Protoplanetary Disk N` placeholders, two of them misspelled upstream, alongside one real belt |
| Sol | in the file; four planetary rings, the tier-within-a-tier the moons array carries, and three `page` corrections (`Mercury (planet)`, `Charon (moon)`, `Oberon (moon)`) |
| Ellis | in the file; the only system in all 90 where two bodies share a key. Its eleventh planet collided with its moon, and upstream records both halves unnamed and designated `Ellis XI` — which is what the type-qualified overlay key exists for, and what `exclude` uses to drop the skeletal duplicate. Also a ring that is its planet's only child |
| Kilian | in the file; fourteen planets, no moons, no belts, and nothing to correct — the shape a system takes when the derivation is right |
| Taranis | in the file; three bodies anchored with `after`, two of them onto the same planet, so the overlay's key order decides which comes first |
| Oberon | in the file; the only degenerate star in the file (`star-degenerate`) |
| Tyrol | in the file; a **nested** binary — the companion is parented to the primary, which carries all nine bodies. Also the system upstream types `SINGLE_STAR` while filing two stars for it, which is why the shape is derived from `parent_id` and not from that field |
| Kyuk'ya (Indra) | in the file; the other nested binary, and the only system needing a `page` correction — upstream carries the Perry Line name, the wiki files it under `Kyuk'ya system`. Also a named belt whose article is under a different title entirely |
| Bacchus | in the file; a **paired** binary, listed B before A upstream, so it pins that file order does not decide which star is written first |
| Baker | in the file; a paired binary whose **B is the larger star**, so it pins that size does not decide either |
| Goss | in the file; the third paired binary, and the only one whose middle planet is named (`Cassel`) rather than taking its designation |
| Odin | in the file; the only body in all 90 systems that upstream types a `SATELLITE` and parents to the **star** — Gainey, which therefore lands on the planet rail rather than nesting, carries no subtype, and is placed with an `after` because `Odin 1a` ends in no Roman numeral. It is the only body marked `tier: moon` at the top level, which is what keeps it measured, coloured and counted as the moon it is rather than as the planet its position would imply |
| Helios | in the file; the **largest planet in the dataset** (Helios III, 137,932 km) and so the planet tier's recorded cap, plus a moon upstream leaves unnamed whose article is under a name of its own (`Helios 2a` → `Marama`) |
| Kai'pua (Kayfa) | in the file; the system where **every** title needed correcting — six entries, the whole system, including a star page the wiki titles with U+2019 while the rest of the system uses U+0027 |
| R.il'a (Rihlah) | in the file; the second Perry Line alias, and the trailing spaces upstream leaves on a star designation and two planet names — the reason `bodyKey` and `upstreamName` trim |
| T.āl | in the file; the star whose upstream designation (`Tal`) drops the macron the wiki uses, so `label` is corrected while the derived page title is already right |
| Kellog | in the file; a name upstream mis-cases (`Quarterdeck`), where the wiki's own styling is canonical and both `page` and `label` are corrected — the reverse of microTech |
| Geddon | in the file; one planet, whose upstream name (`Takto`) has no article under any title, so it is the batch's only red link before correction |
| Banshee | in the file; the only `Neutron` star, the one subtype whose glyph class is a word rather than a spectral letter |
| Nul | in the file; a `Variable` star, which carries **no** `class` key at all and falls back to the plain `star` glyph |
| Chronos | in the file; `Chronos I ` carries a trailing space in its **designation**, which the orbital-numeral rule has to trim before it can read the numeral |
| Davien | in the file; the smallest system with a moon — one `SATELLITE`, parented to a planet, the ordinary case |
| Min | in the file; one of the two systems upstream files **no star** for. Its rail is headed by a rogue gas giant carrying four moons, which is what the article describes too, so a headless rail is the correct picture |
| Tamsa | **not** in the file, and here for that reason: it is the other system upstream files no `STAR` for, but it is not headless. Upstream files a head — `TAMSA.STAR.TAMSA`, id 2521, with both planets parented to it — and types it `BLACKHOLE`, a type the rail has no tier or glyph for. The parent id resolves perfectly well; the object is filtered out by type before the rail is built, which is why the wiki's own [[Tamsa (black hole)]] would be missing from a map of the system it defines. `TestBuildRefusesASystemHeadedByABlackHole` reads this system, so the fixture has to keep it |
| Kilian, Croshaw, Kabal | in the file; the three systems where upstream ties two bodies at the same distance and the Roman numeral has to break it — Kilian's three Sisters at 0.1 apiece, Croshaw IV against both of its clusters at 2.76, Kabal III against its cluster at 1.84. Pyro is the fourth, and has its own row above. In every one of the four the mirror files the loser FIRST, which is what makes them a real test of the tiebreak rather than of upstream's file order |
| Kallis | in the file; the only body in all 90 systems upstream gives **no** distance at all (`Kallis V Accretion Disk`), so its `after` is the one that cannot be retired, plus a second belt whose article disagrees with upstream about where it sits |
| Tanga | in the file; one of the three systems this change reorders. Its belt sits at 3.31 against Tanga I's 7.632, so upstream puts it inside the first planet, and the retired `after: Tanga I` had it the other way round |
| Gliese | in the file; three unnumbered regions interleaved with six planets, all placed by `distance` alone — the densest case of the rule that retired 50 `after` entries |
| Bremen, Branaugh, Caliban, Cano, Cathcart, Centauri, Corel, Elysium, Ferron, Fora, Garron, Genesis, Hades, Hadrian, Horus, Idris, Kiel, Kins, Leir, Magnus, Nemo, Oretani, Oso, Osiris, Oya, Rhetor, Tayac, Tohil, Trise, Vanguard, Virgil, Yulin | in the file; ordinary systems that needed no correction at all. They are here because the overlay lists them, and they are worth keeping: between them they cover most of the 22 planet subtypes and six of the spectral classes |
| Ail'ka, Charon, La'uo (Virtus), Nexus, Orion, Th.us'ūng (Pallas), Tiber, Vega, Yā'mon (Hadur), Ē'aluth (Eealus) | in the file; systems whose only corrections are titles and labels — a page the wiki files elsewhere, a name upstream spells differently. They pin nothing about the derivation that the rows above do not, and they are here because the overlay lists them |

Only the fields `internal/systemmap` reads are kept — id, code, name,
designation, distance, size, type, subtype, star_system_id, parent_id — so the
file stays short enough to read against the output it is expected to produce. The
values are verbatim, not invented: the point of a fixture here is that upstream's
oddities (null names, trailing spaces in designations, sizes in three different
units) are present exactly as they arrive.

### `objects` is in the mirror's order, and that is load-bearing

The generator reads file order as a last-resort tiebreak — `node.order`, which
decides a distance tie with no numeral to settle it, a moon-letter tie, and which
star of an unparented pair is written first. A fixture in an order of its own
therefore hands those rules the answer, and the tests that name them pass with
the rule deleted.

This file was id-sorted until 2026-08-14, and `cmd/starmap` sorts by
`strings.ToUpper(code)`, so the two disagreed wherever it mattered: Kilian
arrived `I, II, III` here and `I, III, II` in production, and Bacchus arrived
`A, B` here and `B, A` in production. Both the numeral tiebreak and the pair
ordering were unpinned as a result — removing either left the whole suite green
while reordering four live rails and two binaries. It is now cut in the mirror's
order, which is what production reads.

So: **preserve `scripts/out/starmap.json`'s object order when you re-cut**. Do
not sort by id, and do not sort by anything else for readability. `systems` is
sorted by name and may stay that way — `Build` looks systems up by name from the
overlay's roster, so nothing reads their file order.

Gurzil is one of the two systems here that `overlay.json` does not list, and it
is carried for a reason other than reproduction: its nine `Protoplanetary Disk N`
placeholders are what the exclusion patterns are tested against, and excluding a
body has to work whether or not its system renders. Tamsa is the other, for the
reason its row gives.

`TestBuildWithoutAStar` still builds Min through a throwaway overlay of its own
rather than reading the committed one, so the starless case stays pinned
independently of whether the system is rolled out. Its opposite number,
`TestBuildRefusesASystemHeadedByABlackHole`, does the same with Tamsa: a system
whose head is a type the rail cannot draw must fail the build rather than render
a rail with nothing at its centre.

### It does not set the disc scale

`systems.json` records `extents` — the smallest and largest `km` per tier — and
those are anchored to **all 90 upstream systems**, not to this cut. So the
`extents` block a test builds from this cut is legitimately narrower than the
committed one, and neither reproduction test compares it. Three tests check the
relations that must hold instead: `TestCommittedExtentsContainTheFixture` (the
cut is a subset, so its range must sit inside the committed one),
`TestCommittedExtentsContainTheRenderedRange` (every body the page renders falls
inside the recorded range, so nothing is clamped to a bound), and
`TestCommittedExtentsAreTheAnchoredValues`, which pins the six figures outright —
the only one of the three that a finished rollout cannot make vacuous.

## Refreshing it

`TestReproducesTheCommittedFile` compares against the committed
`pages/module/SystemMap/systems.json`, so the two move together. If upstream
changes a value, regenerate the page **and** refresh this fixture in the same
commit, or the test will fail on a difference that is real:

```sh
mise run starmap                     # refresh scripts/out/starmap.json
# then cut it down again, keeping the same systems, the same field list,
# and the mirror's object ORDER (see above — sorting it re-blinds two rules)
mise run systemmap                   # rewrite the page from the new mirror
```

Adding a system to the overlay that is not in this cut also fails the test, for
the same reason — add it here too.

## `systems.live.json`

**The acceptance gate's baseline.** `TestReproducesTheLivePage` checks that
regenerating reproduces every system in this capture — Stanton, Pyro, Nyx, Terra
and Castra — exactly as `Module:SystemMap/systems.json` serves them. Whatever it
holds is what is gated, so re-capturing after a deployment widens the gate rather
than resetting it: it went from three systems to five when Terra and Castra
shipped.

It is the live page rather than the repo copy because the two had drifted.
Revision 374302 (2026-08-13, `Fix casing`) lower-cased four belt designations on
the wiki — `Stanton Belt Alpha` → `Stanton belt alpha`, and the same for Pyro's
cluster and Nyx's two belts — and that edit was never mirrored back to git.
Validating the generator against the committed file would therefore have
certified a build that quietly reverted a real editorial decision on the 42
pages those three systems render — their own footprint, not the whole rollout's,
so do not "update" that count to the current page total. The casing is a
derivation rule now (`beltCase`), which is what makes those bytes reproducible
instead of transcribed.

Captured verbatim, so it has **no trailing newline** — MediaWiki does not store
one, and `.editorconfig` exempts this path so an editor cannot silently add it.
Only the `systems` object is compared: `%doc` and `extents` are this package's
own output, and comparing them would gate on whichever build happened to be
deployed rather than on the editorial content.

Re-capture it after deploying, or after somebody edits the page by hand:

```sh
curl -s 'https://starcitizen.tools/index.php?title=Module:SystemMap/systems.json&action=raw' \
  -o scripts/internal/systemmap/testdata/systems.live.json
```

A hand edit that shows up here is a question, not a diff to absorb: decide
whether it is a derivation rule (write it in the generator, as the casing was) or
a judgement (write it in `overlay.json`), then re-capture. Re-capturing first
turns the gate into a rubber stamp.

## `systems.hand-written.json`

The page as it stood before this package took ownership of it: Stanton, Pyro and
Nyx, typed by hand and edited on the wiki. It is frozen, and it is the only copy
of this file's format that `Encode` did not author, which is the whole reason it
is kept — `TestEncodeRoundTripsTheHandWrittenFile` reads it to check tab
indentation, key order, the trailing newline and float formatting.

Pointing that test at the live `systems.json` instead looks equivalent and is
not: that file is now `Encode`'s own output, so decode-then-encode is idempotent
by construction and the test cannot fail. It is deliberately never regenerated.
