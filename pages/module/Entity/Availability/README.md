# Module:Entity/Availability

Renders an entity's acquisition summary and UEX terminal data for items and vehicles. Sibling renderer parallel to [Module:Entity/Related](https://starcitizen.tools/Module:Entity/Related) and [Module:Entity/Description](https://starcitizen.tools/Module:Entity/Description) — consumes [Module:Entity/Data](https://starcitizen.tools/Module:Entity/Data) so it shares Apiunto's cache with the Entity infobox and any other Entity-family template on the page.

The summary grid is always rendered (layout stays stable across pages); the detail card(s) below it fall back to a static "No … data in UEX" header when UEX has no prices for the entity.

## Kind dispatch

`Module:Entity/Data` resolves the entity kind through its kind registry and surfaces both a kind-shaped `apiData` and a canonical `result.kind` (`Commodity` / `Vehicle` / `Item`). Availability branches on `result.kind` — it no longer re-derives the kind from `apiData` fields itself. The kind drives the summary builder (commodity vs vehicle vs item row sets) and gates the Rentals detail card; the Shops card is unified across kinds and reads `uex_prices.purchase` regardless.

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

The same invocation works for vehicles — kind dispatch is transparent.

## API

### `p.main( frame )`

Entry point invoked from `Template:Entity/Availability`.

Resolves the UUID, fetches entity data via `Module:Entity/Data`, then renders:

- **Summary** — item summary (Buy / Loot / Craft / Pledge; Rent inserted only when the editor sets `canRent` explicitly) or vehicle summary (Buy / Rent / Pledge — Loot and Craft are omitted because the concepts don't apply to vehicles in the live game).
- **Detail** — always a **🛒 Shops** card from `uex_prices.purchase`; vehicles get an additional **⏳ Rentals** card from `uex_prices.rental`. The Shops card's Sell column is data-driven: it appears when at least one row has a non-zero `price_sell` (items pass, vehicles don't), so the column toggles without a kind branch in the renderer.

Summary HTML structure: a `<dl>` of `<div>` items, each carrying a `data-state` attribute (`yes`/`no`/`unknown`) for machine-readable consumption and a BEM-style class modifier (`…-item--yes` etc.) for state-coloured visual treatment. The value cell uses a Codex SVG (`CdxIconSuccess` / `CdxIconClear` / `CdxIconHelpNotice`) as a `mask-image`, recoloured via `currentColor`, with a visually-hidden `<span>` carrying the text "Yes" / "No" / "Unknown" for screen readers, translation tools, and reader modes.

Terminal tables go through [TableLua](https://starcitizen.tools/Module:TableLua) wrapped in [CollapsibleCard](https://starcitizen.tools/Module:CollapsibleCard). Fixed columns: System, Location, Updated, Version. Price columns are appended per card: `Buy` (always), `Sell` (Shops card when applicable), `Rent` (Rentals card).

## Data

### Items

Read from the merged Apiunto response:

| Field | Description |
|---|---|
| `uex_prices.purchase` | Array of UEX shop terminal entries. Each entry has `terminal_name`, `starmap_location` (with `name` and `star_system_name`), `price_buy`, `price_sell`, `date_updated` (ISO 8601), and `game_version`. Missing or empty → "No shop data in UEX" notice. Items currently never have a `rental` bucket. |
| `entity_tag_map` | Array of `{ uuid, name }` entries. Scanned for `CanGenerateAsLoot` (drives Loot), `PromotionalItem` and `SubscriberFlair` (either drives Pledge — subscriber-exclusive monthly flair is pledge-only). |
| `is_craftable` | Boolean. Drives the Craft summary card. |

Buy derives from `uex_prices.purchase`: any present non-zero buy price → Yes, all-zero buy prices with rows present → No, missing/empty → Unknown.

### Vehicles

Read from the merged Apiunto response:

| Field | Description |
|---|---|
| `uex_prices` | Dict with two buckets: `purchase` (array of terminals with `price_buy`) and `rental` (array of terminals with `price_rent`). Either bucket may be empty independently. Vehicles never have a Sell side. |
| `is_vehicle` | Top-level key. The Data layer's `Module:Entity/Vehicle.matches()` keys on its **presence** (regardless of value — `true` for ground vehicles, `false` for spaceships) to set `result.kind = 'Vehicle'`, which gates the Rentals detail card. Availability reads `result.kind`, not this field directly. |
| `msrp` | Top-level number (USD pledge price). Presence drives the Pledge summary card. |

Buy derives from `uex_prices.purchase`, Rent from `uex_prices.rental` — same inference logic as items. Pledge is `apiData.msrp ~= nil`.

### Shared

UEX uses `0` rather than null for "not sold here", so the price-range computation filters zeros to avoid collapsing the minimum.

### Editor overrides

Every derived summary flag can be overridden by an editor-supplied wikitext argument:

| Argument | Card | Item default | Vehicle default |
|---|---|---|---|
| `canBuy` | Buy | Derived from `uex_prices.purchase` | Derived from `uex_prices.purchase` |
| `canRent` | Rent | None — card is hidden unless this is set (items aren't structurally rentable) | Derived from `uex_prices.rental` |
| `canLoot` | Loot | Derived from the `CanGenerateAsLoot` entity tag | (card omitted for vehicles) |
| `canCraft` | Craft | Derived from `is_craftable` | (card omitted for vehicles) |
| `canPledge` | Pledge | Derived from the `PromotionalItem` or `SubscriberFlair` entity tag | Derived from `msrp ~= nil` |

Override values pass through [Module:Yesno](https://starcitizen.tools/Module:Yesno), so any of `yes`/`no`/`1`/`0`/`true`/`false` etc. are accepted. Setting `canRent=no` explicitly on an item will render the card with a "No" state — only `nil`/missing hides it.

### Game version formatting

UEX's `game_version` strings look like `4.7.2-LIVE.11674325`. The trailing `-LIVE.<build>` is internal CIG release metadata that doesn't help a player judge data freshness, so the column shows just the marketing portion (`4.7.2`) extracted with the `^[^-]+` Lua pattern.

### Location wikilinks

Both kinds wrap the terminal name in a wikilink to the parent location (`starmap_location.name`). Gateway stations get the destination system appended as a disambiguator (`Stanton Gateway` → `Stanton Gateway (Pyro)`) because their bare names collide with the destination system's wiki page.

## CSS hooks

The module ships its own TemplateStyles in `Module:Entity/Availability/styles.css` — only the summary grid is styled here; the detail cards delegate to [Module:CollapsibleCard](https://starcitizen.tools/Module:CollapsibleCard) and the tables to [Module:TableLua](https://starcitizen.tools/Module:TableLua).

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
├── Availability.lua    # Data shaping, summary grid, item/vehicle detail composition
└── styles.css          # Summary grid styling (state colors, mask-image icons)
```
