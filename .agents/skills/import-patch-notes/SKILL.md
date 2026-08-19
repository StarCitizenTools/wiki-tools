---
name: import-patch-notes
description: Use when a new Star Citizen patch has gone LIVE and its Update: page needs writing or filling in - resolving CIG's patch-notes comm-link, pulling the full notes out of it, and assembling the standard page. Triggered by "a new patch dropped", "import the 4.10 patch notes", "write the Update page for 4.10.0", "4.10.1 is out".
---

# Import Patch Notes for a New Patch

Operator-run pass that turns CIG's patch-notes comm-link into a finished `Update:Star Citizen Alpha <version>` page. Run it once per release, major or point.

This is **not** an ingestion pipeline and is not automated. CIG changes its comm-link format regularly - the wiki's own archive covers eras 1-4 and 404s for every 4.x patch, era-5 notes moved into Vue component attributes, and the block types vary from patch to patch. The steps below record the shape as of Alpha 4.9 (verified 2026-08-19) **and how to re-derive it when it shifts**. Expect to check, not to assume.

The 167-page standardisation pass that established this layout is done; see the `project_patch_pass_resume` memory. Every `Update:` page already matches the skeleton in step 4, so a new page only has to join them.

**REQUIRED BACKGROUND:** `expand-stub-with-source` covers the `{{Cite RSI}}` and named-ref conventions used in steps 4 and 6. Publish with `deploy-to-wiki`'s MCP contract - `wiki: "starcitizen.tools"` on every call.

## When to use vs not

**Use** when:
- A patch has gone LIVE and its `Update:` page is missing, a stub, or has only a summary.
- A point release (4.10.1, 4.10.2) has shipped.

**Don't use** when:
- The patch is unreleased. Unreleased pages carry a roadmap link instead of patch notes and have no CIG comm-link to import.
- You only need one mechanical edit to an existing page.
- The page is on eras 1-4 (anything below 4.0). Those are done and their sources differ.

## Prerequisites

- Public reads via `curl`. No credentials, no API key.
- Writes through the MediaWiki MCP with `bot: true`.

---

## 1. Resolve the comm-link

Patch notes live under `/comm-link/Patch-Notes/<id>-<slug>`. Announcements and patch reports live under `/comm-link/transmission/<id>-<slug>`.

**Always pass `-L`.** `/comm-link/…` redirects to `/en/comm-link/…`; without `-L` curl returns **200 with a zero-byte body**, which looks exactly like "CIG changed the format" when nothing has changed. Set a browser User-Agent too.

If you have the id but not the slug, probe the id-redirect endpoint:

```bash
UA='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/120 Safari/537.36'
curl -s -o /dev/null -w '%{url_effective}\n' -L -r 0-0 -A "$UA" \
  "https://robertsspaceindustries.com/comm-link/SCW/<id>-API"
```

`-r 0-0` keeps it to one byte. **`-I` does not work here** - a HEAD request does not follow this redirect.

The effective URL answers three different questions at once:

| Resolves to | Means |
|---|---|
| `/en/comm-link/…` | a real comm-link - read the section and slug off the URL |
| anything else on the site | the id exists but is not a comm-link (an event page, a sale) |
| unchanged, still `/comm-link/SCW/<id>-API` | **the id does not exist yet** |

That last row is how you tell "CIG has not published it" from "wrong id" - useful before concluding a patch is missing.

If you have neither id nor slug, walk upward from the previous patch's notes id until the ids stop resolving. Alpha 4.0's notes are 20360 and 4.9's are 21245, so roughly 90-100 ids per release; the announcement and patch report land a few weeks *before* the notes, so their ids are lower.

Beware the **soft 404**: a delisted comm-link returns HTTP 200 and serves the index page. Check for a generic `<title>` rather than trusting the status code.

## 2. Pull CIG's prose out of the comm-link

The page HTML is a Vue shell. The prose lives in a separate fragment:

