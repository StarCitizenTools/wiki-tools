# Module:Entity/TypeResolver

Resolves an entity's display metadata (`typeInfo` and `displayType`) from the API record's raw `type` and `classification` strings. The output drives the singular label shown in the infobox header (e.g. "Cooler") and the plural browse category the page files under (e.g. "Coolers"). TypeResolver is a **pure lookup module**: it loads two curated JSON manifests, applies a fixed precedence ladder, and returns. No side effects, no knowledge of rendering.

**Not to be confused with [Module:Entity/SubtypeResolver](https://starcitizen.tools/Module:Entity/SubtypeResolver).** Same naming pattern, different jobs: TypeResolver maps `(type, classification)` → *display* metadata `{ name, category }`, while SubtypeResolver maps a dispatch token → a leaf *behavior* module (`require`d and returned). If you're extending the resolution layer, make sure you're in the right module: display labels live here, subtype dispatch lives there.

## Role in the pipeline

```
Data.get(args)
  │
  ├─ leaf.getTypeInfo(apiData, args)   ← tried first (kind-specific override)
  │
  └─ TypeResolver.resolve(type, classification)   ← consulted only when leaf fails
       │
       ├─ classifications.json  (Ship.* prefix walk)
       │
       └─ types.json            (raw `type` key)
            │
            └─ raw apiData.type  (fail-open string)
                                         │
                                         ▼
                               { typeInfo, displayType }
                                  ↓
                            Entity/Categories
```

[Module:Entity/Data](https://starcitizen.tools/Module:Entity/Data) is the sole caller. It tries the leaf kind's own `getTypeInfo` first; TypeResolver is invoked only when that returns `nil`. The resolved `typeInfo` and `displayType` are then consumed by the Categories module to build structured data and file the page in the correct browse category.

`Data.get` also reads `leaf.family` immediately beside the `resolve` call and threads it into the kind's `getCategories`. `family` is a separate categorisation axis: it is **not** produced by TypeResolver, so don't conflate the two when tracing how a page gets categorised.

## API

### `p.resolve(apiType, classification) → typeInfo, displayType`

```lua
--- @param apiType string|nil  The raw `type` field from the API record (or args.type override)
--- @param classification string|nil  The item-endpoint `classification` path (e.g. "Ship.Weapon.Gun")
--- @return table|nil typeInfo   { name: string, category: string } or nil when unmapped
--- @return string|nil displayType  Singular display label; falls back to apiType when typeInfo is nil
function p.resolve(apiType, classification)
```

`typeInfo` shape:

| Field | Type | Description |
|---|---|---|
| `name` | `string` | Singular display label used in the infobox header (e.g. `"Cooler"`) |
| `category` | `string` | Plural browse category (e.g. `"Coolers"`) |

When no JSON entry matches and the fail-open fallback fires, `typeInfo` is `nil` and `displayType` is the raw `apiType` string (or `nil` if that is also absent).

`p._internal.resolveClassification` is exported for unit tests only and is not part of the public API.

## The precedence ladder

Four mechanisms can produce the `(typeInfo, displayType)` pair, tried in order. Earlier steps win; a later step is reached only when the one above it returns `nil`.

**1. Leaf `getTypeInfo` (highest priority; runs in `Data.get`, before TypeResolver is called)**

If the resolved kind chain has a leaf module that exports `getTypeInfo`, `Data.get` calls it first (lines 285–294 of `Data.lua`). A non-nil return short-circuits everything below. This is how kinds with bespoke labelling logic (e.g. a subtype that derives its label from a stat block field) override the generic lookup without touching the manifests.

**2. `classifications.json`: most-specific `Ship.*` prefix walk**

`resolveClassification` is tried first inside `p.resolve`. It only fires when `classification` starts with `"Ship."`; non-`Ship.*` paths (e.g. `"FPS.Weapon.Medium"`) and `nil` return `nil` immediately, falling through to step 3. For `Ship.*` paths the function walks the full path, then drops trailing `.segment`s one at a time until a matching key is found in [Module:Entity/Item/classifications.json](https://starcitizen.tools/Module:Entity/Item/classifications.json):

```lua
-- TypeResolver.lua lines 23–31 (abridged)
local path = classification       -- e.g. "Ship.Turret.SomethingNew"
while path and path ~= '' do
    local entry = map[path]
    if type(entry) == 'table' then return entry end
    path = path:match('^(.*)%.[^.]+$')  -- strip last segment
end
-- falls through: "Ship.Turret.SomethingNew" → "Ship.Turret" → found
```

Example: `classification = "Ship.Turret.SomethingNew"` has no entry in the map. The walk strips `.SomethingNew` and tries `"Ship.Turret"`, which maps to `{ name = "Turret", category = "Turrets" }`. The grouping-level entry acts as a catch-all for any unmapped child.

**3. `types.json`: raw `type` key**

If `resolveClassification` returns `nil` (no `Ship.*` match), `p.resolve` falls back to [Module:Entity/Item/types.json](https://starcitizen.tools/Module:Entity/Item/types.json) keyed by the raw API `type` string (e.g. `"WeaponPersonal"` → `{ name = "Personal weapon", category = "Personal weapons" }`). This covers FPS items, vehicles, and any entity kind whose endpoint carries no `classification`.

**4. Raw `apiType` string (fail-open, lowest priority)**

When neither JSON file matches, `p.resolve` returns `nil` for `typeInfo` and the raw `apiType` string as `displayType`. The page still renders; it just shows the unformatted API type string as its label. No error is raised.

## Data

### `classifications.json`

Keyed by classification **path string** (`"Ship.Weapon.Gun"`, `"Ship.Turret"`, etc.). Entries are `{ name, category }` objects. Only `Ship.*` paths are present; the prefix walk keeps the file sparse, since a grouping-level entry (`"Ship.Turret"`) automatically covers all unmapped children without listing each one. There is deliberately no top-level `"Ship"` key, so a completely unmapped single-segment path (e.g. `"Ship.SomethingNew"`) falls through to `types.json` rather than landing in a catch-all.

### `types.json`

Keyed by the raw API **`type` string** (`"Cooler"`, `"WeaponPersonal"`, `"QuantumDrive"`, etc.). Entries are the same `{ name, category }` shape. This file is the broadest net: it covers FPS items, clothing, commodities, vehicles, and every entity kind that either lacks a `classification` or whose classification is not a `Ship.*` path.

## Gotchas

**The winning source is not obvious from the output.** Four overlapping mechanisms (leaf `getTypeInfo`, `classifications.json`, `types.json`, and the raw-string fallback) all apply to the same entity. When you're reading an infobox label, you have to trace the ladder to know which step produced it.

**Some entries appear in both JSON files with identical values.** `"Ship.Cooler"` in `classifications.json` and `"Cooler"` in `types.json` both resolve to `{ name = "Cooler", category = "Coolers" }`. Likewise `"Ship.QuantumDrive"` / `"QuantumDrive"`. For items served by the item endpoint the classification path wins (step 2), making the `types.json` entry dead for those items. The duplication is harmless but it means a name change requires updating both files to stay consistent.

**Fail-open degrades silently.** A typo'd or missing entry in both JSON files does not error; instead, it shows the raw API `type` string as the display label. This means a miscategorised entity will render (with an ugly label) rather than crashing, but it will also be filed in no browse category, making it invisible in listings. Watch for labels that look like raw API identifiers (e.g. `"Char_Armor_Helmet"`) as a diagnostic signal.

**Only `Ship.*` classifications are consulted.** `resolveClassification` short-circuits immediately for any `classification` that does not start with `"Ship."`. FPS items, vehicles, and entities without a `classification` field all reach `types.json` regardless of what their `classification` value is.

**The API's `classification_label` field is intentionally ignored.** `TypeResolver` uses only `classification` (the path) and `type`, never `classification_label`. The curated manifests override whatever label the API generates.

## Tests

**`TypeResolver/testcases.lua`** is a ScribuntoUnit suite covering:

- `resolveClassification` with a leaf path that has a direct entry (`"Ship.Turret.PDCTurret"` → `"PDC"` / `"PDCs"`).
- `resolveClassification` with a path that requires the prefix walk (`"Ship.Turret.SomethingNew"` → `"Turrets"` via the `"Ship.Turret"` grouping entry).
- `resolveClassification` with a non-`Ship.*` path and `nil`: both must return `nil`.
- `resolveClassification` with a direct leaf entry for a non-turret type (`"Ship.Weapon.Rocket"` → `"Rocket pod"` / `"Rocket pods"`).
- `resolveClassification` over a `"Ship.Weapon.Gun"` path and a `"Ship.Cooler"` path, exercising the cross-file overlap case where the classification entry wins even though the type also appears in `types.json` (the Cooler duplication noted in Gotchas).
- `p.resolve` end-to-end: classification wins over `types.json` for a `Ship.*` path.
- `p.resolve` end-to-end: `types.json` is used when classification is non-`Ship.*` (`"FPS.Weapon.Medium"` → `"Personal weapon"`).

The suite runs headless in local CI. `mise run test` (or `mise run test:lua:unit TypeResolver`) auto-discovers it as a `pages/module/**/testcases.lua` file; it is a merge-blocking gate. It also surfaces on-wiki via ScribuntoUnit when the module is deployed.

## Architecture

```
Entity/TypeResolver/
├── TypeResolver.lua      # p.resolve + private resolveClassification
└── testcases.lua         # ScribuntoUnit suite
```

TypeResolver has no dependencies beyond `mw.loadJsonData` (called lazily on first resolution). It does not `require` any other Entity module and carries no state between calls, making it safe to require from any context without load-order concerns.
