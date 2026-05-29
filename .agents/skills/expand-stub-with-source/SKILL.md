---
name: expand-stub-with-source
description: Use when an existing wiki page (typically a stub or thin article) needs to be expanded with content sourced from one or more URLs, with proper citations. Covers the RSI page-fetch fallback ladder (curl → playwright-cli → Wayback) and the Development-section / Cite-template / named-ref conventions. Triggered by requests like "expand the X page with this URL", "add a Development section sourced from the patch notes", "fill out this stub from these sources".
---

# Expand a Stub Wiki Page From a Source

End-to-end recipe for growing a thin wiki page with sourced content: fetch the source (with fallbacks for JS-rendered pages), compose a structured draft, **always show the draft before posting**, then update the page with proper citation templates and named refs.

## When to use vs not

**Use** when:
- An existing wiki page (stub, index page, item page) needs substantive content from one or more URLs.
- User cites RSI comm-links, patch notes, Galactapedia, in-game datamine, or community sources.
- A Development section is needed to log patch-history events on an existing page.

**Don't use** when:
- Creating a brand-new wiki page (this skill assumes the page exists).
- Pure structural template migrations like `{{Item}}` → `{{Entity}}` — use `migrate-category-to-entity`.
- Trivial edits (single sentence, single typo) — just edit the page.

## Steps

### 1. Set wiki and read the current page

Set wiki to `https://starcitizen.tools`. Fetch the page via `get-pages` to see current content and note the `latestRevisionId` (needed for `update-page`).

If `{{stub}}` is present, the expansion likely retires it.

### 2. Fetch each source — fallback ladder

For each URL, extract the relevant text by trying the steps below in order. Stop at the first one that returns the content you need.

#### 2a. `curl -sL -A 'Mozilla/5.0'` + grep

Cheapest probe. Works for many older RSI comm-link articles (engineering, transmission, spectrum-dispatch categories) and other SSR'd pages.

```bash
curl -sL -A 'Mozilla/5.0' "$URL" > /tmp/page.html
wc -c /tmp/page.html
grep -ioc "<keyword>" /tmp/page.html
```

If HTML is hefty (>~100KB) AND grep finds your keywords → done. Extract sentences via a Python regex on the tag-stripped text.

#### 2b. JS-shell detection — escalate immediately

If HTML is small (~30KB) and grep finds nothing, check for the RSI JS-shell signature:

```bash
grep -q 'data-rsi-component' /tmp/page.html && ! grep -qi "$KEYWORD" /tmp/page.html \
  && echo "RSI shell page, content is JS-loaded — escalate to playwright"
```

`data-rsi-component` markers are React placeholders RSI hydrates client-side. When present without your keyword, the body isn't in the static HTML. **Don't retry curl with different flags** — escalate.

#### 2c. playwright-cli with `textContent`

For JS-rendered RSI pages (patch notes, dynamic comm-links, store pages):

```bash
playwright-cli -s=rsi-fetch open "$URL"
sleep 3   # let JS hydrate
playwright-cli -s=rsi-fetch --raw eval "document.body.textContent" > /tmp/page.txt
playwright-cli -s=rsi-fetch close
grep -ioc "<keyword>" /tmp/page.txt
```

**Critical: `textContent`, not `innerText`.** Patch notes use collapsible sections that hide most body text behind `display: none`. `innerText` respects display state and skips hidden content; `textContent` returns everything in the DOM. The 3.23.0 patch notes are 6KB of section headings via `innerText` vs 76KB of full body via `textContent` — most of the content is in the 52 hidden sections.

Always `close` the session after extraction so the headless browser doesn't linger.

#### 2d. Wayback Machine

If the RSI URL is dead, moved, or playwright fails:

```bash
# latest snapshot (follows redirect)
curl -sL "https://web.archive.org/web/*/$URL" > /tmp/archived.html
# or list available snapshots
curl -s "https://web.archive.org/cdx/search/cdx?url=$URL&output=json&limit=5"
```

Modern (post-~2018) snapshots often include rendered content (archive.org runs a headless crawler).

#### 2e. Ask the user to paste

When the source is rare or 2a–2d all fail. Faster than fighting JS for one paragraph.

### Do NOT use wiki transcriptions as source-of-truth for patch notes

The wiki's `Update:Star Citizen Alpha X.Y.Z` pages are convenient but **not authoritative** — community transcriptions can be summarized, paraphrased, or stale. Using a wiki transcription while citing the RSI URL propagates drift into your citation.

For patch notes: extract from RSI itself (2a–2d) and cite the RSI URL. For non-patch lore content (older comm-link articles, Galactapedia mirrored pages), the wiki transcription is usually verbatim and safe as a starting point — but verify against the original when fidelity matters.

### 3. Pick the citation template

| Source | Template |
|---|---|
| Anything on robertsspaceindustries.com (comm-link, Patch-Notes, galactapedia, spectrum, pledge) | `{{Cite RSI\|url=...\|text=...\|accessdate=YYYY-MM-DD}}` |
| In-game datamine (no URL) | `{{Cite game\|build=[[Update:Star Citizen Alpha X.Y.Z\|Alpha X.Y.Z]]\|accessdate=YYYY-MM-DD\|text=Datamine}}` |
| Other sources | Check `Category:Citation templates` on the wiki for a fitting one; otherwise raise to the user. |

