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
--- right-aligns them per cell at render time. The one exception is the column-level
--- `numeric` flag, which an empty cell falls back to because it has no value of its
--- own to look numeric.

local Util = require('Module:AGGridColumns/Util')
local AGGridColumns = require('Module:AGGridColumns')
local aggrid = require('mw.ext.aggrid')
local yesno = require('Module:Yesno')

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
--- @field kind? string  Override the auto-classified column kind (e.g. `effect`, `bar`).
--- @field good? string  For `kind=bar`: 'higher' | 'lower', the direction that helps.
--- @field group? string  Header this column sits under; consecutive matches nest together.
--- @field prefix? string  For `eyebrow`: joined before the value, no space ("1" -> "S1").
--- @field suffix? string  For `eyebrow`: unit appended after a space ("5" -> "5 charges").
--- @field suffix1? string  The `suffix` to use when the value is exactly 1 ("1 charge").

--- Parse the multi-line `columns` value. Carried over from Module:DataTableLua:
--- one column per non-blank line; within a line, `;`-separated clauses where the
--- first is the SMW property and the rest are modifiers (`label=X`, `size=X`,
--- `kind=X`, `good=higher|lower`, `group=X`, `prefix=X`, `suffix=X`, `suffix1=X`,
--- or the bare flags `filter` / `eyebrow`).
--- `eyebrow` promotes the column into the lead card instead of rendering it as its
--- own column. `good` applies to `kind=bar` only, naming the direction that helps
--- the reader. Unknown clauses are ignored. Empty-property lines drop.
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
					elseif key == 'good' then
						column.good = value
					elseif key == 'group' then
						column.group = value
					elseif key == 'prefix' then
						column.prefix = value
					elseif key == 'suffix' then
						column.suffix = value
					elseif key == 'suffix1' then
						column.suffix1 = value
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

--- One eyebrow column's value as `{ text, href? }`: a linked label when the value
--- is a single page printout, else plain text. No icon — the brand glyph is
--- PledgeVehicleGrid-specific. nil when the value is empty.
---
--- A composed eyebrow strips the column headers that would otherwise say what a
--- number is — "S1 · 1 · Active" tells a reader nothing — so `prefix` and `suffix`
--- put the unit back. They join differently on purpose, matching how each is
--- actually written: `prefix` has NO space, because Star Citizen writes a size as
--- "S1"; `suffix` takes one, because a unit is a separate word ("5 charges",
--- "60 s"). `suffix1` is the singular, used when the value is exactly 1 — most
--- passive modules have one charge, so "1 charges" would be wrong on more rows
--- than it is right.
--- @param result table
--- @param part table  { alias, prefix?, suffix?, suffix1? }
--- @return table|nil
local function eyebrowPart(result, part)
	local value = result[part.alias]
	local target, display = Util.parseLink(value)
	if target then
		local link = aggrid.link(target, display)
		return {
			text = (link and link.text) or display or target,
			href = link and link.href,
		}
	end
	local text = Util.toText(value)
	if text == nil or text == '' then
		return nil
	end
	local suffix = part.suffix
	if suffix and part.suffix1 and tonumber(text) == 1 then
		suffix = part.suffix1
	end
	if suffix and suffix ~= '' then
		text = text .. ' ' .. suffix
	end
	if part.prefix and part.prefix ~= '' then
		text = part.prefix .. text
	end
	return { text = text }
end