```bash
curl -sL -A "$UA" "<comm-link url>" -o page.html
grep -oE 'alexandria/html/[0-9a-f]+/[0-9a-f]+/[A-Za-z0-9_-]+' page.html | head -1
curl -sL -A "$UA" "https://robertsspaceindustries.com/<fragment path>" -o fragment.html
```

**Inventory what the fragment actually contains before extracting.** The component set varies per patch - 4.8 used narrative components that 4.9 does not have. As of 4.9:

| Component | Attribute | Carries |
|---|---|---|
| `<g-faq>` | `:question-list="…"` | HTML-escaped **JSON** array of `{title, content}` - the feature and fix sections |
| `<g-article>` | `body="…"` | HTML-escaped **HTML** - the release line and known issues |
| `<g-platform-client-component>` | `:properties="…"` | HTML-escaped JSON; walk it for `body` keys (4.8 used this, 4.9 does not) |
| `<g-banner-advanced>` | `:content="…"` | HTML-escaped JSON; `text.title` delimits version spans (step 3) |

Everything else on the page is marketing furniture - banners, nav, subscriber promos. Do not transcribe it.

Two things to filter:

- **Turbulent's lorem ipsum.** The component templates ship pre-filled and some pages leak it into the rendered fragment. Drop any block matching `lorem ipsum`, `ut labore et dolore`, `tempor incididunt`, `dolor sit amet`.
- **Ordering.** Sort blocks by their position in the fragment, not by component type, or the sections come out shuffled.

Convert each block's HTML to wikitext. CIG's own markup is shallow and regular: `h2`/`h3`/`h4` for sections, `ul`/`li` (sometimes nested) for change lists, `p` for prose, `strong`/`em` for emphasis. Map CIG's `h3` onto the page's `h4` so its sections sit under `== Patch notes ==` correctly.

**If the selectors above match nothing**, the format has moved. Re-derive by dumping the fragment and looking for the longest runs of escaped prose - `grep -oE 'alexandria[^"'"'"' ]*'` finds the fragment, and the carrier is whichever attribute holds `&lt;p&gt;` or `&lt;li&gt;`. Record what you find here before moving on.

## 3. Point releases live inside the major's comm-link

CIG stopped giving point releases their own comm-link. 4.7.1, 4.7.2, 4.8.1, 4.8.2 and 4.8.3 all have their notes as a **version-titled section inside the 4.7 / 4.8 comm-link**.

Before concluding a point release has no notes, fetch the **major's** fragment and partition it by `<g-banner-advanced>` markers whose `:content` JSON has a `text.title` matching `Star Citizen Alpha ([\d.]+) LIVE`. Each banner starts a span that runs to the next banner; extract only the blocks inside your version's span.

CIG titles the base patch "Alpha 4.7 LIVE" while the wiki calls it 4.7.0 - zero-pad both sides to three parts before comparing, or the base release matches nothing.

## 4. Assemble the page

The settled skeleton, in this order. Omit a section only when it genuinely has no content.

```
{{PatchData}}
[[File:<banner>|thumb]]              (when one exists)
<lead prose> + <ref name="patchnotes">{{Cite RSI|…}}</ref>

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

Rules that are not negotiable, because the whole namespace follows them:

- **All of CIG's prose goes under `== Patch notes ==`**, keeping CIG's own structure. Do not summarise, reorder or trim it.
- **Known issues goes last** inside `== Patch notes ==`, as `=== Known issues ===`, opening with the gloss `''The issues Cloud Imperium Games listed as outstanding at release.''` so it reads as CIG's list rather than the wiki's.
- **`<references />`**, never `{{reflist}}`. No `=` (h1) headings anywhere.
- **`DEFAULTSORT` zero-pads the minor**: 4.9.0 sorts as `4.09.0, Alpha`.
- Carry `PatchData`, categories and `DEFAULTSORT` from the existing page verbatim when one exists; never synthesise them.

## 5. Promote CIG's pseudo-headings

CIG marks sub-topics several ways that MediaWiki renders as prose, not headings. Promote each to a real subsection one level below its parent. Full catalogue in the `reference_patch_pseudo_heading_shapes` memory; the two that appear in fresh CIG imports:

- `'''// Label'''` and `'''► Label'''` - CIG's **outer** tier.
- A plain bold line, or a paragraph opening `- Label` - the **inner** tier. Where a page uses `//` or `►`, plain-bold labels nest one level under the nearest marker; where it does not, they sit directly under the enclosing heading.

