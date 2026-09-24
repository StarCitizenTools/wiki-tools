# Module:Entity/Navplates

Renders the browse row at the foot of an entity page: a bar with a link out to the manufacturer's catalogue and one to the type hub, each showing how much is on the other side.

Editors use this through `{{Entity/Navplates}}`; see [Template:Entity/Navplates](https://starcitizen.tools/Template:Entity/Navplates). `{{Navplate manufacturers}}` is a shim onto this module, so it renders this bar too.

## For module editors

### Links out, not lists

A footer that lists a whole set on every page in that set renders n² links across the wiki. The bar renders a fixed number of links per page instead, whatever the catalogue grows to, so a new destination belongs here as a hub link, not as a list. `{{Navplate manufacturers}}` passes nothing through: the module resolves the manufacturer itself.

### API

- `Navplates.main(frame)`: builds both cells and returns the bar, or the empty string when neither destination resolves. `Module:Entity/Data` supplies the record.
- `uuid` and `manufacturer` reach the module through `Module:Entity/Data.parseArgs`, which reads the parent frame, so both can be set on `{{Entity/Navplates}}` itself. Neither is normally given: where the API record names no manufacturer, the module reads the page's own Bucket row through `Module:Entity/Store.selfValue`, which already carries whatever `{{Entity}}` resolved including an editorial `|manufacturer=`. A sibling invocation parses its own arguments and cannot see the page's, so the row is the ordinary second source rather than something an editor restates here: one place to declare a manufacturer, not two that can drift.
- The row is also consulted when the API resolves `UNKN`. That code is a real manufacturer record (`Unknown manufacturer`), not one of the sentinels `Module:Entity/Base` filters, so guarding the fallback on nil alone let it mask an editorial `|manufacturer=` naming the actual maker. A stored `Unknown` resolves back to the same record by name, so the guard is idempotent where the page really has no maker.
- `p._internal.resolveHub`, `.countLine`, `.kindHub` and `.countFilter` are re-exported for the ScribuntoUnit suite and are not part of the module's API.

### Destinations

Both point at the hub page's `#list` anchor, which every type hub and company page carries (see [Template:Anchor](https://starcitizen.tools/Template:Anchor)), so the reader lands on the index rather than the lead.

- **Manufacturer**: `Module:Entity/Base.resolveManufacturer`, then the page's stored row. A code `Module:Entity/Base.namesNoMaker` reports (`GENF`, `GEND`, `NONE`, `TBD`) renders no cell whichever source produced it: an editorial `|manufacturer=NONE` is stored as written, because `NONE` is a classification the page records, so the stored row can carry one although the API path filters them.
- **Type**: `hubs.json` maps a type string to the hub page. It is generated from the anchored hubs and keyed on both the singular and the plural, because the value arrives as a category (`Guns`) or as a subject type (`Gun`) depending on which layer answered. The hand overrides cover what pluralisation cannot reach: `Arm armor` and `Leg armor` point at `Arms armor` and `Legs armor`, `Optic` at `Optics attachment`, and the four system types a star system stores (`Single star system`, `Binary star system`, `Trinary star system`, `Star system`) at `Planetary system`.

The destination is looked for in order: the page's **kind**, when `kinds` lists it, which ends the search; otherwise a vehicle's **role**, then the resolved `typeInfo`, then the browse categories the chain contributed leaf-first, then the page's own Bucket row (`Subject type`), which is the only place an editor's `|type=` on `{{Entity}}` is visible to a sibling invocation. A row is read only if nothing earlier resolved, so a page the API and the chain already answer for pays no Bucket query for one.

Role comes first because it is the most specific destination a vehicle has: `Light freighters` says more than `Medium ships`, and `Anti-air vehicles` more than `Ground vehicles`. A spacecraft's own type resolves to no hub at all, so before this the browse row on most ships was a manufacturer cell alone.

Role is matched against `hubs.json`'s `roles` map and nothing else. Role values are generic words (`Medical`, `Mining`, `Cargo`, `Passenger`), and the hub index is one lowercased keyspace shared with guns and armor, so resolving a role through it would let an item hub of the same name capture it and send a reader from a ship to a gun listing. Nothing collides today; the separate map is what keeps that true as hubs are added.

The API record's role is not enough on its own. It is often coarser than the page's (the MOLE is `Medium Mining` upstream and `Prospecting / Mining` on the page), and a vehicle page with a blank `uuid` resolves no record at all, so a sibling invocation sees kind `Item` and an empty `apiData` (Cydnus, Arrastra). Where the API role reaches no hub, the page's Bucket row is read instead: it carries what `{{Entity}}` resolved, editorial override included.

An unresolved destination renders the manufacturer cell alone, which is what a role outside the map gives: the map covers the 17 roles with at least five vehicles, so `Carrier` (Kraken) and `Light salvage` (Vulture) reach nothing rather than a page listing one ship. `Ships`, `Vehicles` and `Spacecraft` exist but carry no `#list` anchor.

A kind reaches its hub through `kinds`, an exact-match map from the resolved kind to one hub for all of its pages, kept out of the shared index for the same reason as roles: kind names such as `Item` and `Location` are generic words. When a kind matches, no other candidate is built at all, because its type strings are a different vocabulary from the one the index is keyed on. Commodity subject types are substances (`Metal`, `Vice`), and `Food` is both a commodity type and the consumable food hub, so a commodity resolved through its type would land on the food-items listing.

Most star system pages have no uuid, so a sibling invocation resolves no record there and reaches its hub only through its stored `Subject type`, which the system-type overrides send to `Planetary system`. A record-backed system reaches the same hub earlier, through its type name.

### Counts

[Bucket](https://www.mediawiki.org/wiki/Extension:Bucket) has no count aggregate, so a count selects the rows and counts them. Measured on the live wiki, the largest catalogue (581 rows) costs about 4 ms of Lua and 10 ms of Bucket time against the 0.58 s of Lua an entity page already spends, so roughly 1% of a render.

Each candidate carries the `Subject type` value that counts the hub it resolves to; a browse category and a role carry none, so a hub reached either way renders no count unless `selects` names it; a kind candidate carries none either. A role hub would be countable by `Role`, but the hubs that predate the `roles` map select their rows by category rather than by `Role`, so the number would size a different set from the page linked. The count has to size the set the cell links to: `Medium ships` is a curated 45 pages, while the `Spacecraft` subject type its pages share selects 240, so counting the type there captioned the link with a number five times the size of the destination.

A hub named in `selects` is counted instead by the selector its own grid uses: `Commodity` by `Category:Commodities`, `Planetary system` by `Category:Systems`. Those hubs span many subject types, so counting the page's own type would size a fraction of the destination.

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
- `mw.loadJsonData` returns a read-only table whose `#` and `next()` are unreliable, so `hubs.json` is read by key or with `pairs`.
- Hub titles are matched lowercased, so a type string only has to differ from the page title in case to resolve. `hubs.json` therefore carries one entry per hub, in the page's own casing.
