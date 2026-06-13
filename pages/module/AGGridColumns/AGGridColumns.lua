require('strict')

--- Shared column-type core for AG Grid grids. Given a list of column specs (each
--- carrying a `kind` from the Registry), builds AG Grid columnDefs and rowData by
--- dispatching to the per-kind builders -- two generic loops, no branching. The
--- consumer owns the SMW fetch, query, gridOptions, render, and styles.

local Registry = require('Module:AGGridColumns/Registry')

local p = {}

--- @param colKind string
--- @return table  the kind module
local function resolve(colKind)
	local kind = Registry[colKind]
	if not kind then
		error('Module:AGGridColumns: unknown column kind "' .. tostring(colKind) .. '"', 2)
	end
	return kind
end

--- Build AG Grid columnDefs from an ordered list of column specs.
--- @param specs table[]
--- @return table[]
function p.buildColumnDefs(specs)
	local defs = {}
	for _, spec in ipairs(specs) do
		defs[#defs + 1] = resolve(spec.kind).buildColDef(spec)
	end
	return defs
end

--- Build AG Grid rowData from SMW results and the same column specs.
--- @param results table[]
--- @param specs table[]
--- @return table[]
function p.buildRowData(results, specs)
	local rows = {}
	for _, result in ipairs(results) do
		local row = {}
		for _, spec in ipairs(specs) do
			row[spec.field] = resolve(spec.kind).buildCellValue(spec, result)
		end
		rows[#rows + 1] = row
	end
	return rows
end

return p
