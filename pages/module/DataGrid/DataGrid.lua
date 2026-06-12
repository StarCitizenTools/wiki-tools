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

local Util = require('Module:DataGrid/Util')
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

--- The synthetic, AG-Grid-safe field id for the i-th editor column. Property names
--- contain spaces/parens, so they are unsafe as AG Grid `field` keys.
--- @param index integer
--- @return string
local function columnField(index)
	return 'c' .. index
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

--- Build the mw.smw.ask query: main-namespace + category condition (plus optional
--- raw conditions), the two lead printouts, one aliased printout per editor column,
--- then the fixed options.
--- @param category string
--- @param columns DataGridColumn[]
--- @param conditions? string
--- @return string[]
function p.buildQuery(category, columns, conditions)
	-- `[[:+]]` restricts to the main namespace so File/Category pages tagged into
	-- the category don't leak in as rows.
	local condition = '[[:+]] [[Category:' .. category .. ']]'
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

--- Classify each editor column ('link' | 'plain') from its non-empty values.
--- @param results table[]
--- @param columns DataGridColumn[]
--- @return string[]
local function classifyColumns(results, columns)
	local classes = {}
	for i, column in ipairs(columns) do
		local alias = p.columnAlias(column)
		local values = {}
		for _, result in ipairs(results) do
			local v = result[alias]
			if v ~= nil then
				values[#values + 1] = v
			end
		end
		classes[i] = Util.classifyColumn(values)
	end
	return classes
end

--- Build AG Grid rowData. Lead: linked thumbnail + linked name (both link to the
--- row's own page). Editor columns: link cells for 'link' columns, decoded text
--- for 'plain' columns.
--- @param results table[]
--- @param columns DataGridColumn[]
--- @param classes string[]
--- @return table[]
local function buildRowData(results, columns, classes)
	local rows = {}
	for _, result in ipairs(results) do
		local pageTitle, pageDisplay = Util.parseLink(result[NAME_ALIAS])
		local row = {
			thumb = Util.buildThumb(result[IMAGE_ALIAS], pageTitle),
			name = pageTitle and aggrid.link(pageTitle, pageDisplay) or nil,
		}
		for i, column in ipairs(columns) do
			local field = columnField(i)
			local value = result[p.columnAlias(column)]
			if classes[i] == 'link' then
				local target, display = Util.parseLink(value)
				row[field] = target and aggrid.link(target, display) or Util.toText(value)
			else
				row[field] = Util.toText(value)
			end
		end
		rows[#rows + 1] = row
	end
	return rows
end

--- Build AG Grid columnDefs: a blank-header linked thumbnail (aggridImage), a
--- linked name (aggridLink), then one def per editor column. Plain columns get the
--- scwSmart gadget type (numeric-aware sort + per-cell right-align); link columns
--- get aggridLink. A `filter`-flagged column gets the checkbox set filter; others
--- get the text filter.
--- @param columns DataGridColumn[]
--- @param classes string[]
--- @return table[]
local function buildColumnDefs(columns, classes)
	local defs = {
		aggrid.imageColumn({
			field = 'thumb',
			header = '',
			sortable = false,
			filter = false,
			width = 72,
			suppressAutoSize = true,
		}),
		aggrid.linkColumn({
			field = 'name',
			header = NAME_ALIAS,
			filter = 'agTextColumnFilter',
		}),
	}
	for i, column in ipairs(columns) do
		local header = (column.label and column.label ~= '') and column.label or column.property
		local filter = column.filter and 'aggridSet' or 'agTextColumnFilter'
		local def
		if classes[i] == 'link' then
			def = aggrid.linkColumn({ field = columnField(i), header = header, filter = filter })
		else
			def = {
				field = columnField(i),
				headerName = header,
				type = 'scwSmart',
				filter = filter,
			}
		end
		defs[#defs + 1] = def
	end
	return defs
end

--- Entry point for {{Data table}}. Reads `category`, `columns`, `conditions` from
--- the parent frame, builds the grid, and returns it preceded by the styles load.
--- @param frame mw.frame
--- @return string
function p.main(frame)
	local getArgs = require('Module:Arguments').getArgs
	local args = getArgs(frame)

	local category = mw.text.trim(args.category or '')
	if category == '' then
		return '<strong class="error">Module:DataGrid: missing required parameter "category".</strong>'
	end

	local columns = p.parseColumns(args.columns)
	if #columns == 0 then
		return '<strong class="error">Module:DataGrid: no columns defined.</strong>'
	end

	local duplicate = p.duplicateAlias(columns)
	if duplicate then
		return '<strong class="error">Module:DataGrid: duplicate column "' .. duplicate .. '".</strong>'
	end

	local conditions = mw.text.trim(args.conditions or '')
	-- An empty category legitimately returns no rows; coerce non-table to {} so the
	-- grid renders empty (AG Grid shows its own "no rows" overlay) rather than erroring.
	local results = mw.smw.ask(p.buildQuery(category, columns, conditions))
	if type(results) ~= 'table' then
		results = {}
	end

	local classes = classifyColumns(results, columns)
	local gridOptions = {
		columnDefs = buildColumnDefs(columns, classes),
		rowData = buildRowData(results, columns, classes),
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
