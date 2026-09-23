# Module:Entity/EmptyState

The placeholder an Entity section shows when it has nothing to list, and the warning it shows when its data failed to load.

Required by the Entity section renderers [Module:Entity/Description](https://starcitizen.tools/Module:Entity/Description), [Module:Entity/Ports](https://starcitizen.tools/Module:Entity/Ports), [Module:Entity/Availability](https://starcitizen.tools/Module:Entity/Availability), [Module:Entity/Blueprints](https://starcitizen.tools/Module:Entity/Blueprints), [Module:Entity/Related](https://starcitizen.tools/Module:Entity/Related), [Module:Entity/UsedBy](https://starcitizen.tools/Module:Entity/UsedBy), [Module:Entity/Orders](https://starcitizen.tools/Module:Entity/Orders), [Module:Entity/Rewards](https://starcitizen.tools/Module:Entity/Rewards) and [Module:Entity/Combat](https://starcitizen.tools/Module:Entity/Combat); not invoked from templates.

## For module editors

### API

- `p.none(message) → string`: a dashed [Module:Mbox](https://starcitizen.tools/Module:Mbox) placeholder with no icon, for when the data says the list is empty.
- `p.failed(message) → string`: a warning-type Mbox with the alert icon, for when the data did not load.

### Gotchas

- Wording: a section's `none` and `failed` messages share one noun (`No ports.`, `Couldn't load ports.`).
- `result.hasApiError` is also set when only a secondary endpoint failed, so a renderer that can draw from a partial record checks its payload before choosing `failed`.
