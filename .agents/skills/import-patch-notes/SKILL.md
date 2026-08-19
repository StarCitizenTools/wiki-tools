---
name: import-patch-notes
description: Use when a new Star Citizen patch has gone LIVE and its Update: page needs writing or filling in - resolving CIG's patch-notes comm-link, pulling the full notes out of it, and turning the pre-release stub into the finished page. Triggered by "a new patch dropped", "import the 4.10 patch notes", "write the Update page for 4.10.0", "4.10.1 is out".
---

# Import Patch Notes for a New Patch

Operator-run pass that turns CIG's patch-notes comm-link into a finished `Update:Star Citizen Alpha <version>` page. Run it once per release, major or point.

This is **not** an ingestion pipeline and is not automated. CIG changes its comm-link format regularly - the wiki's own comm-link mirror (`api.star-citizen.wiki`) covers eras 1-4 and 404s for every 4.x patch, era-5 prose moved into Vue component attributes on a separate fragment, and the component set varies from patch to patch. The steps below record the shape as of Alpha 4.9 (verified 2026-08-19) **and how to re-derive it when it shifts**. Expect to check, not to assume.

The 167-page standardisation pass that established this layout is done; see the `project_patch_page_redesign` and `project_patch_pass_resume` memories. Every `Update:` page already matches the skeleton in step 5, so a new page only has to join them.

**REQUIRED BACKGROUND:** `expand-stub-with-source` covers the `{{Cite RSI}}` and named-ref conventions used in steps 5 and 8, and its draft-before-post discipline applies here in full (step 9). Publish with `deploy-to-wiki`'s MCP contract - `wiki: "starcitizen.tools"` on every call.

## When to use vs not

**Use** when:
- A patch has gone LIVE and its `Update:` page is still the pre-release stub, or has only a summary.
- A point release (4.10.1, 4.10.2) has shipped.

**Don't use** when:
- The patch is unreleased. Those pages carry a roadmap link instead of patch notes and there is no comm-link to import.
- You only need one mechanical edit to an existing page.
- The page is era 1-4 (below 4.0). Those are done and their sources differ.

## Prerequisites

- Public reads via `curl`. No credentials, no API key.
- Writes through the MediaWiki MCP with `bot: true`.

## The starting state is a pre-release stub, not a blank page

Read this before step 1. The page almost always exists already, written months earlier from the roadmap, and **the job is a delta, not a fresh write**. As of today `Update:Star Citizen Alpha 4.10.0` reads:

```
{{stub}}
{{PatchData
| buildnumber =
| Prev = Star Citizen Alpha 4.9.0
| Next = Star Citizen Alpha 4.11.0
| futurerelease = yes
| publishdate =
...
```

`Template:PatchData` keys three visible behaviours off `futurerelease`: the category (`Upcoming Patches` vs `Patch Notes`), the status badge (**Upcoming** vs **Released**), and the short description ("scheduled for" vs "released on"). **Leaving it set publishes a shipped patch as upcoming.** The release transitions:

| Field / section | Pre-release | After import |
|---|---|---|
| `futurerelease` | `yes` | **empty** |
| `buildnumber` | empty | from the release line, e.g. `4.9.0-LIVE.12232306` |
| `publishdate` | empty | the LIVE date |
| `{{stub}}` | present | removed |
| lead | "is a **planned** major update … **expected to bring**" | past tense, what shipped |
| `== Official links ==` | roadmap link only | the real link set (step 7) |
| `== Roadmap deliverables ==` | already populated from the roadmap | reconcile against what actually shipped; deliverables get cut |

Everything else - `Prev`, `Next`, `image`, categories, `DEFAULTSORT` - carries over verbatim. Never synthesise those (`feedback_carry_metadata_verbatim`). Check the neighbouring pages' `| Next =` and `| Prev =` chain to the new page.

## Steps

### 1. Resolve the comm-link

Patch notes live under `/comm-link/Patch-Notes/<id>-<slug>`. Announcements and patch reports live under `/comm-link/transmission/<id>-<slug>`.

