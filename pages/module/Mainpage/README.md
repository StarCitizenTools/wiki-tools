# Module:Mainpage

Renders the main page: hero, highlights, featured article, on this day, the editing invitation, the two community cards, the directory at the foot, and a foot row linking the page an editor changes.

Reached through `Template:Mainpage`, which is one line and takes no parameters:

```wikitext
{{Mainpage}}
```

The page needs nothing else: the module emits its own TemplateStyles and the tracking category that loads the gadget. One dependency lives outside it — `MediaWiki:Citizen.css` drops the body container's gutter for the main page, which is what lets the bands paint full bleed. Anywhere else the bands sit inside the skin's normal gutter.

## Changing what the page shows

Everything an editor changes is in one file, [[Module:Mainpage/settings.json]], linked from the foot of the rendered page. It carries its own guidance in a `_readme` at the top; what follows is the reference.

**That page is not in this repository, deliberately.** It is content rather than code — changed on the wiki by whoever is updating the featured article or the running event — so the wiki is its source of truth and keeps its own history. A copy here would be stale the moment somebody edited it, and a stale tracked copy is worse than none: deploying the module would quietly revert them. It is gitignored, and `deploy-to-wiki` skips it even if an old copy is still sitting on disk. Read the live page to see what it currently holds; the table below is what it may hold.

| Section | Holds |
| --- | --- |
| `featured` | `page` and `text` — the article in the featured card and the line beside its title. The picture is the article's own **Page Image**, so the page name is all there is to set; without one it falls back to a placeholder. With no `page` at all the card falls back to [Star Citizen](https://starcitizen.tools/Star_Citizen) — deliberately not the main page itself, which would render as a self-link and silently kill the whole-card link. |
| `event` | `name`, `page`, `text`, `starts`, `ends`, and **one of** `banner` or `image` — see below. Clearing `name` removes the whole card; clearing `ends` keeps the card and drops its countdown. |
| `patches` | One object per build chip: `channel`, `name`, `page`, `highlights`. `channel: "LIVE"` takes the filled marker and also fills the "this patch" card. Adding a chip is adding an object. |
| `hero` | `image`, `lede`, `ledeDetail`, `searchTails`. |
| `chips` | The row of links under the hero. |
| `directory` | The groups of links at the foot. |

A link entry is `{ "page": …, "label": … }` for somewhere on this wiki or `{ "url": …, "label": … }` for somewhere else; `label` is optional on a wiki link. How many columns the directory shows is not configured anywhere: it reflows to fit.

### The event card's two designs

The picture chooses the design, because the picture is the thing that actually differs. Set one key, not both; with both, `banner` wins.

| Key | Design |
| --- | --- |
| `banner` | One of the 1080×83 strips in [[:Category:Main page banner images]]. It runs across the top of the card **at the height it was drawn**, so the card shows a centred slice of it rather than a shrunken whole — about two thirds at the full measure, about a quarter in the narrowest column. What to check before setting one is not its height, which is fixed, but whether its logo survives a centre crop; a banner with its mark out at an edge loses it on a phone. |
| `image` | An ordinary screenshot. It stands in a column beside the text on a wide card and across the top on a narrow one, so its subject wants to be near the middle. A banner strip set here comes out a smear — a portrait column is the one shape a 13:1 frieze cannot be cropped to. |

Naming the asset names the layout, so no editor can pair a design with a picture it cannot show. Switching between them is a settings edit, never a module edit.

**Why JSON and not a `#switch` template.** Three things that matter to the people editing it: MediaWiki refuses to *save* invalid JSON, so the page cannot be left broken; a list is a real array, so nothing has to be escaped or separated; and the build chips are a list of objects rather than `patch1type` / `patch2type` / `patch3type` flattened into numbered keys. The cost, paid deliberately, is that JSON has no comments — so the guidance that used to sit inline lives in the file's own `_readme` and here.

**A malformed value never takes the page down.** An event date the clock cannot read costs the clock and nothing else; a settings page that has been moved or deleted costs only what it feeds. Dates are accepted as `YYYY-MM-DD`, optionally with `HH:MM` or `HH:MM:SS`, and a trailing `UTC` is tolerated; anything else is treated as unset.

