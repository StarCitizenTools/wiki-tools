# Template:System map

Renders the star, planet, and moon hierarchy of one star system as a horizontal orbit rail. Wraps [Module:SystemMap](https://starcitizen.tools/Module:SystemMap); place it above `{{System navplate}}` at the foot of a body or system article.

## Usage

```wikitext
{{System map|Stanton}}
{{System map|Stanton|collapsed=yes}}
```

## Parameters

| Name | Label | Type | Required | Default | Description | Example |
|------|-------|------|----------|---------|-------------|---------|
| `1` | System | string | Yes |  | System name (`Stanton`, `stanton`, or `Stanton system` all work). Must be listed in [Module:SystemMap/systems.json](https://starcitizen.tools/Module:SystemMap/systems.json); an unrecognised name renders nothing and adds a tracking category. | `Stanton` |
| `collapsed` | Collapsed | boolean | No | `no` | Render the box closed. The map is short, so it opens by default. | `yes` |

## Behavior

- The card header states the system name and a count of its contents, e.g. "4 planets, 12 moons, 1 belt".
- Asteroid belts draw as a speckled band at their orbital position, not a disc, since they're regions with no diameter to draw. A planet's rings draw the same way under it, alongside its moons, counted separately ("9 planets, 19 moons, 4 rings, 2 belts" for Sol); a ring orbiting a moon rather than a planet isn't drawn.
- A system with two stars draws both: a companion orbiting the primary hangs under it like a moon under a planet; two stars orbiting each other instead share one slot at the head of the rail. Each keeps its own entry either way.
- The body matching the current page is marked with a bolder, brighter name and a trailing dot, plus visually hidden text for screen readers. A system article marks nothing, since the map is the page's own subject rather than a location on it.
- Left to right is orbital order, not distance. Disc size is a three-tier convention (star, planet, moon), not proportional to diameter, and is scaled against the whole starmap's extents rather than just the bodies on the page, so a given body is the same size on every page it appears on; see [Module:SystemMap](https://starcitizen.tools/Module:SystemMap) for how sizes are mapped.
- What a body is comes from its disc colour, not text: a gas giant reads as a banded amber disc, an ice giant as a banded blue one, and a type the module doesn't recognise falls back to plain grey.
- [Module:SystemMap/systems.json](https://starcitizen.tools/Module:SystemMap/systems.json) is generated from the ARK Starmap plus hand-written corrections in the [wiki-tools repository](https://github.com/StarCitizenTools/wiki-tools); don't edit it on the wiki, since a rebuild overwrites it. A missing system, wrong link, or misplaced belt is fixed there and redeployed. Page titles are stored in the file rather than looked up, so a page move doesn't self-heal until someone rebuilds.
- Both tracking categories apply in the article namespace only: `Category:System map with unknown system` (the parameter matched no known system) and `Category:Pages with a broken system map link` (a body's target page doesn't exist).

## See also

- [Module:SystemMap](https://starcitizen.tools/Module:SystemMap), implementation.
