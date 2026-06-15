require('strict')

--- @module ProgressTiles
--- A reusable row of square ring-gauge tiles. Each tile draws a value as a
--- progress arc around a square frame (scaled against `max`), with the value in
--- the centre and an optional label below. Domain-agnostic: it knows nothing
--- about what the numbers mean — callers pass the value, label, and arc colour
--- per tile, so it serves armour resistances, ship stats, ratings, or any set of
--- related values.
---
--- The renderer is intentionally "dumb" (it just draws what it's given). The
--- optional `heatmap` helper maps a value to a Citizen status token
--- (error/warning/success) for callers that want a weak->strong colour signal;
--- others pass a fixed accent or per-tile colours. The arc (a conic-gradient) is
--- passed as a CSS custom property the stylesheet consumes; the value text is
--- always --color-base. All visuals use Citizen design tokens, so the output is
--- theme-aware.

local p = {}

local DEFAULT_MAX = 100
local TRACK = 'var(--color-surface-3)'
local DEFAULT_COLOR = 'var(--color-progressive)'
local STYLES = 'Module:ProgressTiles/styles.css'

--- @class ProgressTile
--- @field value number The numeric value (drives the fill and, by default, the displayed text).
--- @field label string|nil Short label shown below the tile. Optional.
--- @field title string|nil Full name surfaced as a hover tooltip. Optional.
--- @field color string|nil CSS colour for the arc (a token string). Defaults to a neutral accent. The value text is always --color-base for legibility.
--- @field text string|nil Overrides the displayed text (e.g. "40%"). Defaults to the value.

--- @class ProgressTilesData
--- @field tiles ProgressTile[] The tiles to render, left to right.
--- @field max number|nil Fill denominator shared by every tile. Defaults to 100.

--- Clamp a value/max ratio to a 0-100 fill percentage. A non-positive max
--- yields 0 (nothing to fill against).
---
--- @param value number
--- @param max number
--- @return number percentage in [0, 100]
local function clampPct(value, max)
	if max <= 0 then
		return 0
	end
	local pct = value / max * 100
	if pct < 0 then
		return 0
	end
	if pct > 100 then
		return 100
	end
	return pct
end

--- Map a value to a Citizen status colour token: weak -> error, mid -> warning,
--- strong -> success. Banding is by fraction of `max` (default thirds); pass
--- `thresholds` = { weakMax, midMax } as fractions to retune (e.g. {0.2, 0.45}).
---
--- @param value number
--- @param max number|nil Defaults to 100.
--- @param thresholds number[]|nil { weakMax, midMax } as fractions of max.
--- @return string CSS colour token
function p.heatmap(value, max, thresholds)
	max = tonumber(max) or DEFAULT_MAX
	local ratio = max > 0 and (tonumber(value) or 0) / max or 0
	local weakMax = thresholds and thresholds[1] or (1 / 3)
	local midMax = thresholds and thresholds[2] or (2 / 3)
	if ratio <= weakMax then
		return 'var(--color-error)'
	end
	if ratio <= midMax then
		return 'var(--color-warning)'
	end
	return 'var(--color-success)'
end

--- Render a row of progress tiles. Returns the TemplateStyles tag plus the HTML,
--- ready to drop into any wikitext or infobox section content.
---
--- @param data ProgressTilesData
--- @return string
function p.render(data)
	data = data or {}
	local tiles = data.tiles or {}
	local max = tonumber(data.max) or DEFAULT_MAX

	local root = mw.html.create('div'):addClass('t-progress-tiles')
	for _, tile in ipairs(tiles) do
		local value = tonumber(tile.value) or 0
		local color = tile.color or DEFAULT_COLOR
		local pct = clampPct(value, max)

		local cell = root:tag('div'):addClass('t-progress-tiles__cell')
		local gauge = cell:tag('div'):addClass('t-progress-tiles__gauge')
		if tile.title then
			gauge:attr('title', tile.title)
		end
		gauge
			:tag('div')
			:addClass('t-progress-tiles__ring')
			:css('--t-progress-tiles-ring', 'conic-gradient(' .. color .. ' ' .. pct .. '%, ' .. TRACK .. ' 0)')
			:tag('div')
			:addClass('t-progress-tiles__center')
		gauge:tag('span'):addClass('t-progress-tiles__value'):wikitext(tile.text or tostring(value))

		if tile.label then
			cell:tag('span'):addClass('t-progress-tiles__label'):wikitext(tile.label)
		end
	end

	local styles = mw.getCurrentFrame():extensionTag({ name = 'templatestyles', args = { src = STYLES } })
	return styles .. tostring(root)
end

-- Test-only exports. Not part of the public API.
p._internal = {
	clampPct = clampPct,
}

return p
