---
name: sync-from-wiki
description: Use when checking whether the Star Citizen Wiki has changes the local repo doesn't have yet. Triggered by requests like "sync from wiki", "check wiki for changes", "pull recent edits", or "see what's changed upstream".
---

# Sync from Wiki

Pull recent changes from the Star Citizen Wiki and reconcile them against the local `pages/` mirror. The inverse of `deploy-to-wiki` — the wiki is the source of truth for this direction.

## Steps

### 1. Set Wiki

Call `set-wiki` with `https://starcitizen.tools`.

### 2. Determine "since" Timestamp

Use the latest commit that touched `pages/`:

```sh
git log -1 --format=%aI -- pages/
```

If the working tree has uncommitted edits to `pages/`, fall back to a wider window (e.g., the prior commit) and warn the user — uncommitted local work has no timestamp anchor.

### 3. Fetch Recent Changes

Call `get-recent-changes` with:

- `since` — the ISO timestamp from step 2.
- `namespace` — `[828, 10]` (Module, Template — the namespaces this repo mirrors).
- `hideBots` — `true`.

If the result is paginated (continuation token), keep fetching until exhausted.

### 4. Categorize Each Change

For each row, classify into one of four buckets:

| Bucket | Detection | Action |
|---|---|---|
| **Own deploy** | `comment` matches `^Sync from Git ...` and `user` is the project deployer (e.g. `Alistair3149`) | Ignore — these are our own pushes. |
| **Drift** | `title` maps to a file we already have locally, but editor is someone else | Investigate (step 5a). |
| **Pull candidate** | `title` is new (`Is new: true`) and would map under a directory we own (e.g., a new sibling renderer under `Module:Entity/...`, or a new TemplateStyles file for an existing module) | Pull (step 5b). |
| **Informational** | `title` is on/under a namespace tree we don't mirror (e.g., random `Template:*` we never deployed) | Report only. |

"Directory we own" check: take the page title's first path segment after the namespace (e.g., `Module:Entity/Ports` → `Entity`). If `pages/<namespace>/<segment>/` exists locally, treat as in-scope.

### 5. Reconcile

#### 5a. Drift (page exists locally, edited by someone else upstream)

1. `get-page` to fetch the wiki source.
2. Compare against the local file (trim trailing whitespace).
3. If they differ, summarize the diff in plain language and ask the user how to proceed: pull wiki onto local, overwrite wiki on next deploy, or merge manually. Do not silently overwrite either side.

#### 5b. Pull candidate (new on wiki, missing locally)

1. `get-page` to fetch the wiki source.
2. Compute the local path using the inverse of `deploy-to-wiki`'s mapping:

   **Module namespace:**
   - `Module:<Name>` → `pages/module/<Name>/<Name>.lua`
   - `Module:<Name>/<Sub...>` (Scribunto) → `pages/module/<Name>/<Sub...>.lua`
   - `Module:<Name>/<Sub...>.css` (sanitized-css) → `pages/module/<Name>/<Sub...>.css`
   - `Module:<Name>/<Sub...>.json` (json) → `pages/module/<Name>/<Sub...>.json`
   - `Module:<Name>/doc` → **flag, don't pull** (requires wikitext → markdown reverse conversion; tell the user to handle manually)

   **Template namespace:**
   - `Template:<Name>` → `pages/template/<Name>/<Name>.wikitext`
   - `Template:<Name>/<Sub...>` (wikitext) → `pages/template/<Name>/<Sub...>.wikitext`
   - `Template:<Name>/<Sub...>.css` → `pages/template/<Name>/<Sub...>.css`
   - `Template:<Name>/doc` → **flag, don't pull** (same reason)

3. `mkdir -p` any new directory, then `Write` the file.

### 6. Lint

Run `mise run fix` then `mise run lint`. The fixer typically converts spaces → tabs and normalizes quotes, so the freshly-pulled local copy will diverge from the wiki copy on whitespace. That's expected.

### 7. Note Whitespace Drift

After step 6, the wiki and local copies of pulled pages now differ on formatting only. Mention this in the summary so the user can decide whether to redeploy to normalize the wiki copy. **Don't auto-deploy** — pulling and pushing in the same flow is too easy to get wrong.

### 8. Summary

Show a categorized summary:

```
Pulled:
- Module:Entity/Ports → pages/module/Entity/Ports/Ports.lua
- Module:Entity/Ports/styles.css → pages/module/Entity/Ports/styles.css

Drift (needs decision):
- Module:Foo — edited by SomeUser at 2026-04-22

Flagged for manual:
- Module:Bar/doc — wikitext→markdown reverse conversion needed

Informational (off-mirror):
- Template:Main page/settings — Weehamster
```

## Gotchas

- **`module.json` is local-only** — module metadata never appears on the wiki, so don't expect to find it there or reverse-create it.
- **`/doc` pages are one-way** — `deploy-to-wiki` converts README.md → wikitext via `doc-page-from-readme`. There's no reverse conversion; pulling a `/doc` edit means hand-editing the README.
- **Lint reformats** — pulled files will be tab-indented after `mise run fix` even if the wiki author used spaces. This is fine; just don't claim "perfect parity" with the wiki after linting.
- **Bots are filtered** — `hideBots: true` skips `MaintenanceBot` and friends. If you need to see bot activity, drop the flag.
- **Patrolling** — `get-recent-changes` doesn't surface patrol status by default. If the user wants to know whether an edit is reviewed, pass `showPatrolStatus: true` (requires patrol rights on the wiki account).
