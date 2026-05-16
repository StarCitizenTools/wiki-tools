# Module:Entity/Availability

Renders an entity's acquisition summary and shop terminal data. Sibling renderer parallel to [Module:Entity/Related](https://starcitizen.tools/Module:Entity/Related) and [Module:Entity/Description](https://starcitizen.tools/Module:Entity/Description) — consumes [Module:Entity/Data](https://starcitizen.tools/Module:Entity/Data) so it shares Apiunto's cache with the Entity infobox and any other Entity-family template on the page.

Two sections, top-to-bottom: a 5-card **summary grid** showing buy/rent/loot/craft/pledge flags, then a collapsible **🛒 Shops** card with UEX-sourced terminal prices. The summary grid always renders so the page layout stays stable; the shop card falls back to a static "No shop data in UEX" header when UEX has no prices for the item.

Items only today — only the items endpoint returns `uex_prices`. The summary grid renders with API-derived flags where possible and `Unknown` otherwise.

## Usage

Invoked through [Template:Entity/Availability](https://starcitizen.tools/Template:Entity/Availability), not called directly from other Lua:

```wikitext
{{Entity/Availability|uuid=80ee3b95-5665-4548-9e2d-d2067895c0ac}}
```

The `uuid` parameter falls back to the SMW UUID set by `Template:Entity` on a prior parse — so on a typical entity page the template is invoked bare:

```wikitext
{{Entity}}

== Availability ==
{{Entity/Availability}}
```

## API

### `p.main( frame )`

Entry point invoked from `Template:Entity/Availability`.

Resolves the UUID from `frame.args.uuid`, the parent frame, or SMW (in that order), fetches entity data via `Module:Entity/Data`, then renders:

1. **Summary grid** — a `<dl>` of 5 `<div>` items, each a label/value pair. Each item gets a `data-state` attribute (`yes`/`no`/`unknown`) for machine-readable consumption and a BEM-style class modifier (`…-item--yes` etc.) for state-coloured visual treatment. The value cell uses a Codex SVG (`CdxIconSuccess` / `CdxIconClear` / `CdxIconHelpNotice`) as a `mask-image`, recoloured via `currentColor`, with a visually-hidden `<span>` carrying the text "Yes" / "No" / "Unknown" for screen readers, translation tools, and reader modes.
2. **🛒 Shops card** — a [CollapsibleCard](https://starcitizen.tools/Module:CollapsibleCard) rendering. The header shows a subtitle (`N locations · Buy <range> · Sell <range>`); the body is a sortable [TableLua](https://starcitizen.tools/Module:TableLua) wikitable; the footer credits UEX.

## Data

Reads two fields from the merged Apiunto response:

| Field | Description |
|---|---|
| `uex_prices` | Array of UEX shop terminal entries. Drives the Shops table. Each entry has `terminal_name`, `starmap_location` (with `name` and `star_system_name`), `price_buy`, `price_sell`, `date_updated` (ISO 8601), and `game_version`. Missing or empty → "No shop data in UEX" notice. |
| `entity_tag_map` | Array of `{ uuid, name }` entries. Scanned for `CanGenerateAsLoot` (drives Loot) and `PromotionalItem` (drives Pledge). |
| `is_craftable` | Boolean. Drives the Craft summary card. |

The Buy summary card derives from `uex_prices` directly: any present buy price → Yes, all-zero buy prices with rows present → No, missing `uex_prices` entirely → Unknown. UEX uses `0` rather than null for "not sold here", so the price-range computation also filters zeros to avoid collapsing the minimum.

### Editor overrides

Every derived summary flag can be overridden by an editor-supplied wikitext argument:

| Argument | Card | Default source |
|---|---|---|
| `canBuy` | Buy | Derived from `uex_prices` |
| `canRent` | Rent | None — card is hidden unless this is set (items aren't structurally rentable; vehicles will default-on once `Module:Entity/Vehicle` lands) |
| `canLoot` | Loot | Derived from the `CanGenerateAsLoot` entity tag |
| `canCraft` | Craft | Derived from `is_craftable` |
| `canPledge` | Pledge | Derived from the `PromotionalItem` entity tag |

Override values pass through [Module:Yesno](https://starcitizen.tools/Module:Yesno), so any of `yes`/`no`/`1`/`0`/`true`/`false` etc. are accepted. Setting `canRent=no` explicitly will render the card with a "No" state — only `nil`/missing hides the card.

### Game version formatting

UEX's `game_version` strings look like `4.7.2-LIVE.11674325`. The trailing `-LIVE.<build>` is internal CIG release metadata that doesn't help a player judge data freshness, so the column shows just the marketing portion (`4.7.2`) extracted with the `^[^-]+` Lua pattern.

## CSS hooks

The module ships its own TemplateStyles in `Module:Entity/Availability/styles.css` — only the summary grid is styled here; the shop card delegates to [Module:CollapsibleCard](https://starcitizen.tools/Module:CollapsibleCard) and the table to [Module:TableLua](https://starcitizen.tools/Module:TableLua).

| Class | Purpose |
|---|---|
| `t-entity-availability-summary` | The grid root (a `<dl>`). Responsive `repeat(auto-fit, minmax(120px, 1fr))` columns. |
| `t-entity-availability-summary-item` | One label/value card. Also carries `--yes` / `--no` / `--unknown` BEM modifiers and a `data-state` attribute. |
| `t-entity-availability-summary-label` | The `<dt>` wrapping the optional icon span and label text. |
| `t-entity-availability-summary-icon` | Decorative category emoji span; `aria-hidden="true"`. |
| `t-entity-availability-summary-value` | The `<dd>` rendered as a 16×16 `mask-image` icon coloured via `currentColor`. |
| `t-entity-availability-summary-value-text` | Visually-hidden text inside the value cell ("Yes" / "No" / "Unknown"). |

State styling lives on the item modifiers: Yes uses success-subtle background and border, No uses muted disabled color with no background tint, Unknown uses warning-subtle background and border. The label inherits the item's color so it stays in lockstep; the value icon is recoloured automatically through `currentColor`.

## Architecture

```
Entity/Availability/
├── Availability.lua    # Data shaping, summary grid, shop card composition
└── styles.css          # Summary grid styling (state colors, mask-image icons)
```