## Structure

| Submodule | Renders |
| --- | --- |
| `Mainpage/Config` | Loads `settings.json`; normalises it into plain Lua and resolves which build is live |
| `Mainpage/Nav` | Turns a link entry into wikitext |
| `Mainpage/Event` | The event card built on a banner strip |
| `Mainpage/Event/Legacy` | The event card built on an ordinary photograph |
| `Mainpage/Hero` | The hero band |
| `Mainpage/Highlights` | The event and patch cards |
| `Mainpage/Featured` | The featured card |
| `Mainpage/OnThisDay` | Today's date page, as a tabber |
| `Mainpage/Editing` | The editing invitation and recent-changes list |
| `Mainpage/Community` | The funding and Discord cards |
| `Mainpage/Directory` | The directory at the foot |

The foot row is small enough to live in `Mainpage` itself rather than take a submodule of its own.

`Config` is the only thing that touches `mw.loadJsonData`. It copies the result into a plain table on the way through, which confines the read-only metatable — the one that breaks `#` and `next()` — to a single function, and drops blank strings so clearing a value behaves the same as deleting its line.

Buttons come from `Module:ButtonLua`, the badge from `Module:BadgeLua` and the clock from `Module:Countdown`, so each keeps its own look and this module supplies only content and placement.

The clock is the one worth spelling out, because it is arranged two ways and neither is this module's to decide. `Module:Countdown` stands its units in a column for a card that gives it a slot down one side, and lies them flat otherwise. The banner card asks for flat by passing `t-countdown--flat`, since it is a single column at every width. The split card cannot: it is stacked between 640 and 900 and side by side above it, and a class cannot be conditional on the viewport — so that one range is a media query in `Mainpage/styles.css` holding a copy of the clock's own declarations. **A copy that has to be kept in step**; it is the only place on this page that restyles another component's internals.

`Mainpage/Highlights` renders the band and the patch card, and hands the event card to whichever of the two event modules the settings call for. Both return nil when the settings do not carry what they need, so an unset event still costs only its own card.

The two highlight cards are `Module:CardLua` media cards. The other five are built here with `.t-card` on a plain div, because they are not media cards — the featured card puts its body *over* the picture under a scrim, and the rest carry no picture at all. `Module:CardLua/styles.css` is therefore listed explicitly in `STYLESHEETS`; leaving it to arrive with a CardLua call would strip the card chrome off the page whenever the highlights band is empty.

### The grid

Every band is `.home-band` (full-bleed ground) wrapping `.home-band__inner` (the measured column). A band of cards puts `.home-grid` on the inner element. All bands share one twelve-column grid so a card edge in one lands on the same line as a card edge in the next — a band that sets its own column ratios breaks that alignment for the whole page.

Spans go on the card itself: `.home-card--read` (8), `.home-card--aside` (4), `.home-card--tall` (8, two rows). They are placement properties, so unlike a class that sets `display` they cannot collide with CardLua's own `.t-card`. **Never put a class that sets `display` on the same element as `t-card`.**

Between 640 and 900 every card becomes `span 6`, which keeps two columns without changing the arrangement. Below 640 the page is a single column in DOM order.

## Styles

| Page | Holds |
| --- | --- |
| `Mainpage/styles.css` | The hero, the bands, the grid, and the responsive stages |
| `Mainpage/cards.css` | The individual cards, the directory, and the foot |
| `Mainpage/ground.css` | The graduation tapes and the dot lattice behind the page |

## The gadget

`MediaWiki:Gadget-mainpage.js` enhances the rendered page: it loads the hero artwork after page load, rolls the stat digits and the search label's tail, drives the clock, and refreshes the activity list — which matters because DPL forces a one-hour parser cache on any page that calls it.

It reads its context from `data-gadget-mainpage-*` attributes on the elements it enhances, so `grep gadget-mainpage-` finds every emitter and the gadget that consumes them. The page renders and reads correctly with the gadget absent.

## Previewing

```wikitext
{{#invoke:Mainpage|hero}}              <!-- the hero on its own -->
{{#invoke:Mainpage|hero|noscript=yes}} <!-- as a reader with no JavaScript sees it -->
```
