require('strict')

--- 'valueList' kind — a multi-value list of plain-text tags (and/or page links), via
--- the extension's aggrid.list + aggridLinkList renderer. Unlike 'linkList' (page links
--- only), it passes plain-text values through unchanged, so a multi-valued text property
--- such as Company Industry/Products renders as a comma list. Its `aggridSet` filter
--- splits the cell into one checkbox per value — a row passes when ANY value is selected.
--- Spec: { field, header, label, filter? }.

local aggrid = require('mw.ext.aggrid')
local Util = require('Module:AGGridColumns/Util')

local p = {}
p.type = 'aggridLinkList'

--- @param spec table
--- @return table
function p.buildColDef(spec)
	return aggrid.listColumn({
		field = spec.field,
		header = spec.header,
		filter = spec.filter or 'aggridSet',
	})
end

--- @param spec table
--- @param result table
--- @return table|nil
function p.buildCellValue(spec, result)
	return Util.buildValueList(result[spec.label])
end

return p
