# Module:SystemMap

Backs `{{System map}}`, which draws one star system as a horizontal orbit rail: the star or stars, the planets and belts orbiting them, and the moons and rings orbiting those. Split across subpages: [Module:SystemMap/Data](https://starcitizen.tools/Module:SystemMap/Data) resolves the system and builds the model, [Module:SystemMap/Renderer](https://starcitizen.tools/Module:SystemMap/Renderer) turns it into the rail, and [Module:SystemMap/systems.json](https://starcitizen.tools/Module:SystemMap/systems.json) holds every system's bodies in orbital order.

Editors use this through `{{System map}}`; see [Template:System map](https://starcitizen.tools/Template:System_map) for the parameters, tracking categories, and what the rail draws.

## For module editors

### API

- `Data.resolveKey(input)` / `Data.buildModel(input, currentTitle)`: resolve the system name and build the `SystemMapModel` (bodies, tiers, current-page flag).
- `Data.discSize(tier, km)`: a body's diameter mapped to a rendered disc size, logarithmic within its tier.
- `Data.summarise(model)`: the header's body-count string.
- `Renderer.renderRail(model)`: the model turned into rail markup.
- `p.render(input, currentTitle, exists, collapsed, track)`: the testable core: everything parser-dependent (title, page existence, tracking) arrives as an argument.
- `p.main(frame)`: wikitext entry point; wires the real title, an `mw.title` existence probe, and [Module:CollapsibleCard](https://starcitizen.tools/Module:CollapsibleCard) for the card shell.

### Gotchas

- Disc size is logarithmic and rank-preserving only, not proportional: Pyro V is 6.6× Hurston's diameter by volume but renders about 1.3× its width. An out-of-range or unsized body clamps to its tier's floor, never its ceiling, so an unmeasured body never overstates itself.
- `p.annotateExistence` calls `mw.title.new(page).exists` once per body, an expensive parser function capped at 100 calls on this wiki; Sol (36 probes) is the worst case among the roughly 90 system articles this ships on. A larger rollout to location pages is not covered by that budget and needs a different approach.
- A companion star is measured at the star tier regardless of which column it renders in: its own diameter, not the column, determines its size.
- Exceeding the expensive-parser-function budget raises a `LuaError`; `p.main` wraps the existence probe in `pcall` and degrades to no tracking category rather than a script error, since a false "missing" flag would be worse than a missing category.
