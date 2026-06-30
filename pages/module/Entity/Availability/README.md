# Module:Entity/Availability

Renders an entity's acquisition block: a state-coloured summary grid (Buy / Rent / Loot / …) and the detail card(s) beneath it. It is a **thin, generic renderer**: it owns no per-kind logic. Instead it asks the matched entity kind for a ready-made spec and paints whatever it gets back.

It is a sibling renderer parallel to [Module:Entity/Related](https://starcitizen.tools/Module:Entity/Related) and [Module:Entity/Description](https://starcitizen.tools/Module:Entity/Description), and consumes [Module:Entity/Data](https://starcitizen.tools/Module:Entity/Data), so it shares Apiunto's cache with the Entity infobox and any other Entity-family template on the page.

## How it works

`Module:Entity/Data` resolves the entity kind through its registry and returns a `result` whose `result.matchedKind` is the **kind module** (`Module:Entity/Item`, `Module:Entity/Vehicle`, `Module:Entity/Commodity`, …). `p.main`:

1. Calls `result.matchedKind.getAcquisition(apiData, args)`.
2. The hook returns a `{ summary, cards }` spec (or `nil`/`false` to opt out).
3. Availability renders the summary grid from `summary` and dispatches each entry in `cards` through `renderCard`.

So **the kind decides what acquisition means**: which summary flags apply, how they're derived, which detail cards exist, and what's in them. Availability only knows three card *shapes* (`terminals` / `links` / `html`) and how to draw a summary grid. When a kind has no `getAcquisition` hook (e.g. `Module:Entity/Contract`, which sets `getAcquisition = false`), `p.main` returns just the TemplateStyles tag: no summary grid, no cards.

> **Extending acquisition for a new kind?** You do **not** edit this file. Implement `p.getAcquisition` on the kind module (see [the hook contract](#the-getacquisition-hook-contract) below).

## Usage

Invoked through [Template:Entity/Availability](https://starcitizen.tools/Template:Entity/Availability), not called directly from other Lua:

```wikitext
{{Entity/Availability|uuid=80ee3b95-5665-4548-9e2d-d2067895c0ac}}
```

The `uuid` parameter falls back to the SMW UUID set by `Template:Entity` on a prior parse, so on a typical entity page the template is invoked bare:

```wikitext
{{Entity}}

== Availability ==
{{Entity/Availability}}
```

The same invocation works for every kind that defines acquisition, because dispatch is transparent. Editors can override any derived summary flag with a wikitext argument; see [Editor overrides](#editor-overrides).

## The getAcquisition hook contract

This is the extension point. A kind module exposes:

```lua
--- @return { summary: table[], cards: table[] } | nil
function p.getAcquisition(apiData, args)
```

(typed at `Module:Entity/Types`, `--- @field getAcquisition`). Return `nil`/`false` to render nothing; otherwise return a table with two keys.

### `summary`: the flag grid

An array of rows, each `{ label, icon, value }`:

| Field | Type | Meaning |
|---|---|---|
| `label` | string | The flag name (`Buy`, `Rent`, `Mine`, …). |
| `icon` | string\|nil | Decorative category emoji shown before the label (`aria-hidden`). Omit for none. |
| `value` | boolean\|nil | `true` → Yes, `false` → No, `nil` → Unknown. Drives the icon, the `data-state` attribute, and the BEM state modifier. |

The grid always renders every row in the order given, so the layout stays stable across pages. There is no "hide this row": a row you don't want, you don't emit.

### `cards`: the detail cards

An array of card specs. `renderCard` dispatches on `card.type`:

| `type` | Shape | Rendered as |
|---|---|---|
| `terminals` | `{ title, caption, description, prices, priceColumns }` | A [CollapsibleCard](https://starcitizen.tools/Module:CollapsibleCard) wrapping a UEX terminal table + a UEX attribution footer. `prices` is the array of terminal rows (or `nil` → card shows only the `description`, e.g. "No shop data in UEX"). `priceColumns` is `{ id, key, label }[]` naming the price columns to append (`{ id='buy', key='price_buy', label='Buy' }`, etc.). |
| `links` | `{ title, buttons }` | A [CardLua](https://starcitizen.tools/Module:CardLua) `renderLinkCard`: a header row with trailing link-out buttons. `buttons` is `{ label, url, weight }[]` ([ButtonLua](https://starcitizen.tools/Module:ButtonLua) props). Used when on-page data is absent and the kind points at an external source. |
| `html` | `{ html }` | Passed through verbatim. For cards a kind pre-renders itself (e.g. the commodity Mining card from [Module:Entity/Commodity/Mining](https://starcitizen.tools/Module:Entity/Commodity/Mining)). |

A `terminals` card's title carries its emoji as an inline `<span aria-hidden="true">` (e.g. `🛒 Shops`), not via the summary-row `icon` field.

### `Module:Entity/Acquisition`: shared logic

Kinds don't reimplement flag/price logic; they build their payload with [Module:Entity/Acquisition](https://starcitizen.tools/Module:Entity/Acquisition), the pure-logic counterpart to this render module:

| Helper | Purpose |
|---|---|
| `resolveFlag(arg, derived)` | Editor override (`arg` via Yesno) wins; else the derived boolean; else `nil` (Unknown). The standard way to turn an override + a derived signal into a summary `value`. |
| `inferCanAcquire(prices, key)` | Any non-zero price at `key` → `true`; rows present but all zero → `false`; missing/empty → `nil`. |
| `priceRange(prices, key)` | `min, max` of non-zero prices (skips UEX zero-sentinels). Drives "is there a Sell side?" and price spans. |
| `hasEntityTag(apiData, name)` | Scans `apiData.entity_tag_map` for a tag by name; present → `true`, map without it → `false`, no map → `nil`. |
| `formatPriceRange(min, max)` | The [Module:UEC](https://starcitizen.tools/Module:UEC) component for a span (glyph + `7` or `7–12`). |
| `locationCountLabel(prices)` | `"1 location"` / `"N locations"`. |
| `buildShopTerminalsDescription(prices)` | Two-sided card description: `"N locations · Buy X · Sell Y"`. |
| `buildSinglePriceDescription(prices, key)` | One-sided: `"N locations · <range>"`. |
| `estimatePrice(rows, key)` | Median price across the newest patch's terminals. Feeds the **stored** `Average purchase/rental price` SMW properties (Vehicle, Vehicle/Cost), *not* the acquisition cards. |

## What each kind contributes

For reference, none of this lives in `Availability.lua`; it lives in each kind's `getAcquisition`.

### Items ([Module:Entity/Item](https://starcitizen.tools/Module:Entity/Item))

- **Summary**: Buy / Loot / Craft / Pledge. Rent is inserted only when the editor sets `canRent` explicitly (items aren't structurally rentable). Buy from `uex_prices.purchase`; Loot from `apiData.is_lootable`; Craft from `apiData.is_craftable`; Pledge from the `PromotionalItem` or `SubscriberFlair` entity tag.
- **Cards**: a single `🛒 Shops` `terminals` card from `uex_prices.purchase`. The Sell column is appended only when some row has a non-zero `price_sell` (the hook computes `hasSell`); the description switches between the two-sided and single-price builders accordingly.

### Vehicles ([Module:Entity/Vehicle](https://starcitizen.tools/Module:Entity/Vehicle))

- **Summary**: Buy / Rent / Pledge. Loot and Craft are omitted (the concepts don't apply to vehicles in the live game). Buy from `uex_prices.purchase`, Rent from `uex_prices.rental`, Pledge from `apiData.msrp ~= nil`.
- **Cards**: a `🛒 Shops` `terminals` card plus a `⏳ Rentals` `terminals` card (`uex_prices.rental`, Rent column). Either falls back to a "No … data in UEX" description when its bucket is empty.

### Commodities ([Module:Entity/Commodity](https://starcitizen.tools/Module:Entity/Commodity))

- **Summary**: Mine / Harvest / Buy. Mine from `is_mineable`, Harvest from `has_harvestables`, Buy from `uex_prices.purchase`.
- **Cards**: a Mining deposit card (`html`, pre-rendered by [Module:Entity/Commodity/Mining](https://starcitizen.tools/Module:Entity/Commodity/Mining)) when present, then a `🛒 Trade` `terminals` card when priced, or a `links` card pointing at SC Trade Tools and UEX (keyed on the commodity slug) when UEX has no terminal prices.

### Contract ([Module:Entity/Contract](https://starcitizen.tools/Module:Entity/Contract))

`getAcquisition = false`, so no acquisition block renders.

## Editor overrides

Every derived summary flag can be overridden by an editor-supplied wikitext argument. These are consumed by the **kind's** `getAcquisition` (via `acq.resolveFlag` / `Module:Yesno`), not by this module:

| Argument | Card | Item default | Vehicle default | Commodity default |
|---|---|---|---|---|
| `canBuy` | Buy | Derived from `uex_prices.purchase` | Derived from `uex_prices.purchase` | Derived from `uex_prices.purchase` |
| `canRent` | Rent | None; row hidden unless this is set | Derived from `uex_prices.rental` | (n/a) |
| `canLoot` | Loot | Derived from `is_lootable` | (omitted) | (n/a) |
| `canCraft` | Craft | Derived from `is_craftable` | (omitted) | (n/a) |
| `canPledge` | Pledge | Derived from `PromotionalItem`/`SubscriberFlair` tag | Derived from `msrp ~= nil` | (n/a) |
| `canMine` | Mine | (n/a) | (n/a) | Derived from `is_mineable` |
| `canHarvest` | Harvest | (n/a) | (n/a) | Derived from `has_harvestables` |

Override values pass through [Module:Yesno](https://starcitizen.tools/Module:Yesno), so `yes`/`no`/`1`/`0`/`true`/`false` etc. are all accepted. Setting `canRent=no` explicitly on an item still emits the Rent row (with a "No" state); only `nil`/missing keeps it hidden.

## Rendering details

These are the formatting behaviours this module owns, applied to whatever the kinds hand it.

### Prices (UEC)

`formatPrice` renders a non-zero price through the [Module:UEC](https://starcitizen.tools/Module:UEC) component: the currency glyph followed by the locale-grouped amount (`123456` → `123,456`). A `0` renders as `-` (UEX stores `0`, not null, for "not sold here"). TableLua strips HTML before sorting, so columns still sort on the underlying number. Card descriptions use the UEC span helper (`formatPriceRange`) for price ranges.

### Game version

UEX's `game_version` strings look like `4.7.2-LIVE.11674325`. The trailing `-LIVE.<build>` is internal CIG release metadata that doesn't help a player judge data freshness, so the column shows just the marketing portion (`4.7.2`), extracted with the `^[^-]+` Lua pattern.

### Dates

`date_updated` (ISO 8601) is wrapped in a `<time>` element whose visible text is truncated to `YYYY-MM-DD`; the `datetime` attribute preserves the full timestamp for machine readers.

### Location wikilinks

Terminal names link to their parent location (`starmap_location.name`). Gateway stations get the destination system appended as a disambiguator (`Stanton Gateway` → `Stanton Gateway (Pyro)`) because their bare names collide with the destination system's wiki page. The visible cell text stays the bare terminal name. The System column links the parent star system.

### UEX attribution footer

Every `terminals` card appends a footer: the `[[File:UEX logo.svg]]` linking to the first per-row `uex_link` (a deep link into that terminal's UEX listing), falling back to `https://uexcorp.space` when no row carries one. `class=metadata` keeps PageImages from selecting the logo as the page image.

## CSS hooks

The module ships its own TemplateStyles in `Module:Entity/Availability/styles.css`. Only the summary grid is styled here; the detail cards delegate to [Module:CollapsibleCard](https://starcitizen.tools/Module:CollapsibleCard) / [Module:CardLua](https://starcitizen.tools/Module:CardLua) and the tables to [Module:TableLua](https://starcitizen.tools/Module:TableLua).

| Class | Purpose |
|---|---|
| `t-entity-availability-summary` | The grid root (a `<dl>`). Responsive `repeat(auto-fit, minmax(120px, 1fr))` columns. |
| `t-entity-availability-summary-item` | One label/value card. Also carries `--yes` / `--no` / `--unknown` BEM modifiers and a `data-state` attribute. |
| `t-entity-availability-summary-label` | The `<dt>` wrapping the optional icon span and label text. |
| `t-entity-availability-summary-icon` | Decorative category emoji span; `aria-hidden="true"`. |
| `t-entity-availability-summary-value` | The `<dd>` rendered as a 16×16 `mask-image` icon coloured via `currentColor`. |
| `t-entity-availability-summary-value-text` | Visually-hidden text inside the value cell ("Yes" / "No" / "Unknown"), for screen readers, translators, and reader modes. |

The value cell uses a Codex SVG (`CdxIconSuccess` / `CdxIconClear` / `CdxIconHelpNotice`) as a `mask-image` recoloured via `currentColor`. State styling lives on the item modifiers: Yes uses success-subtle background and border, No uses muted disabled colour with no background tint, Unknown uses warning-subtle background and border. The label inherits the item's colour so it stays in lockstep; the value icon is recoloured automatically. The canonical machine-readable target is `data-state` on the item `<div>`; scrapers and agents should query `[data-state]` rather than parse class modifiers.

## Architecture

```
Entity/Availability/
├── Availability.lua    # Generic renderer: getAcquisition dispatch, summary grid,
│                       #   renderCard (terminals/links/html), terminal table, formatters
└── styles.css          # Summary grid styling (state colors, mask-image icons)
```

`Availability.lua` holds no per-kind logic. The acquisition `{ summary, cards }` spec is built by each kind's `getAcquisition` hook (`Module:Entity/Item`, `Module:Entity/Vehicle`, `Module:Entity/Commodity`), using the shared logic in `Module:Entity/Acquisition`. Render dependencies: `Module:Entity/Data` (kind resolution + Apiunto cache), `Module:CollapsibleCard`, `Module:CardLua`, `Module:TableLua`, `Module:UEC`. `p._internal.renderCard` is exported for the ScribuntoUnit suite (`testcases.lua`), which covers only the three-way card dispatch; the kind logic is tested in each kind's own suite.
