# Module:Entity/Availability

Renders an entity's acquisition block: a state-coloured summary grid (Buy, Rent, Loot, …) followed by detail cards of UEX terminal prices. It is a thin renderer: the matched kind supplies the whole `{ summary, cards }` spec; this module only knows three card shapes and how to draw the grid.

Editors use this through `{{Entity/Availability}}`; see [Template:Entity/Availability](https://starcitizen.tools/Template:Entity/Availability).

## For module editors

### Hook

Draws `getAcquisition`, resolved leaf-first over the chain (see the Hooks table on [Module:Entity](https://starcitizen.tools/Module:Entity)). Item, Vehicle, and Commodity each define `getAcquisition` on their kind link; Mission and Location define none.

Payload: `{ summary, cards }`.

- `summary`: array of `{ label, icon, value }`; `value` (`true`/`false`/`nil`) drives the Yes/No/Unknown icon, the `data-state` attribute, and the BEM state modifier.
- `cards`: array dispatched by `card.type`: `terminals` (a [Module:CollapsibleCard](https://starcitizen.tools/Module:CollapsibleCard) wrapping a UEX price table + attribution footer, via `renderTerminalTable`), `links` (a [Module:CardLua](https://starcitizen.tools/Module:CardLua) link-out), or `html` (passed through verbatim, e.g. Commodity's pre-rendered Mining card).

A page no kind claimed still builds its chain from the Item fallback leaf, whose `getAcquisition` would fabricate an all-"No" block, so `acquisitionFor` returns nil for it and `p.main` shows a [Module:Entity/EmptyState](https://starcitizen.tools/Module:Entity/EmptyState) box instead. A claimed kind with no `getAcquisition` renders only the styles tag, even when `hasApiError` is set.

### Extending

Change what a kind's acquisition block shows by editing that kind's own `getAcquisition`, never this module. Build the payload with [Module:Entity/Acquisition](https://starcitizen.tools/Module:Entity/Acquisition)'s helpers (`resolveFlag`, `inferCanAcquire`, `priceRange`, `hasEntityTag`, the description builders) instead of reimplementing flag/price logic. A new kind can reuse any of the three card shapes or hand this module pre-rendered `html`.

### Gotchas

- A `terminals` card with no `prices` still renders: only its `description` (the "No … data in UEX" fallback) shows; the card is never dropped.
- UEX stores `0`, not null, for "not sold here"; `priceRange`/`inferCanAcquire` treat zero as absent, and `formatPrice` prints it as `-`.
- `p._internal.renderCard`/`acquisitionFor` are exported only for the ScribuntoUnit suite; they are not part of the module's real API.
- The UEX attribution footer's logo link carries `class=metadata`, which keeps [PageImages](https://www.mediawiki.org/wiki/Extension:PageImages) from picking that logo as the page's own page image.
