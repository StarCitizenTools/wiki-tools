# uuidindex

Reconciles the `UUID:` namespace against the uuid annotations on wiki pages.
See [`../../README.md`](../../README.md) for how to run it; this file covers
what the namespace is and the judgement calls baked into the plan.

## What the namespace is

`UUID:<uuid>` is a redirect to the page holding that uuid, so a game uuid
resolves to a wiki page in one request (`/UUID:<uuid>` follows the redirect).
Every entry is a page of the form:

```
#REDIRECT [[Page name]]
```

The namespace id is 69420. It is **first-letter case-insensitive** like the
rest of the wiki, so the stored title for `a03…` is `UUID:A03…`; the tool
normalises titles to lowercase before comparing, and emits stored-form titles
in the plan.

## Where the uuids come from

Two SMW properties, merged:

- `Uuid` — what `{{Entity}}` stores. Effectively all annotations.
- `UUID` — its predecessor, still emitted by a handful of unmigrated infobox
  pages. Included so those pages stay resolvable; the plan lists them under
  `legacy_property_pages` so the migration debt stays visible.

Three kinds of value never enter the index: annotations outside the main
namespace (a sandbox must not own an index entry), the all-zeros placeholder
uuid (its title carries a hand-written note page instead of a redirect), and
values that are not well-formed uuids (reported under `invalid_values`; the
fix belongs on the annotating page).

## What the plan contains

| Key | Meaning | Apply with |
|---|---|---|
| `create` | uuid annotated, no index entry | `create-page` with `#REDIRECT [[target]]` |
| `retarget` | entry points at the wrong page (usually a page move) | `update-page` with `#REDIRECT [[to]]` |
| `delete` | entry whose uuid nothing annotates any more | `delete-page` |
| `conflicts` | uuid annotated by more than one page | fix the pages, then re-run |
| `invalid_values` | annotation that is not a uuid | fix the page, then re-run |
| `review` | namespace pages left alone, with reasons | human judgement |

The historical edit summary for index edits is `Link UUID to page`; keep using
it so recent-changes filters stay useful.

Only `create` + `retarget` + `delete` count as drift for `-diff`'s exit code.
Conflicts and invalid values are real problems, but they live on ordinary
pages and would otherwise hold the exit code hostage until someone edits
content; they are printed on every run instead.

`review` is deliberately conservative. Non-redirect pages are never deleted
(the two all-zeros placeholder note pages live there), and neither are pages
whose title does not parse as a uuid — a parse failure is as likely to be this
tool's blind spot as it is junk.

## Refusing to plan

A scan that comes back half-empty is a degraded API — an SMW rebuild in
progress, a truncated page list — and planning from it would schedule a mass
deletion of valid index entries. `-min-uuids` / `-min-pages` (default 5000)
abort the run instead, and `-max-delete` (default 100) caps how many deletions
a plan may contain. Raising them should follow inspecting the wiki, not
precede it.

## Cost

One full scan is ~140 anonymous read requests (one large SMW ask per
property, namespace listing, redirect-target resolution in batches of 50), a
few minutes at the default pacing.

The ask deliberately uses one large `limit` rather than offset pagination:
SMW's `$smwgQMaxOffset` (default 5000) silently resets any larger offset to
zero, which turns a naive continue-loop into an infinite cycle. If the
annotation count ever outgrows a single request, the scan fails loudly rather
than spinning; sharding the ask by uuid prefix (`[[Uuid::~0*]]` … `~f*`) is
the escape hatch to implement that day.
