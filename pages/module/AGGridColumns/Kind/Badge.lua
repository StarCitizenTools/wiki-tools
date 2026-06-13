require('strict')

--- 'badge' kind — a BadgeLua-style pill rendered by the gadget's scwBadge type.
--- Generalised from PledgeVehicleGrid's buildBadge. Spec: { field, header, label,
--- variants? = { value -> 'success'|'warning'|'error' }, filter?, width? }.

local Util = require('Module:AGGridColumns/Util')

local p = {}
p.type = 'scwBadge'

--- @param spec table
--- @return table
function p.buildColDef(spec)
	return {
		field = spec.field,
		headerName = spec.header,
		type = 'scwBadge',
		filter = spec.filter or 'aggridSet',
		sortable = true,
		width = spec.width,
		suppressAutoSize = true,
	}
end

--- @param spec table
--- @param result table
--- @return table|nil
function p.buildCellValue(spec, result)
	local text = Util.toText(result[spec.label])
	if text == nil or text == '' then
		return nil
	end
	return { text = text, variant = spec.variants and spec.variants[text] }
end

return p
