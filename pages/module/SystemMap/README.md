# Module:SystemMap

Backs <code><nowiki>{{System map}}</nowiki></code>, which draws one star system
as a horizontal orbit rail: the star or stars, where there are any, the planets
and belts orbiting them, and the moons and rings orbiting those.
[[Template:System map]] covers the parameters, the tracking categories and what
the rail draws.

The work is split across subpages. [[Module:SystemMap/Data]] resolves the system
name, classifies each body and builds the model;
[[Module:SystemMap/Renderer]] turns that model into the rail;
[[Module:SystemMap/styles.css]] styles it; and
[[Module:SystemMap/systems.json]] holds the bodies of every system in orbital
order.

## Reading the map

Left to right is **orbital order, not distance**. The space between two bodies
says nothing about how far apart they are; only the sequence is meaningful.

**Disc size is a three-tier convention and carries no measurement**, so please
do not "correct" it. Within each tier (star, planet, moon) sizes are mapped
logarithmically between the smallest and largest body of that tier in the whole
starmap, not just the ones on the map you are looking at, so a body is drawn the
same size on every page. The mapping preserves rank without being proportional:
Pyro V is 6.6 times Hurston's diameter and renders about 1.3 times its width. A
proportional rail is not an option, since it would put the smallest planet at
well under a tenth of a pixel.

What a body is comes from the colour of its disc instead, and is never printed
as text: a gas giant reads as a banded amber disc and an ice giant as a banded
cyan one, so the two are told apart by colour rather than by size. A body whose
type the module does not recognise falls back to a plain grey disc.

Belts and rings sit outside the scale entirely and are drawn at a fixed size.
Each is a region rather than a body, and has no diameter to draw.

## Adding a system, or fixing a body

**Do not edit [[Module:SystemMap/systems.json]] on the wiki.** It is generated
from the ARK Starmap plus a set of hand-written corrections, and an edit made
here is lost the next time anybody rebuilds it.

Everything that feeds it lives in the
[wiki-tools repository](https://github.com/StarCitizenTools/wiki-tools). A
system that is missing, a body linking to the wrong article, a moon filed under
the wrong planet, a belt sitting in the wrong orbit: all of it is fixed there,
rebuilt, and deployed.

Page titles are stored in the file rather than looked up, so a page move does
not self-heal. The map keeps pointing at the old title and printing the old
label until someone rebuilds; the link itself survives on the redirect the move
leaves behind, and goes red only once that redirect is deleted or suppressed.
Red links collect in `Category:Pages with a broken system map link`, which is
mostly a backlog of bodies nobody has written up yet.
