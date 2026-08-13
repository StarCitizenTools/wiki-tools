# itemstubs

Plans `{{Entity}}` stub pages for datamined items that are missing from the
wiki. See [`../../README.md`](../../README.md) for how to run it; this file
covers the filter chain, the config it's driven by, and the plan it writes.

## What it plans

The source of "missing" is a comparison between two sets of uuids: every item
in the [scunpacked-data](https://github.com/StarCitizenWiki/scunpacked-data)
`items.json` dump, and every uuid the wiki has annotated via SMW's `Uuid` /
`UUID` properties (the same scan `uuidindex` uses, via
`uuidindex.ScanProperties`). An item whose uuid the wiki doesn't know about is
a candidate; everything else in this tool is deciding which candidates are
real and rendering the ones that are.

## Filter chain

`itemstubs.Classify` runs every item through these dispositions in order —
first match wins:

| Disposition | Meaning | Recorded in |
|---|---|---|
| `exists` | uuid already annotated on the wiki | `skipped.exists` |
| `blocked` | unnamed item (built-in), or matches a config `blocklist` pattern | `skipped.blocked.<ruleId>` |
| `unmapped` | dump `Type` has no entry in config `types` | `unmappedTypes` (see below) |
| `excluded` | `types` entry is `"skip": true` | `skipped.excluded` |
| `review` | type is allowlisted, but the item also matches a config `review` pattern | `conflicts` (`review:<ruleId>`) |
| `create` | passed every filter | attempted stub build |

`unnamed` (name empty, or equal to the class name) and `placeholder-uuid` are
the built-in rules rather than config: a nameless item has no page title to
give it, and the all-zeros uuid is never indexed by the wiki, so both are
structural facts about the dump, not editorial judgements.

A note on `nonPuItem`'s class suffixes: `_tow` marks items that exist only in
the Theatre of War game mode, not the persistent universe — same reasoning as
`_gungame` and `_ea_elim`. The suffix has nothing to do with towing.

Passing the filter chain does not guarantee a create entry. Manufacturer
resolution and the title check against the live wiki can still turn a
`create`-disposed item into a conflict:

| Conflict `reason` | Cause |
|---|---|
| `no-manufacturer` | dump carries no usable manufacturer and no config rule resolves one |
| `invalid-title` | the item's name can't be a wiki title as-is (locally, or the API rejects it) |
| `duplicate-name` | two or more missing items would render the same title |
| `title-exists` | a page already exists at that title, but without this uuid |
| `review:<ruleId>` | the item matched a `review` pattern (see below) |
| `unknown-title-status` | the wiki's title-check response didn't classify this title at all (an API quirk); resolve by hand |

**Why most `title-exists` conflicts are noise.** CIG reuses localisation
strings for items that were never implemented, so a large share of
`title-exists` hits are an unimplemented item sharing a name with the real
one the wiki already documents — measured at 87 of 101 on a sample dump. The
two are structurally identical in the API (same `is_base_variant`, `rarity`,
price presence), so the tool cannot tell which one deserves the page — and
one case even inverts: the wiki page holds the placeholder and the flagged
item is the real one. It therefore never auto-dismisses or auto-picks a
`title-exists` conflict; it only attaches evidence about what the page
already documents, so a human can judge at a glance:

- `onPageUuid` — the uuid the existing page already documents (looked up from
  the same `uuidindex` scan `wiki` comes from), when known.
- `onPageClass` — that item's dump class name, when its uuid also resolves to
  an item in the current dump.
- `sameDescription` — whether that item's `Description` is byte-identical
  (after trimming whitespace) to the flagged item's. **A match is evidence
  for the reviewer, not grounds for the tool to drop the item** — the page
  sometimes documents the placeholder, so a `true` here still needs a human
  read, not an automatic skip.

All three fields are set together or not at all: they're omitted when
`onPageUuid` has no entry in `wikiByPage` (the page wasn't found by the
uuidindex scan) or when that uuid doesn't resolve to an item in the dump.

## Config semantics

Everything editorial lives in the committed `config.json`, not Go source —
scope changes are PR-reviewed data.

**A type's `types` entry has two ways to mean "no pages," and they are not
the same:**

- **Absent** (no key for the dump `Type` at all) means *nobody has decided
  yet*. Every item of that type is reported under `unmappedTypes` — count and
  a sample name — on every run, until someone allowlists or skip-lists it.
  Unmapped types are a to-do list, not a rejection; they don't count toward
  `-diff`'s drift.
- **`"skip": true`** means *decided: no pages*. Matching items are counted in
  `skipped.excluded` and nothing more — no per-run report, no drift. A skip
  entry must not also carry `kind` or `label` (config validation rejects
  that); an active entry must carry both.

**`review` rules never decide — they only flag.** A pattern rule under
`review` (matched the same way as `blocklist`: whole-name matches
(`nameExact`), name/class-name substrings or prefixes/suffixes, plus
`descContains` against the dump's description) does not skip the item and
does not create it either: it downgrades an otherwise-createable item into a
`conflicts` entry, with the rendered wikitext attached so the applying agent
only has to judge, not draft. `nameExact` matches the whole name rather than a
substring or prefix — it exists for short placeholder names ("PH", "TBD")
that would otherwise swallow real items sharing the same start or fragment.

**A type's lead links its `label`** to a wiki article: `[[label]]` by
default, `[[labelLink|label]]` when the article name differs from the label
text (`WeaponGun.Gun`'s label "vehicle weapon" links to `[[Gun|vehicle
weapon]]`), and `"noLabelLink": true` when no article exists for the label at
all — the label then renders as plain text instead of a red link repeated on
every page of that type. `labelLink` and `noLabelLink` are mutually
exclusive; config validation rejects a type that sets both.

The seeded config uses this for **built-in ship hardware**: gear bolted to one
hull that a player can never buy, fit, or replace, which earns no page. Whole
types that are only ever built-in (`MissileLauncher.MissileRack`,
`BombLauncher.BombRack`) are `skip: true` instead. But the same hardware also
hides inside types that are otherwise perfectly replaceable — the 890 Jump's
jump module sits among ordinary jump modules — and there the only reliable
signal is the description ("bespoke", "designed specifically for", "built
specifically for"). Those phrases are deliberately narrow: an earlier attempt
matched "built into the", which caught armor whose *boots* have "tubing built
into the soles".

**Manufacturer resolution** (`ResolveManufacturer`) layers over the dump's own
`Manufacturer` field: `byPrefix` (matched against the lowercased class name)
wins outright — it exists for items whose manufacturer data is missing or
wrong — then the dump's own code, overridden by `byName` and then `renames`.
A code with no `names` entry falls back to the dump's manufacturer name as the
link target. `omitInLead` codes (generic/unknown makers like `UNKN`) resolve
successfully but with an empty page, which drops the lead's "manufactured by"
clause and the manufacturer navplate — linking `[[Consumable]]` as if it were
a company would be wrong.

Separately, `ClassManufacturer` reads the manufacturer a class name's leading
token claims and, when it disagrees with the resolved code, records it in the
plan's `manufacturerMismatches` array — advisory, not a filter: the item is
still planned, and the disagreement is surfaced for a human to judge which
side is wrong (see "What the plan contains" and "Applying the plan" below).
`manufacturers.aliases` (keyed class-token code -> resolved code) suppresses
known-legitimate disagreements — Mirai's items still carry `MISC` class names
from before the rename — so a pair listed there is never reported.

## What the plan contains

```jsonc
{
  "meta": {
    "generated": "2026-08-13T12:00:00Z",
    "build": "4.9.0-LIVE.12232306",
    "source": "scunpacked-data@a1b2c3d",
    "wikiUuids": 18422,
    "items": 21987
  },
  "create": [
    {
      "title": "Dominance-1 Scattergun",
      "uuid": "aaaaaaaa-0000-4000-8000-000000000010",
      "type": "WeaponGun.Gun",
      "kind": "component",
      "manufacturer": "HRST",
      "summary": "Create item stub from Alpha 4.9.0 datamine",
      "wikitext": "{{Entity\n|uuid = aaaaaaaa-0000-4000-8000-000000000010\n|name = Dominance-1 Scattergun\n...\n"
    },
    {
      "title": "APX Fire Extinguisher",
      "uuid": "aaaaaaaa-0000-4000-8000-000000000040",
      "type": "WeaponGun.Gun",
      "kind": "component",
      "manufacturer": "ANVL",
      "mismatchFromClass": "KEGR",
      "summary": "Create item stub from Alpha 4.9.0 datamine",
      "wikitext": "{{Entity\n|uuid = aaaaaaaa-0000-4000-8000-000000000040\n|name = APX Fire Extinguisher\n...\n"
    }
  ],
  "conflicts": [
    {
      "reason": "review:bespoke",
      "title": "TMSB-5 Gatling",
      "uuid": "aaaaaaaa-0000-4000-8000-000000000015",
      "note": "flagged by review rule \"bespoke\" (class BEHR_BallisticGatling_Hornet_Bespoke); create only if it deserves a page",
      "wikitext": "{{Entity\n..."
    },
    {
      "reason": "duplicate-name",
      "title": "Cup",
      "uuids": ["aaaaaaaa-0000-4000-8000-000000000012", "aaaaaaaa-0000-4000-8000-000000000013"],
      "note": "several missing items share this name; needs disambiguation"
    },
    {
      "reason": "title-exists",
      "title": "Widowmaker",
      "uuid": "aaaaaaaa-0000-4000-8000-000000000050",
      "note": "page exists without this uuid; disambiguate or merge",
      "wikitext": "{{Entity\n...",
      "onPageUuid": "bbbbbbbb-0000-4000-8000-000000000001",
      "onPageClass": "behr_widowmaker_01",
      "sameDescription": true
    }
  ],
  "skipped": { "exists": 18201, "blocked": { "isPlaceholder": 340, "testItem": 52 }, "excluded": 1877, "unusable": 6 },
  "unmappedTypes": [
    { "type": "Misc.Harvestable", "count": 214, "sample": "Stone Fruit" }
  ],
  "manufacturerMismatches": [
    {
      "title": "APX Fire Extinguisher",
      "uuid": "aaaaaaaa-0000-4000-8000-000000000040",
      "resolved": "ANVL",
      "fromClass": "KEGR",
      "className": "kegr_fire_extinguisher_01"
    }
  ]
}
```

`create` entries are ready to apply mechanically — with one caveat:
`mismatchFromClass` is set (and the same disagreement also appears in
`manufacturerMismatches`) when the class name implies a different maker than
`manufacturer`, so an apply that skips checking it can publish the wrong
manufacturer. `conflicts` is the editorial worklist — every entry names a
`reason` and, where a stub was rendered, carries its `wikitext` so resolving
the conflict doesn't mean re-deriving it. A `title-exists` entry additionally
carries `onPageUuid`/`onPageClass`/`sameDescription` when they're known (see
"Why most `title-exists` conflicts are noise" above) — read `sameDescription`
as a hint to check the page against the flagged item, never as a signal to
skip either one. `unmappedTypes` is sorted by count, so the highest-volume
gaps in the allowlist surface first.

`plan.Drift()` (used by `-diff`) is `len(create) + len(conflicts) > 0` — both
mean somebody has work to do. This differs from `uuidindex`, where conflicts
don't count toward drift: there, a conflict lives on an ordinary page that
would otherwise hold the exit code hostage until someone edits content. Here,
a conflict is itself the plan's output — an entry a human/agent resolves by
editing the plan's disposition, not the wiki — so it belongs in the same
signal as `create`.

## Refusing to plan

| Rail | Flag (default) | Trips when | Exit code |
|---|---|---|---|
| dump floor | `-min-items` (15000) | fewer usable items decoded than this | 1 |
| wiki floor | `-min-uuids` (5000) | fewer annotated uuids scanned than this | 1 |
| creation cap | `-max-create` (500) | more `create` entries than this | **2** |
| drift check | `-diff` | `plan.Drift()` is true | **1** |

The two floors' exit code 1 is an ordinary error exit, not a dedicated rail
code: tripping one returns a plain Go `error` from `run()`, and `main()`
reports and exits 1 for that the same way it would for any other failure.
Only the creation cap has a dedicated exit code (`exitRailTripped` = 2) —
the same split as `cmd/uuidindex`, where `-min-uuids`/`-min-pages` exit via
the ordinary error path and only `-max-delete` gets its own exit 2.

The two floors are checked before a plan is built: a truncated dump download
or a degraded SMW (mid-rebuild, API hiccup) would otherwise be read as "these
items are all missing," which is a false mass-creation signal, not a real
one. Override only after confirming the shortfall is expected (e.g. a
deliberately small `-in` fixture).

The creation cap is checked *after* the plan is written, specifically so a
tripped rail leaves the evidence on disk instead of discarding it: judging
whether 900 planned creates are a config mistake (a type wrongly allowlisted)
or a real backlog means reading them, not re-running a
multi-minute scan. A tripped cap writes to `<out>.rejected.json` and exits
**2**, distinct from `-diff`'s **1** for ordinary drift — raise `-max-create`
only after reading the rejected plan, the same read-before-raising discipline
as `uuidindex`'s `-max-delete`.

`-in` requires `-build`: a local dump file carries no git history to read a
build id from.

## Applying the plan

This tool never writes to the wiki and holds no credentials. Applying a plan
means an agent works through it via the MediaWiki MCP server:

- `create` entries become `create-page` calls, verbatim `wikitext` and
  `summary`, from a bot-flagged account — but check `mismatchFromClass` first:
  a non-empty value means the item's class name implies a different
  manufacturer than the one baked into `manufacturer`/the wikitext (the same
  disagreement also appears in `manufacturerMismatches`), so the entry needs a
  human read before publishing, not a mechanical apply.
- `conflicts` are the editorial worklist — each one needs a human or agent
  judgement call before anything is created (disambiguate a duplicate title,
  decide whether a bespoke variant deserves its own page, resolve a missing
  manufacturer), not a mechanical apply. For `title-exists`, read
  `onPageClass`/`sameDescription` before deciding: a `sameDescription: true`
  usually means the flagged item is CIG's unimplemented reuse of the page's
  name and the page should stay as-is, but not always — the page itself
  sometimes holds the placeholder, so confirm which item is real before
  discarding either one.
- `unmappedTypes` isn't something to apply at all; it's config drift. Feed it
  back into `config.json` (allowlist with a `kind`/`label`, or `"skip": true`)
  and re-run.

## Where the dump and build id come from

`items.json` is tracked in this repo's Git LFS, so the obvious
`raw.githubusercontent.com` URL serves only an LFS pointer file (a few dozen
bytes of text), not the ~130 MB of actual content. `DumpURL` instead points at
`media.githubusercontent.com/media/...`, which resolves LFS objects to their
real bytes.

There's no dump-level field for which game build it was extracted from, so the
build id is read out of the commit history instead: `LatestBuild` walks
`CommitsURL`'s response (newest first) and takes the first commit message
whose first line matches an extraction build id, e.g.
`4.9.0-LIVE.12232306`. Maintenance commits (`fix: correctly classify ejection
seats`) don't match and are skipped, so the reported build always reflects
the extraction the items actually came from. `-build` overrides this outright,
and is required together with `-in`, since a bare dump file on disk carries no
commit history to read one from.
