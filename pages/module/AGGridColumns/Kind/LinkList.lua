require('strict')

--- 'linkList' kind — a comma-separated list of linked pages, via the extension's
--- aggridLinkList column type. Spec: { field, header, label, filter? }.

local aggrid = require('mw.ext.aggrid')
local Util = require('Module:AGGridColumns/Util')

local p = {}
p.type = 'aggridLinkList'

--- @param spec table
--- @return table
function p.buildColDef(spec)
	return aggrid.linkListColumn({
		field = spec.field,
		header = spec.header,
		filter = spec.filter or 'agTextColumnFilter',
	})
end

--- @param spec table
--- @param result table
--- @return table|nil
function p.buildCellValue(spec, result)
	return Util.buildLinkList(result[spec.label])
end

return p