--- The lead card's eyebrow resolver, closed over every `eyebrow` column's key.
--- Several columns compose one line — "Active · 5 charges · 60 s" — so the specs a
--- reader needs to identify a row travel in the lead instead of costing a column
--- each. Only a single part keeps its link: a composed line has no one target.
---
--- `filterPart` is the column the lead's set filter keys on, surfaced separately as
--- `full` (the Card kind's set-filter value). Without it the whole composed line
--- would become the filter option, which is one option per row.
--- @param parts table[]  { alias, prefix?, suffix?, suffix1? }
--- @param filterPart table|nil
--- @return fun(result: table): table|nil
local function eyebrowResolver(parts, filterPart)
	return function(result)
		local rendered = {}
		local single
		for _, part in ipairs(parts) do
			local resolved = eyebrowPart(result, part)
			if resolved then
				rendered[#rendered + 1] = resolved.text
				single = (#rendered == 1) and resolved or nil
			end
		end
		if #rendered == 0 then
			return nil
		end
		local text = table.concat(rendered, ' · ')
		local full = text
		if filterPart then
			-- The filter keys on ONE column, not the composed line, which would give an
			-- option per row. It uses that column's DECORATED text, so a size filter
			-- lists "S1" — the term a reader recognises — rather than a bare "1".
			local resolved = eyebrowPart(result, filterPart)
			full = resolved and resolved.text or nil
		end
		return {
			text = text,
			full = full,
			href = single and single.href or nil,
		}
	end
end

--- Build the AGGridColumns column specs for this query: a single card lead
--- (thumbnail + linked name, optional eyebrow), then one spec per editor column
--- (classified link vs multi-value list vs smart-plain). A column flagged
--- `eyebrow` feeds the lead card and is not emitted as its own column.
--- @param results table[]
--- @param columns DataGridColumn[]
--- @param eyebrowColumns DataGridColumn[]
--- @param pinLead boolean
--- @return table[]
local function buildSpecs(results, columns, eyebrowColumns, pinLead)
	local leadSpec = {
		kind = 'card',
		field = 'lead',
		header = NAME_ALIAS,
		titleLabel = NAME_ALIAS,
		imageLabel = IMAGE_ALIAS,
		filterOn = 'title',
		filter = 'agTextColumnFilter',
	}
	-- Sizing. Unpinned, the lead grows to fill horizontal slack left by the
	-- content-sized data columns, so rows span the full container instead of ending
	-- short; LEAD_WIDTH floors it. Pinned, it takes that as a FIXED width: a pinned
	-- column lives outside AG Grid's centre viewport, where flex has nothing to flex
	-- against, and the two together leave the column unpinned.
	--
	-- Pinning keeps the lead on screen while the data columns scroll under it.
	-- Sideways scrolling is not what makes a wide table unusable; losing track of
	-- which row you are reading is. Opt-in, because pinning splits the viewport and
	-- draws a divider even when nothing overflows.
	if pinLead then
		leadSpec.pinned = 'left'
		leadSpec.width = LEAD_WIDTH
	else
		leadSpec.flex = 1
		leadSpec.minWidth = LEAD_WIDTH
	end
	if eyebrowColumns[1] then
		local parts, filterPart = {}, nil
		for _, column in ipairs(eyebrowColumns) do
			local part = {
				alias = p.columnAlias(column),
				prefix = column.prefix,
				suffix = column.suffix,
				suffix1 = column.suffix1,
			}
			parts[#parts + 1] = part
			if column.filter and not filterPart then
				filterPart = part
			end
		end
		leadSpec.eyebrow = eyebrowResolver(parts, filterPart)
		-- A `filter`-flagged eyebrow moves the lead's filter off the name and onto
		-- that value as a checkbox set — "show me only the Active modules". The name
		-- stays searchable through the grid's quickSearch box, so nothing is lost.
		if filterPart then
			leadSpec.filterOn = 'eyebrow'
			leadSpec.filter = 'aggridSet'
		end
	end
	local specs = { leadSpec }
	local groups = { false }
	local KINDS = { list = 'valueList', link = 'link', plain = 'smart' }
	for i, column in ipairs(columns) do
		if not column.eyebrow then
			groups[#specs + 1] = (column.group ~= nil and column.group ~= '') and column.group or false
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
			elseif column.kind == 'bar' then
				-- Bars are scaled on the column, so the spec carries the largest
				-- magnitude in it; a per-cell scale would make two rows incomparable,
				-- which is the whole point of drawing them.
				local max = 0
				for _, result in ipairs(results) do
					local n = Util.toNumber(result[alias])
					if n ~= nil and math.abs(n) > max then
						max = math.abs(n)
					end
				end
				specs[#specs + 1] = {
					kind = 'signedBar',
					field = 'c' .. i,
					header = header,
					label = alias,
					good = column.good,
					max = max,
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
				-- All-numeric, not majority-numeric: the flag exists so an empty cell
				-- can be aligned like the rest of its column, and in a mixed column
				-- there is no "rest" to align to.
				local numeric = #values > 0
				for _, v in ipairs(values) do
					if not Util.looksNumeric(v) then
						numeric = false
						break
					end
				end
				specs[#specs + 1] = {
					kind = KINDS[Util.classifyColumn(values)],
					field = 'c' .. i,
					header = header,
					label = alias,
					filter = column.filter and 'aggridSet' or 'agTextColumnFilter',
					numeric = numeric,
				}
			end
		end
	end
	return specs, groups
end

--- Nest runs of consecutive columns that share a `group` into AG Grid column
--- groups. Grouping is what turns nine unfamiliar stat names into the two or three
--- questions a reader actually has ("what does the rock do", "what do I take
--- home"), so it is a header row, not decoration.
---
--- Only CONSECUTIVE matches nest: a group is a position in the table, and letting
--- non-adjacent columns join one would silently reorder the editor's columns.
--- @param defs table[]
--- @param groups (string|false)[]  aligned with defs
--- @return table[]
local function groupColumnDefs(defs, groups)
	local out = {}
	local i = 1
	while i <= #defs do
		local group = groups[i]
		if not group then
			out[#out + 1] = defs[i]
			i = i + 1
		else
			local children = {}
			while i <= #defs and groups[i] == group do
				children[#children + 1] = defs[i]
				i = i + 1
			end
			out[#out + 1] = { headerName = group, children = children }
		end
	end
	return out
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

	-- Every `eyebrow` column composes the lead card's second line, in the order the
	-- editor wrote them.
	local eyebrowColumns = {}
	for _, column in ipairs(columns) do
		if column.eyebrow then
			eyebrowColumns[#eyebrowColumns + 1] = column
		end
	end
	local pinLead = yesno(args.pinlead, false)

	-- A query that matches nothing legitimately returns no rows; coerce non-table to
	-- {} so the grid renders empty (AG Grid shows its own "no rows" overlay) rather
	-- than erroring.
	local results = mw.smw.ask(p.buildQuery(category, columns, conditions))
	if type(results) ~= 'table' then
		results = {}
	end

	local specs, groups = buildSpecs(results, columns, eyebrowColumns, pinLead)
	local gridOptions = {
		columnDefs = groupColumnDefs(AGGridColumns.buildColumnDefs(specs), groups),
		rowData = AGGridColumns.buildRowData(results, specs),
		quickSearch = true,
		expand = true,
		pagination = false,
		rowHeight = eyebrowColumns[1] and EYEBROW_ROW_HEIGHT or ROW_HEIGHT,
		autoSizeStrategy = { type = 'fitCellContents' },
		defaultColDef = { sortable = true, resizable = true },
	}

	local styles = frame:extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:DataGrid/styles.css' },
	})

	return styles .. '<div class="t-datagrid">' .. aggrid.render(gridOptions) .. '</div>'
end

-- Test-only exports. Not part of the public API.
p._internal = {
	buildSpecs = buildSpecs,
	groupColumnDefs = groupColumnDefs,
	eyebrowResolver = eyebrowResolver,
}

return p
