# Module:Entity/Location/Place

Place leaf of the Location kind: stations, outposts, landing zones and the venues inside them. Editors reach it through [Template:Location](https://starcitizen.tools/Template:Location), with a `|uuid=` or, on a page with no game record, `|family=place`.

## For module editors

### API

- `p.family = 'place'`. [Module:Entity/Location](https://starcitizen.tools/Module:Entity/Location) dispatches `Outpost`, `Outpost_InvalidQT`, `Manmade`, `Manmade_VisibleOnInteraction`, `LandingZone`, `PointOfInterest`, `NavPoint` and `Asteroid_ValidQT` records here.
- Editorial args: `classification` (a class in [classes.json](https://starcitizen.tools/Module:Entity/Location/Place/classes.json)), `parent`, `lagrange` (L1 to L5), `zone`, `operator`, `jurisdiction`, `system`, `starmapcode` (aliases `starmapcode`/`code`), and the lore fields `founder`, `founded`, `population`.
- Stores `Classification`, `Zone`, `Lagrange point`, `Parent`, `System`, `Operator`, `Jurisdiction` and `Amenities` in the `location` bucket.
- `starmapcode` is not stored; it feeds the Starmap footer button and the "Starmap code" metadata row (`locationUtil.starmapFooterButtons`/`starmapMetadataItems`), the same pair every Location leaf with a starmap code uses.

### Gotchas

- The class names what a place is; where it sits is the zone, derived per page in this order: a valid curated `|lagrange=` makes it `lagrange`; else a valid curated `|zone=` from the closed vocabulary wins outright, because the record can be wrong (the API parents Levski to the star, Nyx, though it sits on Delamar, and some Pyro stations are likewise parented to the star while orbiting a planet); else a record whose PARENT is a landing zone, station, outpost, point of interest or asteroid base makes it `inside`; else a record typed `Outpost`/`Outpost_InvalidQT`/`LandingZone` is `surface`, and `Manmade`/`Manmade_VisibleOnInteraction`/`Asteroid_ValidQT` is `orbit` (`star` when parented to the star); else the class's own default zone.
- `|lagrange=` accepts only `L1` to `L5`, case-insensitively, stored upper-case; any other value is dropped rather than shown or stored.
- `|parent=` and `|operator=` each take a plain page name or a `[[wikilink]]`. The stored value, its category and the lookup all use the link target; the infobox shows the pipe text where there is one, else the target with a trailing `(qualifier)` dropped.
- A curated `|parent=` beats the record's own parent. It is required for Lagrange stations, which the API parents to the star rather than to the point.
- Jurisdiction is resolved in `enrich` by [Module:Entity/Location/Jurisdiction](https://starcitizen.tools/Module:Entity/Location/Jurisdiction), walking the record's API parents, never the curated `|parent=`. A page with no record reads its curated parent page's stored `Jurisdiction` instead.
- Categories: the class category from `getTypeInfo`, replaced by `Locations with an unknown classification` when `|classification=` is missing or unrecognised; the operator's category; and `<System> system`. Independently, an invalid curated `|lagrange=`/`|zone=` adds `Locations with an invalid zone or Lagrange point`, so a page can carry both tracking categories at once.
