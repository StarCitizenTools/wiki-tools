# Template:Entity/Availability

Renders an at-a-glance summary of where an entity can be bought, rented, looted, crafted, mined, harvested, or pledged, followed by detail card(s) of UEX terminal prices. Place it as body content further down the page, separate from the `{{Entity}}` infobox at the top.

## Usage

Explicit UUID, same invocation for every kind:

```wikitext
{{Entity/Availability|uuid=80ee3b95-5665-4548-9e2d-d2067895c0ac}}
```

When `{{Entity}}` has been invoked earlier on the page, the UUID can be omitted; it falls back to the value stored in SMW on the current page:

```wikitext
{{Entity}}

== Availability ==
{{Entity/Availability}}
```

Editor overrides for the summary flags, set only when the API-derived value is wrong or unknown:

```wikitext
{{Entity/Availability|canLoot=no|canCraft=yes}}
```

## Parameters

| Name | Label | Type | Required | Default | Description | Example |
|------|-------|------|----------|---------|-------------|---------|
| `uuid` | UUID | string | No | (falls back to the SMW uuid stored by a prior `{{Entity}}` parse) | UUID of the entity to render. Required if `{{Entity}}` hasn't been invoked. | `80ee3b95-5665-4548-9e2d-d2067895c0ac` |
| `canBuy` | Can buy | boolean | No | Derived from UEX purchase data (all three kinds) | Override for the "Buy" summary card. Set to `no` when UEX has stale prices for an entity removed from shops. | `no` |
| `canRent` | Can rent | boolean | No | Items: card hidden unless set. Vehicles: derived from `uex_prices.rental`. Not used for commodities. | Whether the entity is rentable; for items the card is hidden by default. | `yes` |
| `canLoot` | Can loot | boolean | No | Items: derived from `apiData.is_lootable`. Not used for vehicles or commodities. | Override for the "Loot" summary card. Items only. | `yes` |
| `canCraft` | Can craft | boolean | No | Items: derived from `is_craftable`. Not used for vehicles or commodities. | Override for the "Craft" summary card. Items only. | `no` |
| `canPledge` | Can pledge | boolean | No | Items: entity tag. Vehicles: `msrp` presence. Not used for commodities. | Override for the "Pledge" summary card. | `yes` |
| `canMine` | Can mine | boolean | No | Commodities: derived from `is_mineable`. Not used for items or vehicles. | Override for the "Mine" summary card. Commodities only. | `yes` |
| `canHarvest` | Can harvest | boolean | No | Commodities: derived from `has_harvestables`. Not used for items or vehicles. | Override for the "Harvest" summary card. Commodities only. | `yes` |

## Behaviour

### What renders, by kind

- **Items** render a summary grid of Buy, Loot, Craft, Pledge (Rent is inserted only when `canRent` is set explicitly), plus one Shops card of UEX purchase terminals.
- **Vehicles** render Buy, Rent, Pledge, plus a Shops card and a Rentals card.
- **Commodities** render Mine, Harvest, Buy, plus a mining-deposit card when the commodity has one, then a Trade card: a UEX terminal table when priced, otherwise link-out buttons to SC Trade Tools and UEX.
- **Missions**, and any page no kind claims (an unresolved or missing uuid), render nothing at all, not even an empty grid.

### Cards and flags

- Each summary flag shows a yes/no/unknown state; unknown means the API couldn't tell, not that the value is false.
- Every `canX` argument accepts any [Module:Yesno](https://starcitizen.tools/Module:Yesno) input (`yes`, `no`, `1`, `0`, `true`, `false`, and their variants).
- A `canX` override always wins over the derived value once set, including `canRent=no` on an item, which still shows the Rent row (with a "No" state) instead of hiding it; only leaving it unset hides the row.
- An item's Shops card or a vehicle's Shops/Rentals card with no UEX prices collapses to a static "No … data in UEX" header rather than disappearing. A commodity with no trade prices doesn't get this: it gets a link-out card instead (see above), so this fallback header never appears for commodities.
- Terminal location links disambiguate gateway stations by appending the terminal's own parent star system (`Stanton Gateway` becomes `Stanton Gateway (Pyro)`), since the bare terminal name collides with that system's own wiki page.

## See also

- [Template:Entity](https://starcitizen.tools/Template:Entity), the infobox that owns the page's SMW data, SHORTDESC, and categories; sets the uuid this template falls back to.
- [Template:Entity/Related](https://starcitizen.tools/Template:Entity/Related), sibling renderer for set components and cosmetic variants.
- [Template:Entity/Description](https://starcitizen.tools/Template:Entity/Description), sibling renderer for the in-game description.
- [Module:Entity/Availability](https://starcitizen.tools/Module:Entity/Availability), the implementation.
