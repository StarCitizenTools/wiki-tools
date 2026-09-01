require('strict')

--- 'card' kind — a compact entity cell (thumbnail + eyebrow + title) rendered by
--- the gadget's scwEntityCard type. Generalised from PledgeVehicleGrid's buildCard.
--- Spec: { field, header, titleLabel, imageLabel?, filter?, filterOn?, pinned?,
---         width? | (flex?, minWidth?),
---         eyebrow? = fun(result): { text, full?, href?, icon? }|nil }.
--- Sizing is either fixed (`width`) or flexible (`flex`, with `minWidth` as its
--- floor) so the card can absorb a grid's leftover horizontal space.
--- The eyebrow resolver is consumer-supplied (e.g. PledgeVehicleGrid maps a
--- manufacturer to its short name + brand glyph), so this kind stays generic.
--- `filterOn` ('title'|'eyebrow') tells the gadget which packed field the filter
--- keys on; unset = the gadget default (eyebrow, falling back to title).

local aggrid = require('mw.ext.aggrid')
local Util = require('Module:AGGridColumns/Util')

local p = {}
p.type = 'scwEntityCard'

--- @param spec table
--- @return table
function p.buildColDef(spec)
	local def = {
		field = spec.field,
		headerName = spec.header,
		type = 'scwEntityCard',
		filter = spec.filter or 'aggridSet',
		sortable = true,
		suppressAutoSize = true,
	}
	-- Sizing: a fixed `width`, or `flex` (with `minWidth` as its floor) to absorb
	-- the grid's leftover horizontal space. flex and width are mutually exclusive
	-- in AG Grid, so emit only one.
	if spec.flex then
		def.flex = spec.flex
		def.minWidth = spec.minWidth
	else
		def.width = spec.width
	end
	-- Which packed field the filter keys on. The gadget's scwEntityCard
	-- filterValueGetter reads this; unset = its default (eyebrow → title), so
	-- PledgeVehicleGrid (no filterOn) is unaffected.
	if spec.filterOn then
		def.scwCardFilterOn = spec.filterOn
	end
	-- Pinned, the card stays on screen while the data columns scroll under it, so a
	-- value several screens to the right still has a subject. Only set when asked:
	-- pinning splits AG Grid's viewport and draws a divider even with no overflow.
	if spec.pinned then
		def.pinned = spec.pinned
	end
	return def
end

--- @param spec table
--- @param result table
--- @return table|nil
function p.buildCellValue(spec, result)
	local titleTarget, titleDisplay = Util.parseLink(result[spec.titleLabel])
	if not titleTarget then
		return nil
	end
	local titleLink = aggrid.link(titleTarget, titleDisplay)
	local card = {
		title = (titleLink and titleLink.text) or titleDisplay or titleTarget,
		titleHref = titleLink and titleLink.href,
		image = spec.imageLabel and Util.buildThumb(result[spec.imageLabel], titleTarget) or nil,
	}
	if spec.eyebrow then
		local eb = spec.eyebrow(result)
		if eb then
			card.eyebrow = eb.text
			card.eyebrowFull = eb.full
			card.eyebrowHref = eb.href
			card.eyebrowIcon = eb.icon
		end
	end
	return card
end

return p
