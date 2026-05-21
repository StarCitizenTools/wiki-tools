# Module:Entity/Ports

Renders an entity's port loadout for items and vehicles. Sibling renderer parallel to [Module:Entity/Availability](https://starcitizen.tools/Module:Entity/Availability) and [Module:Entity/Description](https://starcitizen.tools/Module:Entity/Description) — consumes [Module:Entity/Data](https://starcitizen.tools/Module:Entity/Data) so it shares Apiunto's cache with the Entity infobox and any other Entity-family template on the page.

The output is a vertical stack of category cards. Categories come from the API's `category_label` (the canonical [HardpointCategory.php](https://github.com/StarCitizenWiki/API/blob/develop/app/Support/Game/HardpointCategory.php) list — Weapons, Manned Turrets, Coolers, Quantum Drives, Life Support, etc.). Each card holds one row per aggregated port group, with an optional count prefix (`04×`, `13×`), a size pill (`S5`, `S1–5` for ranges), and the equipped item link. When the port has children that warrant expanding (turrets, missile racks), an indented child tree appears below the row with CSS-drawn L-shaped connector lines linking each parent to its children.

## Architecture

The module is a thin coordinator that delegates to three focused sub-modules: `Categories` (config), `Pipeline` (data transformations), and `Render` (wikitext generation). The contract crossing the Pipeline → Render boundary is a `groups` array of category cards with aggregated rows.

```
Entity/Ports/
├── Ports.lua                       # coordinator: parse args, fetch data, dispatch
├── Categories.lua                  # categories.lookup, categories.deriveLabel
├── Pipeline.lua                    # pipeline.process(rawPorts, opts) → groups
├── Render.lua                      # render.fromGroups(groups) → wikitext
├── categories.json                 # category_label → { order | collapsed, expandIntoTypes? }
├── styles.css                      # TemplateStyles for wrapper, cards, rows, pills, tree
├── Categories/testcases.lua        # ScribuntoUnit suite over lookup + deriveLabel
└── Pipeline/testcases.lua          # ScribuntoUnit suite over pipeline stages + end-to-end
```

`Render` has no testcases — it returns mw.html strings that are best verified by inspecting rendered output, not unit tests.

## Pipeline

`pipeline.process(rawPorts, { isVehicle = bool })` runs the following stages and returns the render-ready `groups` array:

1. **Normalize** — walk the raw API tree, produce normalized port nodes (name, displayName, type/subType, size range, equipped item, derived category, recursive children).
2. **Clean children** — recursively drop collapsed-category nodes from every node's children, preserving the top-level so collapsed-category top-level ports can still route to "Other". A primary turret no longer shows its display screens / controller subports in its L-tree.
3. **Narrow children (vehicles only)** — apply each parent category's `expandIntoTypes` allowlist to its remaining children, dropping types that aren't `collapsed` but still don't belong in the L-tree (cockpit panels, etc.). Items skip this step entirely.
4. **Aggregate** — collapse sibling nodes with identical signatures into `{ count, representative, expandable, children }` aggregates. Signature includes type, subType, sizeMin, sizeMax, equipped item name, editable flag, accepted compatible_types, and a recursive child signature. The `expandable` boolean is pre-computed here so Render doesn't need to inspect category internals.
5. **Group** — bucket top-level aggregates into one primary card per distinct category label, plus a single "Other" card at the bottom whose body is sub-grouped by the original collapsed-category label. Primary cards sort by `order` ascending; the "Other" card always sorts last and renders closed by default.

