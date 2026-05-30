---
name: migrate-category-to-entity
description: Use when migrating all article pages in a Category:<Type> from the legacy {{Item}} template to {{Entity}}, normalizing page structure, updating the type's index article, and cleaning up legacy size-based subcategories. Triggered by requests like "migrate Weapon mounts to Entity", "do a Coolers sweep", "convert Quantum drives pages to the Entity template".
---

# Migrate a Category to Entity

End-to-end sweep that takes every article page in `Category:<Type>` from the legacy `{{Item}}` infobox to `{{Entity}}`, normalizes the page structure to the canonical layout, swaps the index article's `#ask` for `{{Data table}}`, and deletes the now-empty legacy `<Type> (Size N)`-style subcategories that the old `{{Item}}` template autocategorized into.

## When to use vs not

**Use** when:
- A type's article pages are still using `{{Item}}` and the wiki has the corresponding classification wired into `Module:Entity/Item/classifications.json`.
- The user names a type (Coolers, Quantum drives, Rocket pods, Guns, etc.) or category to migrate.

**Don't use** when:
- Pages are already on `{{Entity}}` — they don't need a re-migration.
- The type doesn't have a classification entry yet — wire `classifications.json` and the on-wiki category tree first (see `project_entity_category_taxonomy` memory).
- The "category" is mixed (e.g. user wants to migrate three unrelated pages, not a whole category) — do those manually.

## Steps

### 1. Set wiki and size the scope

Set wiki to `https://starcitizen.tools`. Call `get-category-members` on the target category with `limit: 500`. You should see:
- Mainspace article pages (the migration targets).
- Subcategory entries named like `Category:<Type> (Size N)` for N = 1..10 — legacy autocategories from the old `{{Item}}` template, to be deleted at the end.

Report the article-page count to the user before starting. Real ranges seen so far: PDCs ~7, Weapon mounts 26.

### 2. Sample before batching

Read 2-3 representative article pages via `get-pages` (one minimal, one with extra sections, one with refs in the lead). Verify:
- The infobox is `{{Item}}` with params `uuid`, `name`, `image`, `manufacturer` — these map verbatim to `{{Entity}}`. If a page uses different params, stop and investigate.
- Which canonical sections are already present and which are missing. Most pages will need `== Crafting ==` added (was never part of `{{Item}}`-era pages); some will lack `== Description ==` too.
- Any per-page oddities to preserve (extra sections like `== Development ==`, copy-paste bugs in names, double-space typos, dangling category links, page-specific refs).

### 3. Batch-fetch source and revision IDs

For all remaining pages: one `get-pages` call for source, plus one `get-page-history` per page for `latestRevisionId` (required by `update-page` as an edit-conflict guard). These can fire in parallel in a single message.

### 4. Migrate each article

For every page, the canonical structure is:

```wikitext
{{Entity
|uuid = <uuid from {{Item}} block>
|name = <name>
|image = <image>
|manufacturer = <manufacturer code>
}}

<lead paragraph>

== Description ==
{{Entity/Description}}

== Ports ==
{{Entity/Ports}}

== Acquisition ==
{{Entity/Availability}}

== Crafting ==
{{Entity/Blueprints}}

== Related ==
{{Entity/Related}}

== Used by ==
{{Entity/UsedBy}}

== References ==
<references />

{{Navplate manufacturers|<manufacturer code>}}
```

Rules:
- Section order is fixed; insert missing ones in the right place.
- `{{Entity/Blueprints}}` goes on every page even if the item isn't currently craftable — the template renders empty for items without blueprint data.
- Normalize heading spacing: `== Section ==` (single space inside the `==`). Some legacy pages have `==Section==`.
- Preserve page-specific extras (e.g. `== Development ==`) between `Used by` and `References`.
- Preserve refs in the lead and any `<ref name>` definitions.
- Preserve the `{{Navplate manufacturers|<code>}}` and the manufacturer code from the infobox.
- Do **not** add categories — `Module:Entity` handles structural + manufacturer categories from the classification + manufacturer code automatically.

### 5. Lead-paragraph prose pass

Default is **light polish** that fixes obvious clunkers (typos, awkward "It allows the installation of one vehicle weapon and transforms..." → tighter active voice). Many type categories have pages that were generated from a template during import and never edited — for those, deeper rewrites are fair game; ask the user to confirm before doing it across the batch.

**Hard prose rules** (learned the hard way):

