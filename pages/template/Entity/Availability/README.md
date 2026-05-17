# Template:Entity/Availability

Renders an at-a-glance summary of where an entity can be acquired in-game, followed by collapsible card(s) of UEX terminal prices. Works for items and vehicles — the rendering adapts to the entity kind automatically. Designed to sit further down an entity page as body content, separate from the [Template:Entity](https://starcitizen.tools/Template:Entity) infobox at the top. Reads the same upstream API data via Module:Entity/Data, so the cache is shared with any other Entity-family template on the page.

The summary grid always renders so the page layout stays stable. The detail card(s) below fall back to a static "No … data in UEX" header when UEX has no prices for the entity.

## Usage

Explicit UUID — same invocation for items and vehicles:

```wikitext
{{Entity/Availability|uuid=80ee3b95-5665-4548-9e2d-d2067895c0ac}}
```

When `Template:Entity` has been invoked earlier on the page, the UUID can be omitted — it falls back to the value stored in SMW on the current page:

```wikitext
{{Entity}}

== Availability ==
{{Entity/Availability}}
```

Editor overrides for the summary flags (only set when the API-derived value is wrong or unknown):

```wikitext
{{Entity/Availability|canLoot=no|canCraft=yes}}
```

## Parameters

| Name | Label | Type | Required | Default | Description | Example |
|------|-------|------|----------|---------|-------------|---------|
| `uuid` | UUID | string | No | (falls back to SMW UUID on the current page) | UUID of the entity to render. If omitted, defaults to the UUID stored in SMW (set by Template:Entity on a prior parse). Required if Template:Entity hasn't been invoked. | `80ee3b95-5665-4548-9e2d-d2067895c0ac` |
| `canBuy` | Can buy | boolean | No | Derived from UEX shop data (items: `uex_prices`; vehicles: `uex_prices.purchase`) | Override for the "Buy" summary card. Set to `no` when UEX has stale prices for an entity that's been removed from shops. | `no` |
| `canRent` | Can rent | boolean | No | Items: card hidden unless set explicitly. Vehicles: derived from `uex_prices.rental`. | Whether the entity is rentable. For items the card is hidden by default (items aren't structurally rentable) — set this only when an item exposes a real rental mechanic. For vehicles the card always renders with a derived value. | `yes` |
| `canLoot` | Can loot | boolean | No | Items: derived from the `CanGenerateAsLoot` entity tag. Vehicles: card omitted. | Override for the "Loot" summary card. Items only — the card is not rendered for vehicles. | `yes` |
| `canCraft` | Can craft | boolean | No | Items: derived from `is_craftable`. Vehicles: card omitted. | Override for the "Craft" summary card. Items only — the card is not rendered for vehicles. | `no` |
| `canPledge` | Can pledge | boolean | No | Items: derived from the `PromotionalItem` or `SubscriberFlair` entity tag. Vehicles: derived from `msrp` presence. | Override for the "Pledge" summary card. | `yes` |

## Behavior

### Summary grid

- **Items** render a responsive 4-card grid: **Buy**, **Loot**, **Craft**, **Pledge**. **Rent** is inserted only when the editor sets `canRent` explicitly.
- **Vehicles** render a 3-card grid: **Buy**, **Rent**, **Pledge**. Loot and Craft are omitted (neither concept applies to vehicles in the live game).
- Each card shows the category icon, label, and a yes/no/unknown state communicated through icon and color (success / muted / warning).

### Detail cards

- **Items** render one **🛒 Shops** card. The header subtitle summarises the data: `N locations · Buy <range> · Sell <range>`. Single-sided markets are labelled accordingly (`Buy <range> · Not sellable`). The body is a sortable table with columns System, Location, Buy, Sell, Updated, Version.
- **Vehicles** render two cards — **🛒 Shops** for purchase terminals (Buy column) and **⏳ Rentals** for rental terminals (Rent column). Each subtitle is `N locations · <range>`. Vehicles never have a Sell side.
- Both location columns are wikilinked to their parent locations. Gateway stations get the destination system appended as a disambiguator (`Stanton Gateway` → `Stanton Gateway (Pyro)`). Prices use thousands separators (`123,456`). The version column is trimmed from the full `4.7.2-LIVE.11674325` to just the marketing portion (`4.7.2`) so players can gauge how stale a row is.
- When UEX has no data, each card collapses to a static "No … data in UEX" header — same visual shell, no expand affordance.

### Editor flags

- `canX` flags accept any [Module:Yesno](https://starcitizen.tools/Module:Yesno) input (`yes`, `1`, `true`, `no`, `0`, `false`, etc.).
- When unset, each flag falls back to its API-derived value (or `Unknown` when the API can't tell).
- Setting `canRent=no` explicitly on an item will render the card with a "No" state — only `nil`/missing hides it.

### Footer

Each detail card ends with a credit line: *Data from [UEX Corp](https://uexcorp.space)*.

## See also

- [Template:Entity](https://starcitizen.tools/Template:Entity) — the main entity infobox; sets the SMW UUID this template falls back to.
- [Template:Entity/Related](https://starcitizen.tools/Template:Entity/Related) — sibling renderer for set components and cosmetic variants.
- [Template:Entity/Description](https://starcitizen.tools/Template:Entity/Description) — sibling renderer for the in-game description.
- [Module:Entity/Availability](https://starcitizen.tools/Module:Entity/Availability) — implementation.
- [Module:Entity/Data](https://starcitizen.tools/Module:Entity/Data) — kind dispatch and data fetching.
