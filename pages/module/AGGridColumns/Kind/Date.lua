require('strict')

--- 'date' kind — an ISO (YYYY-MM-DD) date column, filtered by AG Grid's date
--- picker and sorted chronologically by the default string comparator.
--- Spec: { field, header, label, filter? }.

local Util = require('Module:AGGridColumns/Util')

local p = {}
p.type = false

--- @param spec table
--- @return table
function p.buildColDef(spec)
	return {
		field = spec.field,
		headerName = spec.header,
		-- AG Grid gates every filter on a truthy colDef.filter (isFilterAllowed), so
		-- the data type's own default filter is unreachable without one.
		filter = spec.filter or 'agDateColumnFilter',
		-- Declared rather than inferred. AG Grid derives cellDataType from
		-- rowData[0][field] alone -- no loop, no null-skipping -- so a first row whose
		-- value is missing or not strict ISO resolves it to false/'text'. That strips
		-- the date filter's comparator, leaving it to compare a string against a Date:
		-- both coerce to NaN, every comparison is false, and each condition silently
		-- matches nothing or everything with no console error.
		cellDataType = 'dateString',
	}
end

--- @param spec table
--- @param result table
--- @return string|nil
function p.buildCellValue(spec, result)
	local text = Util.toText(result[spec.label])
	if text == nil then
		return nil
	end
	-- Zero-pad an unpadded Y-M-D. The dateString type renders anything failing
	-- /^\d{4}-\d{2}-\d{2}$/ as an EMPTY cell and drops it from every date condition,
	-- so "2020-3-16" would otherwise vanish twice over. Any other shape passes
	-- through unchanged, staying visibly wrong rather than quietly invented.
	local year, month, day = text:match('^(%d%d%d%d)%-(%d%d?)%-(%d%d?)$')
	if year then
		return string.format('%s-%02d-%02d', year, tonumber(month), tonumber(day))
	end
	return text
end

return p
