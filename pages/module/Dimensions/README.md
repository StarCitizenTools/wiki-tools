# Module:Dimensions

Renders an isometric CSS-3D diagram of an object's bounding box: measurement lines with end ticks on each axis, and caller-supplied metrics such as mass in the box's bottom-right corner. With JavaScript, the `dimensions` gadget opens the diagram into a full view for comparing sizes.

Required by [Module:Entity/Vehicle/Dimensions](https://starcitizen.tools/Module:Entity/Vehicle/Dimensions) and [Module:Entity/Facet/Dimensions](https://starcitizen.tools/Module:Entity/Facet/Dimensions), both thin adapters. Not invoked from templates.

## For module editors

### API

`p._main(args, frame?)` returns an HTML string, or `nil` when `length`/`width`/`height` are missing, non-numeric, or not positive. `frame` is optional and falls back to `mw.getCurrentFrame()`.

| Field | Type | Required | Description |
|---|---|---|---|
| `length`, `width`, `height` | number (m) | Yes | Must be > 0. |
| `lengthAlt`, `widthAlt`, `heightAlt` | number (m) | No | Shown as a subtle parenthetical; dropped when equal to the primary value. |
| `stowed` | boolean | No | The box is the object's stowed (cargo) size rather than its physical size. Only `true` counts. |
| `metrics` | `{ label, value }[]` | No | Ordered label-over-value pairs in the bottom-right corner, e.g. mass; `value` is a pre-formatted display string. |

`p.main(frame)` is the `#invoke` entry point (reads [Module:Arguments](https://starcitizen.tools/Module:Arguments)), but renders a bare physical box: `stowed` and `metrics` are Lua-only arguments with no wikitext form.

### Gotchas

- `transform-style: preserve-3d` is set inline from Lua on several elements because the [TemplateStyles](https://www.mediawiki.org/wiki/Extension:TemplateStyles) sanitizer rejects it as a stylesheet property.
- The root carries `data-length`/`data-width`/`data-height` (+ `-alt` variants when they render) for machine reading, and `data-gadget-dimensions-size` (`physical` or `stowed`), which the gadget uses to tell an item's two diagrams apart. A visually-hidden text summary covers all values, metrics included, for screen readers; the scene and the metrics are `aria-hidden`.
- Every diagram adds the hidden [Category:Pages using dimensions gadget](https://starcitizen.tools/Category:Pages_using_dimensions_gadget): the `dimensions` gadget, which opens the diagram into a full view, loads only on pages in it.
- Composite CSS transforms are stashed in custom properties and consumed bare: the sanitizer rejects `var()` nested inside a `transform` function argument, but not inside a custom-property declaration.
