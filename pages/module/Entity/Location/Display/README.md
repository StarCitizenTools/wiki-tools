# Module:Entity/Location/Display

The infobox pieces every Location leaf builds the same way, so a system, a planet and a belt read alike: the starmap sensor meters, the location chain and the anchors it links, the affiliation shown, and the Starmap button and code row.

Editors never invoke this module directly; it runs inside [Template:Location](https://starcitizen.tools/Template:Location), which declares the kind, or inside [Template:Entity](https://starcitizen.tools/Template:Entity) when the probe claims a location record; the leaves that call it are on [Module:Entity/Location](https://starcitizen.tools/Module:Entity/Location).

## For module editors

### API

- `p.formatSensor(value) → string|nil`, `p.appendSensorMeter(items, label, value)`: the starmap 0-10 readings as `8.1/10` text and as a full-width MeterBar row. Zero is the no-reading sentinel, so both return/append nothing for it, which is also the test callers use before storing a value.
- `p.starmapFooterButtons(code) → table[]`, `p.starmapMetadataItems(code) → table[]`: the Starmap button and code row, one definition for every leaf so they cannot drift apart. The row breaks the code at its dots with `<wbr>`, since a code runs to 39 unbreakable characters. Both return an empty list without a code.
- `p.locationChain(starsystem, system, parentName, parentTarget) → string|nil`: the Location row, `affiliation space › system › parent`. The first tier is the SYSTEM's affiliation, never the page's, because it links the systems category; the caller supplies only the parent, the one tier each leaf resolves differently.
- `p.tier(name, target) → string|nil`: one tier of that row, linked only when the target page exists, so a chain never paints a red link.
- `p.anchorTitle(name, qualifier) → string`: the qualified title (`<name> (planet)`) when that page exists, else the bare name. Both directions occur: ArcCorp's article sits at the qualified title, while a binary's component star sits at the bare `Goss A`.
- `p.celestialParentAnchor(starsystem, obj) → name, target`: what an object orbits, qualified `star` for a star or black hole and `planet` otherwise.
- `p.affiliationDisplay(starsystem, resolved) → string|nil`: the affiliation to show. Free text keeps the editor's markup; a canonical token renders as its linked label, so `|affiliation=UEE` reads like a sibling page's linked United Empire of Earth.
