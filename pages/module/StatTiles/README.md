# Module:StatTiles

A strip of small stat tiles, a prominent value over an overline-style label per tile. The count-at-a-glance sibling of [Module:MeterBar](https://starcitizen.tools/Module:MeterBar) (one bounded value on a fill track) and [Module:ProgressTiles](https://starcitizen.tools/Module:ProgressTiles) (ring gauges): reach for this when the payload is a row of discrete counts rather than a scale.

Required by [Module:Entity/Location/StarSystem](https://starcitizen.tools/Module:Entity/Location/StarSystem); not invoked from templates.

## For module editors

### API

`p.render(data)` returns `<templatestyles>` + a `t-stat-tiles` grid (fixed 3 columns), or `''` when no item survives filtering, so a `SectionBuilder` row collapses.

| Field | Type | Description |
|---|---|---|
| `items` | `StatTilesItem[]` | `{ value, label, title? }`. An item without a `value` or a `label` is dropped. `title` is a hover tooltip, for when `label` is abbreviated. |

```lua
local statTiles = require( 'Module:StatTiles' )
statTiles.render( {
	items = {
		{ value = 4, label = 'Planets' },
		{ value = 12, label = 'Moons' },
		{ value = 2, label = 'Belts', title = 'Asteroid belts' },
	},
} )
```

### Styles

[Module:StatTiles/styles.css](https://starcitizen.tools/Module:StatTiles/styles.css) binds Citizen design tokens (`--color-surface-0`, `--border-subtle`, `--font-size-x-small`, spacing scale), theme-aware for free. Value and label deliberately use a fixed `1.25` line-height rather than a paired token: labels come from a fixed catalog and never wrap, so the token line-heights (sized for running text) would leave the tile visibly slack.
