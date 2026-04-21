# Template:Entity/Description

Renders an entity's in-game description as a quoted block, with the API capture version printed below. Designed to sit further down an entity page as body prose, separate from the [Template:Entity](https://starcitizen.tools/Template:Entity) infobox at the top. Reads the same upstream API data via Module:Entity/Data, so the cache is shared with any other Entity-family template on the page.

## Usage

Explicit UUID:

```wikitext
{{Entity/Description|uuid=80ee3b95-5665-4548-9e2d-d2067895c0ac}}
```

When `Template:Entity` has been invoked earlier on the page, the UUID can be omitted — it falls back to the value stored in SMW on the current page:

```wikitext
{{Entity}}

== Description ==
{{Entity/Description}}
```

## Parameters

| Name | Type | Required | Default | Description | Example |
|------|------|----------|---------|-------------|---------|
| `uuid` | string | No | (falls back to SMW UUID on the current page) | UUID of the entity to render. If omitted, defaults to the UUID stored in SMW (set by Template:Entity on a prior parse). Required if Template:Entity hasn't been invoked. | `80ee3b95-5665-4548-9e2d-d2067895c0ac` |

## Behavior

- The container always renders so the page layout stays stable. When the API returns no description, an "No description available from the API." placeholder is shown in a muted style.
- The description text is wrapped in `<blockquote>` with `aria-label="In-game description"` for assistive tech.
- The version line below the quote is the Apiunto `version` field — useful for cross-referencing the in-game build the description was captured from.

## See also

- [Template:Entity](https://starcitizen.tools/Template:Entity) — the main entity infobox; sets the SMW UUID this template falls back to.
- [Template:Entity/Availability](https://starcitizen.tools/Template:Entity/Availability) — sibling renderer for shop/loot/pledge availability.
- [Template:Entity/Related](https://starcitizen.tools/Template:Entity/Related) — sibling renderer for variants and set components.
- [Module:Entity/Description](https://starcitizen.tools/Module:Entity/Description) — implementation.
