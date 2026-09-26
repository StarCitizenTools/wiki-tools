# Module:SystemMap

Backs `{{System map}}`, which draws one star system as a horizontal orbit rail: the star or stars, the planets and belts orbiting them, and the moons and rings orbiting those. Split across subpages: [Module:SystemMap/Data](https://starcitizen.tools/Module:SystemMap/Data) resolves the system and builds the model, [Module:SystemMap/Renderer](https://starcitizen.tools/Module:SystemMap/Renderer) turns it into the rail, and [Module:SystemMap/systems.json](https://starcitizen.tools/Module:SystemMap/systems.json) holds every system's bodies in orbital order.

Editors use this through `{{System map}}`; see [Template:System map](https://starcitizen.tools/Template:System_map) for the parameters, tracking categories, and what the rail draws.

## For module editors

### API

- `Data.resolveKey(input)` / `Data.buildModel(input, currentTitle)`: resolve the system name and build the `SystemMapModel` (bodies, tiers, current-page flag).
- `Data.discSize(tier, km)`: a body's diameter mapped to a rendered disc size, logarithmic within its tier.
- `Data.summarise(model)`: the header's body-count string.
- `Data.findBody(page)`: where a page sits in the system data, or nil for a belt, ring, place, or unknown title: `{ system = { key, page, affiliation }, kind = 'star'|'planet'|'moon', entry, planet? }` (`planet` is set only for a moon, its own planet's entry).
- `Renderer.renderRail(model)`: the model turned into rail markup.
- `p.render(input, currentTitle, exists, collapsed, track)`: the testable core: everything parser-dependent (title, page existence, tracking) arrives as an argument.
- `p.main(frame)`: wikitext entry point; wires the real title, an `mw.title` existence probe, and [Module:CollapsibleCard](https://starcitizen.tools/Module:CollapsibleCard) for the card shell.

### Gotchas

- The header's eyebrow is the system's affiliation (`systems.json` `affiliation`, a code) in the Location breadcrumb's compact form, e.g. "UEE space", linking `Category:<label> systems`. Rendering it requires `Module:Entity/Location/Util`, so an edit to that module, or to one of its own requires, re-renders every page carrying a system map.
- Disc size is logarithmic and rank-preserving only, not proportional: Pyro V's diameter is 6.6× Hurston's but renders about 1.3× its width. An unsized body, or one whose tier has no valid extents, draws at its tier's floor; a body whose diameter *exceeds* the tier's recorded maximum clamps to the tier's cap instead, so it reads as "at least as big as anything here" rather than overstating or erroring.
- `p.annotateExistence` calls `mw.title.new(page).exists` once per body, an expensive parser function capped at 100 calls on this wiki; Sol (36 probes) is the worst case among the 75 systems in `systems.json`. A larger rollout to location pages is not covered by that budget and needs a different approach.
- A companion star is measured at the star tier regardless of which column it renders in: its own diameter, not the column, determines its size.
- Exceeding the expensive-parser-function budget raises a `LuaError`; `p.main` wraps the existence probe in `pcall` and degrades to no tracking category rather than a script error, since a false "missing" flag would be worse than a missing category.
- `systems.json` is generated, not hand-maintained: the `scripts/cmd/systemmap` Go tool in this repository rebuilds it from the upstream ARK Starmap plus `pages/module/SystemMap/overlay.json`'s hand-written corrections. An edit to the deployed page is overwritten by the next regeneration; a wrong body, link, or placement is corrected in the overlay and redeployed through the tool. Titles are stored rather than looked up, so a page move needs an overlay correction and a rebuild rather than self-healing.
