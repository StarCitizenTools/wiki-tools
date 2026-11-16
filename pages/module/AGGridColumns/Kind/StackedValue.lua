require('strict')

--- 'stackedValue' kind — a primary number over an optional muted secondary (shown
--- only when it differs), rendered by the gadget's scwStacked type. Generalised
--- from PledgeVehicleGrid's buildPriceStack. Spec: { field, header, curLabel,
--- origLabel?, origHeader?, prefix? (default '$'), width? }.
---
--- Row fields: `<field>` is the current number, which sort, the number filter and
--- export use. `<field>Original` is the original number whenever one is stored,
--- equal or not; with `origHeader` it is also a hidden column of that name for the
--- export. Both are formatted client-side by the same `format` spec, so the second
--- line reads like the first.

local Util = require('Module:AGGridColumns/Util')

local p = {}
p.type = 'scwStacked'

--- @param field string
--- @return string
function p.originalField(field)
	return field .. 'Original'
end

--- A fresh table per call: Scribunto's PHP serializer rejects one table referenced
--- by two colDefs.
--- @param spec table
--- @return table
local function numberFormat(spec)
	return { style = 'number', prefix = spec.prefix or '$' }
end

--- @param spec table
--- @return table
function p.buildColDef(spec)
	return Util.withCsvHeader({
		field = spec.field,
		headerName = spec.header,
		sort = spec.sort,
		type = 'scwStacked',
		filter = 'agNumberColumnFilter',
		cellClass = 'ag-right-aligned-cell',
		headerClass = 'ag-right-aligned-header',
		width = spec.width,
		suppressAutoSize = true,
		format = numberFormat(spec),
		context = { originalField = spec.origLabel and p.originalField(spec.field) or nil },
	})
end

--- @param spec table
--- @return table[]
function p.buildCompanionColDefs(spec)
	if not (spec.origLabel and spec.origHeader) then
		return {}
	end
	return {
		Util.withCsvHeader({
			field = p.originalField(spec.field),
			headerName = spec.origHeader,
			hide = true,
			type = 'numericColumn',
			format = numberFormat(spec),
		}),
	}
end

--- @param spec table
--- @param result table
--- @return number|nil current
--- @return table|nil companions
function p.buildCellValue(spec, result)
	local current = Util.toNumber(result[spec.curLabel])
	if not spec.origLabel then
		return current
	end
	return current, { [p.originalField(spec.field)] = Util.toNumber(result[spec.origLabel]) }
end

return p
