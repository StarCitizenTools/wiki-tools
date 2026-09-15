# Template:Entity/Combat

Renders a contract's combat encounter as a table of spawn groups, under the total number of hostiles. Place it as a `== Combat ==` section on a contract page, below the description.

## Usage

Explicit UUID:

```wikitext
{{Entity/Combat|uuid=1c7c6b3b-424a-4909-8902-de4dc38e8a83}}
```

When `{{Entity}}` has been invoked earlier on the page, the UUID can be omitted; it falls back to the value a previous parse stored on the current page, so on a brand-new page it resolves only after the page has been saved and re-parsed (purged or re-saved):

```wikitext
{{Entity}}

== Combat ==
{{Entity/Combat}}
```

## Parameters

| Name | Label | Type | Required | Default | Description | Example |
|------|-------|------|----------|---------|-------------|---------|
| `uuid` | UUID | string | No | (falls back to the uuid stored by a prior `{{Entity}}` parse) | UUID of the contract to render. Required if `{{Entity}}` hasn't been invoked. | `1c7c6b3b-424a-4909-8902-de4dc38e8a83` |

## Behavior

- Each row is one spawn group: the game's own group name, its role, whether it spawns as a ship or on foot, how many can be present at once, and the vehicles it can draw from.
- Hostile groups are listed first, then escort targets, defend targets, and anything untagged. The group name carries its own head count, so a row reading `Soldier x 2` spawns two soldiers.
- The concurrent count and the vehicle pool apply to ship groups only. On an on-foot group both cells are an em dash, which reflects the data rather than a gap in it.
- Vehicles are listed alphabetically and named by their wiki page title, with the manufacturer omitted. The whole pool is shown, and one that has no page yet appears as plain text rather than as a broken link.
- A contract with no recorded encounter shows "No combat encounters recorded for this contract." Most contracts have none, so add this section only where the data exists.

## See also

- [Template:Entity](https://starcitizen.tools/Template:Entity), the infobox that owns the page's structured data, SHORTDESC, and categories; sets the uuid this template falls back to.
- [Template:Entity/Orders](https://starcitizen.tools/Template:Entity/Orders), sibling renderer for the cargo a contract requests.
- [Template:Entity/Rewards](https://starcitizen.tools/Template:Entity/Rewards), sibling renderer for the items and blueprints a contract awards.
- [Module:Entity/Combat](https://starcitizen.tools/Module:Entity/Combat), the implementation.
