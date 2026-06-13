require('strict')

--- 'smart' kind — a plain text column rendered by the gadget's numeric-aware
--- scwSmart type (numeric-looking values sort numerically + right-align per cell).
--- Spec: { field, header, label, filter? }.

local Util = require('Module:AGGridColumns/Util')

local p = {}
p.type = 'scwSmart'

--- @param spec table
--- @return table
function p.buildColDef(spec)
	return {
		field = spec.field,
		headerName = spec.header,
		type = 'scwSmart',
		filter = spec.filter or 'agTextColumnFilter',
	}
end

--- @param spec table
--- @param result table
--- @return string|nil
function p.buildCellValue(spec, result)
	return Util.toText(result[spec.label])
end

return p
