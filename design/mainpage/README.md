# Main page design aids

Not wiki pages. Everything under `pages/` mirrors something that exists on the
wiki; this does not, and the deploy skill must never be pointed at it.

## `event-photo-guides.svg`

The template for an event card photograph — the `image` key in
[Module:Mainpage/settings.json](../../pages/module/Mainpage/settings.json).

Open it in Affinity, Illustrator, Figma or Inkscape, put artwork **below** the
`#guides` group, then hide or delete that group and export at **1600 × 900**.

Anything that must always be seen — a logo, a ship, a face — goes inside the
box marked SAFE. Everything outside it is real picture that carries the
composition on one layout and is cut on the other.

## Why the safe box is only 36% of the canvas

The card crops one file to two very different boxes, both centred, both
`object-fit: cover`:

| Viewport | Box | Ratio |
| --- | --- | --- |
| ≥ 900px | 256 × 270 | 0.95, a near-square column |
| < 900px | full card width, 21:8 | 2.63, a wide strip |

A 16:9 source keeps `8/15` of its **width** in the column and `128/189` of its
**height** in the strip. What survives both is the intersection — 853 × 610 on
a 1600 × 900 canvas. That box is an exact bound, not a comfort margin: content
sitting on the line is on the last visible pixel.

## Two things not to helpfully fix

**The labels are outlines, not text, and must stay that way.** Affinity's SVG
importer ignores `paint-order`, so the dark halo that keeps labels readable
over artwork — a stroke painted *behind* the fill — lands on top instead and
turns them into black smears. And live text substitutes whatever font the
machine has, which drifts the labels away from the guides they label. Outlines
have neither problem. The halo is two copies of the same outlines, one stroked
and one plain, painted in that order.

**The safe rectangle is stroked inside its boundary, not centred on it.**
Centred, half the stroke falls outside the safe region and is clipped away by
the very crop the box exists to describe.

## If the numbers change

This file is generated output; regenerate it rather than patching paths by
hand. The 256 is `.home-event-split`'s 16rem picture column in
`Module:Mainpage/cards.css`, and the 270 is the tallest that column gets (at a
900px viewport — it is 248 at the full measure, and the tighter of the two is
what the safe area has to be solved for). The 21:8 is Module:CardLua's stacked
ratio. Change any of them and this template is wrong, silently — a guide that
lies is worse than none.
