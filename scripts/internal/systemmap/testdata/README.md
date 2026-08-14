# testdata

`starmap.json` is a cut of a real `cmd/starmap` run, eighteen systems wide:

| System | Why it is here |
|---|---|
| Stanton | live on the wiki; the reproduction gate. Also the only system whose Planetary Ring orbits a moon (`Ring of Yela`) and so must **not** render, plus jump points, landing zones and stations that must not reach the rail |
| Pyro | live; the `moonOf` reparenting (Pyro IV under Pyro V) and two `iconRatio` corrections |
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
| Min | not in the file; one of the two systems upstream files **no star** for. It carries a planet and four moons, so it is the case that proves a headless rail is still worth drawing |
| Tamsa | not in the file; the other starless system, and the one whose planets are parented to a star id that is not in the data at all |

Only the fields `internal/systemmap` reads are kept — id, code, name,
designation, size, type, subtype, star_system_id, parent_id — so the file stays
short enough to read against the output it is expected to produce. The values
are verbatim, not invented: the point of a fixture here is that upstream's
oddities (null names, trailing spaces in designations, sizes in three different
units) are present exactly as they arrive.

Min and Tamsa are the two systems that are here without being in `overlay.json`,
because what they prove is that the model does not assume a star: neither is
rolled out, and `TestBuildWithoutAStar` builds them through a throwaway overlay
of its own.

### It does not set the disc scale

`systems.json` records `extents` — the smallest and largest `km` per tier — and
those are anchored to **all 90 upstream systems**, not to these eleven. So the
`extents` block a test builds from this cut is legitimately narrower than the
committed one, and neither reproduction test compares it. Two tests check the
relation that must hold instead: `TestCommittedExtentsContainTheFixture` (the
eleven are a subset, so their range must sit inside the committed one) and
`TestCommittedExtentsReachBeyondTheFile` (the committed range must be wider than
the systems the page renders, or the anchoring has been lost).

## Refreshing it

`TestReproducesTheCommittedFile` compares against the committed
`pages/module/SystemMap/systems.json`, so the two move together. If upstream
changes a value, regenerate the page **and** refresh this fixture in the same
commit, or the test will fail on a difference that is real:

```sh
mise run starmap                     # refresh scripts/out/starmap.json
# then cut it down again, keeping the same eleven systems and the same field list
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
