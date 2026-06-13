require('strict')

--- 'image' kind — a (optionally linked) thumbnail cell, via the extension's
--- aggridImage column type. Spec: { field, header, imageLabel, linkLabel?,
--- filter?, sortable?, width?, suppressAutoSize? }. The cell links to the page
--- named by `linkLabel` (a page printout), if given.

local aggrid = require('mw.ext.aggrid')
local Util = require('Module:AGGridColumns/Util')

local p = {}
p.type = 'aggridImage'

--- @param spec table
--- @return table
function p.buildColDef(spec)
	return aggrid.imageColumn({
		field = spec.field,
		header = spec.header,
		sortable = spec.sortable,
		filter = spec.filter,
		width = spec.width,
		suppressAutoSize = spec.suppressAutoSize,
	})
end

--- @param spec table
--- @param result table
--- @return table|nil
function p.buildCellValue(spec, result)
	local linkTarget = spec.linkLabel and (Util.parseLink(result[spec.linkLabel])) or nil
	return Util.buildThumb(result[spec.imageLabel], linkTarget)
end

return p
