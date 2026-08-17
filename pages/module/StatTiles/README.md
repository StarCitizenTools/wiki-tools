# Module:StatTiles

A strip of small stat tiles — a prominent value over an overline label per
tile. The count-at-a-glance sibling of [Module:MeterBar](../MeterBar/) (one
bounded value on a fill track) and [Module:ProgressTiles](../ProgressTiles/)
(ring gauges). First consumer: the Entity star-system infobox's astronomical
object counts.

## Usage

```lua
local statTiles = require('Module:StatTiles')

statTiles.render({
    items = {
        { value = 4, label = 'Planets' },
        { value = 12, label = 'Moons' },
        { value = 2, label = 'Belts', title = 'Asteroid belts' },
    },
})
```

Returns the TemplateStyles tag plus a `t-stat-tiles` grid (3 columns). Items
without a `value` or a `label` are dropped; when nothing remains, `render` returns `''` so a
SectionBuilder row collapses. `title` becomes a hover tooltip for abbreviated
labels.

## CSS

`styles.css` binds Citizen design tokens only (`--color-surface-0`,
`--border-subtle`, `--font-size-x-small` + `--line-height-x-small`, spacing
scale) — theme-aware for free.
