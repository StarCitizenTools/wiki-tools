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
- Asteroid belts draw as a speckled band at their orbital position, not a disc: they're regions, not bodies, with no diameter to draw. A planet's rings draw the same way, under it alongside its moons, and count separately ("9 planets, 19 moons, 4 rings, 2 belts" for Sol). A ring orbiting a moon rather than a planet isn't drawn at all.
- A system with two stars draws both: a companion orbiting the primary hangs under it like a moon under a planet; two stars orbiting each other instead share one slot at the head of the rail. Each keeps its own entry either way.
- The body matching the current page is marked with a bolder, brighter name and a trailing dot, plus visually hidden text for screen readers. A system article marks nothing, since the map is the page's own subject rather than a location on it.
- Left to right is orbital order, not distance. Disc size is a three-tier convention (star, planet, moon), not a measurement; see [Module:SystemMap](https://starcitizen.tools/Module:SystemMap) for how sizes are mapped.
- [Module:SystemMap/systems.json](https://starcitizen.tools/Module:SystemMap/systems.json) is generated from the ARK Starmap plus hand-written corrections in the [wiki-tools repository](https://github.com/StarCitizenTools/wiki-tools). It should not be edited on the wiki, since the next rebuild overwrites it; a missing system, a wrong link, or a misplaced belt is fixed there and redeployed. Because page titles are stored in the file rather than looked up, a page move does not self-heal: the map keeps the old title and label until someone rebuilds.
- Both tracking categories apply in the article namespace only: `Category:System map with unknown system` (the parameter matched no known system) and `Category:Pages with a broken system map link` (a body's target page doesn't exist).

## See also

- [Module:SystemMap](https://starcitizen.tools/Module:SystemMap), implementation.
