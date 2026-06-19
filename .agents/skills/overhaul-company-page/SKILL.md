---
name: overhaul-company-page
description: Use when bringing a Star Citizen Wiki company or manufacturer article up to the canonical standard - converting {{Infobox company}} to {{Company}}, enriching from Galactapedia and the RSI Portfolio, restructuring sections, adding a products table, copyediting to wiki style, and setting the short description. Triggered by "do the company pass on <X>", "overhaul the <company> page", "continue the company pages sweep".
---

# Overhaul a Company Page

Per-page pass that brings a company/manufacturer article to the canonical standard: `{{Company}}` infobox, Galactapedia + Portfolio-sourced content, a flat section structure, a `{{Manufacturer products}}` table for manufacturers, neutral wiki-style prose, and a curated short description. Run it on each page across the ~280 legacy `{{Infobox company}}` transclusions. The pilot reference page is [[Behring Applied Technology]]; the field survey and the area-served noise-cut rule live in the `project_company_areaserved` memory.

The steps are ordered and later steps assume earlier ones. Skip a step already satisfied (a page already on `{{Company}}` skips step 1).

**REQUIRED BACKGROUND:** the `expand-stub-with-source` skill covers the source-fetch fallback ladder and the `{{Cite RSI}}` / named-ref conventions used in steps 2-3 and 6. Deploy any code/template change with `deploy-to-wiki`, never from this skill.

## When to use vs not

**Use** when:
- A company/manufacturer page is on legacy `{{Infobox company}}`, or is on `{{Company}}` but not yet enriched/structured/copyedited.
- The user names a company or asks to continue the company pass.

**Don't use** when:
- The subject is a faction/organization with no manufacturer identity or product line - `{{Company}}` may not be the right template.
- The page is already at standard, or you only need one mechanical edit.

## Prerequisites

- `Module:Company`, `Template:Company`, and `Template:Manufacturer products` exist on the wiki and in this repo.
- Public reads work via `curl` (`api.star-citizen.wiki`, plus the MediaWiki `action=parse` / `action=ask` / `action=query`); writes go through the MediaWiki MCP with `wiki: "starcitizen.tools"` on every call.

## Steps

### 1. Convert {{Infobox company}} -> {{Company}}

Map the legacy params onto `{{Company}}`. Key differences:
- **Multi-value fields use a semicolon (`;`)**, not a comma (avoids colliding with commas inside names/links): `industry`, `products`, `founder`, `subsidiaries`, `predecessor`, `successor`, `allies`, `rivals`, `keypeople`. `predecessor`/`successor` are multi-value because a merger has several predecessors (and a split, several successors); each renders as a list and stores an SMW Page list.
- **Drop the legacy comment placeholders.** `{{Infobox company}}` carries `|param = <!-- ... -->` hints; do not copy them into `{{Company}}` - they add nothing and interfere with VisualEditor. Keep only populated parameters and drop empty ones entirely (no bare `|param =` lines).
- **Manufacturer code is derived** from the company name via `Module:Manufacturers` - there is no `code` param; drop any legacy one.
- **`founded` is a clean year** (e.g. `2554`). The module renders the date via `{{Start date and age}}`; do not pass a template.
- **`headquarters`**: separate multiple HQs with `;`; each as `place, ..., system`. The module stores one star system per HQ (the last wikilink of each segment) to SMW. Keep the display tidy - drop redundant pipes (`[[Terra system|Terra]]` -> `[[Terra system]]`) and do not over-disambiguate - but keep each distinct real place: a city/planet/system chain like `[[Jata]], [[Cestulus]], [[Davien system]]` is fine, not just two links.
- **`areaserved`**: apply the noise-cut - leave it blank when it is simply the whole UEE (`[[United Empire of Earth]]` / `UEE space` / `Human occupied space`); fill it only when narrower (a city, planet, system, or "limited export"). It is an SMW Page list (semicolon-separated, every served place).

### 2. Enrich from Galactapedia

Galactapedia is the most up-to-date canon; **prefer it whenever it conflicts with older content.**

1. **Find the article.** If the infobox already has `galactapediaurl`, the ID is the 12-char token in it (e.g. `0n9vZ4GpQn` from `.../0n9vZ4GpQn-behring`). Otherwise search `GET /api/galactapedia?query=<name>` and take the result whose `type`/`template` is `Company`.
2. **Fetch** `GET /api/galactapedia/<ID>?include=properties` (ID only, <=12 chars - the full `<id>-slug` is rejected; `/api/v2` redirects to `/api`). Two things you need:
   - `translations.en_EN` - the prose (markdown with `[text](url)` RSI galactapedia links) for the lead. Always present.
   - `properties` - an array of `{name, value}` pairs holding RSI's infobox data (`industry`, `products`, `founded`, `headquarters`). **Returned only when you pass `?include=properties`** - the default fetch omits it. The default fetch does give `tags`, `category`, `categories`, and `thumbnail`.
