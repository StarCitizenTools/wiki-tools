---
name: deploy-to-wiki
description: Use when deploying a module or template from the local pages/ directory to the Star Citizen Wiki. Triggered by requests like "deploy Details", "push module to wiki", "sync InfoboxLua to wiki", or "deploy Template:Entity/Description".
---

# Deploy Page to Wiki

Deploy a single module or template from `pages/<namespace>/<Name>/` to the Star Citizen Wiki using the MediaWiki MCP server.

## Steps

### 1. Target the Wiki

Pass `wiki: "starcitizen.tools"` explicitly on **every** MCP call in this workflow. The server is stateless — there is no persistent "current wiki", and omitting `wiki` falls back to the configured default, which may be a different wiki. For writes (`create-page` / `update-page`), that means a missing `wiki` can silently edit the wrong wiki, so always name it.

### 2. Scan Local Files

Determine the namespace from the path (`pages/module/...` → `Module:`, `pages/template/...` → `Template:`). Read all files in `pages/<namespace>/<Name>/`. Map each file to a wiki page title and content model.

**Module namespace (`pages/module/<Name>/`):**

- `<Name>.lua` (filename matches directory name) → `Module:<Name>` — content model: `Scribunto`
- `<Other>.lua` → `Module:<Name>/<relative path without .lua extension>` — content model: `Scribunto`
- `*.css` → `Module:<Name>/<relative path with extension>` — content model: `sanitized-css`
- `*.json` (except `module.json`) → `Module:<Name>/<relative path with extension>` — content model: `json`
- `README.md` → `Module:<Name>/doc` — content model: `wikitext` (requires conversion, see step 5)
- `module.json` → **skip** — module metadata, not deployed (see step 5 for how it's used)
- `overlay.json` → **skip** — hand-owned input to a generator under `scripts/`, not a page the wiki reads. Pushing one would create a wiki page nothing loads, which an editor could then change with no effect — and a silent divergence between wiki and repo is exactly the failure this file exists to prevent.
- `Mainpage/settings.json` → **skip** — EDITOR-owned content. It is the main page's control panel, changed on the wiki by whoever is updating the featured article or the running event, so the wiki is its source of truth and any local copy is stale the moment they do. It is gitignored for the same reason, but a stale copy can still be sitting on disk from before that, which is why this skip is here and not left to the file's absence. Deploying it reverts an editor's work with no warning and no diff anyone reads.

**Template namespace (`pages/template/<Name>/`):**

- `<Name>.wikitext` (filename matches directory name) → `Template:<Name>` — content model: `wikitext`
- `<Other>.wikitext` → `Template:<Name>/<relative path without .wikitext extension>` — content model: `wikitext`
- `*.css` → `Template:<Name>/<relative path with extension>` — content model: `sanitized-css`
- `README.md` → `Template:<Name>/doc` — content model: `wikitext` (requires conversion, see step 5)
- Subdirectories (e.g. `pages/template/Entity/Description/`) recurse with the same rules — the subpath becomes part of the wiki title.

### 3. Choose the Edit Summary

Run `git status --porcelain` and `git log --oneline -1`.

- **Working tree clean** (local files match the last commit) → use `Sync from Git (<hash>)`.
- **Working tree dirty** (uncommitted local changes — the deploy wouldn't correspond to that hash) → use a short descriptive summary of what actually changed instead. Never cite a commit hash that doesn't reflect what's being pushed.
- **No commits exist** → use `Sync from Git`.

### 4. Deploy Each File (except README.md)

For each non-README file:

1. Read the local file content.
2. Call `get-page` with `content: "none", metadata: true` to check existence and capture `latestRevisionId` (the `latestId` for conflict-safe updates). Don't pull full page source for comparison — use `compare-pages` (step 4) instead. When several pages need checking at once, use `get-pages` to batch the existence/metadata reads in one call.
3. **Page does not exist** → call `create-page` with the content, title, content model, and edit summary. Note: only `create-page` needs `contentModel`; `update-page` inherits from the existing page.
4. **Page exists** → detect whether it differs from local with a server-side diff instead of pulling content into context:
   - Call `compare-pages` with `fromTitle: <wiki title>`, `toText: <local content>`, `includeDiff: false` — a cheap change-detection response (just the change flag + size delta, no diff body). A trailing-newline-only difference is not a real change; MediaWiki normalizes trailing whitespace on save.
   - **No change** → skip, tell the user it's up to date.
   - **Differs** → follow the diff confirmation flow below.
5. **Diff confirmation flow** (page exists and differs):
   - Call `compare-pages` again with `includeDiff: true` (same `fromTitle` + `toText`) to get the compact diff over the wire — this is both the change explanation and a dry-run preview of exactly what the update will write. Summarize it for the user in plain language.
   - Call `get-page-history` to find who last edited and when (drift guard: if the latest editor isn't the deployer account, surface it before overwriting).
   - Ask the user to confirm before updating.
   - If confirmed, call `update-page` with the local content, the `latestId` from step 2 (required to prevent edit conflicts), and the edit summary.

### 5. Deploy README.md as /doc

Invoke the `doc-page-from-readme` skill to convert the README to wikitext. Pass:

- `readme` — contents of the local README.md.
- `namespace` — `"Module"` or `"Template"` based on the page being deployed.
- `pageName` — the part after the colon (e.g. `InfoboxLua`, `Entity/Description`).
- `moduleMeta` — parsed `module.json` if present; otherwise omit. (Templates don't carry one.)
- `wikiDomain` — `"starcitizen.tools"`.

The skill returns ready-to-push wikitext (headings dropped, links internalized, MD → wikitext, `<templatedata>` injected for templates with a Parameters table, `{{documentation|...}}` prepended). Don't apply additional transformations on top — the skill is the single source of truth for that pipeline.

Then deploy to `<Namespace>:<Name>/doc` following the same exists/differs/create logic from step 4.

### 6. Summary

After all files are processed, show a summary table:

| Page | Action |
|---|---|
| `Module:Details` | Created / Updated / Skipped (up to date) |
| `Module:Details/doc` | Created / Updated / Skipped (up to date) |
| `Template:Entity/Description` | Created / Updated / Skipped (up to date) |
| `Template:Entity/Description/doc` | Created / Updated / Skipped (up to date) |
