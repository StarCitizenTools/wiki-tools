# Module:Entity/TypeResolver

Resolves an entity's display metadata, the infobox header label and the plural browse category, from the API record's raw `type` and `classification` strings. A pure lookup: loads two curated JSON manifests, applies a fixed precedence ladder, and returns.

Editors never invoke this module directly; it runs inside [Template:Entity](https://starcitizen.tools/Template:Entity), [Template:Vehicle](https://starcitizen.tools/Template:Vehicle) and [Template:Location](https://starcitizen.tools/Template:Location).

## For module editors

### API

`p.resolve(apiType, classification) → typeInfo, displayType`: `typeInfo` is `{ name, category }`, or `nil` when unmapped; `displayType` is `typeInfo.name` when resolved, else the raw `apiType` string (or `nil` when that is also absent).

Not to be confused with [Module:Entity/SubtypeResolver](https://starcitizen.tools/Module:Entity/SubtypeResolver): that module dispatches a token to a leaf behaviour module, while this one maps `(type, classification)` to a display label.

### Precedence ladder

1. The leaf's own `getTypeInfo(ctx)`, tried by `Data.get` before `TypeResolver` runs at all; a non-nil return wins outright.
2. [classifications.json](https://starcitizen.tools/Module:Entity/Item/classifications.json), only when `classification` starts with `Ship.`: walks the full path, then drops trailing `.segment`s until a match, so a grouping-level entry (`Ship.Turret`) catches every unmapped child under it.
3. [types.json](https://starcitizen.tools/Module:Entity/Item/types.json), keyed by the raw `type` string; the fallback for FPS items, vehicles, and any kind whose classification isn't a `Ship.*` path.
4. The raw `apiType` string itself: `typeInfo` is `nil`, `displayType` is the unformatted API value. No error is raised.

### Gotchas

- Some entries duplicate across both JSON files with identical values (`Ship.Cooler` in classifications, `Cooler` in types). For an item-endpoint record the classification path wins, so the `types.json` entry is dead for those items, but a name change must still update both files to stay consistent.
- The API's `classification_label` field is never read; only `classification` (the path) and `type` feed the ladder.
- A miscategorised entity renders with the raw API type string as its label rather than erroring, and files in no browse category. A label that looks like a raw identifier (`Char_Armor_Helmet`) is the tell.
