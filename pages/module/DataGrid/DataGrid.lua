require('strict')

--- Generic browse-table component on AG Grid (Extension:AGGrid), the successor to
--- Module:DataTableLua. Same {{Data table}} contract (category + multi-line columns
--- + conditions), but virtualised rows, rich cells, and REST-served data. Reads
--- every row from SMW (mw.smw.ask), reshapes the results into AG Grid rowData +
--- columnDefs, and returns the grid.
---
--- Column model: a single card lead (thumbnail + linked name, optional eyebrow
--- from a column flagged `eyebrow`), then one column per editor line. An eyebrow
--- column feeds the lead card and is not emitted as its own column. Each remaining
--- editor column is classified from its values as a multi-value list column
--- (aggridLinkList, when any row holds several values), a page-link column (aggridLink),
--- or a plain column (the gadget's scwSmart type). A `filter`-flagged list column gets
--- the extension's set filter, which splits each cell into one option per value. Numeric
--- typing is NOT decided here -- scwSmart sorts numeric-looking values numerically and
--- right-aligns them per cell at render time.

local Util = require('Module:AGGridColumns/Util')
local AGGridColumns = require('Module:AGGridColumns')
local aggrid = require('mw.ext.aggrid')

local p = {}

-- SMW aliases (result-row keys) for the two fixed lead columns.
local IMAGE_ALIAS = 'Image'
local NAME_ALIAS = 'Name'

-- Fixed query tail.
local QUERY_OPTIONS = { 'mainlabel=-', 'limit=1000' }

-- Lead card geometry. The lead flexes to absorb any leftover horizontal space
-- (the data columns auto-size to content, so short tables would otherwise leave a
-- ragged gap on the right); LEAD_WIDTH is its floor, not a fixed width. Rows are
-- compact when the card is just thumbnail + name, taller when an eyebrow adds a
-- second line.
local LEAD_WIDTH = 260
local ROW_HEIGHT = 48
local EYEBROW_ROW_HEIGHT = 60

--- @class DataGridColumn
--- @field property string
--- @field label? string
--- @field size? string    Parsed for forward-compatibility; unused (see README).
--- @field filter? boolean
--- @field eyebrow? boolean Promote this column into the lead card's eyebrow.
--- @field kind? string  Override the auto-classified column kind (e.g. `effect`).

--- Parse the multi-line `columns` value. Carried over from Module:DataTableLua:
--- one column per non-blank line; within a line, `;`-separated clauses where the
--- first is the SMW property and the rest are modifiers (`label=X`, `size=X`, or
--- the bare flags `filter` / `eyebrow`, or `kind=X`). `eyebrow` promotes the column into the
--- lead card instead of rendering it as its own column. Unknown clauses are
--- ignored. Empty-property lines drop.
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
					elseif key == 'kind' then
						column.kind = value
					elseif clause == 'filter' then
						column.filter = true
					elseif clause == 'eyebrow' then
						column.eyebrow = true
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

--- A generic eyebrow resolver for the lead card, closed over the eyebrow column's
--- result-row key. Returns the value as `{ text, full, href? }`: a linked label
--- when the value is a single page printout, else plain text. No icon — the brand
--- glyph is PledgeVehicleGrid-specific. Returns nil when the value is empty.
--- @param alias string
--- @return fun(result: table): table|nil
local function eyebrowResolver(alias)
	return function(result)
		local value = result[alias]
		local target, display = Util.parseLink(value)
		if target then
			local link = aggrid.link(target, display)
			return {
				text = (link and link.text) or display or target,
				full = display or target,
				href = link and link.href,
			}
		end
		local text = Util.toText(value)
		if text and text ~= '' then
			return { text = text, full = text }
		end
		return nil
	end
end

--- Build the AGGridColumns column specs for this query: a single card lead
--- (thumbnail + linked name, optional eyebrow), then one spec per editor column
--- (classified link vs multi-value list vs smart-plain). A column flagged
--- `eyebrow` feeds the lead card and is not emitted as its own column.
--- @param results table[]
--- @param columns DataGridColumn[]
--- @param eyebrowColumn DataGridColumn|nil
--- @return table[]
local function buildSpecs(results, columns, eyebrowColumn)
	local leadSpec = {
		kind = 'card',
		field = 'lead',
		header = NAME_ALIAS,
		titleLabel = NAME_ALIAS,
		imageLabel = IMAGE_ALIAS,
		filterOn = 'title',
		filter = 'agTextColumnFilter',
		-- Grow to fill horizontal slack left by the content-sized data columns, so
		-- rows span the full container instead of ending short. LEAD_WIDTH floors it;
		-- when the columns already overflow there is no slack and it sits at the floor.
		flex = 1,
		minWidth = LEAD_WIDTH,
	}
	if eyebrowColumn then
		leadSpec.eyebrow = eyebrowResolver(p.columnAlias(eyebrowColumn))
	end
	local specs = { leadSpec }
	local KINDS = { list = 'valueList', link = 'link', plain = 'smart' }
	for i, column in ipairs(columns) do
		if not column.eyebrow then
			local alias = p.columnAlias(column)
			local header = (column.label and column.label ~= '') and column.label or column.property
			if column.kind == 'effect' then
				-- Dietary-effect badge list: each value classified by Module:DietaryEffect;
				-- the set filter splits the cell into one option per effect.
				specs[#specs + 1] = {
					kind = 'badgeList',
					field = 'c' .. i,
					header = header,
					label = alias,
					classify = require('Module:DietaryEffect').gridClassify,
					filter = 'aggridSet',
				}
			elseif column.kind == 'boolean' then
				-- Tri-state boolean: each value classified by Module:Boolean,
				-- rendered icon-only; the set filter keys on "Yes"/"No".
				specs[#specs + 1] = {
					kind = 'boolean',
					field = 'c' .. i,
					header = header,
					label = alias,
					filter = 'aggridSet',
				}
			else
				local values = {}
				for _, result in ipairs(results) do
					if result[alias] ~= nil then
						values[#values + 1] = result[alias]
					end
				end
				specs[#specs + 1] = {
					kind = KINDS[Util.classifyColumn(values)],
					field = 'c' .. i,
					header = header,
					label = alias,
					filter = column.filter and 'aggridSet' or 'agTextColumnFilter',
				}
			end
		end
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

	-- At most one column may be promoted into the lead card's eyebrow.
	local eyebrowColumn
	for _, column in ipairs(columns) do
		if column.eyebrow then
			if eyebrowColumn then
				return '<strong class="error">Module:DataGrid: only one eyebrow column allowed.</strong>'
			end
			eyebrowColumn = column
		end
	end

	-- A query that matches nothing legitimately returns no rows; coerce non-table to
	-- {} so the grid renders empty (AG Grid shows its own "no rows" overlay) rather
	-- than erroring.
	local results = mw.smw.ask(p.buildQuery(category, columns, conditions))
	if type(results) ~= 'table' then
		results = {}
	end

	local specs = buildSpecs(results, columns, eyebrowColumn)
	local gridOptions = {
		columnDefs = AGGridColumns.buildColumnDefs(specs),
		rowData = AGGridColumns.buildRowData(results, specs),
		quickSearch = true,
		pagination = false,
		rowHeight = eyebrowColumn and EYEBROW_ROW_HEIGHT or ROW_HEIGHT,
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
