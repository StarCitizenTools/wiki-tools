# scripts

Go programs that build wiki content, or plans for changing it, from data the
wiki does not maintain by hand.

Each one **generates a file and tells you how it differs from the live wiki**.
None of them write to the wiki: publishing goes through the MediaWiki MCP
server, where an agent can resolve conflicts and make editorial calls. Nothing
here touches credentials, and every command runs unauthenticated.

Most tools mirror an upstream API. `uuidindex` is the other shape: its source
is the wiki itself, and its output is a plan of edits rather than page content.

## Requirements

Go 1.23+, provided by `mise install`. There are no other dependencies.

## Tools

| Tool | Generates | Source |
|---|---|---|
| `starmap` | `Module:Starmap/starmap.json` | [ARK Starmap API](https://robertsspaceindustries.com/starmap) |
| `uuidindex` | reconciliation plan for the `UUID:` redirect namespace | the wiki itself (SMW `Uuid` annotations vs `UUID:` pages) |

## Usage

Every tool follows the same shape:

```sh
mise run starmap:diff     # has upstream changed? exits 1 if the live page is stale
mise run starmap          # write the file to scripts/out/
```

Then publish `scripts/out/<file>` to the wiki.

> **Publishing large files.** The MCP `update-page` tool takes the page source as
> a parameter, so an agent has to hold the whole file in context to send it. That
> is fine for ordinary pages, but not for a megabyte of JSON like the starmap.
> Those are posted to the action API directly, streaming the file from disk.

`:diff` is the one to reach for routinely — it is read-only and safe to run on a
schedule to answer "has CIG changed anything?". It prints a field-level summary
rather than a line diff, because these files are large:

```
DRIFT against Module:Starmap/starmap.json (rev 374320)
  systems: 90 -> 90  (+0 added, -0 removed, 86 changed)
         86x aggregated_danger
  objects: 889 -> 889  (+0 added, -0 removed, 0 changed)
```

Run `go run ./cmd/<tool> -h` for the full flag list.

## Output is not committed

Generated files land in `scripts/out/`, which is gitignored. They are megabytes
of data mirrored from upstream APIs: committing them would add churn on every
regeneration without adding anything reviewable, and the wiki page is their real
home.

## Warnings you should not ignore

**Schema drift.** Tools check every upstream field against a known-key set and
report anything new:

```
WARNING: 1 unrecognised upstream field(s):
  object.orbital_inclination
```

The output is still valid — the new field is simply not included. But it means
the upstream data changed, so somebody should decide whether we want it. This
exists because the previous starmap generator ignored unknown fields silently
and an upstream renaming pass went unnoticed for about nine months.

**Refusing to write.** A run aborts if the upstream returns implausibly little
data (`-min-systems` / `-min-objects` for starmap, `-min-uuids` / `-min-pages`
for uuidindex). That is a degraded API, not a real change; overriding the floor
is almost never the right response.

**Refusing to delete.** `uuidindex` is the only tool whose plan can remove
pages, so it also caps how many (`-max-delete`, default 100). Tripping the cap
writes the plan to `<out>.rejected.json` and exits **2** rather than 1, so the
deletions can be read before anyone decides they are real. Raise the cap only
after reading them.

## Adding a tool

Put the command in `cmd/<name>/`, and reuse the shared packages rather than
re-solving their problems:

- `internal/httpx` — rate-limited HTTP with bounded retry and backoff.
- `internal/mediawiki` — read-only page fetch, for diffing against what is live.

Then add `<name>` and `<name>:diff` tasks to `.mise.toml`, and a row to the table
above. Keep the tool read-only: generating and publishing are separate steps on
purpose, so that a bad generation cannot become a bad edit without someone
looking at it first.

Per-tool notes live next to the tool — see [`cmd/starmap`](cmd/starmap/README.md)
and [`cmd/uuidindex`](cmd/uuidindex/README.md).
