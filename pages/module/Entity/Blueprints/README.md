# Module:Entity/Blueprints

Renders an entity's crafting blueprints and dismantle returns. Sibling renderer parallel to [Module:Entity/Availability](https://starcitizen.tools/Module:Entity/Availability) and [Module:Entity/Description](https://starcitizen.tools/Module:Entity/Description) — consumes [Module:Entity/Data](https://starcitizen.tools/Module:Entity/Data) so it shares Apiunto's cache with the Entity infobox and any other Entity-family template on the page.

Each blueprint produces a [Module:CollapsibleCard](https://starcitizen.tools/Module:CollapsibleCard) titled with the output item name. The card description shows the blueprint key followed by a `Grade N` [Module:BadgeLua](https://starcitizen.tools/Module:BadgeLua) chip. Body lists the recipe aspects — input material in SCU plus a modifier table (min/max percentage deltas, colour-coded by directionality). A parallel "Dismantle" section renders one card per blueprint whose API entry includes dismantle data; the body is a single Material / Return table.

Items only today. Blueprints data is exposed on the items endpoint via `apiData.blueprint`; vehicles don't carry it.

> Temporary non-interactive view. An interactive crafting explorer (quality slider, recomputed values, etc.) requires a dedicated MediaWiki extension and is out of scope for this module.

## Usage

Invoked through [Template:Entity/Blueprints](https://starcitizen.tools/Template:Entity/Blueprints), not called directly from other Lua:

```wikitext
{{Entity/Blueprints|uuid=80ee3b95-5665-4548-9e2d-d2067895c0ac}}
```

The `uuid` argument falls back to the SMW UUID set by `Template:Entity` on a prior parse — so on a typical entity page the template is invoked bare:

```wikitext
{{Entity}}

== Blueprints ==
{{Entity/Blueprints}}
```

## API

### `p.main( frame )`

Entry point invoked from `Template:Entity/Blueprints`.

Resolves the UUID via `Module:Entity/Data`, fetches the entity, and renders two adjacent sections:

- **Blueprints** — one CollapsibleCard per blueprint whose entry carries `aspects.aspects`. Card title is `output_name`; description is `key` followed by a `Grade N` badge. Body holds one block per aspect, with an input material row (name + SCU quantity) and a modifier table.
- **Dismantle** — one CollapsibleCard per blueprint whose entry carries `dismantle_returns`. Card chrome matches the Blueprints section; body is a single Material / Return table.

Both sections render their headings unconditionally so the page outline stays stable. Each section independently falls back to a muted `<p class="t-entity-blueprint-empty">` notice in two cases:

- `result.hasApiError` → "Blueprint data unavailable." / "Dismantle data unavailable."
- No matching entries → "No blueprints found for this item." / "No dismantle returns for this item."

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
                input = { name = 'Material', quantity_scu = 1 },
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
        { name = 'Material', quantity_scu = 1 },
    },
}
```

The Blueprints and Dismantle sections each filter the array independently — a blueprint with only `dismantle_returns` and no `aspects` renders in Dismantle but not Blueprints, and vice versa.

### Modifier value display

Each modifier emits two cells (min, max) showing the percentage delta from baseline — i.e. `at_min_quality - 1` and `at_max_quality - 1`, formatted with a trailing `%`. The cell is wrapped in a coloured span: green when the value is on the "better" side per `better_when`, red on the worse side, plain text at zero. So a `better_when = 'lower'` modifier whose `at_min_quality` is `0.85` renders as `-15 %` in green (a -15% drift toward the better direction).

## CSS hooks

The module ships its own TemplateStyles in `Module:Entity/Blueprints/styles.css` — card chrome delegates to [Module:CollapsibleCard](https://starcitizen.tools/Module:CollapsibleCard) and tables to [Module:TableLua](https://starcitizen.tools/Module:TableLua).

| Class | Purpose |
|---|---|
| `t-entity-blueprint` | Wrapper around each Blueprints card. Reserved for future structural styling. |
| `t-entity-dismantle` | Wrapper around each Dismantle card. |
| `t-entity-blueprint-empty` | Muted-italic `<p>` notice for the API-error and no-data paths. |
| `t-entity-blueprint-grade` | Hook on the Grade badge — applies `margin-inline-start: var(--space-xs)` so the chip sits clear of the key in the card description. |
| `t-entity-blueprint-aspect` | One aspect block inside the card body. |
| `t-entity-blueprint-aspect__name` | Small muted header above each aspect's material/modifier table. |
| `t-entity-blueprint-material` | 2-column grid holding the input material name and quantity. |
| `t-entity-blueprint-material__name`, `t-entity-blueprint-material__quantity` | Cells in the material grid; `quantity` is right-aligned. |
| `t-entity-blueprint-aspect-modifier__red`, `t-entity-blueprint-aspect-modifier__green` | State colours for modifier deltas (`--color-destructive`, `--color-success`). |

## Architecture

```
Entity/Blueprints/
├── Blueprints.lua    # Data fetch, card composition, aspect / modifier rendering
└── styles.css        # Aspect block layout, empty-state, modifier colour states
```
