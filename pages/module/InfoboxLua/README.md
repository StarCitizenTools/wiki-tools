# Module:InfoboxLua

Data-driven infobox system: pass a Lua table describing the infobox and get back rendered HTML with collapsible sections, tabbed images and subsections, and multi-column item layouts.

Required by [Module:WearableSet](https://starcitizen.tools/Module:WearableSet), [Module:Entity/Infobox](https://starcitizen.tools/Module:Entity/Infobox), and [Module:Company](https://starcitizen.tools/Module:Company); not invoked from templates.

## For module editors

### API

`p.render(data)` returns `<templatestyles>` + the infobox HTML. Schemas are defined in [Module:InfoboxLua/Types](https://starcitizen.tools/Module:InfoboxLua/Types) and enforced per component by [Module:InfoboxLua/Util](https://starcitizen.tools/Module:InfoboxLua/Util)'s `validateAndConstruct`.

**Infobox**: `title` (required), `subtitle?`, `image?` (filename string or an Image table), `imageUploadName?` (overrides the auto-discovery/upload convention base, default `'<page title> - infobox'`), `images?` (Image[], rendered as tabs), `sections?` (Section[]), `class?`, `css?` (`{ property = value }`).

**Section**: `label?`, `content?` (wikitext), `items?` (Item[]), `sections?` (nested Section[], rendered as tabs, keyed only by `label`), `columns?` (default `1`), `collapsible?` (default `false`; not honoured on a nested subsection), `collapsed?` (default `false`; only takes effect when `collapsible = true`), `class?`.

**Item**: `content` (required, wikitext), `label?`, `class?`. [Module:InfoboxLua/Components/Item/Card](https://starcitizen.tools/Module:InfoboxLua/Components/Item/Card) (`getItemComponentData(data)`) composes a `label?` + `content?` + `items?` block into one Item, for a card-shaped entry nested inside a section's `items`.

**Image**: `src?` (filename; auto-discovered when omitted, see Gotchas), `overlay?` (wikitext), `label?` (tab label), `size?` (px, default `400`), `class?`.

### Gotchas

- `validateAndConstruct` raises a hard Lua error, not `nil`, for a missing required field or a key absent from the schema; a component's `if not x then return nil end` guard is unreachable dead code.
- An `Image` with no `src` auto-discovers `'<page title> - infobox.webp'`/`.png`/`.jpg` in that order ([Module:InfoboxLua/ImageResolver](https://starcitizen.tools/Module:InfoboxLua/ImageResolver)); finding none, it falls back to the placeholder image and marks the container `data-gadget-quantumupload-name` (+ `-categories`) for the QuantumUpload gadget's upload control.
- The first rendered image carries `pageimage` (scores +1000 for [PageImages](https://www.mediawiki.org/wiki/Extension:PageImages), MediaWiki 1.44+); the upload placeholder carries `notpageimage` instead (-1000), so a page waiting on an image falls back to a real image elsewhere, or none.
