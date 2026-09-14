# Module:Entity/Rewards

Renders a Mission page's reward items and blueprints as two sectioned tables, or an "unavailable"/"no rewards" notice when the API has no data.

Editors use this through `{{Entity/Rewards}}`; see [Template:Entity/Rewards](https://starcitizen.tools/Template:Entity/Rewards). The `Rewards` property is written separately, by `{{Entity}}` from the Mission kind's own structured data.

## For module editors

### API

`p.main(frame)` reads `apiData.reward_groups` and `apiData.blueprints` via `Module:Entity/Data` and renders the item and blueprint sections. Each cell's text comes from [Module:Entity/Rewards/Lines](https://starcitizen.tools/Module:Entity/Rewards/Lines) (`itemLine`, `blueprintLine`), the same helpers `Module:Entity/Mission.getStructuredData` uses for the `Rewards` property.

### Gotchas

- `processItems`/`processBlueprints` also build the per-section caption text (drop chance, mission-owner-only note); that display-only info has no structured-data counterpart and stays local to this module.
