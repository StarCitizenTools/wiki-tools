# Module:Dimensions

Renders an isometric CSS-3D diagram of an object's bounding box at honest scale: measurement lines with end ticks on each axis, an optional reference cuboid on the same ground plane, and a footer bar of caller-supplied metrics plus the reference legend. Hovering the diagram (pointer devices only) rotates it to a top-down plan view; the rotation is disabled under reduced-motion preferences.

Required by [Module:Entity/Vehicle/Dimensions](https://starcitizen.tools/Module:Entity/Vehicle/Dimensions) and [Module:Entity/Facet/Dimensions](https://starcitizen.tools/Module:Entity/Facet/Dimensions), both thin adapters; [Module:Dimensions/presets](https://starcitizen.tools/Module:Dimensions/presets) supplies reusable reference objects. Not invoked from templates.

## For module editors

### API

`p._main(args, frame?)` returns an HTML string, or `nil` when `length`/`width`/`height` are missing, non-numeric, or not positive. `frame` is optional and falls back to `mw.getCurrentFrame()`.

| Field | Type | Required | Description |
|---|---|---|---|
| `length`, `width`, `height` | number (m) | Yes | Must be > 0. |
| `lengthAlt`, `widthAlt`, `heightAlt` | number (m) | No | Shown as a subtle parenthetical; dropped when equal to the primary value. |
| `reference` | table | No | A resolved reference cuboid: `{ length, width, height, label, color?, colorLight?, colorDark? }` (metres; colour trio falls back to the CSS default). Not a type key; the caller resolves it. |
| `metrics` | `{ label, value }[]` | No | Ordered footer rows, e.g. mass; `value` is a pre-formatted display string. |

`p.main(frame)` is the `#invoke` entry point (reads [Module:Arguments](https://starcitizen.tools/Module:Arguments)), but renders a bare box: `reference` and `metrics` are Lua-only table arguments with no wikitext form.

[Module:Dimensions/presets](https://starcitizen.tools/Module:Dimensions/presets) (domain-agnostic references only; a consumer defines its own domain-specific ones):

- `p.human`: 0.3 × 0.5 × 1.8 m.
- `p.banana`: 0.05 × 0.05 × 0.2 m, standing upright, with its own yellow colour trio.
- `p.resolveAuto(longest)`: the largest of the two above whose longest dimension does not exceed `longest`; falls back to the smallest when the object is smaller than both (being dwarfed by the banana is the intended scale story, not an edge case to hide).

### Gotchas

- `transform-style: preserve-3d` is set inline from Lua on several elements because the TemplateStyles sanitizer rejects it as a stylesheet property.
- The root carries `data-length`/`data-width`/`data-height` (+ `-alt` variants when they render) for machine reading; a reference's identity is not exposed as a data attribute, only its geometry via CSS custom properties. A visually-hidden text summary covers all values for screen readers; the visual scene itself is `aria-hidden`.
- Composite CSS transforms are stashed in custom properties and consumed bare: the sanitizer rejects `var()` nested inside a `transform` function argument, but not inside a custom-property declaration.
