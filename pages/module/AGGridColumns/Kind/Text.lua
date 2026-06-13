require('strict')

--- 'text' kind — a plain text column (no custom type; AG Grid's default cell).
--- Spec: { field, header, label, filter? }.

local Util = require('Module:AGGridColumns/Util')

local p = {}
p.type = false

--- @param spec table
--- @return table
function p.buildColDef(spec)
	return { field = spec.field, headerName = spec.header, filter = spec.filter or 'agTextColumnFilter' }
end

--- @param spec table
--- @param result table
--- @return string|nil
function p.buildCellValue(spec, result)
	return Util.toText(result[spec.label])
end

return p
