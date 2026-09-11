# Module:Mainpage

Renders the main page: hero, highlights, featured article, on this day, the editing invitation, two community cards, and the directory, plus a foot row linking to the page an editor changes.

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
| `Mainpage/Editing` | The editing invitation plus a DPL-backed recent-changes list. |
| `Mainpage/Community` | The funding card and the Discord/follow card. |
| `Mainpage/Directory` | The grouped text directory at the foot. |

`Mainpage.lua` composes these into the page and renders the foot row itself; that row is small enough to not need a submodule of its own.

### Settings contract

Every other submodule reads settings through `Config`, never through `mw.loadJsonData` directly:

- `Config.section(name)` / `Config.list(name)`: one top-level object or array, `{}`/empty when the section is missing or blank, so a caller never has to nil-check first (`Config.lua:101-116`).
- `Config.toIso(value)`: a settings date to ISO 8601 UTC, or `nil` for anything it can't read; it never raises (`Config.lua:134-163`).
- `Config.livePatch()`: the one build every consumer agrees is "live" (the first `patches` entry with `channel: "LIVE"`, else the first with a `name`), resolved once so the hero's status chip and the patch card can't name different builds (`Config.lua:177-193`).
- `load()` wraps `mw.loadJsonData` in `pcall`; a moved or deleted settings page degrades to `{}` rather than raising (`Config.lua:80-90`).

`toPlain` (`Config.lua:47-77`) is the one place that touches the loaded page's read-only table, whose metatable breaks `#` and `next()`; it copies the result into a plain table, drops blank strings to `nil`, and compacts arrays. Read a new settings field through `Config`'s existing functions rather than adding a second `mw.loadJsonData` call elsewhere.

### Styles

| Page | Holds |
| --- | --- |
| `Mainpage/styles.css` | The hero, the bands, the grid, and the responsive stages. |
| `Mainpage/cards.css` | The individual cards, the directory, and the foot. |
| `Mainpage/ground.css` | The graduation tapes and the dot lattice behind the page. |

The page runs full bleed: `MediaWiki:Citizen.css` drops the body container's gutter specifically for this page, which is what lets the bands paint edge to edge (`Mainpage/styles.css:11-12`). That rule lives outside this module and outside this repository.

### Gadget

`MediaWiki:Gadget-mainpage.js` enhances the rendered page: it loads the hero artwork after page load, rolls the stat digits and the search label's tail, drives the clock, manages the two scrolling cards' fade cues, and refreshes the activity list. It reads its context from `data-gadget-mainpage-*` attributes on the elements it enhances, so `grep gadget-mainpage-` finds every emitter and the one gadget that consumes them. The page renders and reads correctly with the gadget absent.

### Previewing

```wikitext
{{#invoke:Mainpage|hero}}              <!-- the hero on its own -->
{{#invoke:Mainpage|hero|noscript=yes}} <!-- as a reader with no JavaScript sees it -->
```

### Gotchas

- `Module:Mainpage/settings.json` is editor-owned content, not tracked in this repository (gitignored: `.gitignore:20`); `deploy-to-wiki` skips it even if a stale copy is sitting on disk, since deploying it would silently revert an editor's changes.
- `STYLESHEETS` lists [Module:CardLua](https://starcitizen.tools/Module:CardLua)'s `styles.css` explicitly rather than letting it arrive with a CardLua call: six of the seven cards are built here with plain `.t-card` divs, so their surface, border, and radius would otherwise depend on the event card (the only CardLua consumer) happening to render (`Mainpage.lua:41-54`).
- Card spans (`.home-card--read`, `--aside`, `--tall`) are placement properties, not display ones; a class that sets `display` must never share an element with `t-card`, since CardLua's own `display` would collide with it (`Mainpage.lua:18-21`).
- The split event card's clock is restyled from the page for one viewport range (640-899.98px, `Mainpage/styles.css:541-603`), duplicating [Module:Countdown](https://starcitizen.tools/Module:Countdown)'s own stacked/flat declarations, because a CSS class can't be conditional on viewport width. That copy has to be kept in step by hand. The banner card avoids this entirely by asking Countdown for `t-countdown--flat` at every width instead.
- `band()` takes varargs, not a table: a table would be walked with `ipairs`, which stops at the first `nil`, so one card declining to render would silently drop every card listed after it (`Mainpage.lua:87-105`).
- The foot row's edit links and `Mainpage/OnThisDay`'s "Add an event" link both build their URL with `mw.uri.fullUrl`, not `callParserFunction`: `fullurl` is a colon magic word registered as `fullurl:`, which `callParserFunction` cannot resolve (`Mainpage.lua:107-130`, `OnThisDay.lua:94-104`).
- `Mainpage/Editing`'s recent-changes list is built from DPL, which forces a one-hour parser cache on any page that calls it; those rows are first paint and the no-JS reading only, never the freshness mechanism. `MediaWiki:Gadget-mainpage.js` polls the API to keep the visible list live (`Editing.lua:10-19`).

### Extending

A new card is a submodule with a `render()` that returns `nil` or a string; wire its call into `Mainpage.render`'s band composition and, if it ships its own stylesheet, add that stylesheet to `STYLESHEETS` explicitly rather than relying on the call site to pull it in. It then picks one of the three span classes off the shared twelve-column `.home-grid` (`.home-card--read` spans 8, `.home-card--aside` 4, `.home-card--tall` 8 across two rows); between 640 and 899.98px every span collapses to 6, and below 640 the page is one column in DOM order, so a new span value needs checking against both breakpoints.
