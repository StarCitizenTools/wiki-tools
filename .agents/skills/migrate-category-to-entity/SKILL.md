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

Report the article-page count to the user before starting. Real ranges seen so far: PDCs ~7, Weapon mounts 26, Guns 132.

**Exclude unmigratable pages from the worklist.** Some category members are placeholder items with **no UUID** (e.g. weapons that exist only in the localization `labels.json`, not as an in-game entity). They have no API record, so `{{Entity}}` cannot render them. Identify them up front (members whose `{{Item}}` block has no `uuid`, or whose SMW `UUID` is empty) and leave them on `{{Item}}`; they will keep a few legacy subcats alive (step 9). Also exclude redirects. Report the *migratable* count, not the raw member count.

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
{{Navplate <type, e.g. power plants / vehicle weapons>}}
```

Rules:
- Section order is fixed; insert missing ones in the right place.
- **Always keep the `== Ports ==` / `{{Entity/Ports}}` section, even for component types where it currently renders "No ports."** (power plants, coolers, etc. have no child ports today). It is data-driven and forward-compatible: CIG may add ports in a future patch and the section then populates automatically. Do not strip it as empty noise.
- Add BOTH navplates at the foot: `{{Navplate manufacturers|<code>}}` and the type navplate (`{{Navplate <type plural>}}`, e.g. `{{Navplate power plants}}`). Confirm the type navplate exists before relying on it.
- **Keep only `uuid`/`name`/`image`/`manufacturer` in the `{{Entity}}` block; drop every other legacy `{{Item}}` param.** Stat-bearing types (weapons) carry many (`Damage`, `Damage Type`, `Range`, `Ammo Count`, `Rate`, `Power Drain`, `IR Signature`, `UEC Cost`, …); `{{Entity}}` renders all of that from the API now, so they are dropped.
- `{{Entity/Blueprints}}` goes on every page even if the item isn't currently craftable — the template renders empty for items without blueprint data.
- Normalize heading spacing: `== Section ==` (single space inside the `==`). Some legacy pages have `==Section==`.
- Preserve page-specific extras (e.g. `== Development ==`) between `Used by` and `References`.
- **Drop a section only if it is an empty stub — never drop a section by name alone.** A table that looks droppable (`== Harvest locations ==`, `== Trade data ==`) is often *populated* with curated detail (specific moons, caves, spawn notes) that exists nowhere in the API. Decide per section on *content*, not heading: a section is a real keeper if it contains any populated table cell (`| [[...]]`), a `[[File:...]]` (galleries often use raw file links, not `{{Gallery|...}}`), or a Development/timeline row with prose — **even when that row has no `YYYY-MM-DD` date** (e.g. `| Added in Alpha 4.1.0`). Drop only the genuinely empty scaffolds (`|<!--System-->` stubs, `{{Gallery|}}`, a `{| class="timeline" |- |}` with no rows). When a script automates this, audit the deployed pages against their originals afterward (parse both section sets, flag any kept-content section missing from the deploy) — a name-based DROP list silently eats real content.
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
- **A deeper rewrite must not eat real lore.** When the original lead carries genuine facts (manufacturer relationship, series role, origin/history, "first Xi'an vehicle weapon", "assimilated tech"), keep it as a following sentence rather than collapsing everything into the one-line template. Drop only restatements of stats the infobox now shows (damage, range, rate) and pure filler. After a bulk run, the section-diff audit (step 4's last rule) catches *dropped sections*; lore lives in the lead, so spot-check a sample of leads too.
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

Fire `update-page` calls in parallel — they're independent and the wiki handles concurrent edits fine. **For large categories (100+), run the migration as several parallel batch-agents**: write the transform spec (steps 4-5) to a shared file, hand each agent that spec plus a disjoint sub-list of pages, then run the section-diff audit over the whole set afterward. **Bulk runs must use a bot-flagged account** (`bot: true` on `update-page`) so they don't flood Recent Changes for other editors; **verify the first edit returns `botMarked: true`** before continuing. If it returns `false`, the session's account lacks the `bot` right, so stop and switch credentials rather than flooding RC unflagged (edits cannot be retroactively flagged). Edit summary pattern: `"Migrate {{Item}} → {{Entity}}; add Crafting section; normalize headings; lead polish"` (adjust for what actually changed on the page — e.g. "fix copy-paste bug in lead" or "preserve Development section").

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

### 9. Delete the legacy subcategory tree

The old `{{Item}}` template autocategorized into more than `(Size N)`: also `(Grade X)`, `(<item_type>)` (e.g. `Guns (Laser Cannon)`), and standalone grouping/mechanism categories (e.g. `Cannon`, `Repeater`, `Scattergun`). Enumerate the full tree (subcats of `Category:<Type plural>`, plus any `(Grade X)` red categories) and drain + delete it:

1. **Leaves before parents.** Delete the leaf `(item_type)`/`(Size N)`/`(Grade X)` cats first; a grouping parent (`Cannon`, etc.) only empties once its child subcats are gone, then delete it.
2. **Verify each is empty** via `get-category-members` before deleting. `delete-page` reason: *"Legacy {{Item}} autocategory; drained after Entity migration (size/type are now structured-data facets, not categories)"*. (`delete-page` has no bot flag; deletions log regardless.)
3. **Relocate manually-categorized Files, don't orphan them.** Weapon images are sometimes hand-filed into a type/size subcat. Edit each such File to replace the legacy subcat with the **parent** `[[Category:<Type plural>]]` (files don't appear as table rows: the `{{Data table}}` query is main-namespace-only). Then the leaf empties and can be deleted.
4. **Keep any subcat still holding an unmigratable straggler.** The no-UUID placeholder pages (step 1) can't migrate, so the few subcats they sit in (and their grouping parents) cannot be emptied. Leave those; never delete a cat with an article member.

### 9b. Galactapedia link sweep (post-migration enrichment)

`{{Entity}}` renders a Galactapedia link in its External-sites row from the `|galactapedia_url=` param (via `Module:Entity/officialSites.json`). After migrating, sweep the [Galactapedia API](https://api.star-citizen.wiki/api/galactapedia) and add the param wherever an entity has a matching article:

1. Page through `/api/galactapedia` (paginate `page[number]` — it caps at ~200/page) into a map of `normalize(title) → [{title, url}]`, where `url = "https://robertsspaceindustries.com" + rsi_url`.
2. For each migrated page lacking `galactapedia_url`, look up `normalize(entity name)`. Add the param **only on an exact single-title match** (skip if 0 or >1 — avoids linking a same-named ship/place). Insert it into the `{{Entity}}` block; preserve all other content.
3. When a legacy `== See also ==` holds the entity's OWN Galactapedia article (slug matches the entity), promote it to `galactapedia_url` and drop that bullet; keep *related-but-different* Galactapedia links (e.g. "Hydrogen Fuel Refinery" on the Hydrogen Fuel page) as a See-also.
4. Most entries have no article — that's expected; verify a couple of "no match" names really are absent (substring-scan the title map) so you trust the exact-match approach.

### 10. Summary table

After everything, show:

| What | Count | Notes |
|---|---|---|
| Articles migrated | N | URLs to a couple as spot-checks |
| Index article | 1 | Link |
| Category page | 1 | Link |
| Legacy subcategories deleted | N | (drained; some kept if held by unmigratable stragglers) |

## Gotchas

- **1Password / MCP auth timeout** (`command "op" timed out after 10s`): the user reconnects MCP via `/mcp`. Pause and ask them; don't retry blindly. Subagents independently hit this — prefer running deploy from the coordinator context after reconnect.
- **Mainspace title required to test categories**: when verifying renders via `parse-wikitext`, pass a mainspace `title` parameter. `Module:Entity` guards content-category emission to namespace 0.
- **The wiki uses `$wgArticlePath = "/$1"`**: articles live at the root, not under `/wiki/`. `Special:FilePath/<File>` resolves files; `/wiki/Special:FilePath/...` 404s. Don't hardcode the CDN host.
- **Drop legacy stat params; keep only the four core.** `uuid`/`name`/`image`/`manufacturer` map to `{{Entity}}`; stat-bearing types (weapons) carry many legacy `{{Item}}` stat params (`Damage`, `Damage Type`, `Range`, `Ammo Count`, `Rate`, `Power Drain`, `IR Signature`, `UEC Cost`, …) that `{{Entity}}` now renders from the API — drop them all. Stop to ask only if a param is neither a known legacy stat nor one of the four core (a genuinely new field `{{Entity}}` does not know).
- **Enumerate the API by paging `page[number]`, never trust one list call.** `/api/commodities?page[size]=500` returns only ~200 rows while `meta.total` says more — the page size is capped server-side. A worklist built from a single list call silently misses records. Page through `page[number]` until `last_page`, and resolve any specific record by direct `/{uuid}` fetch (the list omits some that the direct endpoint returns).
- **An empty-array field still `matches()`.** `box_sizes_scu: []` decodes to an empty Lua table, which is `~= nil`, so `Module:Entity/Commodity.matches()` fires and the page renders fine. Records with `[]` here (Oxygen, Biological Samples, Virus Cultures) are real commodities that were simply never given a wiki page — create them; no code change needed.
- **Name collisions need a disambiguated title or a hands-off.** A canonical game-data name may already be a `{{Disambig}}` (e.g. `Mercury`) or a rich non-commodity article (e.g. `Molina Mold`, a `{{Infobox Species}}` page). Create the entity at `<Name> (commodity)` and add a disambig entry, or leave the existing article alone — don't overwrite it.
- **Create-bucket pages still need the lead pass.** Pages created (not migrated) tend to get a bare templated lead like `"'''X''' is a [[Commodity|processed]] commodity."`. Give them the same grounded-lead pass as migrated pages (pull the API `description`, write a real one-sentence lead + game cite); audit for the `"is an? … commodity\.?$"` pattern to find them.
- **Don't touch `{{Entity}}` template internals from this skill.** This is a content-migration skill; template changes belong in a separate session.
- **The `{{Item}}` template still exists wiki-side** during migration — it's not breaking, just legacy. Other categories may still rely on it. Don't delete the template.
- **Category mass-deletion trips the harness security classifier.** Deleting many shared categories in one run is flagged as unauthorized external-system writes, and a subagent doing it gets blocked mid-run. Get **explicit user confirmation of the specific delete targets** as a listed batch before running the deletions; don't try to work around the gate.

## What this skill does not do

- It doesn't add a type to `Module:Entity/Item/classifications.json` or wire the on-wiki category tree. If the user's type isn't in the map, do that first (see `project_entity_category_taxonomy` memory) before running this skill.
- It doesn't deploy code changes. Use `deploy-to-wiki` for that.
- It doesn't fabricate factual content for sparse pages. Leave sparse pages sparse.