**Always pass `-L`.** `/comm-link/…` 301s to `/en/comm-link/…`; without `-L` you get a **301 and a zero-byte body**, which reads like "CIG changed the format" when nothing has changed. Set a browser User-Agent too.

If you have the id but not the slug, probe the id-redirect endpoint. **Capture the status code** - it, not the URL, is the discriminator:

```bash
UA='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/120 Safari/537.36'
curl -s -o /dev/null -w '%{http_code} %{url_effective}\n' -L -r 0-0 -A "$UA" \
  "https://robertsspaceindustries.com/comm-link/SCW/<id>-API"
```

`-r 0-0` keeps it to one byte. The two signals together answer three questions:

| Result | Means |
|---|---|
| `200` at `/en/comm-link/…` | a real comm-link - read the section and slug off the URL |
| `200` at some other path | the id exists but is not a comm-link (an event page, a sale) |
| `404` at `/en/comm-link/SCW/<id>-API` | **the id does not exist yet** |

That last row is how you tell "CIG has not published it" from "wrong id". Note the URL is *not* unchanged on a miss - `/en/` still gets inserted - so match on the `404` and the `SCW/…-API` tail, not on the URL alone.

**Do not use `-I`.** A HEAD request returns **200 for every id**, including ids that do not exist (verified with 99999, where GET gives 404). It makes the whole id space look alive.

If you have neither id nor slug, **scan the whole window** above the previous patch's notes id and keep every hit under `/comm-link/Patch-Notes/`. Do not stop at the first miss: the id space is sparse, and 21240, 21200 and 21100 are all 404 while 21245 exists. Alpha 4.0's notes are 20360 and 4.9's are 21245, so roughly 90-100 ids per release; the announcement and patch report land *before* the notes, so their ids are lower.

Beware the **soft 404**: a delisted comm-link returns HTTP 200 and serves the index page. Check for a generic `<title>` rather than trusting the status code alone.

### 2. Pull CIG's prose out of the comm-link

The page HTML is a Vue shell. The prose lives in a separate fragment:

```bash
curl -sL -A "$UA" "<comm-link url>" -o page.html
grep -oE 'alexandria/html/[0-9a-f]+/[0-9a-f]+/[A-Za-z0-9_-]+' page.html | head -1
curl -sL -A "$UA" "https://robertsspaceindustries.com/<fragment path>" -o fragment.html
```

(No leading slash on the concatenation - the grep output already starts at `alexandria/`.)

**Inventory what the fragment actually contains before extracting.** The component set varies per patch. As of 4.9:

| Component | Attribute | Encoding | Carries |
|---|---|---|---|
| `<g-faq>` | `:question-list="…"` | HTML-escaped **JSON** | the feature/fix sections, as `{title, content}` |
| `<g-article>` | `body="…"` | **raw HTML**, entities escaped | the release line, and one or more of stability / bug fixes / known issues |
| `<g-platform-client-component>` | `:properties="…"` | HTML-escaped JSON | narrative bodies - walk for `body` keys (4.8 uses this, 4.9 does not) |
| `<g-banner-advanced>` | `:content="…"` | HTML-escaped JSON | version and divider banners (step 3) |

Watch the encoding column: the JSON attributes need an unescape *then* a parse, but `g-article`'s `body=` is already raw markup (`<h3>…`) with only entities escaped. A blanket unescape step mangles one or the other.

Everything else is marketing furniture - `g-grid` (roughly 47KB of the 88KB 4.9 fragment), nav, `g-introduction`, subscriber promos. Do not transcribe it. `g-introduction` is a judgement call: it holds the Build Info block (LTP status, server meshing config, starting aUEC), which 4.0.0 and 4.2.1 transcribe under `=== Build and server information ===` but 4.5.0 onward drop. **Drop it** - modern pages do.

Two things to filter:

