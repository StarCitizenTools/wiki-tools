# Module:Boolean

Renders a tri-state boolean as a single machine-readable icon. The single source of truth for the yes / no / unknown icon, colour, and label, shared by the `{{Boolean}}` template, the Entity infobox facets, and the AG Grid `boolean` column kind. Modeled on [Module:DietaryEffect](https://starcitizen.tools/Module:DietaryEffect).

- **Yes** (truthy) → green check (`CdxIconSuccess.svg`, `--color-success`)
- **No** (falsy) → grey cross (`CdxIconClear.svg`, `--color-disabled`)
- **Unknown** (`nil` / unrecognised) → amber help glyph (`CdxIconHelpNotice.svg`, `--color-warning`)

"No" is deliberately **grey, not red**: the absence of a trait is neutral, not an error (a red cross would wrongly signal something is wrong for a row like "Reclosable: No"). This matches [Module:Entity/Availability](https://starcitizen.tools/Module:Entity/Availability).

Input is normalised through [Module:Yesno](https://starcitizen.tools/Module:Yesno), so `yes` / `1` / `true` and `no` / `0` / `false` (in any case) all work.

## Machine-readable

`render` emits the state three ways, so the icon is never the only carrier of meaning:

- `title` — hover tooltip.
- `data-state` (`yes` / `no` / `unknown`) — the canonical attribute for scrapers and AI agents to query (`[data-state]`).
- A visually-hidden text span — read by screen readers, translation tools, and reader modes (which ignore `aria-label`).

## API

### `p.classify(value)`

Returns the state table `{ state, icon, label }` for a value (never `nil` — an unrecognised value resolves to the `unknown` state). `state` is `'yes'`, `'no'`, or `'unknown'`; `icon` is the Codex SVG file name; `label` is the display word.

```lua
local Boolean = require( 'Module:Boolean' )
Boolean.classify( 'yes' )  --> { state = 'yes', icon = 'CdxIconSuccess.svg', label = 'Yes' }
Boolean.classify( nil )    --> { state = 'unknown', icon = 'CdxIconHelpNotice.svg', label = 'Unknown' }
```

### `p.render(value)`

Returns the icon-only inline markup (the infobox / wikitext face): a coloured currentColor mask via [Module:Icon](https://starcitizen.tools/Module:Icon) plus the machine-readable hooks above. The returned string includes its own and `Module:Icon`'s `<templatestyles>`, so it can be dropped straight into an infobox row's content.

```lua
Boolean.render( food.one_shot_consume )
```

### `p.gridClassify(value)`

Returns `{ text, state, icon }` for the AG Grid path (`text` is the sort / set-filter key). Consumed by [Module:AGGridColumns](https://starcitizen.tools/Module:AGGridColumns)'s `boolean` kind, which a `{{Data table}}` column reaches via `kind=boolean`. Mirrors `DietaryEffect.gridClassify`.

### `p.main(frame)`

Wikitext entry point behind `{{Boolean}}`. The first positional argument is the value: `{{Boolean|yes}}`.

## Architecture

```
Boolean/
├── Boolean.lua    # STATES map, classify / render / gridClassify / main
├── styles.css     # per-state colour + visually-hidden text
└── testcases.lua  # ScribuntoUnit tests for classify / gridClassify
```

Per project convention only the classification logic (`classify`, `gridClassify`) is unit-tested; the rendered HTML is verified by browser QA.
