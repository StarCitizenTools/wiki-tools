---
name: deploy-to-wiki
description: Use when deploying a module from the local pages/ directory to the Star Citizen Wiki. Triggered by requests like "deploy Details", "push module to wiki", or "sync InfoboxLua to wiki".
---

# Deploy Module to Wiki

Deploy a single module from `pages/module/<Name>/` to the Star Citizen Wiki using the MediaWiki MCP server.

## Steps

### 1. Set Wiki

Call `set-wiki` with `https://starcitizen.tools`.

### 2. Scan Local Files

Read all files in `pages/module/<Name>/`. Determine the wiki page title and content model for each file using these rules:

- `<Name>.lua` (filename matches directory name) → `Module:<Name>` — content model: `Scribunto`
- `<Other>.lua` → `Module:<Name>/<relative path without .lua extension>` — content model: `Scribunto`
- `*.css` → `Module:<Name>/<relative path with extension>` — content model: `sanitized-css`
- `*.json` (except `module.json`) → `Module:<Name>/<relative path with extension>` — content model: `json`
- `README.md` → `Module:<Name>/doc` — content model: `wikitext` (requires conversion, see step 5)
- `module.json` → **skip** — module metadata, not deployed (see step 5 for how it's used)

### 3. Get Git Commit Hash

Run `git log --oneline -1` to get the short commit hash for the edit summary. If no commits exist, use `Sync from Git` as the edit summary. Otherwise use `Sync from Git (<hash>)`.

### 4. Deploy Each File (except README.md)

For each non-README file:

1. Read the local file content.
2. Call `get-page` with `metadata: true` to fetch the wiki page.
3. **Page does not exist** → call `create-page` with the content, title, content model, and edit summary. Note: only `create-page` needs `contentModel`; `update-page` inherits from the existing page.
4. **Page exists, content matches local** → skip, tell the user it's up to date. Note: trim trailing whitespace/newlines when comparing, as local files may have a trailing newline.
5. **Page exists, content differs** → follow the diff confirmation flow:
   - Call `get-page-history` to find who last edited and when.
   - Explain the differences to the user in plain language (what changed, what was added/removed).
   - Ask the user to confirm before updating.
   - If confirmed, call `update-page` with the local content, the `latestId` from `get-page` metadata (required to prevent edit conflicts), and the edit summary.

### 5. Deploy README.md as /doc

Convert the README markdown to wikitext before deploying:

1. **Read `module.json`** if it exists in the module directory. Build the `{{documentation}}` template args:
   - Always include `git=true`.
   - If `module.json` has `"origin": "wikipedia"`, also include `fromWikipedia=true`.
   - Example: `{{documentation|git=true|fromWikipedia=true}}`
2. **Prepend** the `{{documentation|...}}` template followed by one blank line.
3. **Drop** the `# Module:<Name>` H1 heading (first line) — it's redundant on the wiki page.
4. **Drop** the `## Requirements` section (heading and its content) — this is for developers on GitHub, not wiki readers.
5. **Drop** the `## Architecture` section (heading and its content) — this is for contributors on GitHub, not wiki readers.
6. **Convert markdown to wikitext:** headings, inline code, links, bold, italic, lists, and tables (`{| class="wikitable" ... |}`). Fenced code blocks (`` ```lang ``) become `<syntaxhighlight lang="lang">...</syntaxhighlight>`.

Then deploy to `Module:<Name>/doc` following the same exists/differs/create logic from step 4.

### 6. Summary

After all files are processed, show a summary table:

| Page | Action |
|---|---|
| `Module:Details` | Created / Updated / Skipped (up to date) |
| `Module:Details/doc` | Created / Updated / Skipped (up to date) |
