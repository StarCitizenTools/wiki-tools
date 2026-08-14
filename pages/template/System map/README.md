# Template:System map

Renders the star, planet and moon hierarchy of one star system as a horizontal
orbit rail. Place it above <code><nowiki>{{System navplate}}</nowiki></code> at
the foot of a body or system article.

Backed by [[Module:SystemMap]].

## Usage

<pre>
{{System map|Stanton}}
{{System map|Stanton|collapsed=yes}}
</pre>

## Parameters

| Name | Label | Type | Required | Default | Description | Example |
|------|-------|------|----------|---------|-------------|---------|
| `1` | System | string | Yes |  | System name. Accepts `Stanton`, `stanton` or `Stanton system`. Any system listed in [[Module:SystemMap/systems.json]] works; an unrecognised name renders nothing and files the page in a tracking category. | `Stanton` |
| `collapsed` | Collapsed | boolean | No | `no` | Render the box closed. The map is short, so it opens by default. | `yes` |

## Behaviour

The card header carries the system name and a count of what is in it, such as
"4 planets, 12 moons, 1 belt".

Asteroid belts appear in the rail at their orbital position, drawn as a speckled
band rather than a disc. They are regions rather than bodies, and have no
meaningful diameter to draw.

A planet's rings hang under it alongside its moons, drawn as a flat speckled band
for the same reason. They are counted apart from the moons, so Sol reads
"9 planets, 19 moons, 4 rings, 2 belts". A ring that orbits a moon rather than a
planet is not drawn at all: the rail nests one level.

A system with two stars draws both, in one of two ways. Where the second star
orbits the first, it hangs under it the way a moon hangs under a planet. Where
the two orbit each other, they share a single slot at the head of the rail and
the orbit line begins at the pair rather than at either star. Each star keeps
its own entry either way, because each has its own article.

The body matching the current page is marked with a bolder, brighter name and
a trailing dot, plus a visually hidden "(current page)" for screen readers.
On a system article nothing is marked, because the map is the subject of the
page rather than a location within it.

Left to right is orbital order, not distance. Disc size is a three-tier
convention (star, planet, moon) and is not a measurement; see
[[Module:SystemMap]] for why.

## Adding a system

[[Module:SystemMap/systems.json]] is **generated** and should not be edited on the
wiki: the next rebuild overwrites it. It is built from the ARK Starmap plus a set
of hand-written corrections, both of which live in the
[wiki-tools repository](https://github.com/StarCitizenTools/wiki-tools). A missing
system, a wrong link, or a belt in the wrong orbit is fixed there and redeployed.

## Tracking categories

Both categories apply in the article namespace only, so sandboxes and module
subpages cannot fill them.

- `Category:System map with unknown system`: the first parameter did not match
  a supported system.
- `Category:Pages with a broken system map link`: tracks missing links in the
  map.
