# Template:Entity/Availability

Renders an at-a-glance summary of where an entity can be acquired in-game, followed by a collapsible card of shop terminal prices. Designed to sit further down an entity page as body content, separate from the [Template:Entity](https://starcitizen.tools/Template:Entity) infobox at the top. Reads the same upstream API data via Module:Entity/Data, so the cache is shared with any other Entity-family template on the page.

Items only today — shop pricing comes from UEX via the items endpoint. The summary grid always renders; the shop card renders a "No shop data in UEX" notice when prices are missing.

## Usage

Explicit UUID:

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
| `canBuy` | Can buy | boolean | No | Derived from UEX shop data | Override for the "Buy" summary card. Set to `no` when UEX has stale prices for an item that's been removed from shops. | `no` |
| `canRent` | Can rent | boolean | No | (card hidden) | Whether the entity is rentable. Items aren't structurally rentable, so the Rent card is hidden by default — set this only when an item exposes a real rental mechanic. Vehicles will default-on once `Module:Entity/Vehicle` lands. | `yes` |
| `canLoot` | Can loot | boolean | No | Derived from the `CanGenerateAsLoot` entity tag | Override for the "Loot" summary card. Use when the API tag is missing or wrong. | `yes` |
| `canCraft` | Can craft | boolean | No | Derived from `is_craftable` | Override for the "Craft" summary card. | `no` |
| `canPledge` | Can pledge | boolean | No | Derived from the `PromotionalItem` entity tag | Override for the "Pledge" summary card. Use when the item is buyable in the pledge store but not flagged as promotional. | `yes` |

## Behavior

- Renders a responsive 5-card summary grid: **Buy**, **Rent** (only when set), **Loot**, **Craft**, **Pledge**. Each card shows the category icon, label, and a yes/no/unknown state communicated through icon and color (success / muted / warning).
- Below the summary, a collapsible **🛒 Shops** card lists UEX shop terminal prices in a sortable table — System, Location, Buy, Sell, Updated, Version. Both location columns are wikilinked to their parent locations. Prices use thousands separators (`123,456`). The version column is trimmed from the full `4.7.2-LIVE.11674325` to just the marketing portion (`4.7.2`) so players can gauge how stale a row is.
- The shop card's subtitle summarises the data: `N locations · Buy <range> · Sell <range>`. Single-sided markets are labelled accordingly (`Buy <range> · Not sellable`).
- When UEX has no data for the item, the shop card collapses to a static "No shop data in UEX" header — same visual shell, no expand affordance.
- Editor `canX` flags accept any [Module:Yesno](https://starcitizen.tools/Module:Yesno) input (`yes`, `1`, `true`, `no`, `0`, `false`, etc.). When unset, each flag falls back to its API-derived value (or `Unknown` when the API can't tell).
- Footer line credits UEX: *Data from [UEX Corp](https://uexcorp.space)*.

## See also

- [Template:Entity](https://starcitizen.tools/Template:Entity) — the main entity infobox; sets the SMW UUID this template falls back to.
- [Template:Entity/Related](https://starcitizen.tools/Template:Entity/Related) — sibling renderer for set components and cosmetic variants.
- [Template:Entity/Description](https://starcitizen.tools/Template:Entity/Description) — sibling renderer for the in-game description.
- [Module:Entity/Availability](https://starcitizen.tools/Module:Entity/Availability) — implementation.
