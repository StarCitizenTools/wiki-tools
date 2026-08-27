# Main page design aids

Not wiki pages. Everything under `pages/` mirrors something that exists on the
wiki; this does not, and the deploy skill must never be pointed at it.

| File | For |
| --- | --- |
| `event-photo-guides.svg` | The event card's `image` key — an ordinary photograph |

Open it in Illustrator, Figma or Inkscape, put artwork **below** the `#guides`
group, then hide or delete that group and export at 1600 × 900.

There is deliberately no template for the card's other design, the `banner`
key. Those files are a closed set — the twenty-five 1080×83 strips already in
`Category:Main page banner images`, drawn for the old full-width main page —
and nobody authors new ones. What matters when picking one is not a canvas but
a check: the card shows a centred slice, 66% of the file at its widest and 27%
at its narrowest, so a logo out near either end is lost on a phone.

## Why the template throws away 64% of the canvas

The card crops one file to two very different boxes, both centred, both
`object-fit: cover`:

| Viewport | Box | Ratio |
| --- | --- | --- |
| ≥ 900px | 256 × 270 | 0.95, a near-square column |
| < 900px | full card width, 21:8 | 2.63, a wide strip |

A 16:9 source keeps `8/15` of its **width** in the column and `128/189` of its
**height** in the strip. What survives both is the intersection — 853 × 610 on
a 1600 × 900 canvas, which is 36% of it. That box is an exact bound, not a
comfort margin: content sitting on the line is on the last visible pixel.

The 256 comes from `.home-event-split`'s 16rem picture column in
`Module:Mainpage/cards.css`; the 270 is the tallest that column gets (at a
900px viewport — it is 248 at the full measure, and the tighter of the two is
what the safe area has to be solved for).

## Keeping it honest

The template encodes measurements taken off the live card. If the picture
column or the stacked ratio ever changes, it is wrong and silently so — a
template that lies is worse than none. Re-measure before trusting it after any
change to `Module:Mainpage/cards.css` or `Module:CardLua/styles.css`.
