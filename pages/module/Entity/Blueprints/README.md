# Module:Entity/Blueprints

Renders an entity's crafting blueprints and dismantle returns. A sibling renderer parallel to [Module:Entity/Availability](https://starcitizen.tools/Module:Entity/Availability) and [Module:Entity/Description](https://starcitizen.tools/Module:Entity/Description), it consumes [Module:Entity/Data](https://starcitizen.tools/Module:Entity/Data) so it shares Apiunto's cache with the Entity infobox and any other Entity-family template on the page.

Each blueprint produces a [Module:CollapsibleCard](https://starcitizen.tools/Module:CollapsibleCard) titled with the output item name. The card description shows the blueprint key followed by a `Grade N` [Module:BadgeLua](https://starcitizen.tools/Module:BadgeLua) chip. Body lists the recipe aspects: input material quantity (SCU for resources, a bare count for discrete items) plus a modifier table (min/max deltas, colour-coded by directionality). A parallel "Dismantle" section renders one card per blueprint whose API entry includes dismantle data; the body is a single Material / Return table.

The module dispatches on entity kind. **Items** read blueprint data from `apiData.blueprint` (the items endpoint) and get the two-section Blueprints / Dismantle view above. **Commodities** aren't craftable, so they short-circuit to a "Used in crafting" summary card: a recipe count plus a link to the filtered blueprints list (see [Commodity branch](#commodity-branch)). Vehicles don't carry blueprint data.

> Temporary non-interactive view. An interactive crafting explorer (quality slider, recomputed values, etc.) requires a dedicated MediaWiki extension and is out of scope for this module.

## Usage

Invoked through [Template:Entity/Blueprints](https://starcitizen.tools/Template:Entity/Blueprints), not called directly from other Lua:

```wikitext
{{Entity/Blueprints|uuid=80ee3b95-5665-4548-9e2d-d2067895c0ac}}
```

The `uuid` argument falls back to the SMW UUID set by `Template:Entity` on a prior parse, so on a typical entity page the template is invoked bare:

```wikitext
{{Entity}}

== Blueprints ==
{{Entity/Blueprints}}
```

## API

### `p.main( frame )`

Entry point invoked from `Template:Entity/Blueprints`.

Resolves the UUID via `Module:Entity/Data`, fetches the entity, then dispatches on `result.kind`:

- **`Commodity`** → short-circuits to the [Used in crafting](#commodity-branch) card; the two item sections below are skipped entirely.
- **everything else** (items) → renders two adjacent sections:
  - **Blueprints**: one CollapsibleCard per blueprint whose entry carries `aspects.aspects`. Card title is `output_name`; description is `key` followed by a `Grade N` badge. Body holds one block per aspect, with an input material row (name + quantity) and a modifier table.
  - **Dismantle**: one CollapsibleCard per blueprint whose entry carries `dismantle_returns`. Card chrome matches the Blueprints section; body is a single Material / Return table.

On the item path, both sections render their headings unconditionally so the page outline stays stable. Each section independently falls back to a muted `<p class="t-entity-blueprint-empty">` notice in two cases:

- `result.hasApiError` → "Blueprint data unavailable." / "Dismantle data unavailable."
- No matching entries → "No blueprints found for this item." / "No dismantle returns for this item."

### Commodity branch

For a `Commodity` entity, `renderCommodityUsedIn` replaces the whole two-section view with a single [Module:CardLua](https://starcitizen.tools/Module:CardLua) link card. Commodities are consumed by hundreds of recipes (e.g. Aslarite: 830), so the module shows a count plus a link rather than enumerating a table. It resolves the commodity name (`apiData._refinedRecord.name`, falling back to `apiData.name`), then calls `usedInBlueprintCount`, which makes one cheap fetch to the Wiki API `blueprints?filter[ingredient]=<name>&page[size]=1` endpoint (via `Module:Entity/Api`) and reads `meta.total`. The card is titled "Browse N recipes" with a "Wiki API" button linking to the full filtered query.

Three muted empty-states (same `t-entity-blueprint-empty` notice):

- no resolvable name → "No crafting data available."
- fetch failure (`usedInBlueprintCount` returns nil) → "Crafting usage data unavailable."
- zero recipes → "Not used as an ingredient in any known crafting recipe."

## Data

Reads `apiData.blueprint` (array). Shape per entry:

```lua
{
    key = 'blueprint-key',
    output_name = 'Output Item',
    grade = 5,                       -- defaults to '1' when missing
    aspects = {
        aspects = {
            {
                name = 'Aspect Name',
                input = { name = 'Material', quantity_scu = 1 },  -- or quantity = 3
                modifiers = {
                    {
                        label = 'Range',
                        modifier_range = { at_min_quality = 0.85, at_max_quality = 1.15 },
                        better_when = 'higher',   -- or 'lower'
                    },
                },
            },
        },
    },
    dismantle_returns = {
        { name = 'Material', quantity_scu = 1 },  -- or quantity = 3
    },
}
```

Materials come in two flavours. Resource materials carry `quantity_scu` and render as `N SCU`; discrete item materials carry a plain `quantity` count (no SCU) and render as the bare number (e.g. `3`). `formatQuantity` prefers `quantity_scu`, falls back to `quantity`, and returns `''` when neither is present. `modifier_range` is itself optional: some blueprints (e.g. power plants) omit it, and the min/max cells are nil-guarded so they collapse rather than erroring.

The Blueprints and Dismantle sections each filter the array independently. A blueprint with only `dismantle_returns` and no `aspects` renders in Dismantle but not Blueprints, and vice versa.

### Modifier value display

Each modifier emits two cells (min, max) showing the delta from baseline (`at_min_quality - 1` and `at_max_quality - 1`) with a trailing ` %` appended. Note the `%` suffix is glued onto the **raw** delta with no ×100 multiply, so the printed number is the fractional delta, not a true percentage. A non-zero delta is wrapped in a coloured span: green when the value is on the "better" side per `better_when`, red on the worse side. A delta of exactly zero produces an empty cell (the span is only emitted for `val < 0` or `val > 0`); a missing/unrecognised `better_when` falls back to the raw delta as plain text with no colour and no ` %` suffix. So a `better_when = 'lower'` modifier whose `at_min_quality` is `0.85` computes `0.85 - 1 = -0.15` and renders as `-0.15 %` in green (a drift toward the better direction).

## CSS hooks

The module ships its own TemplateStyles in `Module:Entity/Blueprints/styles.css`, but delegates most chrome to shared primitives: item cards to [Module:CollapsibleCard](https://starcitizen.tools/Module:CollapsibleCard), the commodity link card to [Module:CardLua](https://starcitizen.tools/Module:CardLua), Grade chips to [Module:BadgeLua](https://starcitizen.tools/Module:BadgeLua), and tables to [Module:TableLua](https://starcitizen.tools/Module:TableLua). The commodity recipe count is fetched through [Module:Entity/Api](https://starcitizen.tools/Module:Entity/Api) and number-formatted with [Module:Entity/Format](https://starcitizen.tools/Module:Entity/Format).

| Class | Purpose |
|---|---|
| `t-entity-blueprint` | Wrapper around each Blueprints card. Reserved for future structural styling. |
| `t-entity-dismantle` | Wrapper around each Dismantle card. |
| `t-entity-blueprint-empty` | Muted-italic `<p>` notice for the API-error and no-data paths. |
| `t-entity-blueprint-grade` | Hook on the Grade badge that applies `margin-inline-start: var(--space-xs)` so the chip sits clear of the key in the card description. |
| `t-entity-blueprint-aspect` | One aspect block inside the card body. |
| `t-entity-blueprint-aspect__name` | Small muted header above each aspect's material/modifier table. |
| `t-entity-blueprint-material` | 2-column grid holding the input material name and quantity. |
| `t-entity-blueprint-material__name`, `t-entity-blueprint-material__quantity` | Cells in the material grid; `quantity` is right-aligned. |
| `t-entity-blueprint-aspect-modifier__red`, `t-entity-blueprint-aspect-modifier__green` | State colours for modifier deltas (`--color-destructive`, `--color-success`). |

## Architecture

```
Entity/Blueprints/
├── Blueprints.lua    # Kind dispatch, data fetch, card composition, aspect / modifier rendering
└── styles.css        # Aspect block layout, empty-state, modifier colour states
```

Requires `Module:Entity/Data` (UUID resolution + shared fetch), `Module:Entity/Api` (commodity ingredient count), `Module:Entity/Format` (number formatting), `Module:CollapsibleCard`, `Module:CardLua`, `Module:BadgeLua`, and `Module:TableLua`.
