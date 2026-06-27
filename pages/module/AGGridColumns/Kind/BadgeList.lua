require('strict')

--- 'badgeList' kind — a multi-value list of BadgeLua-style pills, rendered by the
--- gadget's scwBadgeList type. Domain-agnostic: each raw value is mapped to a badge
--- by a `classify` function supplied in the spec (e.g. Module:DietaryEffect's
--- gridClassify), which returns { text, variant?, icon?, href? }. This kind resolves
--- the icon file name to a URL (currentColor mask) and the page title to a link.
--- The `aggridSet` filter splits the cell into one option per badge text.
--- Spec: { field, header, label, classify, filter? }.

local aggrid = require('mw.ext.aggrid')
local Icon = require('Module:Icon')
local Util = require('Module:AGGridColumns/Util')

local p = {}
p.type = 'scwBadgeList'

--- @param spec table
--- @return table
function p.buildColDef(spec)
	return {
		field = spec.field,
		headerName = spec.header,
		type = 'scwBadgeList',
		filter = spec.filter or 'aggridSet',
		sortable = true,
	}
end

--- @param spec table
--- @param result table
--- @return table|nil  { list = { { text, variant?, iconSrc?, href? }, ... } } or nil
function p.buildCellValue(spec, result)
	local values = result[spec.label]
	if values == nil then
		return nil
	end
	-- A multi-valued SMW printout arrives as an array; a single value as a scalar.
	if type(values) ~= 'table' then
		values = { values }
	end

	local list = {}
	for _, value in ipairs(values) do
		local badge = spec.classify(Util.toText(value))
		if badge then
			local href
			if badge.href then
				local link = aggrid.link(badge.href)
				href = link and link.href
			end
			list[#list + 1] = {
				text = badge.text,
				variant = badge.variant,
				iconSrc = badge.icon and Icon.src(badge.icon) or nil,
				href = href,
			}
		end
	end

	if list[1] == nil then
		return nil
	end
	return { list = list }
end

return p