`{{Cite RSI}}` param order (per `Template:Cite RSI/doc`): `url`, `text`, `accessdate`. All three should be filled. `int` is deprecated — don't use.

When unsure, **look at how the article currently cites things** — match existing convention rather than introducing a new pattern.

### 4. Compose the draft

Target layout:

```wikitext
[Lead paragraph: define the term, scope the article. Cite the foundational source here.]<ref name="...">{{Cite RSI|url=...|text=...|accessdate=...}}</ref>

[Body paragraph(s): mechanics, current state, behavior. Specific claims get their own refs; reuse via <ref name="..." /> when one source covers several sentences.]

[Existing {{Data table}} / transcluded content, unchanged unless the user asks otherwise.]

== Development ==
{{Timeline styles}}
{| class="timeline"
|-
|[[Update:Star Citizen Alpha X.Y.Z|Alpha X.Y.Z]]
|What changed in this patch.<ref name="patch-X.Y.Z">{{Cite RSI|...}}</ref>
|}

== References ==
<references/>

[[Category:...]]
{{Short description|...}}
```

**Ref conventions:**
- **Always** use `name="..."`, even single-use (project rule). Future editors will reuse them.
- Names: short and descriptive — `name="hardpoints"`, `name="patch-3.23"`, `name="ig4.1.1"`.
- Define the full `<ref name="X">{{Cite ...}}</ref>` once; reuse via self-closing `<ref name="X" />`. Order of definition vs reuse doesn't matter to the wiki, but typically the full def lives in the first occurrence.

**Structural conventions:**
- **Development section** mirrors `Point Defense Turret`: `{{Timeline styles}}` + `{| class="timeline"` with `version-link | description-with-ref` rows separated by `|-`.
- **Don't add a Development section** if there's no patch-history event to log. Single-entry sections look thin; the section can come later when more events exist.
- **Remove `{{stub}}`** if your expansion is substantive. Leave it if you're only adding a sentence or two.
- **Preserve `[[Category:...]]` and `{{Short description|...}}`** unless the scope actually changes.

### 5. Show the draft BEFORE posting — non-negotiable

Always present the full proposed page source to the user before calling `update-page`. This catches:
- Wrong wikilinks / self-redirect links (`[[X]]` where X redirects to the page you're editing)
- Mis-paraphrased content or wrong ref names
- Scope creep, redundancy
- House-style mismatches

Format: paste the full source in a wikitext code block, then a brief diff summary of what changed and a list of any decisions you'd like the user to confirm. End with "Post?" or equivalent.

**Do not deploy on the user's behalf without an explicit "yes, post"** or equivalent. The iterative loop saves churn.

### 6. Update the page

`update-page` with the title, full new source, and the `latestRevisionId` from step 1. Edit summary describes what changed: *"Expand: <what>; add Development section; drop stub"* is a typical pattern.

If `update-page` returns `editconflict` (the user touched the page in parallel via VisualEditor), refetch via `get-pages`, merge their changes with your draft preserving their additions, and retry.

## Prose conventions

The full rules live in memory; quick pointers:

- **No em-dashes** in article body prose ([[feedback_no_em_dash]]). Commas, parens, colons, sentence splits.
- **No "Star Citizen X" qualifiers.** Wiki context is implicit — "Ships" not "Star Citizen ships."
- **Distinguish in-game UI terms from API/data terms.** Player-facing prose uses the in-game label (e.g. "weapon mount"); data structures and category names follow API conventions (e.g. "GunTurret"). When both exist, lean in-game for prose.
- **Don't link to redirects of the current page.** If `[[X]]` redirects to the page you're editing, drop the link.
- **Player-friendly language, retain game-specific terms.** Players know "gimbal mount", "hardpoint", "PDC" — don't dumb those down. Avoid jargon nouns like "articulation" when "lets the pilot aim" works.
- **Don't fabricate facts.** If the source doesn't say it, don't write it. Sparse pages stay sparse.

## Gotchas

- **1Password / MCP auth timeout** (`command "op" timed out after 10s`): user reconnects MCP via `/mcp`. Pause and ask; don't retry blindly.
- **`innerText` vs `textContent`**: never use `innerText` for content extraction on pages with collapsed sections. Always `textContent`.
- **playwright-cli session lifetime**: use a named session (`-s=rsi-fetch`) so cleanup is targeted; always `close` after extraction.
- **Wiki transcription drift for patch notes**: never cite the wiki's `Update:` page as if it were the RSI source. Extract from RSI (2a–2d), cite RSI.
- **`get-page-history` is one call per page**; if you need revs for many pages, bulk-fetch via the wiki's own action=query API (`curl -G 'https://starcitizen.tools/api.php' --data-urlencode 'action=query' --data-urlencode 'prop=revisions' --data-urlencode 'rvprop=content|ids' --data-urlencode 'rvslots=main' --data-urlencode 'format=json' --data-urlencode "titles=Page1|Page2|..."`) — content is at `pages[*].revisions[0].slots.main.*`.

## What this skill does not do

- Doesn't create brand-new wiki pages.
- Doesn't perform structural template migrations (use `migrate-category-to-entity`).
- Doesn't deploy code or modules (use `deploy-to-wiki`).
- Doesn't fabricate content when sources are silent.
