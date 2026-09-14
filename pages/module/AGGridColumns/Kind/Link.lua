require('strict')

--- 'link' kind — a single linked page, via the extension's aggridLink column type.
--- Spec: { field, header, label, filter? }. Cell links the page target read from
--- result[label], `[[...]]` markup or a bare title alike; nil (an empty cell) when it
--- does not resolve to one.

local aggrid = require('mw.ext.aggrid')
local Util = require('Module:AGGridColumns/Util')

local p = {}
p.type = 'aggridLink'

--- @param spec table
--- @return table
function p.buildColDef(spec)
	local def = aggrid.linkColumn({ field = spec.field, header = spec.header, filter = spec.filter })
	def.sort = spec.sort
	return def
end

--- @param spec table
--- @param result table
--- @return table|string|nil
function p.buildCellValue(spec, result)
	local target, display = Util.pageTarget(result[spec.label])
	if target then
		return aggrid.link(target, display)
	end
	return nil
end

return p