- **Turbulent's lorem ipsum.** The component templates ship pre-filled and it leaks into the rendered fragment. In 4.8.1's span a `g-platform-client-component` carries a lorem `body` *right beside* the real one. Drop any block matching `lorem ipsum`, `ut labore et dolore`, `tempor incididunt`, `dolor sit amet`.
- **Ordering.** Sort blocks by their offset in the fragment, not by component type, or the sections come out shuffled.

**If the selectors match nothing**, the format has moved. Dump the fragment and look for the longest runs of escaped prose; the carrier is whichever attribute holds `&lt;p&gt;` or `&lt;li&gt;`. Record what you find here before moving on.

### 3. Point releases live inside the major's comm-link

CIG stopped giving point releases their own comm-link. 4.7.1, 4.7.2, 4.8.1, 4.8.2 and 4.8.3 all have their notes as a **version-titled section inside the 4.7 / 4.8 comm-link**.

Partition the major's fragment by `<g-banner-advanced>` markers, but **only those whose `:content` JSON has a `text.title` matching `Star Citizen Alpha ([\d.]+) LIVE`**. Each *version* banner starts a span running to the next *version* banner, or to end of fragment for the last one.

**Divider banners do not split a span.** CIG uses the same component for section dividers, and they sit *inside* a version span. The live 4.8 fragment:

```
  1525  VERSION  Star Citizen Alpha 4.8.3 LIVE
 10279  VERSION  Star Citizen Alpha 4.8.2 LIVE
 20480  VERSION  Star Citizen Alpha 4.8.1 LIVE
 31045  VERSION  Star Citizen Alpha 4.8 LIVE     <- base span, runs to EOF (147246)
 83775  divider  Features and Gameplay
126460  divider  Bug Fixes & Technical Updates
140606  divider  Known Issues & Information
```

Treating dividers as span boundaries ends the 4.8 base span at 83775 and **silently discards about 78% of the patch notes**. Version banners are ordered newest-first, so the base release is the last span - exactly where the truncation costs most.

Those three divider titles are worth knowing by name: they also supply the group labels for `== What's new ==` (step 5), and whether a `Known Issues` divider exists at all tells you whether the patch has a known-issues section.

CIG titles the base patch "Alpha 4.8 LIVE" while the wiki calls it 4.8.0 - zero-pad both sides to three parts before comparing, or the base release matches nothing.

### 4. Turn CIG's blocks into wikitext

CIG's markup is shallow and regular: `h2`/`h3`/`h4` for sections, `ul`/`li` (sometimes nested) for change lists, `p` for prose, `strong`/`em` for emphasis.

**Heading depth is per carrier, not global:**

- A `g-faq` entry's `title` becomes an `h3` section; `h3`s *inside* its `content` map onto `h4`.
- A `g-article`'s own `h3`s map onto `h3` - they are top-level sections. 4.9's second article carries `<h3>Stability & Performance</h3>` and `<h3>Bug Fixes</h3>`, which the live page renders as `=== Stability and performance ===` / `=== Bug fixes ===`. Mapping them to `h4` buries the whole bug-fix tree a level too deep.

**A faq `title` is a teaser string, not a heading.** Keep only the text before the first colon, then canonicalise it (`reference_heading_case_normalisation`):

| fragment `title` | heading |
|---|---|
| `Gameplay: "Support the Miners" Mission Pack - Ordnance Framing - Frieght Eleva…` | `=== Gameplay ===` |
| `Ships & Vehicles:  Hit Markers - Weapon Rebalance` | `=== Ships and vehicles ===` |
| `Content & Feature Updates: Defend Location Missions` | `=== Content and feature updates ===` |

Emitting the whole string ships CIG's typos as headings (`Frieght` above). Headings *inside* a block are kept verbatim - only the faq title is truncated at the colon.

### 5. Assemble the page

The settled skeleton, in this order. Omit a section only when it genuinely has no content.

