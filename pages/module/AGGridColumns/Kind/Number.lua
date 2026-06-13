require('strict')

--- 'number' kind — a numeric column (real number value; the extension applies the
--- Intl `format` client-side). Spec: { field, header, label, format?, filter? }.

local Util = require('Module:AGGridColumns/Util')

local p = {}
p.type = 'numericColumn'

--- @param spec table
--- @return table
function p.buildColDef(spec)
	return {
		field = spec.field,
		headerName = spec.header,
		filter = spec.filter or 'agNumberColumnFilter',
		type = 'numericColumn',
		format = Util.cloneFormat(spec.format),
	}
end

--- @param spec table
--- @param result table
--- @return number|nil
function p.buildCellValue(spec, result)
	return Util.toNumber(result[spec.label])
end

return p
