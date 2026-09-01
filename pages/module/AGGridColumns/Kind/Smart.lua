require('strict')

--- 'smart' kind — a plain text column rendered by the gadget's numeric-aware
--- scwSmart type (numeric-looking values sort numerically + right-align per cell).
--- Spec: { field, header, label, filter?, numeric? }.

local Util = require('Module:AGGridColumns/Util')

local p = {}
p.type = 'scwSmart'

--- @param spec table
--- @return table
function p.buildColDef(spec)
	local def = {
		field = spec.field,
		headerName = spec.header,
		type = 'scwSmart',
		filter = spec.filter or 'agTextColumnFilter',
	}
	-- Alignment is otherwise decided per cell from the value, which leaves a MISSING
	-- value with nothing to decide from. This says the whole column is numeric, so
	-- the gadget can right-align the empty cells too and the missing-value dashes
	-- line up with the figures above them.
	if spec.numeric then
		def.scwNumericColumn = true
	end
	return def
end

--- @param spec table
--- @param result table
--- @return string|nil
function p.buildCellValue(spec, result)
	return Util.toText(result[spec.label])
end

return p