```
{{PatchData}}
[[File:<banner>|thumb]]              (when one exists)
<lead prose> + <ref>{{Cite RSI|…}}</ref>

== Official links ==
== What's new ==                     (only when CIG published a summary)
== Patch notes ==
== Roadmap deliverables ==
== Media ==
== References ==
<references />

{{DEFAULTSORT:<n.nn.n>, Alpha}}
[[Category:Major Patches]]          or [[Category:Minor Patches]]
```

Rules the whole namespace follows:

- **All of CIG's prose goes under `== Patch notes ==`**, keeping CIG's own structure. Do not summarise, reorder or trim it.
- **Known issues goes last** inside `== Patch notes ==`, as `=== Known issues ===`, opening with the gloss `''The issues Cloud Imperium Games listed as outstanding at release.''` so it reads as CIG's list rather than the wiki's. Some patches have none - 4.9 links a Knowledge Base instead, and its page has no such section. Do not manufacture one.
- **`<references />`**, never `{{reflist}}`. No `=` (h1) headings anywhere.
- **`DEFAULTSORT` zero-pads the minor**: 4.9.0 sorts as `4.09.0, Alpha`. A few legacy pages lack it; add it, that is the settled form.
- **`== What's new ==`** is a wikilinked digest of the release, grouped under bold labels that reuse the divider-banner titles from step 3 (`'''Features and Gameplay'''`, `'''Bug Fixes and Technical Updates'''`). Include it only when CIG published a summary to digest.

### 6. Promote CIG's pseudo-headings

CIG marks sub-topics several ways that MediaWiki renders as prose, not headings. Promote each to a real subsection one level below its parent. Full catalogue in `reference_patch_pseudo_heading_shapes`; the two that appear in fresh CIG imports:

- `'''// Label'''` and `'''► Label'''` - CIG's **outer** tier.
- A plain bold line, or a paragraph opening `- Label` - the **inner** tier. Where a page uses `//` or `►`, plain-bold labels nest one level under the nearest marker; where it does not, they sit directly under the enclosing heading.

CIG's bolding is unreliable: 4.8.0 writes `'''// 01 - '''Approach and Defend Tranquility`, closing the bold run after the number. The label is everything after the marker, bolded or not.

Guards, or prose gets promoted:

- **A trailing full stop disqualifies it.** `?` and `!` do not - FAQ-style headings are real (`What can I expect?`).
- Not a label if a value follows an inner colon: `Build Update: VERSION 4.8.3-LIVE.12122953` is a statement, and appears un-promoted on the live 4.8.1. A classifying colon is fine: `Delivery: Courier`.
- Not a label if it trails off into the next line (`PIT provides an interface to`).

### 7. Official links, Media, and Roadmap deliverables

**`== Official links ==`**, in this order, as `{{Link RSI}}` bullets. The `url=` is **site-relative** - no leading slash, no `/en/`:

```wikitext
* {{Link RSI|url=comm-link/Patch-Notes/21245-Star-Citizen-Alpha-49|text=Full patch notes}}
* {{Link RSI|url=comm-link/transmission/21220-Alpha-49-Frontier-Tensions|text=Alpha 4.9: Frontier Tensions}} &ndash; announcement
* {{Link RSI|url=comm-link/transmission/21228-Inside-Star-Citizen|text=Inside Star Citizen: Alpha 4.9 Patch Report}}
```

Order: full patch notes, the Spectrum release-notes thread when one exists, the announcement (suffixed ` &ndash; announcement`), then the patch report.

**`== Media ==`** carries the YouTube videos as bare external links:

```wikitext
* [https://www.youtube.com/watch?v=OX__JZULs-Y Inside Star Citizen: Alpha 4.9 Patch Report] &ndash; ''YouTube''
```

The announcement trailer first, then the patch report. The announcement transmission usually embeds both - pull the video ids from it rather than searching YouTube.

The wiki's comm-link mirror finds announcements and reports faster than probing ids, and it **does** carry the transmission series even though it has no Patch-Notes series:

```bash
curl -s 'https://api.star-citizen.wiki/api/comm-links?filter[title]=Frontier%20Tensions'   # -> rsi_url, id 21220
curl -s 'https://api.star-citizen.wiki/api/comm-links?filter[title]=Inside%20Star%20Citizen' # newest first
```

