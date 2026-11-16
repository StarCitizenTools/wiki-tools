require('strict')

--- 'card' kind — a compact entity cell (thumbnail + eyebrow + title) rendered by
--- the gadget's scwCard type. Generalised from PledgeVehicleGrid's buildCard.
--- Spec: { field, header, titleLabel, imageLabel?, displayLabel?, filter?,
---         filterOn?, pinned?, width? | (flex?, minWidth?),
---         eyebrow? = fun(result): { text, full?, href?, icon? }|nil,
---         eyebrowHeader? }.
--- Sizing is either fixed (`width`) or flexible (`flex`, with `minWidth` as its
--- floor) so the card can absorb a grid's leftover horizontal space.
--- The eyebrow resolver is consumer-supplied (e.g. PledgeVehicleGrid maps a
--- manufacturer to its short name + brand glyph), so this kind stays generic.
--- `filterOn` ('title'|'eyebrow') picks which of the two the column filter keys
--- on; unset = the eyebrow, falling back to the title.
--- `displayLabel`, when it names a non-empty string result field, is shown as
--- the title instead of `titleLabel`'s own text; the link still targets
--- `titleLabel`. Store's `page_name` builtin is the bare page title and does
--- not carry a page's `{{DISPLAYTITLE}}`.
---
--- Row fields: `<field>` is the title, the value sort and export use.
--- `<field>Eyebrow` is the eyebrow's `full` text (else its `text`): the filter
--- option and, with `eyebrowHeader`, a hidden column of that name for the export.
--- `<field>View` holds what only the renderer reads: { titleHref, image, eyebrow,
--- eyebrowHref, eyebrowIcon }, where `eyebrow` is the short label shown.

local aggrid = require('mw.ext.aggrid')
local Util = require('Module:AGGridColumns/Util')

local p = {}
p.type = 'scwCard'

--- @param field string
--- @return string
function p.eyebrowField(field)
	return field .. 'Eyebrow'
end

--- @param field string
--- @return string
function p.viewField(field)
	return field .. 'View'
end

--- @param spec table
--- @return table
function p.buildColDef(spec)
	local def = {
		field = spec.field,
		headerName = spec.header,
		sort = spec.sort,
		type = 'scwCard',
		filter = spec.filter or 'aggridSet',
		sortable = true,
		suppressAutoSize = true,
		context = {
			eyebrowField = p.eyebrowField(spec.field),
			viewField = p.viewField(spec.field),
			filterOn = spec.filterOn,
		},
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
	-- Pinned, the card stays on screen while the data columns scroll under it, so a
	-- value several screens to the right still has a subject. Only set when asked:
	-- pinning splits AG Grid's viewport and draws a divider even with no overflow.
	if spec.pinned then
		def.pinned = spec.pinned
	end
	return def
end

--- @param spec table
--- @return table[]
function p.buildCompanionColDefs(spec)
	if not spec.eyebrowHeader then
		return {}
	end
	return {
		{ field = p.eyebrowField(spec.field), headerName = spec.eyebrowHeader, hide = true },
	}
end

--- @param spec table
--- @param result table
--- @return string|nil title
--- @return table|nil companions
function p.buildCellValue(spec, result)
	local titleTarget, titleDisplay = Util.pageTarget(result[spec.titleLabel])
	if not titleTarget then
		return nil
	end
	local titleLink = aggrid.link(titleTarget, titleDisplay)
	local displayName = spec.displayLabel and result[spec.displayLabel]
	if type(displayName) ~= 'string' or displayName == '' then
		displayName = nil
	end
	local title = displayName or (titleLink and titleLink.text) or titleDisplay or titleTarget
	local view = {
		titleHref = titleLink and titleLink.href,
		image = spec.imageLabel and Util.buildThumb(result[spec.imageLabel], titleTarget) or nil,
	}
	local companions = { [p.viewField(spec.field)] = view }
	if spec.eyebrow then
		local eb = spec.eyebrow(result)
		if eb then
			view.eyebrow = eb.text
			view.eyebrowHref = eb.href
			view.eyebrowIcon = eb.icon
			companions[p.eyebrowField(spec.field)] = eb.full or eb.text
		end
	end
	return title, companions
end

return p
