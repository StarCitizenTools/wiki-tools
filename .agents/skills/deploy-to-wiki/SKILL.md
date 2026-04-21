---
name: deploy-to-wiki
description: Use when deploying a module or template from the local pages/ directory to the Star Citizen Wiki. Triggered by requests like "deploy Details", "push module to wiki", "sync InfoboxLua to wiki", or "deploy Template:Entity/Description".
---

# Deploy Page to Wiki

Deploy a single module or template from `pages/<namespace>/<Name>/` to the Star Citizen Wiki using the MediaWiki MCP server.

## Steps

### 1. Set Wiki

Call `set-wiki` with `https://starcitizen.tools`.

### 2. Scan Local Files

Determine the namespace from the path (`pages/module/...` → `Module:`, `pages/template/...` → `Template:`). Read all files in `pages/<namespace>/<Name>/`. Map each file to a wiki page title and content model.

**Module namespace (`pages/module/<Name>/`):**

- `<Name>.lua` (filename matches directory name) → `Module:<Name>` — content model: `Scribunto`
- `<Other>.lua` → `Module:<Name>/<relative path without .lua extension>` — content model: `Scribunto`
- `*.css` → `Module:<Name>/<relative path with extension>` — content model: `sanitized-css`
- `*.json` (except `module.json`) → `Module:<Name>/<relative path with extension>` — content model: `json`
- `README.md` → `Module:<Name>/doc` — content model: `wikitext` (requires conversion, see step 5)
- `module.json` → **skip** — module metadata, not deployed (see step 5 for how it's used)

**Template namespace (`pages/template/<Name>/`):**

- `<Name>.wikitext` (filename matches directory name) → `Template:<Name>` — content model: `wikitext`
- `<Other>.wikitext` → `Template:<Name>/<relative path without .wikitext extension>` — content model: `wikitext`
- `*.css` → `Template:<Name>/<relative path with extension>` — content model: `sanitized-css`
- `README.md` → `Template:<Name>/doc` — content model: `wikitext` (requires conversion, see step 5)
- Subdirectories (e.g. `pages/template/Entity/Description/`) recurse with the same rules — the subpath becomes part of the wiki title.

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

1. **Read `module.json`** if it exists in the directory (modules only — templates don't carry one). Build the `{{documentation}}` template args:
   - Always include `git=true`.
   - If `module.json` has `"origin": "wikipedia"`, also include `fromWikipedia=true`.
   - Example: `{{documentation|git=true|fromWikipedia=true}}`. For templates without `module.json`, just `{{documentation|git=true}}`.
2. **Prepend** the `{{documentation|...}}` template followed by one blank line.
3. **Drop** the `# <Namespace>:<Name>` H1 heading (first line) — redundant on the wiki page.
4. **Drop** the `## Requirements` section (heading and its content) — for developers on GitHub, not wiki readers.
5. **Drop** the `## Architecture` section (heading and its content) — for contributors on GitHub, not wiki readers.
6. **Generate `<templatedata>` for templates with a `## Parameters` Markdown table.** Invoke the `templatedata-from-readme` skill on the README content. It returns a `<templatedata>` block. Replace the `## Parameters` section (heading + table) with the heading followed by a blank line and the `<templatedata>` block. Skip this step when deploying a Module README.
7. **Internalize wiki links.** For every Markdown link `[Text](URL)` where URL starts with `https://starcitizen.tools/`:
   - Strip the URL prefix to get the page name (URL-decode and replace `_` with spaces).
   - If `Text` matches the page name → emit `[[<Page>]]`.
   - Otherwise → emit `[[<Page>|<Text>]]`.
   Leave non-`starcitizen.tools` URLs as-is so they render as external links.
8. **Convert markdown to wikitext:** headings, inline code, links, bold, italic, lists, and tables (`{| class="wikitable" ... |}`). Fenced code blocks (`` ```lang ``) become `<syntaxhighlight lang="lang">...</syntaxhighlight>`. The `<templatedata>` block from step 6 must pass through verbatim — do not re-process it as Markdown.

Then deploy to `<Namespace>:<Name>/doc` following the same exists/differs/create logic from step 4.

### 6. Summary

After all files are processed, show a summary table:

| Page | Action |
|---|---|
| `Module:Details` | Created / Updated / Skipped (up to date) |
| `Module:Details/doc` | Created / Updated / Skipped (up to date) |
| `Template:Entity/Description` | Created / Updated / Skipped (up to date) |
| `Template:Entity/Description/doc` | Created / Updated / Skipped (up to date) |