`render.fromGroups(groups)` consumes that output and produces wikitext. Each card renders as a [Module:CollapsibleCard](https://starcitizen.tools/Module:CollapsibleCard).

Stateless. No JS, no Extension:Details, no FloatingUI.

## Data contract (Pipeline → Render)

```lua
groups = {
    { label, order, collapsed, rows = { aggregatedPort, ... } },
    -- the last entry, when present, is the "Other" card:
    { label = 'Other', order = 1000, collapsed = true, rows = {...},
      subGroups = { { label, rows }, ... } },
}

aggregatedPort = {
    count,            -- integer
    expandable,       -- boolean, pre-computed (true when category has expandIntoTypes)
    representative,   -- a normalized port node
    children,         -- recursive array of aggregatedPort
}
```

Render reads `agg.expandable` (never `agg.representative.category.expandIntoTypes`). This keeps Render decoupled from Categories internals.

## Usage

Invoked through [Template:Entity/Ports](https://starcitizen.tools/Template:Entity/Ports), not directly:

```wikitext
{{Entity/Ports|uuid=80ee3b95-5665-4548-9e2d-d2067895c0ac}}
```

The `uuid` argument falls back to the SMW UUID set by `Template:Entity` on a prior parse — so on a typical entity page the template is invoked bare:

```wikitext
{{Entity}}

== Ports ==
{{Entity/Ports}}
```

Works identically for items and vehicles.

## Data files

### `categories.json`

Keyed by the API's `category_label` string. Mirrors the upstream Apiunto layout — sync from [HardpointCategory.php on `develop`](https://github.com/StarCitizenWiki/API/blob/develop/app/Support/Game/HardpointCategory.php) when categories change.

```json
{
  "categories": {
    "Weapons":         { "order": 5 },
    "Manned Turrets":  { "order": 10, "expandIntoTypes": ["Turret", "WeaponGun", "MissileLauncher"] },
    "Power Plants":    { "order": 33 },
    "Controllers":     { "collapsed": true },
    "Crew Stations":   { "collapsed": true }
  },
  "typeAliases": {
    "WeaponAttachment": "Weapon attachments"
  }
}
```

- **`order`** (primary card) controls sort position; lower first. Ties break on `label` alphabetically.
- **`collapsed: true`** routes every port carrying that category label into the single "Other" card at the bottom (rendered closed by default).
- **`expandIntoTypes`** (optional, vehicle-only) is the per-parent allowlist of child types kept in the L-tree under that category. Used to drop cockpit panels / displays from turret children.
- **`typeAliases`** maps an API `type` string to a category label, for ports that lack `category_label` (typically items). M4A Cannon's `WeaponAttachment` ports use this to land in the "Weapon attachments" card. Items with unaliased types fall through to a CamelCase-split label rendered as their own primary card.
- Unknown labels (a category we haven't catalogued yet) default to a primary card with `order: 999` — fail-open, so new CIG categories render until we sync.

## Aggregation rules

Two sibling ports merge into one aggregate row only when ALL of these match:

- `type` and `subType`
- `sizeMin` and `sizeMax`
- `equipped.name` (or both unequipped)
- `editable` flag
- The full recursive signature of their children

This means 7 manned turrets carrying identical CF-557 Galdereens at identical sizes collapse to one row with `count = 7`. Mixed loadouts naturally produce multiple separate rows.

Aggregation is **per-parent**: only direct siblings under the same parent (or top-level under the same category) get merged.

## Child tree

When an aggregate has children that are also rendered (filter kept them), the row appends a recursive `<ul class="t-entity-ports-tree">` containing one `<li>` per child. Each `<li>` carries the same `[count?] [pill] [label]` shape as the row headline, and may nest its own `<ul>` for grandchildren — the structure recurses to whatever depth the data exposes.

L-shaped connector lines are drawn entirely in CSS via pseudo-elements on each `<li>`: a vertical trunk (`::before`) runs top-to-bottom and is clamped to the elbow on the last child; a horizontal branch (`::after`) joins the trunk to the child's content. No Lua-side glyphs, no per-layer markup.

Indent comes from each nested `<ul>`'s `padding-left`, so deeper nesting just steps further in.

## Size pill precedence

When something is equipped, the pill shows the *equipped item's* size — more useful than the port's accepted range. A flex `S1–5` fuel mount with a size-4 tank installed reads as `S4`, not `S1–5`. Only empty ports fall back to the port's range.

## Empty + error states

| Condition | Output |
|---|---|
| `result.hasApiError` | `<p class="t-entity-ports-empty">Port data unavailable.</p>` |
| `apiData.ports` missing or empty | `<p class="t-entity-ports-empty">No ports.</p>` |

If every top-level port lands in a collapsed category, the module renders only the "Other" card — no separate empty-state, since users can expand it.

TemplateStyles is emitted on every path so the empty notice picks up its muted-italic styling.

## Accessibility and machine readability

The DOM is designed to work for both screen-reader users and DOM-scraping consumers (the future topology gadget, external tools).

**A11y:**

- The root wrapper carries `role="region" aria-label="Port loadout"` so AT users land in a named landmark.
- The "Other" card's sub-category headings use `role="heading" aria-level="4"` on a `<div>` (not an `<h*>`) so the MediaWiki parser doesn't generate TOC anchors but AT still picks up the heading structure.
- The zero-pad span (`0` in `04×`) carries `aria-hidden="true"` — it's alignment, not data.
- Solo count cells (`01×` when no sibling has count > 1) carry `aria-hidden="true"` on the whole cell — the "1×" is structural filler, not information.
- Hardware-locked ports get a visually-hidden `<span class="t-entity-ports-sr-only">hardware-locked</span>` after the label. The pill's diagonal stripe overlay is invisible to AT without this.

**Machine readability:**

Every port — top-level row AND every `<li>` in the L-tree — carries the same set of `data-port-*` attrs so any DOM scraper can identify it without parsing the visible text:

| Attribute | Value |
|---|---|
| `data-port-type` | API `type` (e.g. `Turret`, `WeaponGun`, `MissileLauncher`) |
| `data-port-subtype` | API `sub_type` / `subtype` (e.g. `GunTurret`) |
| `data-port-size-min` | Lower bound of accepted size range |
| `data-port-size-max` | Upper bound of accepted size range |
| `data-port-count` | Aggregated count (e.g. `4` for a row of 4 identical turrets) |
| `data-port-category` | The resolved category label (e.g. `Manned Turrets`) |
| `data-equipped-name` | Equipped item name (omitted when port is empty) |
| `data-equipped-uuid` | Equipped item UUID (omitted when port is empty or the API didn't surface one) |

## CSS hooks

All visible elements are class-targeted; no inline styles. Rows flex-wrap naturally at narrow widths and the child tree always renders as its own block underneath.

| Class | Purpose |
|---|---|
| `t-entity-ports` | Wrapper. Cards stack via Module:CollapsibleCard's own `margin-block`. Carries `role="region" aria-label="Port loadout"`. |
| `t-entity-ports-empty` | The fallback `<p>` for the empty paths. Muted italic. |
| `t-entity-ports-sr-only` | Visually-hidden utility (clipped 1×1 box). Used inside the row head to surface "hardware-locked" state that the visual stripe can't convey to AT. |
| `t-entity-ports-cat-body` | Padded body inside each Module:CollapsibleCard, holding the row stack. CollapsibleCard supplies the card chrome and the toggle header. |
| `t-entity-ports-subcat` | Sub-category heading inside the "Other" card. Uses Citizen overline tokens. `role="heading" aria-level="4"` on a `<div>` (not an `<h*>`) so the MW parser doesn't generate TOC anchors. |
| `t-entity-ports-row` | Aggregated port row. Flex-wrap so the structure pattern wraps at narrow widths. Carries the full `data-port-*` attr set (see Accessibility section above). |
| `t-entity-ports-head` | Inline-flex containing the headline (optional count + pill + label + sr-only locked marker). Stays together; never wraps mid-headline. |
| `t-entity-ports-count` | Count prefix (`7×`, `4×`, `16×`) — monospace, accent color. Omitted entirely when no row in the sibling group exceeds count = 1; aria-hidden when solo. |
| `t-entity-ports-count__pad` | Leading zero span on single-digit counts. Always `aria-hidden`. |
| `t-entity-ports-label` | Port / equipped item label. `min-width: 0` + `overflow-wrap: anywhere` so long unbreakable names wrap inside the row on narrow viewports. |
| `t-entity-ports-pill` | Layout add-on for size badges (monospace + min-width + centered). Pills render via [Module:BadgeLua](https://starcitizen.tools/Module:BadgeLua) with the `success` variant when equipped. The `--locked` modifier adds a diagonal stripe overlay on top of whatever bg BadgeLua applied. |
| `t-entity-ports-tree` | Recursive `<ul>` below a row when the port has children. Each `<li>` draws its own L-line via `::before` (vertical trunk) and `::after` (horizontal branch). Nested `<ul>`s indent via `padding-left` so deeper layers step further in. Each `<li>` also carries the full `data-port-*` attr set so nested ports are equally self-describing. |

## Deferred / open

- **Attachment-slot policy.** Currently we render every layer including all-empty groups (Policy 2 from the design brainstorm). Revisit if attach slots become game-mechanically significant or generate too much noise on real ships.
- **Drill-down per instance.** Not in scope — the inline structure pattern conveys the loadout shape, and per-hardpoint locations (Front turret, Lower-left turret, etc.) are deemed not part of the player summary. Adding `<details>` back later is additive, not a rewrite.
- **Topology gadget.** A future interactive JS gadget can consume the `data-port-*` attrs on `.t-entity-ports-row` to draw a real schematic. The current module emits the DOM that gadget will read; no changes needed here.