Announcements are titled like `Alpha 4.9: Frontier Tensions`; patch reports are always `Inside Star Citizen`.

**`== Roadmap deliverables ==`** is a `{| class="wikitable"` grouped by category with `colspan="2"` header rows. It comes from **RSI's roadmap, not the patch notes** - the two do not match, and deliverables get cut. The pre-release page already has this table; reconcile it against what shipped rather than rebuilding it. Link subjects that have wiki pages.

### 8. Write the lead

Wiki-written, not CIG's. One or two sentences naming what the release is actually for, cited.

**Never invent a summary.** If you cannot ground a claim in the notes, the announcement or the patch report, state the release factually instead: `'''Star Citizen Alpha 4.10.0''' is a major update for ''[[Star Citizen]]''.`

Cite whatever actually grounds the claim - era-5 leads commonly cite the patch report or a Roadmap Roundup rather than the notes. `<ref name="patchnotes">` is the corpus-wide convention (132 of 168 pages) and is the right name when the lead does cite the notes; do not force it when it does not.

No em dashes in wiki prose (`feedback_no_em_dash`).

### 9. Show the draft, then deploy and verify

**Show the assembled page before publishing and wait for an explicit yes** (`expand-stub-with-source` §5). This step overwrites a live 25-50KB article; the draft gate is not optional.

Publish through the MediaWiki MCP with `wiki: "starcitizen.tools"` and **`bot: true`**; confirm `botMarked` in the response.

Then run both gates. Neither is optional - a successful `update-page` proves only that the wiki stored something. Do not lean on `latestRevisionId` as a conflict guard; it is accepted but not enforced (`reference_mcp_updatepage_latestid_not_enforced`), so the byte-diff is the real check.

**Fidelity gate - did the extraction keep everything?** Every heading and body line **in the blocks you extracted in step 2** must appear in the output. (Not the whole fragment - most of it is marketing furniture, and gating on that floods you with false misses until you switch the gate off.) Normalise both sides - strip wiki markup, HTML tags, `&nbsp;`, punctuation, lowercase - and report any source line with no match. This is the gate that matters most: there is no committed generator, successive runs are not byte-reproducible, and silent truncation is the failure mode. During the pass it caught 19 lost table rows on 4.0.0 and a whole patch duplicated on 4.0.2.

**Byte-diff gate - did the wiki store what you sent?** Fetch `index.php?title=<title>&action=raw` and diff against your source. Use `action=raw`, not `get-page`, which truncates at 50k. Tolerate only a trailing-newline difference. Hand-pasting a long page has already introduced a stray blank line once; this is what catches it.

Fix and redeploy until both are clean.

## Gotchas

- **Check the previous patch's page first.** Fetch its `action=raw` and match its conventions wherever they disagree with this document - the corpus is the authority, and it drifts. Cheapest possible guard against this file going stale.
- **Edit sections back to front.** MediaWiki's `section=N` replaces a section *and its subsections*, and promoting a label adds a subsection, renumbering everything after it. Section edits are much cheaper than a full-page write on a 50KB page.
- A section edit that would drop subsections is refused unless you pass `removeSubsections`. That refusal is usually telling you the target section is broader than you think - re-target rather than override.
- The mainspace twin (`Star Citizen Alpha 4.10.0`) is a redirect to the `Update:` page. Leave it alone.

## What this skill does not do

- **Eras 1-4** (below Alpha 4.0). Those pages are complete and were built from different sources - the wiki's comm-link mirror rather than the Vue fragment.
- **Detecting that a patch shipped.** An operator starts this; nothing polls.
- **Deciding whether a thin point release keeps `{{stub}}`.** If CIG published almost nothing, a short page is the correct outcome - do not pad it. Whether the tag stays is the owner's editorial call.
- **Authoring roadmap deliverables.** They come from RSI's roadmap and are usually already on the page before the patch ships.
