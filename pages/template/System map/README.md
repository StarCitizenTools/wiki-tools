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

| Parameter | Required | Default | Description |
| --- | --- | --- | --- |
| `1` | yes | — | System name. Accepts `Stanton`, `stanton` or `Stanton system`. Supported systems: Stanton, Pyro, Nyx. |
| `collapsed` | no | `no` | Render the box closed. The map is short, so it opens by default. |

## Behaviour

The card header carries the system name and a count of what is in it, such as
"4 planets, 12 moons, 1 belt".

Asteroid belts appear in the rail at their orbital position, drawn as a speckled
band rather than a disc — they are regions rather than bodies, and have no
meaningful diameter to draw.

The body matching the current page is marked with a ring and a trailing dot.
On a system article nothing is marked, because the map is the subject of the
page rather than a location within it.

Left to right is orbital order. Disc size is a three-tier convention (star,
planet, moon) and is not a measurement; see [[Module:SystemMap]] for why.

## Tracking categories

Both categories apply in the article namespace only, so sandboxes and module
subpages cannot fill a category that is meant to stay empty.

- `Category:System map with unknown system` — the first parameter did not match
  a supported system.
- `Category:Pages with a broken system map link` — a body in the map points at a
  page that no longer exists, usually after a page move.
