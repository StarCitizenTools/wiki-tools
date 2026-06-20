require('strict')

--- Generic browse-table component on AG Grid (Extension:AGGrid), the successor to
--- Module:DataTableLua. Same {{Data table}} contract (category + multi-line columns
--- + conditions), but virtualised rows, rich cells, and REST-served data. Reads
--- every row from SMW (mw.smw.ask), reshapes the results into AG Grid rowData +
--- columnDefs, and returns the grid.
---
--- Column model: a fixed lead thumbnail + linked name, then one column per editor
--- line. Each editor column is classified from its values as a page-link column
--- (aggridLink) or a plain column (the gadget's scwSmart type). Numeric typing is
--- NOT decided here -- scwSmart sorts numeric-looking values numerically and right-
--- aligns them per cell at render time.

local Util = require('Module:AGGridColumns/Util')
local AGGridColumns = require('Module:AGGridColumns')
local aggrid = require('mw.ext.aggrid')

local p = {}

-- SMW aliases (result-row keys) for the two fixed lead columns.
local IMAGE_ALIAS = 'Image'
local NAME_ALIAS = 'Name'

-- Fixed query tail.
local QUERY_OPTIONS = { 'mainlabel=-', 'limit=1000' }

--- @class DataGridColumn
--- @field property string
--- @field label? string
--- @field size? string    Parsed for forward-compatibility; unused (see README).
--- @field filter? boolean

--- Parse the multi-line `columns` value. Carried over from Module:DataTableLua:
--- one column per non-blank line; within a line, `;`-separated clauses where the
--- first is the SMW property and the rest are modifiers (`label=X`, `size=X`, or
--- the bare flag `filter`). Unknown clauses are ignored. Empty-property lines drop.
--- @param raw string
--- @return DataGridColumn[]
function p.parseColumns(raw)
	local columns = {}
	for line in (tostring(raw or '') .. '\n'):gmatch('([^\n]*)\n') do
		line = mw.text.trim(line)
		if line ~= '' then
			local column = {}
			local isFirst = true
			for clause in (line .. ';'):gmatch('([^;]*);') do
				clause = mw.text.trim(clause)
				if isFirst then
					column.property = clause
					isFirst = false
				elseif clause ~= '' then
					local key, value = clause:match('^(.-)%s*=%s*(.*)$')
					if key == 'label' then
						column.label = value
					elseif key == 'size' then
						column.size = value
					elseif clause == 'filter' then
						column.filter = true
					end
				end
			end
			if column.property and column.property ~= '' then
				columns[#columns + 1] = column
			end
		end
	end
	return columns
end

--- The SMW alias / result-row key for an editor column: its `label`, else the
--- property name verbatim. Always emitted as an explicit `=alias` so result rows
--- key deterministically (never relies on bare-property keying).
--- @param column DataGridColumn
--- @return string
function p.columnAlias(column)
	if column.label and column.label ~= '' then
		return column.label
	end
	return column.property
end

--- The first editor column whose alias collides with another column or with a lead
--- key. mw.smw.ask keys by alias, so a collision silently drops a column's data.
--- @param columns DataGridColumn[]
--- @return string|nil  the offending alias, or nil when all are unique
function p.duplicateAlias(columns)
	local seen = { [IMAGE_ALIAS] = true, [NAME_ALIAS] = true }
	for _, column in ipairs(columns) do
		local alias = p.columnAlias(column)
		if seen[alias] then
			return alias
		end
		seen[alias] = true
	end
	return nil
end

--- Build the mw.smw.ask query: a main-namespace restriction, an optional category
--- condition, and optional raw conditions; then the two lead printouts, one aliased
--- printout per editor column, and the fixed options. At least one of `category` or
--- `conditions` should be non-empty (`main` enforces this) — a bare `[[:+]]` would
--- otherwise match the entire main namespace.
--- @param category string
--- @param columns DataGridColumn[]
--- @param conditions? string
--- @return string[]
function p.buildQuery(category, columns, conditions)
	-- `[[:+]]` restricts to the main namespace so File/Category pages don't leak in
	-- as rows.
	local condition = '[[:+]]'
	if category and category ~= '' then
		condition = condition .. ' [[Category:' .. category .. ']]'
	end
	if conditions and conditions ~= '' then
		condition = condition .. ' ' .. conditions
	end
	local query = { condition, '?Page Image=' .. IMAGE_ALIAS, '?=' .. NAME_ALIAS }
	for _, column in ipairs(columns) do
		query[#query + 1] = '?' .. column.property .. '=' .. p.columnAlias(column)
	end
	for _, option in ipairs(QUERY_OPTIONS) do
		query[#query + 1] = option
	end
	return query
end

--- Build the AGGridColumns column specs for this query: the fixed lead thumbnail +
--- linked name, then one spec per editor column (classified link vs smart-plain).
--- @param results table[]
--- @param columns DataGridColumn[]
--- @return table[]
local function buildSpecs(results, columns)
	local specs = {
		{
			kind = 'image',
			field = 'thumb',
			header = '',
			imageLabel = IMAGE_ALIAS,
			linkLabel = NAME_ALIAS,
			sortable = false,
			filter = false,
			width = 72,
			suppressAutoSize = true,
		},
		{ kind = 'link', field = 'name', header = NAME_ALIAS, label = NAME_ALIAS, filter = 'agTextColumnFilter' },
	}
	for i, column in ipairs(columns) do
		local alias = p.columnAlias(column)
		local values = {}
		for _, result in ipairs(results) do
			if result[alias] ~= nil then
				values[#values + 1] = result[alias]
			end
		end
		local class = Util.classifyColumn(values)
		specs[#specs + 1] = {
			kind = (class == 'link') and 'link' or 'smart',
			field = 'c' .. i,
			header = (column.label and column.label ~= '') and column.label or column.property,
			label = alias,
			filter = column.filter and 'aggridSet' or 'agTextColumnFilter',
		}
	end
	return specs
end

--- Entry point for {{Data table}}. Reads `category`, `columns`, `conditions` from
--- the parent frame, builds the grid, and returns it preceded by the styles load.
--- @param frame mw.frame
--- @return string
function p.main(frame)
	local getArgs = require('Module:Arguments').getArgs
	local args = getArgs(frame)

	local category = mw.text.trim(args.category or '')
	local conditions = mw.text.trim(args.conditions or '')
	if category == '' and conditions == '' then
		return '<strong class="error">Module:DataGrid: provide a "category" or "conditions" to query.</strong>'
	end

	local columns = p.parseColumns(args.columns)
	if #columns == 0 then
		return '<strong class="error">Module:DataGrid: no columns defined.</strong>'
	end

	local duplicate = p.duplicateAlias(columns)
	if duplicate then
		return '<strong class="error">Module:DataGrid: duplicate column "' .. duplicate .. '".</strong>'
	end

	-- A query that matches nothing legitimately returns no rows; coerce non-table to
	-- {} so the grid renders empty (AG Grid shows its own "no rows" overlay) rather
	-- than erroring.
	local results = mw.smw.ask(p.buildQuery(category, columns, conditions))
	if type(results) ~= 'table' then
		results = {}
	end

	local specs = buildSpecs(results, columns)
	local gridOptions = {
		columnDefs = AGGridColumns.buildColumnDefs(specs),
		rowData = AGGridColumns.buildRowData(results, specs),
		quickSearch = true,
		pagination = false,
		rowHeight = 48,
		autoSizeStrategy = { type = 'fitCellContents' },
		defaultColDef = { sortable = true, resizable = true },
	}

	local styles = frame:extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:DataGrid/styles.css' },
	})

	return styles .. '<div class="t-datagrid">' .. aggrid.render(gridOptions) .. '</div>'
end

return p
