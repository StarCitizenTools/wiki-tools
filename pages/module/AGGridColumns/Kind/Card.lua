require('strict')

--- 'card' kind — a compact entity cell (thumbnail + eyebrow + title) rendered by
--- the gadget's scwEntityCard type. Generalised from PledgeVehicleGrid's buildCard.
--- Spec: { field, header, titleLabel, imageLabel?, filter?, filterOn?, width?,
---         eyebrow? = fun(result): { text, full?, href?, icon? }|nil }.
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
		width = spec.width,
		suppressAutoSize = true,
	}
	-- Which packed field the filter keys on. The gadget's scwEntityCard
	-- filterValueGetter reads this; unset = its default (eyebrow → title), so
	-- PledgeVehicleGrid (no filterOn) is unaffected.
	if spec.filterOn then
		def.scwCardFilterOn = spec.filterOn
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