- **No jargon nouns**: avoid constructions like "gimballed size 1 station", "gimbal articulation", "two gimballed positions". They sound machine-written.
- **Let wikilinks do the explaining**: the page links to `[[gimbal mount]]` / `[[weapon mount]]` — those articles cover what the mechanism does. The lead doesn't need to re-explain.
- **Pipe-link category-level terms to the type's index article.** Example: in a ball-turret page lead, write `[[Weapon mount|ball turret]]` rather than bare `ball turret`. Same for `[[Weapon mount|nose turret]]`, `[[Weapon mount|turret mount]]`, etc. Apply only to the **first occurrence** in the lead. Terms that already have their own article (e.g. `[[gimbal mount]]`) keep their bare link.
- **No em-dashes** in article body prose (project rule from `feedback_no_em_dash`).
- **Don't fabricate facts.** If the original is silent on weapon capacity or specs (some Reliant pages), keep the lead minimal — `"is a size N turret mount manufactured by [[X]] for the [[Y series]]."` is fine.
- **Cite the game build.** These pages are `{{Entity}}`-rendered, i.e. sourced from game/API data, and usually have no other citation. End the lead sentence with one game-data ref:
  `<ref name="ig<patch digits>">{{Cite game|build=[[Star Citizen Alpha <patch>|Alpha <patch>]]|accessdate=<edit date>}}</ref>`
  e.g. `<ref name="ig480">{{Cite game|build=[[Star Citizen Alpha 4.8.0|Alpha 4.8.0]]|accessdate=2026-05-29}}</ref>`. Use the **current live patch** (the API's `game_version` tells you — 4.8.0 at time of writing) and the **edit date** for `accessdate`; name the ref `ig<patch digits>` and reuse via `<ref name="ig480" />` if cited again. This is the baseline cite for otherwise-uncited game-data prose — it does **not** replace `{{Cite RSI}}` where a real RSI/Spectrum/Galactapedia source exists. The canonical structure (step 4) already carries `== References ==` + `<references />` to render it.

**Lead template that has held up:**

> *"The '''<Page name>''' is a [[Manufacturer]] size N [[Weapon mount|<kind>]] fitted to the [[Series]], carrying N size M vehicle weapons."*

For converter mounts (VariPuck-style 1:1 adapters), even tighter:

> *"The '''<Page name>''' is a [[Manufacturer]] size N [[gimbal mount]] for a single size N vehicle weapon."*

For dual-position mounts (PC2-style splitters):

> *"The '''<Page name>''' is a [[Manufacturer]] size [N+2] dual [[weapon mount]] that holds two size N vehicle weapons on a single fixed hardpoint, each on its own gimbal."*

### 6. Deploy article updates

Fire all `update-page` calls in parallel in a single message — they're independent and the wiki handles concurrent edits fine. Edit summary pattern: `"Migrate {{Item}} → {{Entity}}; add Crafting section; normalize headings; lead polish"` (adjust for what actually changed on the page — e.g. "fix copy-paste bug in lead" or "preserve Development section").

### 7. Update the index article (`<Type singular>`, e.g. `Weapon mount`)

Fetch the page. If it has a `#ask` query, replace it with `{{Data table}}` matching the PDC pattern at `Point Defense Turret`:

```wikitext
{{Data table
| category = <Type plural>
| columns =
    Item type ; label=Type ; filter
    Manufacturer ; filter
    Size
}}
```

Other rules for the index article:
- Lead and `{{Short description}}` must honor the **full breadth** of the category, not just the common case. E.g. `Category:Weapon mounts` contains both gimbal adapters (VariPucks) and turret housings (Anvil nose/ball turrets); a lead that describes only converters is wrong.
- Ensure `[[Category:Ship components]]` (or the appropriate root category) is present.
- Ensure `{{Short description|...}}` is present and accurate.
- Preserve `{{stub}}` if it was there — adding `{{Data table}}` is content but doesn't unilaterally retire the stub marker.

### 8. Update the category page (`Category:<Type plural>`)

Set the header to `{{Category header|pages|[[<Type singular>]]s}}` (note: capital first letter on the link, matching the article title). Preserve the parent category link (e.g. `[[Category:Turrets]]` for Weapon mounts). If the page had an `#ask`/table, remove it — that lives on the article now.

### 9. Delete legacy size subcategories

For each `Category:<Type plural> (Size N)`:
1. Call `get-category-members` to confirm it's empty (the `{{Item}} → {{Entity}}` migration drains them, but verify per category).
2. If empty → `delete-page` with reason: *"Legacy autocategory from {{Item}} template; drained after Entity migration (size is now a structured-data facet, not a category)"*.
3. If NOT empty → investigate the remaining members before deleting. A non-Entity page hardcoded into the subcat would be lost. Don't delete on faith.

### 10. Summary table

After everything, show:

| What | Count | Notes |
|---|---|---|
| Articles migrated | N | URLs to a couple as spot-checks |
| Index article | 1 | Link |
| Category page | 1 | Link |
| Size subcategories deleted | N | (all empty post-migration) |

## Gotchas

- **1Password / MCP auth timeout** (`command "op" timed out after 10s`): the user reconnects MCP via `/mcp`. Pause and ask them; don't retry blindly. Subagents independently hit this — prefer running deploy from the coordinator context after reconnect.
- **Mainspace title required to test categories**: when verifying renders via `parse-wikitext`, pass a mainspace `title` parameter. `Module:Entity` guards content-category emission to namespace 0.
- **The wiki uses `$wgArticlePath = "/$1"`**: articles live at the root, not under `/wiki/`. `Special:FilePath/<File>` resolves files; `/wiki/Special:FilePath/...` 404s. Don't hardcode the CDN host.
- **Param compatibility is verbatim for items so far**, but other types may carry extra `{{Item}}` params (no examples yet). If you see a param `{{Entity}}` doesn't know, stop and ask whether to drop it or extend `{{Entity}}`.
- **Don't touch `{{Entity}}` template internals from this skill.** This is a content-migration skill; template changes belong in a separate session.
- **The `{{Item}}` template still exists wiki-side** during migration — it's not breaking, just legacy. Other categories may still rely on it. Don't delete the template.

## What this skill does not do

- It doesn't add a type to `Module:Entity/Item/classifications.json` or wire the on-wiki category tree. If the user's type isn't in the map, do that first (see `project_entity_category_taxonomy` memory) before running this skill.
- It doesn't deploy code changes. Use `deploy-to-wiki` for that.
- It doesn't fabricate factual content for sparse pages. Leave sparse pages sparse.
