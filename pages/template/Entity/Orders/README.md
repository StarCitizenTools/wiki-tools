# Template:Entity/Orders

Renders the cargo a contract asks you to haul: a totals row, then one row per order giving its quantity, cargo, and size. Place it as an `== Orders ==` section on a contract page, below the description.

## Usage

Explicit UUID:

```wikitext
{{Entity/Orders|uuid=656765fd-3a64-458f-be3a-3131a94cefb7}}
```

When `{{Entity}}` has been invoked earlier on the page, the UUID can be omitted; it falls back to the value a previous parse stored on the current page, so on a brand-new page it resolves only after the page has been saved and re-parsed (purged or re-saved):

```wikitext
{{Entity}}

== Orders ==
{{Entity/Orders}}
```

## Parameters

| Name | Label | Type | Required | Default | Description | Example |
|------|-------|------|----------|---------|-------------|---------|
| `uuid` | UUID | string | No | (falls back to the uuid stored by a prior `{{Entity}}` parse) | UUID of the contract to render. Required if `{{Entity}}` hasn't been invoked. | `656765fd-3a64-458f-be3a-3131a94cefb7` |

## Behavior

- Unique Items counts order lines. An order adds to Total Units or to Total SCU, never both; an order with no quantity shows `?` and adds to neither.
- An order matched by tag rather than by a specific item shows `Cargo` when it sets a container size and `Package` when it does not; an item the API leaves unnamed shows as `Mission item`.
- A contract with no hauling orders shows the placeholder "No items requested."; an upstream fetch failure shows the warning "Couldn't load requested items."

## See also

- [Template:Entity](https://starcitizen.tools/Template:Entity), the infobox that owns the page's structured data, SHORTDESC, and categories; sets the uuid this template falls back to.
- [Template:Entity/Rewards](https://starcitizen.tools/Template:Entity/Rewards), sibling renderer for the items and blueprints a contract awards.
- [Template:Entity/Combat](https://starcitizen.tools/Template:Entity/Combat), sibling renderer for a contract's combat encounter.
- [Module:Entity/Orders](https://starcitizen.tools/Module:Entity/Orders), the implementation.
