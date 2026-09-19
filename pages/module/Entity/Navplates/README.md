# Module:Entity/Navplates

Renders the browse row at the foot of an entity page: a bar with a link out to the manufacturer's catalogue and one to the type hub, each showing how much is on the other side.

Editors use this through `{{Entity/Navplates}}`; see [Template:Entity/Navplates](https://starcitizen.tools/Template:Entity/Navplates). It also renders wherever `{{Navplate manufacturers}}` is still called, because that template is now a shim onto this module.

## For module editors

### What it replaces

`{{Navplate manufacturers}}` and the per-type navplates listed a whole set on every page in that set, so a manufacturer with n products rendered n² links across the wiki. Clark Defense Systems alone accounted for roughly 337,000 of 828,792, and 741 of the 844 links on `ADP Arms Grey` were its two footer navplates. This renders two links per page whatever the catalogue grows to.

The swap was made by rewriting `{{Navplate manufacturers}}` into a shim onto this module rather than by editing its 6,335 transclusions; the shim passes nothing through, since the module resolves the manufacturer itself. `{{Navplate manufacturer}}` is a redirect to it and needed nothing. The per-type navplates (`{{Navplate personal armor}}`, `{{Navplate vehicles}}` and the rest) are **not** yet replaced: the type cell duplicates part of what they do, so a page can currently show both.

### API

- `Navplates.main(frame)`: builds both cells and returns the bar, or the empty string when neither destination resolves. `Module:Entity/Data` supplies the record.
- `uuid` and `manufacturer` reach the module through `Module:Entity/Data.parseArgs`, which reads the parent frame, so both can be set on `{{Entity/Navplates}}` itself. Neither is normally given: where the API record names no manufacturer, the module reads the page's own Bucket row through `Module:Entity/Store.selfValue`, which already carries whatever `{{Entity}}` resolved including an editorial `|manufacturer=`. A sibling invocation parses its own arguments and cannot see the page's, so the row is the ordinary second source rather than something an editor restates here: one place to declare a manufacturer, not two that can drift.
- The row is also consulted when the API resolves `UNKN`. That code is a real manufacturer record (`Unknown manufacturer`), not one of the sentinels `Module:Entity/Base` filters, so guarding the fallback on nil alone let it mask an editorial `|manufacturer=` naming the actual maker. A stored `Unknown` resolves back to the same record by name, so the guard is idempotent where the page really has no maker.
- `p._internal.resolveHub` / `.countLine` are re-exported for the ScribuntoUnit suite and are not part of the module's API.

### Destinations

Both point at the hub page's `#list` anchor, which every type hub and company page carries (see [Template:Anchor](https://starcitizen.tools/Template:Anchor)), so the reader lands on the index rather than the lead.

- **Manufacturer**: `Module:Entity/Base.resolveManufacturer`, which already filters the `GENF` / `GEND` / `NONE` / `TBD` placeholder codes.
- **Type**: `hubs.json` maps a type string to the hub page. It is generated from the anchored hubs and keyed on both the singular and the plural, because the value arrives as a category (`Guns`) or as a subject type (`Gun`) depending on which layer answered. Three entries are hand overrides where pluralisation cannot reach the page: `Arm armor` and `Leg armor` point at `Arms armor` and `Legs armor`, `Optic` at `Optics attachment`.

The type is looked for in order: the resolved `typeInfo`, then the browse categories the chain contributed leaf-first, then the page's own Bucket row (`Subject type`), which is the only place an editor's `|type=` on `{{Entity}}` is visible to a sibling invocation. The row is read only if nothing earlier resolved, so a page the chain already answers for does not pay a Bucket query for a value it never consults.

An unresolved type renders the manufacturer cell alone. `Ships`, `Vehicles` and `Spacecraft` exist but carry no `#list` anchor, so a spacecraft usually falls back to a role hub (`Medium ships`, `Light fighters`) or to nothing. Commodities resolve nothing either: their subject types are the substances (`Metal`), which never got hub pages, so `{{Navplate commodities}}` still does that job.

### Counts

[Bucket](https://www.mediawiki.org/wiki/Extension:Bucket) has no count aggregate, so a count selects the rows and counts them. Measured on the live wiki, the largest catalogue (581 rows) costs about 4 ms of Lua and 10 ms of Bucket time against the 0.58 s of Lua an entity page already spends, so roughly 1% of a render.

Each candidate carries the `Subject type` value that counts the hub it resolves to, and a browse category carries none, so a hub reached that way renders no count. The count has to size the set the cell links to: `Medium ships` is a curated 45 pages, while the `Spacecraft` subject type its pages share selects 240, so counting the type there captioned the link with a number five times the size of the destination.

Two further things follow from how the count is taken, and neither is a bug to fix here:

- The number is baked into the parser cache, whose expiry is three days, and a Bucket read registers no dependency. Adding a product does not re-parse its siblings, so a count can trail the wiki by up to three days.
- Bucket counts entity rows and a category counts pages. `Behring Applied Technology` is 185 by Bucket and 188 by category, because three pages sit in the manufacturer category without an entity row.

A failed read returns `nil` and the count line is suppressed; `nil` and `0` are deliberately different, since `0` would claim an empty destination.

### Styles

`styles.css` owns the look. Two constraints are load-bearing:

- Two cells sit side by side only at `min-width: 1120px`, Citizen's own desktop edge, and stack below it. The content column is not monotonic in viewport width, because the table-of-contents sidebar arrives at 1120: a 1119 px viewport gives a 1071 px column and a 1120 px viewport gives 740 px. 740 px is therefore the narrowest column the bar sees at or above that edge, and two cells fit it. A container query would say this directly, but TemplateStyles rejects `@container` and a rejected rule is fatal to the whole stylesheet.
- The title wraps rather than clipping, so no name is ever cut short: the longest, `Musashi Industrial and Starflight Concern`, takes two lines in a 393 px cell. Flex makes the neighbouring cell match the taller one.
- The count rides the eyebrow rather than sitting beside the title. It is the same register of small subtle type, and it leaves the title row to the title, which is what lets a long name wrap into the full width of the cell.
- The arrow is pinned to the cell's top corner at `rotate( -45deg )` and is out of flow, so a wrapping title cannot push it around; the cell reserves its gutter with `padding-inline-end` instead. The angle is a literal because TemplateStyles drops a `transform` whose value comes from `var()`.
- The cell is the target, not the text. The wikilink sits on the first line and `::after` stretches it over the cell, which keeps it a real wikilink (it redlinks, previews and tracks like any other) while the icon and the count sit outside its label, where a wikilink label cannot hold them.

### Gotchas

- The cell carries no brand icon. One was tried and dropped: the curated `Sc-icon-brand-<code>.svg` family covers 29 manufacturers against 88 with a catalogue, and type hubs have none at all, so most cells showed nothing and the ones that did were inset from their neighbour. The manufacturer's page image is not a substitute either, because 35 of the 126 that have one are opaque Galactapedia cards or JPEGs. Reinstating it is a file-existence lookup on the manufacturer code, and costs one expensive parser function.
- The arrow is `CdxIconArrowNext.svg` through [Module:Icon](https://starcitizen.tools/Module:Icon) as a `currentColor` mask, so it takes the cell's colour in both themes instead of needing `skin-invert`. `Icon.render` returns markup only, so `Module:Icon/styles.css` is emitted alongside this module's own.
- `mw.loadJsonData` returns a read-only table whose `#` and `next()` are unreliable, so `hubs.json` is only ever read by key.
- `Ballistic Repeater` and `Ballistic repeater` are two separate pages, as are `Distortion Repeater` and `Distortion repeater`. Only the lowercase ones are in `hubs.json`: they carry the content and the inbound links, while the capitalised pair are 320-byte orphans with none. Merging them is a content fix, not a code one, and until it happens the map is what keeps the lookup from being a coin flip.
