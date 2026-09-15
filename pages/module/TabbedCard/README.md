# Module:TabbedCard

A card whose body is a set of tabs: the [Module:CardLua](https://starcitizen.tools/Module:CardLua) shell wrapped around a [TabberNeue](https://www.mediawiki.org/wiki/Extension:TabberNeue) tabber, for a group of alternative readings of one thing that would otherwise stack as several separate boxes.

Required by [Module:Entity/Description](https://starcitizen.tools/Module:Entity/Description), which uses it for a contract that carries several interchangeable in-game descriptions. Also invocable directly as `{{#invoke:TabbedCard|main|label1=…|content1=…}}`.

## For module editors

### API

- `p.render(props)`: `{ tabs, footer?, flush?, class? }`. `tabs` is a list of `{ label, content }`; the first is the open tab. Returns `<templatestyles>` + markup, or `''` when no tab survives `resolveTabs`, so a caller can hand over whatever it has and get nothing rather than an empty card.
- `p.resolveTabs(tabs)`: the tabs worth rendering, keeping order. Drops any entry without both a non-empty string `label` and non-empty `content`, and stringifies `content` so callers can pass `mw.html` nodes. Exposed because it is the only logic here worth a test.
- `p.main(frame)`: the `#invoke` entry point. Reads numbered pairs `label1`/`content1` … up to 20, plus `footer`, `flush` and `class`.

### Extending

`flush = true` drops the panel padding, for a body that owns its own edges (a table, an image). Anything else about the box belongs to `CardLua`: pass `footer` for an attribution line below a divider, or `class` for a consumer hook.

### Gotchas

- `p.main` stops at the first missing number, so `label3` with no `label2` silently loses the third tab rather than renumbering it. That is deliberate: a renumbering pass would hide the typo instead of showing it.
- `mw.ext.tabber` is resolved inside `render`, not captured at module load. The tabber library only exists on the `mw` global on-wiki, and a load-time capture makes the module unrequirable off-wiki, which breaks the unit runner for every module that requires it.
- The tab strip takes a raised fill and runs to the card's edge, relying on `.t-card`'s `overflow: clip` to trim it to the border radius. A consumer that overrides the card's overflow gets square corners behind the tabs.

### Styles

CSS lives in [Module:TabbedCard/styles.css](https://starcitizen.tools/Module:TabbedCard/styles.css), loaded automatically by `render`. It sets only the tabber's fit inside the card, since the shell already supplies the border, surface, radius and corner clipping. Class contract: `t-tabbed-card` (root, on the `CardLua` card) and the `t-tabbed-card--flush` modifier.
