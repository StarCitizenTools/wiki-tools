require('strict')

--- Generic browse-table component. Wraps the Semantic MediaWiki
--- `format=datatables` `#ask` pattern so call sites pass only a category and a
--- multi-line column list; every DataTables option is fixed here. Search-pane
--- facets are declared per column and their indices are computed automatically.

--- @class DataTableColumn
--- @field property string  SMW property name (the printout subject).
--- @field label? string    Header override; defaults to the property name.
--- @field size? string     Printout format hint, e.g. '100px' for images.
--- @field filter? boolean   Whether this column gets a search-pane facet.

local p = {}

-- The two columns the template always prepends, in render order.
-- Their printouts mirror the original hand-written query: a 100px page image
-- with no header, then the page itself labelled "Name". They occupy rendered
-- column indices 0 and 1, so editor-supplied columns start at index 2.
local LEAD_PRINTOUTS = { '?Page Image#100px=', '?=Name' }
local LEAD_COLUMN_COUNT = #LEAD_PRINTOUTS

-- Fixed DataTables options, identical for every browse table.
local FIXED_OPTIONS = {
	'mainlabel=-',
	'format=datatables',
	'limit=1000',
	'datatables-pageLength=10',
	'datatables-deferRender=true',
	'datatables-responsive=false',
	'datatables-scrollX=true',
	'datatables-mark=true',
	'datatables-searchPanes=true',
	'datatables-searchPanes.initCollapsed=true',
}

--- Parse the multi-line `columns` value into an ordered list of columns.
--- One column per non-blank line. Within a line, `;`-separated clauses: the
--- first is the SMW property, the rest are modifiers (`label=X`, `size=X`, or
--- the bare flag `filter`). Unknown clauses are ignored for forward
--- compatibility. Lines whose property is empty are dropped.
---
--- @param raw string
--- @return DataTableColumn[]
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
					-- Anything else is ignored on purpose.
				end
			end

			if column.property and column.property ~= '' then
				columns[#columns + 1] = column
			end
		end
	end

	return columns
end

--- Build the SMW printout string for a single column.
--- Format: `?Property[#size][=label]`. A size with no label yields an empty
--- header (`?Prop#100px=`), matching the image convention.
---
--- @param column DataTableColumn
--- @return string
local function buildPrintout(column)
	local printout = '?' .. column.property
	if column.size then
		printout = printout .. '#' .. column.size
	end
	if column.label then
		printout = printout .. '=' .. column.label
	elseif column.size then
		printout = printout .. '='
	end
	return printout
end

--- Compute the 0-based rendered indices of every `filter`-flagged column.
--- Lead columns (image, name) shift editor columns by LEAD_COLUMN_COUNT.
---
--- @param columns DataTableColumn[]
--- @return integer[]
local function facetIndices(columns)
	local indices = {}
	for i, column in ipairs(columns) do
		if column.filter then
			indices[#indices + 1] = (i - 1) + LEAD_COLUMN_COUNT
		end
	end
	return indices
end

--- Assemble the ordered `#ask` argument list (condition, printouts, options).
---
--- @param category string
--- @param columns DataTableColumn[]
--- @return string[]
function p.buildAskArgs(category, columns)
	-- `[[:+]]` restricts the query to the main namespace (leading `:` is the
	-- main-namespace prefix, `+` the wildcard). Without it, File/Category pages
	-- tagged into the same category leak into the table as rows.
	local args = { '[[:+]] [[Category:' .. category .. ']]' }

	for _, printout in ipairs(LEAD_PRINTOUTS) do
		args[#args + 1] = printout
	end
	for _, column in ipairs(columns) do
		args[#args + 1] = buildPrintout(column)
	end

	for _, option in ipairs(FIXED_OPTIONS) do
		args[#args + 1] = option
	end

	local facets = facetIndices(columns)
	if #facets > 0 then
		args[#args + 1] = 'datatables-searchPanes.columns=' .. table.concat(facets, ',')
	end

	return args
end

--- Entry point. Reads `category` and `columns` from the template's parameters
--- (via the parent frame), builds the query, and returns the DataTables-rendered
--- table preceded by the required styles load.
---
--- @param frame mw.frame
--- @return string
function p.main(frame)
	local getArgs = require('Module:Arguments').getArgs
	local args = getArgs(frame)

	local category = mw.text.trim(args.category or '')
	if category == '' then
		return '<strong class="error">Module:DataTableLua: missing required parameter "category".</strong>'
	end

	local columns = p.parseColumns(args.columns)
	if #columns == 0 then
		return '<strong class="error">Module:DataTableLua: no columns defined.</strong>'
	end

	local styles = frame:expandTemplate({ title = 'Datatable styles' })
	local table_ = frame:callParserFunction('#ask', p.buildAskArgs(category, columns))

	return styles .. table_
end

return p
