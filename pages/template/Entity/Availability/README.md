# Template:Entity/Availability

Renders an at-a-glance summary of where an entity can be bought, rented, looted, crafted, mined, harvested, or pledged, followed by detail card(s) of UEX terminal prices. Place it as body content further down the page, separate from the `{{Entity}}` infobox at the top.

## Usage

Explicit UUID, same invocation for every kind:

```wikitext
{{Entity/Availability|uuid=80ee3b95-5665-4548-9e2d-d2067895c0ac}}
```

When `{{Entity}}` has been invoked earlier on the page, the UUID can be omitted; it falls back to the value a previous parse stored on the current page, so on a brand-new page it resolves only after the page has been saved and re-parsed (purged or re-saved):

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
| `uuid` | UUID | string | No | (falls back to the uuid stored by a prior `{{Entity}}` parse) | UUID of the entity to render. Required if `{{Entity}}` hasn't been invoked. | `80ee3b95-5665-4548-9e2d-d2067895c0ac` |
| `canBuy` | Can buy | boolean | No | (derived from UEX purchase data, all three kinds) | Override for the "Buy" summary flag. Set to `no` when UEX has stale prices for an entity removed from shops. | `no` |
| `canRent` | Can rent | boolean | No | (items: card hidden unless set; vehicles: derived from uex_prices.rental; not used for commodities) | Whether the entity is rentable; for items the card is hidden by default. | `yes` |
| `canLoot` | Can loot | boolean | No | (items: derived from apiData.is_lootable; not used for vehicles or commodities) | Override for the "Loot" summary flag. Items only. | `yes` |
| `canCraft` | Can craft | boolean | No | (items: derived from is_craftable; not used for vehicles or commodities) | Override for the "Craft" summary flag. Items only. | `no` |
| `canPledge` | Can pledge | boolean | No | (items: entity tag; vehicles: msrp presence; not used for commodities) | Override for the "Pledge" summary flag. | `yes` |
| `canMine` | Can mine | boolean | No | (commodities: derived from is_mineable; not used for items or vehicles) | Override for the "Mine" summary flag. Commodities only. | `yes` |
| `canHarvest` | Can harvest | boolean | No | (commodities: derived from has_harvestables; not used for items or vehicles) | Override for the "Harvest" summary flag. Commodities only. | `yes` |

## Behavior

### What renders, by kind

- **Items** render summary flags for Buy, Loot, Craft, Pledge (Rent is inserted only when `canRent` is set explicitly), plus one Shops card of UEX purchase terminals.
- **Vehicles** render Buy, Rent, Pledge, plus a Shops card and a Rentals card.
- **Commodities** render Mine, Harvest, Buy, plus a mining-deposit card when the commodity has one, then a Trade card: a UEX terminal table when priced, otherwise link-out buttons to SC Trade Tools and UEX.
- **Missions and locations** render nothing: no grid, and no warning when the fetch failed.
- **A page no kind claims** shows the placeholder "No availability details." when it has no uuid, or the warning "Couldn't load availability details." when its uuid matches no kind.

### Cards and flags

- Each summary flag shows a yes/no/unknown state; unknown means the API couldn't tell, not that the value is false.
- Every `canX` argument accepts any [Module:Yesno](https://starcitizen.tools/Module:Yesno) input (`yes`, `no`, `1`, `0`, `true`, `false`, and their variants).
- A `canX` override always wins over the derived value once set, including `canRent=no` on an item, which still shows the Rent row (with a "No" state) instead of hiding it; only leaving it unset hides the row.
- An item's Shops card or a vehicle's Shops/Rentals card with no UEX prices collapses to a static "No … data in UEX" header rather than disappearing. A commodity with no trade prices doesn't get this: it gets a link-out card instead (see above), so this fallback header never appears for commodities.
- Terminal location links disambiguate gateway stations by appending the terminal's own parent star system (`Stanton Gateway` becomes `Stanton Gateway (Pyro)`), since the bare terminal name collides with that system's own wiki page.

## See also

- [Template:Entity](https://starcitizen.tools/Template:Entity), the infobox that owns the page's structured data, SHORTDESC, and categories; sets the uuid this template falls back to.
- [Template:Entity/Related](https://starcitizen.tools/Template:Entity/Related), sibling renderer for set components and cosmetic variants.
- [Template:Entity/Description](https://starcitizen.tools/Template:Entity/Description), sibling renderer for the in-game description.
- [Module:Entity/Availability](https://starcitizen.tools/Module:Entity/Availability), the implementation.
