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
band rather than a disc — they are regions rather than bodies, and have no
meaningful diameter to draw.

A planet's rings hang under it alongside its moons, drawn as a flat speckled band
for the same reason. They are counted apart from the moons, so Sol reads
"9 planets, 19 moons, 4 rings, 2 belts". A ring that orbits a moon rather than a
planet is not drawn at all: the rail nests one level.

The body matching the current page is marked with a bolder, brighter name and
a trailing dot, plus a visually hidden "(current page)" for screen readers.
On a system article nothing is marked, because the map is the subject of the
page rather than a location within it.

Left to right is orbital order. Disc size is a three-tier convention (star,
planet, moon) and is not a measurement; see [[Module:SystemMap]] for why.

## Adding a system

[[Module:SystemMap/systems.json]] is **generated** and should not be edited on the
wiki: the next regeneration overwrites it. It is built from the ARK Starmap mirror
plus a hand-owned overlay carrying the corrections the starmap cannot supply, such
as where an asteroid belt sits relative to the planets. Both live in the
[wiki-tools repository](https://github.com/StarCitizenTools/wiki-tools).

## Tracking categories

Both categories apply in the article namespace only, so sandboxes and module
subpages cannot fill a category that is meant to stay empty.

- `Category:System map with unknown system` — the first parameter did not match
  a supported system.
- `Category:Pages with a broken system map link` — a body in the map points at a
  page that no longer exists, usually after a page move.
