require('strict')

--- 'link' kind — a single linked page, via the extension's aggridLink column type.
--- Spec: { field, header, label, filter? }. Cell links the page parsed from
--- result[label]; falls back to plain decoded text when it is not a page link.

local aggrid = require('mw.ext.aggrid')
local Util = require('Module:AGGridColumns/Util')

local p = {}
p.type = 'aggridLink'

--- @param spec table
--- @return table
function p.buildColDef(spec)
	return aggrid.linkColumn({ field = spec.field, header = spec.header, filter = spec.filter })
end

--- @param spec table
--- @param result table
--- @return table|string|nil
function p.buildCellValue(spec, result)
	local value = result[spec.label]
	local target, display = Util.parseLink(value)
	if target then
		return aggrid.link(target, display)
	end
	return Util.toText(value)
end

return p
