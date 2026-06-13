require('strict')

--- 'stackedValue' kind — a primary number over an optional muted secondary (shown
--- only when it differs), rendered by the gadget's scwStackedValue type. The raw
--- current number is kept for sort + the number filter. Generalised from
--- PledgeVehicleGrid's buildPriceStack. Spec: { field, header, curLabel, origLabel?,
--- prefix? (default '$'), width? }.

local Util = require('Module:AGGridColumns/Util')

local p = {}
p.type = 'scwStackedValue'

--- @param spec table
--- @return table
function p.buildColDef(spec)
	return {
		field = spec.field,
		headerName = spec.header,
		type = 'scwStackedValue',
		filter = 'agNumberColumnFilter',
		cellClass = 'ag-right-aligned-cell',
		headerClass = 'ag-right-aligned-header',
		width = spec.width,
		suppressAutoSize = true,
	}
end

--- @param spec table
--- @param result table
--- @return table|nil
function p.buildCellValue(spec, result)
	local current = Util.toNumber(result[spec.curLabel])
	if current == nil then
		return nil
	end
	local prefix = spec.prefix or '$'
	local lang = mw.getContentLanguage()
	local stack = { value = current, text = prefix .. lang:formatNum(current) }
	local original = spec.origLabel and Util.toNumber(result[spec.origLabel]) or nil
	if original ~= nil and original ~= current then
		stack.sub = prefix .. lang:formatNum(original)
	end
	return stack
end

return p
