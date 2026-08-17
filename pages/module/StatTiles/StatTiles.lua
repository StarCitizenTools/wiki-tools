require('strict')

--- @module StatTiles
--- A strip of small stat tiles: a prominent value over an overline-style label
--- per tile. The count-at-a-glance sibling of Module:MeterBar (one bounded
--- value on a track) and Module:ProgressTiles (ring gauges): reach for
--- StatTiles when the payload is a row of discrete counts rather than a scale.
---
--- Domain-agnostic: the caller passes { value, label, title? } items; items
--- without a value are dropped, so callers can pass a fixed catalog and let
--- absent stats collapse. All visuals live in the stylesheet and bind to
--- Citizen tokens, so the output is theme-aware.

local p = {}

local STYLES = 'Module:StatTiles/styles.css'

--- @class StatTilesItem
--- @field value number|string The stat value, shown prominently.
--- @field label string Short tile label (overline style; keep to a word or two).
--- @field title string|nil Full name surfaced as a hover tooltip on the tile.

--- @class StatTilesData
--- @field items StatTilesItem[]

--- Keep the items that actually carry a value and a label.
--- @param items StatTilesItem[]|nil
--- @return StatTilesItem[]
local function presentItems(items)
	local out = {}
	for _, item in ipairs(items or {}) do
		if item.value ~= nil and item.value ~= '' and item.label ~= nil then
			out[#out + 1] = item
		end
	end
	return out
end

--- Render the tile strip, or '' when no item carries a value — so callers can
--- hand the result to SectionBuilder and let the empty row collapse.
--- @param data StatTilesData
--- @return string
function p.render(data)
	data = data or {}
	local items = presentItems(data.items)
	if #items == 0 then
		return ''
	end

	local root = mw.html.create('div'):addClass('t-stat-tiles')
	for _, item in ipairs(items) do
		local tile = root:tag('div'):addClass('t-stat-tiles__cell')
		if item.title then
			tile:attr('title', item.title)
		end
		tile:tag('div'):addClass('t-stat-tiles__value'):wikitext(tostring(item.value))
		tile:tag('div'):addClass('t-stat-tiles__label'):wikitext(item.label)
	end

	local styles = mw.getCurrentFrame():extensionTag({ name = 'templatestyles', args = { src = STYLES } })
	return styles .. tostring(root)
end

-- Test-only exports. Not part of the public API.
p._internal = {
	presentItems = presentItems,
}

return p