CIG's bolding is unreliable: 4.8.0 writes `'''// 01 - '''Approach and Defend Tranquility`, closing the bold run after the number. The label is everything after the marker, bolded or not.

Guards, or prose gets promoted:

- Not a label if it ends in `.`, `!` or `?`. (A `?` **is** fine in an FAQ heading - only a full stop demotes.)
- Not a label if a value follows an inner colon: `Build Update: VERSION 4.8.3-LIVE.12122953` is a statement. A classifying colon is fine: `Delivery: Courier`.
- Not a label if it trails off into the next line (`PIT provides an interface to`).

## 6. Official links, Media, and Roadmap deliverables

**`== Official links ==`**, in this order, as `{{Link RSI}}` bullets:

1. `Full patch notes` - the Patch-Notes comm-link
2. the Spectrum release-notes thread, when one exists
3. the announcement transmission, suffixed ` &ndash; announcement`
4. `Inside Star Citizen: Alpha <major> Patch Report`, when one exists

**`== Media ==`** carries the YouTube videos, each suffixed ` &ndash; ''YouTube''`: the announcement trailer, then the Inside Star Citizen patch report. The announcement transmission usually embeds both - pull the video ids from it rather than searching YouTube.

Announcements are titled like `Alpha 4.9: Frontier Tensions` and sit under `/comm-link/transmission/`. Patch reports are always titled `Inside Star Citizen`. Both land a few weeks before the notes, so their ids are *lower* than the patch-notes id.

**`== Roadmap deliverables ==`** is a `{| class="wikitable"` of the release's roadmap cards, grouped by category with `colspan="2"` header rows. This comes from **RSI's roadmap, not the patch notes** - the two do not match, and deliverables get cut. Link the subjects that have wiki pages.

## 7. Write the lead

Wiki-written, not CIG's. One or two sentences naming what the release is actually for, cited with `<ref name="patchnotes">{{Cite RSI|…}}</ref>`.

**Never invent a summary.** If you cannot ground a claim in the notes, the announcement or the patch report, state the release factually instead: `'''Star Citizen Alpha 4.10.0''' is a major update for ''[[Star Citizen]]''.`

No em dashes in wiki prose (`feedback_no_em_dash`).

## 8. Deploy and verify

Publish through the MediaWiki MCP with `wiki: "starcitizen.tools"` and **`bot: true`** on every write; confirm `botMarked` in the response.

Then run both gates. Neither is optional - a successful `update-page` proves only that the wiki stored something.

**Fidelity gate - did the extraction keep everything?** Every heading and every body line in CIG's fragment must appear in the output. Normalise both sides (strip wiki markup, HTML tags, `&nbsp;`, punctuation; lowercase) and report any source line with no match. This is the gate that matters most here: there is no committed generator, so successive runs are not byte-reproducible, and a silently truncated extraction is the failure mode. During the pass this caught 19 lost table rows on 4.0.0 and a whole patch duplicated on 4.0.2.

**Byte-diff gate - did the wiki store what you sent?** Fetch `index.php?title=<title>&action=raw` and diff against your source. Use `action=raw`, not `get-page`, which truncates at 50k. Tolerate only a trailing-newline difference. Hand-pasting a long page has already introduced a stray blank line once; this is what catches it.

Fix and redeploy until both are clean.

## Notes

- Deploying a section at a time is cheaper than a full page and safer for large pages, but MediaWiki's `section=N` replaces a section **and its subsections**. Promoting a label adds a subsection and renumbers everything after it, so **edit sections back to front**.
- A page's mainspace twin (`Star Citizen Alpha 4.10.0`) is a redirect. Leave it alone.
- If a point release is still a stub after import because CIG published almost nothing, that is the correct outcome - do not pad it. Whether to keep `{{stub}}` is the owner's editorial call.
