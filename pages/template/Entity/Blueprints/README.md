# Template:Entity/Blueprints

Renders an entity's crafting blueprints and dismantle returns. Items only — vehicles don't expose blueprint data. Designed to sit further down an entity page as body content, separate from the [Template:Entity](https://starcitizen.tools/Template:Entity) infobox at the top. Reads the same upstream API data via Module:Entity/Data, so the cache is shared with any other Entity-family template on the page.

Each blueprint becomes a collapsible card titled with the output item name. The card description shows the blueprint key and a small `Grade N` badge; the body lists the recipe aspects with their input materials (in SCU) and a min/max modifier table coloured green/red according to the modifier's directionality. A parallel "Dismantle" section renders one card per blueprint whose API entry includes dismantle data, with a single Material / Return table.

The Blueprints and Dismantle section headings always render so the page layout stays stable. Each section independently falls back to a muted "No data" notice when the upstream fetch fails or the entity exposes no matching data.

> Temporary non-interactive view. An interactive crafting explorer is planned but requires a dedicated MediaWiki extension.

## Usage

Explicit UUID:

```wikitext
{{Entity/Blueprints|uuid=80ee3b95-5665-4548-9e2d-d2067895c0ac}}
```

When `Template:Entity` has been invoked earlier on the page, the UUID can be omitted — it falls back to the value stored in SMW on the current page:

```wikitext
{{Entity}}

== Blueprints ==
{{Entity/Blueprints}}
```

## Parameters

| Name | Label | Type | Required | Default | Description | Example |
|------|-------|------|----------|---------|-------------|---------|
| `uuid` | UUID | string | No | (falls back to SMW UUID on the current page) | UUID of the entity to render. If omitted, defaults to the UUID stored in SMW (set by Template:Entity on a prior parse). Required if Template:Entity hasn't been invoked. | `80ee3b95-5665-4548-9e2d-d2067895c0ac` |

## Behavior

### Blueprints section

One collapsible card per blueprint whose API entry carries recipe aspects. Card title is the output item name; the description is the blueprint key followed by a small `Grade N` badge separated by `var(--space-xs)`. Card body lists each recipe aspect with its input material (name + SCU quantity) and a modifier table — two columns of percentage deltas (min / max quality) coloured green/red according to the modifier's directionality.

### Dismantle section

One collapsible card per blueprint whose API entry includes dismantle data. Same card chrome as Blueprints; body is a single Material / Return table listing what the player gets back when dismantling.

### Empty states

Both section headings always render. Each section independently shows a muted-italic notice when:

- the upstream API fetch failed — *"Blueprint data unavailable."* / *"Dismantle data unavailable."*
- the entity has no matching data — *"No blueprints found for this item."* / *"No dismantle returns for this item."*

## See also

- [Template:Entity](https://starcitizen.tools/Template:Entity) — the main entity infobox; sets the SMW UUID this template falls back to.
- [Template:Entity/Availability](https://starcitizen.tools/Template:Entity/Availability) — sibling renderer for acquisition / shop data.
- [Template:Entity/Related](https://starcitizen.tools/Template:Entity/Related) — sibling renderer for set components and cosmetic variants.
- [Module:Entity/Blueprints](https://starcitizen.tools/Module:Entity/Blueprints) — implementation.
- [Module:Entity/Data](https://starcitizen.tools/Module:Entity/Data) — kind dispatch and data fetching.
