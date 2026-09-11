# Module:Entity/Blueprints

Renders an item's crafting blueprints and dismantle returns, or, for a commodity, a card linking to the recipes that use it as an ingredient.

Editors use this through `{{Entity/Blueprints}}`; see [Template:Entity/Blueprints](https://starcitizen.tools/Template:Entity/Blueprints).

## For module editors

### Hook

Draws `getBlueprints`, resolved leaf-first (see the Hooks table on [Module:Entity](https://starcitizen.tools/Module:Entity)). Payload (`EntityBlueprintsPayload` in [Module:Entity/Types](https://starcitizen.tools/Module:Entity/Types)):

- `blueprints`: Base's default, `{ blueprints = ctx.apiData.blueprint }`; inherited by every kind that doesn't override it. Entry shape: `key`, `output_name`, `grade`, `aspects.aspects[]` (each an `input` material + `modifiers[]`), `dismantle_returns[]`. A blueprint carrying only `aspects` or only `dismantle_returns` renders in just the matching section.
- `ingredient`: `{ name }`, returned only by Commodity, in place of `blueprints`. Commodities are crafting inputs, never outputs, so this switches the module to the "Browse N recipes" card instead of the two-section view.

### Extending

A kind with its own blueprint concept returns either `blueprints` (reusing the two-section item view; entries need the same shape as `apiData.blueprint`) or `ingredient = { name = … }` (the used-in-crafting card). Vehicles define neither, so vehicle pages fall through to Base's default and render the item-worded empty states rather than being omitted.

### Gotchas

- `formatQuantity` prefers `quantity_scu` over `quantity`; a material with neither renders an empty cell rather than erroring.
- `modifier_range` is optional (e.g. power plants omit it); the min/max cells are nil-guarded to collapse instead of erroring.
- A modifier's `%` suffix is glued onto the raw fractional delta with no ×100 multiply: `at_min_quality = 0.85` on a `better_when = 'lower'` modifier computes `0.85 - 1 = -0.15` and prints as `-0.15 %`, not `-15 %`.
- `result.hasApiError` produces wording distinct from a genuine no-data page ("… unavailable." vs "No … found/returns…"), and `usedInBlueprintCount`'s live Wiki API fetch distinguishes a fetch failure from a genuine zero the same way, so an outage never reads as "not used in crafting."
