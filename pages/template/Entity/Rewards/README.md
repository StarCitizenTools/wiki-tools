# Template:Entity/Rewards

Renders the items and blueprints a contract awards, under its own Items and Blueprints subheadings. Place it as a `== Rewards ==` section on a contract page, below the description.

## Usage

Explicit UUID:

```wikitext
{{Entity/Rewards|uuid=f0274151-6591-4bab-b6db-bd01536f9f28}}
```

When `{{Entity}}` has been invoked earlier on the page, the UUID can be omitted; it falls back to the value a previous parse stored on the current page, so on a brand-new page it resolves only after the page has been saved and re-parsed (purged or re-saved):

```wikitext
{{Entity}}

== Rewards ==
{{Entity/Rewards}}
```

## Parameters

| Name | Label | Type | Required | Default | Description | Example |
|------|-------|------|----------|---------|-------------|---------|
| `uuid` | UUID | string | No | (falls back to the uuid stored by a prior `{{Entity}}` parse) | UUID of the contract to render. Required if `{{Entity}}` hasn't been invoked. | `f0274151-6591-4bab-b6db-bd01536f9f28` |

## Behavior

- Both subheadings always render. Items get one table per reward group, captioned with who receives them (every contract member, or only the contract owner); blueprints get one table per pool, captioned with its drop chance.
- An empty list shows the placeholder "No items awarded." or "No blueprints awarded." An upstream fetch failure shows the warnings "Couldn't load awarded items." and "Couldn't load awarded blueprints." in place of both lists.

## See also

- [Template:Entity](https://starcitizen.tools/Template:Entity), the infobox that owns the page's structured data, SHORTDESC, and categories; sets the uuid this template falls back to.
- [Template:Entity/Orders](https://starcitizen.tools/Template:Entity/Orders), sibling renderer for the cargo a contract requests.
- [Template:Entity/Combat](https://starcitizen.tools/Template:Entity/Combat), sibling renderer for a contract's combat encounter.
- [Module:Entity/Rewards](https://starcitizen.tools/Module:Entity/Rewards), the implementation.
