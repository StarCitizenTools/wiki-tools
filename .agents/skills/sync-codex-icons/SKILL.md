---
name: sync-codex-icons
description: Use when reconciling the Star Citizen Wiki's `Category:Codex icons` against the upstream `wikimedia/design-codex` repo. Triggered by requests like "sync Codex icons", "upload new Codex icons", "check for Codex icon updates", or "update CdxIcon files".
---

# Sync Codex Icons

Mirror SVG icons from [`wikimedia/design-codex`](https://github.com/wikimedia/design-codex) at `packages/codex-icons/src/images/` into the Star Citizen Wiki's File namespace under the `CdxIcon*` prefix.

The wiki file page itself is the sync ledger: the `|date=` field on each `File:CdxIcon*.svg` description page records the upstream commit date at the time of upload. Compare upstream `gh api` commit dates against the wiki's `|date=` to detect drift without fetching binary content.

## Conventions (don't change these without asking the user)

| Field | Value |
|---|---|
| Source repo | `wikimedia/design-codex` |
| Source path | `packages/codex-icons/src/images/` |
| Source ref | `main` (unless the user passes a tag/sha) |
| Title prefix | `CdxIcon` |
| Title rule | Prepend `CdxIcon`, capitalize the first character of the basename, change nothing else. Hyphens and existing camelCase preserved verbatim. Examples: `add.svg` → `CdxIconAdd.svg`; `arrowNext.svg` → `CdxIconArrowNext.svg`; `articlesSearch-ltr.svg` → `CdxIconArticlesSearch-ltr.svg`; `bold-arab-ain.svg` → `CdxIconBold-arab-ain.svg`; `logo-Wikimedia-Commons.svg` → `CdxIconLogo-Wikimedia-Commons.svg`; `textDirLTR.svg` → `CdxIconTextDirLTR.svg`. |
| Description rule | Replace hyphens with spaces, insert space at camelCase boundaries (lowercase→uppercase transitions), capitalize the first character, preserve all other case. Append ` icon in Codex`. Examples: `arrowNext` → "Arrow Next icon in Codex"; `bold-arab-ain` → "Bold arab ain icon in Codex"; `logo-Wikimedia-Commons` → "Logo Wikimedia Commons icon in Codex"; `articlesSearch-ltr` → "Articles Search ltr icon in Codex"; `textDirLTR` → "Text Dir LTR icon in Codex". |
| Date | Latest upstream commit date for the file, `YYYY-MM-DD` (UTC) |
| Author | `Wikimedia Foundation` |
| License | `{{GPLv2+}}` |
| Category | `[[Category:Codex icons]]` |
| Edit summary | `Sync Codex icon (wikimedia/design-codex@<short-sha>)` (use full short hash of the latest commit touching that file) |

### File page wikitext template

```
=={{int:filedesc}}==
{{Information
|description={{en|1=<Description> icon in Codex}}
|date=<YYYY-MM-DD>
|source=https://github.com/wikimedia/design-codex
|author=Wikimedia Foundation
|permission=
|other versions=
}}

=={{int:license-header}}==
{{GPLv2+}}

[[Category:Codex icons]]
```

## Steps

### 1. Set Wiki

Call `set-wiki` with `mcp://wikis/starcitizen.tools`. Always do this first — the MCP server resets to its `defaultWiki` (`localhost:8080` in this setup) on every connection, and silently routing uploads at the local Docker wiki produces a confusing `ECONNREFUSED 127.0.0.1:8080` error mid-batch.

### 2. List Upstream Icons

```sh
gh api "repos/wikimedia/design-codex/contents/packages/codex-icons/src/images?ref=main" --jq '.[] | select(.name | endswith(".svg")) | .name'
```

This is the authoritative upstream set. Keep the raw filenames around — needed for both the title derivation and the per-file commit lookup.

### 3. List Wiki Icons

Call `get-category-members` with `category: "Codex icons"`, `namespace: 6` (File). Paginate until exhausted.

For each member, fetch its description page source (`get-page` on `File:<Name>`) and parse `|date=` out of the `{{Information}}` template. Cache `{title, date}`.

### 4. Three-Way Diff

Build three buckets by joining the upstream filename set against the wiki title set (after applying the title-casing convention from "Conventions"):

| Bucket | Detection | Action |
|---|---|---|
| **New** | upstream filename has no matching wiki title | Upload (step 5). |
| **Date drift** | both sides exist, wiki `|date=` ≠ upstream commit date | Investigate (step 6). |
| **Removed upstream** | wiki title has no matching upstream filename | Flag only — do not delete (step 7). |
| **In sync** | both sides exist, dates match | Skip silently. |

### 5. Upload New Icons

For each filename in **New**:

1. Get the latest commit date and short SHA for the file:
   ```sh
   gh api "repos/wikimedia/design-codex/commits?path=packages/codex-icons/src/images/<filename>&per_page=1" \
     --jq '.[0] | {date: .commit.committer.date[:10], sha: .sha[:7]}'
   ```
2. Derive the wiki title: `CdxIcon` + PascalCase of the basename (without `.svg`).
3. Derive the description: hyphens → spaces, sentence case (capitalize first word only).
4. Download the file:
   ```sh
   curl -fsSL "https://raw.githubusercontent.com/wikimedia/design-codex/main/packages/codex-icons/src/images/<filename>" \
     -o /tmp/cdx-icons/<filename>
   ```
   (`/tmp/cdx-icons/` must be in the MCP server's `uploadDirs` — see Gotchas if the upload fails with "uploads are disabled".)
5. Call `upload-file` with the local path, the derived title, the wikitext template (filled with description and date), and a comment of `Sync Codex icon (wikimedia/design-codex@<sha>)`.

**Always sequential, never parallel.** Issuing multiple `upload-file` calls in the same tool-use block has crashed the MCP server in practice (one bad call + several in-flight = closed connections, lost state). One call at a time. If you hit `rate_limited`, back off and resume.

### 6. Investigate Date Drift

For each title with a date mismatch, the SVG content *may or may not* have changed — Codex sometimes touches files with formatting-only commits.

1. Download the upstream SVG bytes to `/tmp/cdx-icons/<filename>`.
2. Fetch the wiki's current binary via `get-file` (gives a download URL) and compare bytes.
3. **Bytes match (description-only drift):** call `update-page` on the file description page with the new `|date=` and a comment of `Sync Codex icon date (wikimedia/design-codex@<sha>)`. Pass `latestId` from `get-page` metadata to avoid edit conflicts.
4. **Bytes differ (real content update):** two-step update.
   1. Call `update-file` with the local SVG path, the wiki title, and a comment of `Sync Codex icon (wikimedia/design-codex@<sha>)`. This adds a new revision to the file's upload history; prior revisions are preserved.
   2. Call `update-page` on the description page to bump `|date=` (and any other field that changed), reusing the same edit summary. Pass `latestId` from `get-page` metadata.

### 7. Flag Removed Upstream

Wiki has `File:CdxIconFoo.svg` but the upstream repo no longer contains `foo.svg`. Don't auto-delete — Codex occasionally renames or temporarily drops icons, and the wiki may have references that need migration first.

Report:

```
Removed upstream (manual review):
- File:CdxIconFoo.svg — last wiki date: 2024-08-12, last upstream commit removing it: <sha> (<date>) "<commit subject>"
```

### 8. Summary

```
New (uploaded):
- File:CdxIconArrowNext.svg ← arrow-next.svg @ c42e885 (2025-09-30)
- ...

Date drift (description-only, auto-updated):
- File:CdxIconBell.svg: 2024-01-15 → 2025-11-02 @ a1b2c3d

Date drift (content changed, new revision uploaded):
- File:CdxIconLogo.svg @ d4e5f6a (rev 2)

Removed upstream (manual review):
- File:CdxIconFoo.svg

In sync: 387 icons (skipped)
```

## Gotchas

- **`upload-file-from-url` is blocked by domain allowlist.** Star Citizen Wiki's `$wgCopyUploadsDomains` does not include `raw.githubusercontent.com`. Always download to `/tmp/cdx-icons/` and use `upload-file`.
- **MCP `uploadDirs` must include `/tmp/cdx-icons`.** If `upload-file` errors with "uploads are disabled on this server (no upload directories configured)", stop and ask the user to add the path to the MediaWiki MCP server's `config.json` `uploadDirs` and reconnect.
- **`upload-file` is for initial uploads only.** It refuses if the title already exists. For new revisions of an existing file, use `update-file` (or `update-file-from-url`). Never delete-then-re-upload — that destroys file history.
- **PascalCase preserves all hyphen-separated segments.** `bold-arab-ain.svg` → `CdxIconBoldArabAin.svg`, not `CdxIconBoldArab-ain.svg` or any other folding. Locale codes (`zh-hant`, `en`, etc.) are just more segments; treat them identically to other words.
- **Date is committer date, truncated to `YYYY-MM-DD` UTC.** Don't use the author date (rebases muddle it) and don't keep the time component (looks noisy on the file page and `{{Information}}` doesn't expect it).
- **Commit lookup for renames:** `gh api .../commits?path=<new-path>` follows the file at that path only — if Codex moves icons to a new location, this will return the rename commit's date, not the original creation date. That's correct behavior here (the upstream "as of" date is what we record), but note it if a user asks why a date suddenly jumped.