3. **Industry trap:** do not copy the `properties` `industry` values verbatim - they are inconsistent (some omit "manufacture", some are stale, e.g. `weapon attachments`), and the GP page's displayed infobox factors the shared "manufacture" out entirely. Cross-reference the `tags` (`weapon component manufacturer`, `munitions manufacturer`, ...) to produce the clean, fully-qualified list: `Weapons manufacture; Weapon components manufacture; Munitions manufacture; Spacecraft components manufacture`.
4. **Casing:** sentence-case each `industry`/`products` list item for display (e.g. `Personal weapons; Spacecraft weapons`). The module's SMW transform lower-cases them for storage automatically.
5. **Map and reconcile.** `properties` `founded` is the bare year (`2554`). `properties` `headquarters` gives planet designations (`Terra (Terra III); MacArthur (Kilian V)`) - render each as a concise `[[place]], [[system]]` (`[[Terra (planet)|Terra]], [[Terra system]]`; `[[MacArthur]], [[Kilian system]]`). Reconcile every field and the lead against GP, but keep the page's value when it is *newer* than GP (the page may already supersede an old portfolio). Complete the Galactapedia citation: `<ref name="galactapedia">{{Cite RSI|url=...|text=Galactapedia: <Name>|accessdate=<edit date>}}</ref>`.

### 3. Enrich from the RSI Portfolio

1. **Find the Portfolio comm-link:** list `GET /api/comm-links?filter[series]=Portfolio` and paginate with `page[number]=N` (the plain `series=`/`query=`/`page=` params are ignored; only the `filter[...]` / `page[number]` JSON:API forms work). URL-encode the brackets (`--data-urlencode 'filter[series]=Portfolio'`, or `filter%5Bseries%5D=...&page%5Bnumber%5D=N`) - unquoted brackets in a shell silently return an empty or mixed result. Match by company name (titles are `Portfolio: <Name>`).
2. **Fetch** `GET /api/comm-links/<id>` for the content + `rsi_url`. Enrich the page's prose with it; **prefer Galactapedia on any conflict.** Cite with `{{Cite RSI}}`.
3. **`portfoliourl`:** set it to the comm-link's `rsi_url` **only if the URL genuinely still serves the portfolio.** RSI soft-404s removed comm-links, so the status code alone lies: a `HEAD` (`curl -I`) returns `200` even for a removed portfolio. Use a `GET` (`curl -sL -A 'Mozilla/5.0'`, never `-I`) and require BOTH a non-404 status AND a body that actually contains the article (grep for the company name or a distinctive sentence, not the generic RSI boilerplate). Fail either check -> leave `portfoliourl` blank and cite the content via its Wayback archive. (Behring is the worked example: `HEAD`=200 but `GET`=404 and the body is the generic shell, so `portfoliourl` stays blank.)
4. If the page already contains the portfolio content (common - many pages were originally built from it), this step is a citation/verify pass, not new prose.

### 4. Structure: keep sections flat

Use top-level sections; **do not add a `== Lore ==` wrapper** (the flagship pages - Anvil, RSI, Aegis, Crusader, Drake, Origin - all use flat `==History==`). Canonical order:

`History -> [page-specific: Departments / Manufacturing / Jurisdiction / ...] -> Products -> Gallery -> Trivia -> See also -> References`

In-fiction narrative and real-world notes are sibling top-level sections (e.g. `==Development==`), never nested under an umbrella.

### 5. Products table (manufacturers only)

If the company manufactures items, add a Products section in the content band (after the in-fiction prose, before the appendix sections):

```wikitext
==Products==
{{Manufacturer products}}
```

- The category defaults to the page title. **Verify the category actually has members** (`get-category-members` on `Category:<page title>`): every migrated item carries a manufacturer category equal to the *manufacturer name*. When the page title differs from it (disambiguated, abbreviated, or differently-cased - `ArcCorp (company)` -> `ArcCorp`, `Microtech`, `MISC`), pass the override `{{Manufacturer products | <category>}}`. A 0-member category usually means the wrong name - try the variants first.
- **If the category is *genuinely* empty** after checking the title and its plausible variants (the company simply has no products catalogued on the wiki yet - e.g. A-Tek, Accelerated Mass Design, Armitage), **omit the `==Products==` section entirely** rather than emit an empty grid. An empty `{{Manufacturer products}}` renders a dead/broken-looking table. Re-add the section when product pages exist.
- **Confirm the members are products**, not just that the count is nonzero - a few company categories also hold non-product pages (e.g. `Category:ArcCorp` mixes in mining areas), and the table lists every main-namespace member.
- **Drop `{{Navplate manufacturers|<CODE>}}`** - the live, filterable table supersedes the static navbox.
- **Ship manufacturers are a known rough edge.** A ship-maker's category (e.g. `Aegis Dynamics`) mixes its **ships** (which have no `Item type`) with its **components** (Coolers, Flight Blades, ...); `{{Manufacturer products}}` lists both, with a blank `Item type` for the ships. Use it anyway for now - a ship-appropriate products presentation is a separate future effort. Behring, a pure component-maker, was the clean case.

