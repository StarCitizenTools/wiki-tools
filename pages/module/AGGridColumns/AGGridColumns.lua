require('strict')

--- Shared column-type core for AG Grid grids. Given a list of column specs (each
--- carrying a `kind` from the Registry), builds AG Grid columnDefs and rowData by
--- dispatching to the per-kind builders -- two generic loops, no branching. The
--- consumer owns the fetch, query, gridOptions, render, and styles.
---
--- A row field holds one fact. A kind whose cell shows several (a card's title and
--- eyebrow, a price over its original) writes each extra fact to a companion field
--- and may declare a hidden companion column for it, which is what puts that fact
--- in a CSV export.

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

--- Build AG Grid columnDefs from an ordered list of column specs. Each kind
--- forwards `sort` itself; `sortIndex`, AG Grid's precedence among initially
--- sorted columns, is set here for every kind. A kind's companion columns follow
--- its own, so an `allColumns` export lists each fact beside the column it
--- belongs to until a reader drags a column between them.
--- @param specs table[]
--- @return table[]
function p.buildColumnDefs(specs)
	local defs = {}
	local seen = {}
	-- AG Grid renames a repeated colId with a suffix and keeps going, and the later
	-- row field overwrites the earlier, so a companion named like another column
	-- would show one column's values under both headers.
	local function add(def)
		if seen[def.field] then
			error('Module:AGGridColumns: two columns use the field "' .. tostring(def.field) .. '"', 3)
		end
		seen[def.field] = true
		defs[#defs + 1] = def
	end
	for _, spec in ipairs(specs) do
		local kind = resolve(spec.kind)
		local def = kind.buildColDef(spec)
		def.sortIndex = spec.sortIndex
		add(def)
		if kind.buildCompanionColDefs then
			for _, companion in ipairs(kind.buildCompanionColDefs(spec)) do
				add(companion)
			end
		end
	end
	return defs
end

--- Build AG Grid rowData from fetched result rows and the same column specs.
--- @param results table[]
--- @param specs table[]
--- @return table[]
function p.buildRowData(results, specs)
	local rows = {}
	for _, result in ipairs(results) do
		local row = {}
		for _, spec in ipairs(specs) do
			local value, companions = resolve(spec.kind).buildCellValue(spec, result)
			row[spec.field] = value
			for field, companion in pairs(companions or {}) do
				row[field] = companion
			end
		end
		rows[#rows + 1] = row
	end
	return rows
end

return p
