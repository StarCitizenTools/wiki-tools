# Module:Mainpage

Renders the main page: hero, highlights, featured article, on this day, the editing invitation, two community cards, and the directory.

Editors use this through `{{Mainpage}}`; see [Template:Mainpage](https://starcitizen.tools/Template:Mainpage) for what an editor can change and where.

## For module editors

### Submodules

| Submodule | Renders |
| --- | --- |
| `Mainpage/Config` | Loads `settings.json`; normalises it to plain Lua and resolves which build is live. |
| `Mainpage/Nav` | Turns a settings link entry into wikitext; the hero chips and the directory both read it. |
| `Mainpage/Hero` | The full-bleed hero band: patch status, wiki statline, lede, search trigger, chip strip. |
| `Mainpage/Highlights` | The band under the hero: the event card (whichever design applies) and the current-patch card. |
| `Mainpage/Event` | The event card built on a 1080×83 banner strip. |
| `Mainpage/Event/Legacy` | The event card built on an ordinary photograph. |
| `Mainpage/Featured` | The featured card: a whole-card link over the featured page's own artwork. |
| `Mainpage/OnThisDay` | Today's date page, transcluded as a two-panel tabber. |
| `Mainpage/Editing` | The editing invitation; the recent-changes list beneath it is built entirely by the mainpage gadget. |
| `Mainpage/Community` | The funding card and the Discord/follow card. |
| `Mainpage/Directory` | The grouped text directory at the foot. |

`Mainpage.lua` composes these into the page and renders the foot row itself; that row is small enough to not need a submodule of its own. Buttons come from [Module:ButtonLua](https://starcitizen.tools/Module:ButtonLua), the badge from [Module:BadgeLua](https://starcitizen.tools/Module:BadgeLua), and the clock from [Module:Countdown](https://starcitizen.tools/Module:Countdown): each keeps its own look, and this module supplies only content and placement.

### Settings contract

Every other submodule reads settings through `Config`, never through `mw.loadJsonData` directly:

- `Config.section(name)` / `Config.list(name)`: one top-level object or array, `{}`/empty when the section is missing or blank, so a caller never has to nil-check first (`Config.lua:101-116`).
- `Config.toIso(value)`: a settings date to ISO 8601 UTC, or `nil` for anything it can't read; it never raises (`Config.lua:134-163`).
- `Config.livePatch()`: the build every consumer agrees is "live" (the first `patches` entry with `channel: "LIVE"`, else the first with a `name`), resolved once so the hero's status chip and the patch card can't disagree (`Config.lua:177-193`).
- `load()` wraps `mw.loadJsonData` in `pcall`; a moved or deleted settings page degrades to `{}` rather than raising (`Config.lua:80-90`).

`toPlain` (`Config.lua:47-77`) copies the loaded page's read-only table (whose metatable breaks `#` and `next()`) into a plain one, dropping blank strings to `nil`, compacting arrays, and discarding every `_`-prefixed key as editor guidance. Read a new settings field through `Config`, never a second `mw.loadJsonData` call.

### Styles

| Page | Holds |
| --- | --- |
| `Mainpage/styles.css` | The hero, the bands, the grid, and the responsive stages. |
| `Mainpage/cards.css` | The individual cards, the directory, and the foot. |
| `Mainpage/ground.css` | The graduation tapes and the dot lattice behind the page. |

The page runs full bleed: `MediaWiki:Citizen.css` drops the body container's gutter for this page, letting the bands paint edge to edge; that rule lives outside this module and this repository (`Mainpage/styles.css:11-12`).

### Gadget

`MediaWiki:Gadget-mainpage.js` enhances the rendered page: it loads the hero artwork after page load, rolls the stat digits and search-label tail, drives the clock, manages the two scrolling cards' fade cues, and builds the activity list, reading its context from `data-gadget-mainpage-*` attributes (so `grep gadget-mainpage-` finds every emitter). The page renders and reads correctly with the gadget absent, except the activity list: without the gadget it stays empty and the card offers its "See all changes" link instead.

### Previewing

```wikitext
{{#invoke:Mainpage|hero}}              <!-- hero only -->
{{#invoke:Mainpage|hero|noscript=yes}} <!-- no-JS view -->
```

### Gotchas

- `Module:Mainpage/settings.json` is editor-owned content, not tracked in this repository (gitignored: `.gitignore:20`); `deploy-to-wiki` skips it even if a stale copy is sitting on disk, since deploying it would silently revert an editor's changes.
- `STYLESHEETS` lists [Module:CardLua](https://starcitizen.tools/Module:CardLua)'s `styles.css` explicitly: six of the seven cards use plain `.t-card` divs, so their surface, border, and radius would otherwise depend on the event card (the only CardLua consumer) rendering (`Mainpage.lua:41-54`).
- Card spans (`.home-card--read`, `--aside`, `--tall`) are placement properties, not display ones: a class that sets `display` must never share an element with `t-card`, since CardLua's own `display` would collide (`Mainpage.lua:18-21`).
- The split event card's clock is restyled from the page for one viewport range (640-899.98px, `Mainpage/styles.css:541-603`), duplicating [Module:Countdown](https://starcitizen.tools/Module:Countdown)'s stacked/flat declarations by hand, since a CSS class can't be conditional on viewport width. The banner card avoids this by asking Countdown for `t-countdown--flat` at every width instead.
- `band()` takes varargs, not a table, since `ipairs` stops at the first `nil` and would let one declined card drop every card listed after it (`Mainpage.lua:87-105`).
- The foot row's edit link and `Mainpage/OnThisDay`'s "Add an event" link both use `mw.uri.fullUrl`, not `callParserFunction`: `fullurl` is a colon magic word (`fullurl:`) that `callParserFunction` cannot resolve (`Mainpage.lua:107-130`, `OnThisDay.lua:94-104`).
- `Mainpage/Editing`'s recent-changes list is built entirely by `MediaWiki:Gadget-mainpage.js` from `list=recentchanges`: without JS the container renders empty and the card falls back to its "See all changes" link (`Editing.lua:10-12`).
- The directory's column count isn't set in Lua: `.home-dir` is `repeat(auto-fit, minmax(125px, 1fr))`, so the groups reflow on their own and `Mainpage/Directory` just emits them (`Directory.lua:10-13`).

### Extending

Every band shares one layout contract: `.home-band` is the full-bleed ground, `.home-band__inner` the measured column inside it, and a band of cards adds `.home-grid` on that inner element, all off one shared twelve-column grid; a band with its own column ratios breaks alignment for every other band (`Mainpage.lua:11-17`).

A new card is a submodule with a `render()` that returns `nil` or a string; wire its call into `Mainpage.render`'s band composition and, if it ships its own stylesheet, add it to `STYLESHEETS` explicitly. It then picks one of the three span classes (`.home-card--read` spans 8, `.home-card--aside` 4, `.home-card--tall` 8 across two rows); between 640 and 899.98px every span collapses to 6, and below 640 the page is one column in DOM order, so a new span value needs checking against both breakpoints.