### 6. Copyedit to wiki style

Full pass on the prose to neutral, encyclopedic, third-person wiki style. Preserve **every** fact, `<ref>` (including a reused `<ref name="x"/>` appearing the right number of times), `[[wikilink]]`, template, and HTML comment - change only the voice/grammar.

- Remove marketing/hype/editorialising ("the biggest gun in the galaxy", "famously", "lightning-quick", "More horrific rumors").
- No second person, no rhetorical questions.
- **No em or en dashes as punctuation** (project rule); use commas, parentheses, or separate sentences.
- Remove informal usage: "etc.", "a lot of", "one-stop shop", `...` ellipses, sentence fragments. Fix grammar (dangling subjects, comma splices, double spaces).
- Attribute rumours neutrally ("It is widely believed", "Some reports suggest"). American English.
- A `draft -> adversarial-verify` workflow works well here: one agent rewrites, a second checks fact/ref/wikilink preservation and residual style issues against the original before posting. Always show the draft before posting.

### 7. Short description (must be the LAST thing on the page)

`Module:Company` sets an automatic `SHORTDESC` ("<Race> company in the <industry> industry"). It runs when `{{Company}}` is parsed, near the top. SHORTDESC is **last-wins**, and **`noreplace` is NOT honored on this wiki** - so a `{{Short description}}` placed *above* `{{Company}}` is silently overridden and dead.

- Place `{{Short description|...}}` at the **end of the page** (after `{{Company}}`, e.g. after the categories) so it wins. If a legacy one sits at the top, move it to the end.
- **Curate it to say what the company is at a glance AND to differentiate it from its peers.** Lead with the company's most distinguishing trait, not a mechanical formula. Home location (`<Race> <type> based on <primary HQ>`) is only one differentiator, and a weak one when the HQ is a default (most Human companies are on Earth/Terra, so "based on Earth" distinguishes nothing). Prefer a sharper trait when one exists: the product specialty (`Human energy weapons manufacturer`), market position, or characteristic structure. Example: Aopoa is best as `Xi'an light spacecraft manufacturing monopoly`, because every Xi'an company holds a single-industry monopoly, so naming the sector + the monopoly says far more than the location. Keep it concise (~40 chars).
- Verify with `action=query&prop=pageprops` that the stored `shortdesc` is your curated value, not the module's auto one.

## Gotchas

- **MCP write auth** resolves wiki credentials via the `op` (1Password) CLI; reads do not need it, so use `curl` for all the read/verify steps. If writes fail with an `op` error, the user fixes the credential helper - pause and ask.
- **AG Grid data store:** a `{{Manufacturer products}}` / `{{Data table}}` grid serves its rows from a per-revision store written by LinksUpdate, not inline. After editing a consumer page the grid can be briefly empty until LinksUpdate runs; HTML inspection cannot confirm rows loaded (the grid is client-side), and a headless/anonymous browser session may not render AG Grid at all. The wiring is correct if `<div class="ext-aggrid" data-mw-aggrid-pageid=...>` is emitted with the right `columnDefs`.
- **Galactapedia `properties` needs `?include=properties`** - the default fetch omits it entirely (no industry/products/founded/headquarters). And the `industry` values it returns are messy; expand them via `tags` (step 2).
- **Galactapedia `thumbnail` is usually a generic placeholder.** GP serves a single shared placeholder image (byte-identical, md5 `278879e3c41a001689260f0933a7f4ba`, exactly 5003 bytes) for company articles that have no real logo. A non-null `thumbnail` does NOT mean a real image exists. Before flagging a page as missing an image, download the thumbnail and check it against that md5/size; only a genuinely distinct image is a real, uploadable logo (in a 158-page sweep, 14 of 16 flagged thumbnails were this placeholder).
- **Portfolio `rsi_url` soft-404s** - RSI serves a `200` SPA shell for removed comm-links (a `HEAD`/`curl -I` especially); verify liveness with a `GET` plus a body check, never the status code alone (step 3).
- **`{{Short description}}` must be last** - the single most common mistake, because the wiki convention elsewhere is top-of-page.
- **Don't fabricate facts** for sparse pages; leave them sparse.
- **Outdated lore:** content from an old portfolio that predates current canon keeps its `{{Outdated}}`/`{{Note}}` flags - the copyedit fixes voice, not staleness.

## What this skill does not do

- It doesn't deploy module/template code (use `deploy-to-wiki`) or generate the `{{Manufacturer products}}` doc (use `doc-page-from-readme`).
- It doesn't migrate factions/organizations that aren't companies.
- It doesn't invent factual content for sparse pages.
