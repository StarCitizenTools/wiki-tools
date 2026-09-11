# Module:CardLua

A reusable card primitive: a bordered, surface-coloured, rounded container with a shared header row (title + description, an optional trailing element) and an optional always-visible footer. [Module:CollapsibleCard](https://starcitizen.tools/Module:CollapsibleCard), `renderLinkCard`, and `renderMediaCard` are specializations built on it.

Required by [Module:CollapsibleCard](https://starcitizen.tools/Module:CollapsibleCard), [Module:Mainpage/Event/Event](https://starcitizen.tools/Module:Mainpage/Event/Event), [Module:Mainpage/Event/Legacy](https://starcitizen.tools/Module:Mainpage/Event/Legacy), [Module:Entity/Availability](https://starcitizen.tools/Module:Entity/Availability), and [Module:Entity/Blueprints](https://starcitizen.tools/Module:Entity/Blueprints); not invoked from templates.

## For module editors

### API

- `p.render(props)`: wraps `content` (and optional `footer`) in the card shell; returns `<templatestyles>` + markup. `{ content, footer?, class? }`.
- `p.renderHeader(props)` / `p.renderHeaderContent(title, description)`: a static header row (title + description, optional `trailing` element on the right). `renderHeaderContent` is exposed separately so an interactive consumer (`CollapsibleCard`'s `<summary>`) can place it inside its own header element alongside its own trailing control.
- `p.renderLinkCard(props)`: a static card whose header's trailing slot is one or more [Module:ButtonLua](https://starcitizen.tools/Module:ButtonLua) buttons. `{ title, description?, buttons, class? }`.
- `p.renderMediaBody(props)` / `p.renderMediaCard(props)`: a card that leads with a picture (`image`, `imageAlt?`, `imageWidth?` default 480) followed by a `content` slot, usually `renderMediaBody(...)`'s standard text block (`title`, `link?`, `kicker?`, `body?`, `readout?`, `more?`). `layout` is `'split'` (default, art beside text) or `'banner'` (art across the top). `stretchLink = true` makes the whole card clickable by stretching the title's own anchor over it (requires a link in `content`); it costs body text selectability.
- `p.mediaCard(frame)`: the `#invoke` entry point wrapping `renderMediaCard` + `renderMediaBody`; not currently invoked by any template. Its `after` argument is deliberately untyped wikitext appended after the body (e.g. `|after={{#invoke:Countdown|main|…}}`), letting a template hand in a second column without this module learning what it is.

### Gotchas

- `renderMediaBody`'s `body` wikitext is prefixed with a literal newline: `mw.html` emits the wrapping `<div>` inline, so a leading `*` list would otherwise sit right after `>` and render as literal text instead of opening a list.
- `more` renders as `aria-hidden` styled text, never a second anchor: the title already links the page (or, on a stretched card, the whole surface does), so a second link would only be a duplicate stop for keyboard and screen-reader users.
- On a `stretchLink` card, `styles.css` only auto-lifts `<a>` elements specifically inside `.t-card__body`, `.t-card__readout`, or `.t-card__footer` (`position: relative; z-index: 2`); any other interactive element, or a link elsewhere (e.g. a consumer's own extra content column), needs its own lift or it becomes unclickable under the stretched anchor.

### Styles

CSS lives in [Module:CardLua/styles.css](https://starcitizen.tools/Module:CardLua/styles.css), loaded automatically by `render`. Class contract for consumers: `t-card` (root), `t-card__header` / `__header-content` / `__title` / `__description` / `__trailing`, `t-card__content`, `t-card__footer`, `t-card__media-layout` (`--split` / `--banner`), `t-card__media`, `t-card__media-body`, `t-card__kicker`, `t-card__body` (styles a wikitext `*` list to card scale), `t-card__foot` / `__readout` / `__readout-label` / `__readout-value`, `t-card__more`, and `t-card--link` (the stretch-link modifier).
