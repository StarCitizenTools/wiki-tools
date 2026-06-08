require('strict')

-- PledgeVehicleGrid: renders the List of pledge vehicles as an AG Grid via the
-- AGGrid extension. Sources every pledge vehicle from SMW (mw.smw.ask), reshapes
-- the results into AG Grid rowData, and returns the grid. Replaces the former
-- `#ask format=datatables` table: same columns, but virtualised rows, rich cells
-- (linked names, thumbnails, loaner link-lists), and REST-served data.
--
-- SMW value handling: mw.smw.ask returns each row as a flat table of *formatted
-- display strings*. Numerics carry units and embed the nbsp as the literal
-- entity text "&#160;", so values are HTML-decoded before being stripped to a
-- number (otherwise the "160" leaks in). Page/file printouts return
-- wikilink/file markup ("[[:100i|100i]]", "[[File:X.png|frameless|...]]"),
-- parsed to titles here. Multi-valued printouts (Loaner) arrive as arrays.

local aggrid = require('mw.ext.aggrid')

local p = {}

-- Source thumbnail width in px. The display height is fixed to 56px by
-- styles.css (width:auto), so this only governs image resolution.
local IMAGE_WIDTH = 120

-- Decode a single scalar SMW value to clean text.
local function decodeScalar(value)
	if type(value) == 'table' then
		value = value.fulltext or value.fullText or value.text or value.label
	end
	if value == nil then
		return nil
	end
	return mw.text.decode(tostring(value), true)
end

-- Map a function over a (possibly multi-valued) SMW result value, joining the
-- decoded results with ", ". Single values pass straight through `fn`.
local function mapJoin(value, fn)
	if type(value) == 'table' and value[1] ~= nil then
		local parts = {}
		for _, v in ipairs(value) do
			local t = decodeScalar(v)
			if t and t ~= '' then
				parts[#parts + 1] = fn(t)
			end
		end
		return table.concat(parts, ', ')
	end
	local s = decodeScalar(value)
	if s == nil then
		return nil
	end
	return fn(s)
end

local function identity(s)
	return s
end

local function toText(value)
	return mapJoin(value, identity)
end

-- Coerce to a number: decode entities first (drops the nbsp "160" leak), then
-- strip currency, units, and grouping separators.
local function toNumber(value)
	if type(value) == 'number' then
		return value
	end
	if type(value) == 'table' and value[1] ~= nil then
		value = value[1]
	end
	local text = decodeScalar(value)
	if text == nil then
		return nil
	end
	return tonumber((text:gsub('[^%d%.%-]', '')))
end

-- Parse "[[:Target|Display]]" (a single SMW page value) into target, display.
local function parseLink(markup)
	if type(markup) == 'table' then
		markup = markup[1]
	end
	local s = decodeScalar(markup)
	if s == nil then
		return nil
	end
	local inner = s:match('^%[%[(.-)%]%]$') or s
	local target = inner:match('^([^|]*)')
	if target then
		target = target:gsub('^:', '')
	end
	if not target or target == '' then
		return nil
	end
	return target, inner:match('|(.*)$')
end

-- Build a linked-thumbnail cell value from "[[File:X.png|frameless|...]]" markup,
-- linked to the row's own page. nil when the file is absent or missing on-wiki.
local function buildThumb(markup, linkTarget)
	if type(markup) == 'table' then
		markup = markup[1]
	end
	local s = decodeScalar(markup)
	if s == nil then
		return nil
	end
	local inner = s:match('^%[%[(.-)%]%]$') or s
	local file = inner:match('^([^|]*)')
	if not file or file == '' then
		return nil
	end
	return aggrid.thumb(file, IMAGE_WIDTH, linkTarget and { link = linkTarget } or nil)
end

-- Build a link-list cell value from a (possibly multi-valued) page printout.
local function buildLinkList(value)
	if value == nil then
		return nil
	end
	local items = (type(value) == 'table' and value[1] ~= nil) and value or { value }
	local targets = {}
	for _, m in ipairs(items) do
		local target = parseLink(m)
		if target then
			targets[#targets + 1] = target
		end
	end
	if #targets == 0 then
		return nil
	end
	return aggrid.linkList(targets)
end

-- Numeric display formats. The extension applies these client-side via Intl on
-- the real number, so the underlying value (and thus sort / filter / set-filter
-- / CSV export) stays numeric -- only the rendered text gains grouping and a
-- unit. `style` is always 'number'; `useGrouping` defaults to true, so thousands
-- separators come for free. Decimals are left unset to preserve each value's
-- natural precision.
local FMT_DOLLARS = { style = 'number', prefix = '$' } -- real-money pledge store
local FMT_AUEC = { style = 'number', suffix = ' aUEC' } -- in-game currency
local FMT_METERS = { style = 'number', suffix = ' m' }
local FMT_KG = { style = 'number', suffix = ' kg' }
local FMT_SCU = { style = 'number', suffix = ' SCU' }
local FMT_SPEED = { style = 'number', suffix = ' m/s' }
local FMT_RATE = { style = 'number', suffix = ' °/s' }
local FMT_PLAIN = { style = 'number' } -- grouping only; SMW stores no unit

-- Column set mirroring the live List of pledge vehicles #ask. `label` is the SMW
-- printout label the result row is keyed by; `field` is the AG Grid field.
-- `kind` selects a rich renderer; `num` marks numeric; `format` is its numeric
-- display spec (see above). `filter` overrides the default column filter -- the
-- low-cardinality categorical columns use the extension's checkbox set filter
-- ('aggridSet'). `w` is an explicit width (currently UNUSED -- the grid
-- auto-sizes via autoSizeStrategy; retained so buildColumnDefs can switch back
-- to fixed widths if needed).
local COLUMNS = {
	{ field = 'image', label = 'Image', header = 'Image', kind = 'image', w = 135 },
	{ field = 'name', label = 'Name', header = 'Name', kind = 'link', w = 150 },
	{ field = 'manufacturer', label = 'Manufacturer', header = 'Manufacturer', filter = 'aggridSet', w = 175 },
	{ field = 'career', label = 'Career', header = 'Career', filter = 'aggridSet', w = 110 },
	{ field = 'role', label = 'Role', header = 'Role', filter = 'aggridSet', w = 180 },
	{ field = 'size', label = 'Size', header = 'Size', filter = 'aggridSet', w = 80 },
	{ field = 'production', label = 'Production state', header = 'Production state', filter = 'aggridSet', w = 120 },
	{
		field = 'availability',
		label = 'Pledge availability',
		header = 'Pledge availability',
		filter = 'aggridSet',
		w = 140,
	},
	{ field = 'pledge', label = 'Pledge', header = 'Pledge', num = true, format = FMT_DOLLARS, w = 85 },
	{ field = 'origPledge', label = 'Orig pledge', header = 'Orig pledge', num = true, format = FMT_DOLLARS, w = 90 },
	{ field = 'warbond', label = 'Warbond', header = 'Warbond', num = true, format = FMT_DOLLARS, w = 90 },
	{
		field = 'origWarbond',
		label = 'Orig warbond',
		header = 'Orig warbond',
		num = true,
		format = FMT_DOLLARS,
		w = 95,
	},
	{ field = 'loaner', label = 'Loaner', header = 'Loaner', kind = 'linkList', w = 160 },
	{ field = 'avgPrice', label = 'Avg purchase', header = 'Avg purchase', num = true, format = FMT_AUEC, w = 105 },
	{
		field = 'avgRental',
		label = 'Avg daily rental',
		header = 'Avg daily rental',
		num = true,
		format = FMT_AUEC,
		w = 105,
	},
	{ field = 'length', label = 'Length', header = 'Length', num = true, format = FMT_METERS, w = 80 },
	{ field = 'width', label = 'Width', header = 'Width', num = true, format = FMT_METERS, w = 80 },
	{ field = 'height', label = 'Height', header = 'Height', num = true, format = FMT_METERS, w = 80 },
	{ field = 'mass', label = 'Mass', header = 'Mass', num = true, format = FMT_KG, w = 90 },
	{ field = 'minCrew', label = 'Min crew', header = 'Min crew', num = true, w = 80 },
	{ field = 'maxCrew', label = 'Max crew', header = 'Max crew', num = true, w = 80 },
	{ field = 'stowage', label = 'Stowage', header = 'Stowage', num = true, format = FMT_PLAIN, w = 95 },
	{ field = 'cargo', label = 'Cargo', header = 'Cargo', num = true, format = FMT_SCU, w = 80 },
	{ field = 'scm', label = 'SCM speed', header = 'SCM speed', num = true, format = FMT_SPEED, w = 85 },
	{ field = 'maxSpeed', label = 'Max speed', header = 'Max speed', num = true, format = FMT_SPEED, w = 90 },
	{ field = 'roll', label = 'Roll', header = 'Roll', num = true, format = FMT_RATE, w = 75 },
	{ field = 'pitch', label = 'Pitch', header = 'Pitch', num = true, format = FMT_RATE, w = 75 },
	{ field = 'yaw', label = 'Yaw', header = 'Yaw', num = true, format = FMT_RATE, w = 75 },
	{ field = 'conceptDate', label = 'Concept date', header = 'Concept date', w = 110 },
}

local function buildQuery()
	return {
		'[[:+]] [[Category:Pledge ships||Pledge vehicles]]',
		'?Page Image=Image',
		'?=Name',
		'?Manufacturer',
		'?Career',
		'?Role',
		'?Ship matrix size=Size',
		'?Production state#-=Production state',
		'?Pledge availability#-=Pledge availability',
		'?Pledge price#-=Pledge',
		'?Original pledge price#-=Orig pledge',
		'?Warbond pledge price#-=Warbond',
		'?Original warbond pledge price#-=Orig warbond',
		'?Loaner vehicle=Loaner',
		'?Average price=Avg purchase',
		'?Average rental price (1 day)=Avg daily rental',
		'?Entity length#-=Length',
		'?Entity width#-=Width',
		'?Entity height#-=Height',
		'?Mass#-=Mass',
		'?Minimum crew#-=Min crew',
		'?Maximum crew#-=Max crew',
		'?Vehicle inventory#-=Stowage',
		'?Cargo capacity#-=Cargo',
		'?SCM speed#-=SCM speed',
		'?Maximum speed#-=Max speed',
		'?Roll rate#-=Roll',
		'?Pitch rate#-=Pitch',
		'?Yaw rate#-=Yaw',
		'?Concept announcement date#-=Concept date',
		'mainlabel=-',
		'limit=1000',
	}
end

local function buildRowData(results)
	local rows = {}
	for _, result in ipairs(results) do
		-- Resolve the row's own page title once; it links the Name cell and is
		-- the click target for the thumbnail.
		local nameTarget, nameDisplay = parseLink(result['Name'])
		local row = {}
		for _, col in ipairs(COLUMNS) do
			local raw = result[col.label]
			if col.num then
				row[col.field] = toNumber(raw)
			elseif col.kind == 'link' then
				row[col.field] = nameTarget and aggrid.link(nameTarget, nameDisplay) or nil
			elseif col.kind == 'image' then
				row[col.field] = buildThumb(raw, nameTarget)
			elseif col.kind == 'linkList' then
				row[col.field] = buildLinkList(raw)
			else
				row[col.field] = toText(raw)
			end
		end
		rows[#rows + 1] = row
	end
	return rows
end

-- Shallow-copy a format spec. The FMT_* constants are shared by several columns,
-- but Scribunto's PHP serializer rejects the same table appearing more than once
-- in a structure ("Cannot pass circular reference to PHP"), so each colDef needs
-- its own instance. Values are scalars, so a shallow copy is enough.
local function cloneFormat(fmt)
	if fmt == nil then
		return nil
	end
	local copy = {}
	for k, v in pairs(fmt) do
		copy[k] = v
	end
	return copy
end

local function buildColumnDefs()
	local defs = {}
	for _, col in ipairs(COLUMNS) do
		local def
		if col.kind == 'image' then
			def = aggrid.imageColumn({
				field = col.field,
				header = col.header,
				sortable = false,
				filter = false,
			})
		elseif col.kind == 'link' then
			def = aggrid.linkColumn({
				field = col.field,
				header = col.header,
				filter = col.filter or 'agTextColumnFilter',
			})
		elseif col.kind == 'linkList' then
			def = aggrid.linkListColumn({
				field = col.field,
				header = col.header,
				filter = col.filter or 'agTextColumnFilter',
			})
		elseif col.num then
			def = {
				field = col.field,
				headerName = col.header,
				filter = col.filter or 'agNumberColumnFilter',
				type = 'numericColumn',
				format = cloneFormat(col.format),
			}
		else
			def = { field = col.field, headerName = col.header, filter = col.filter or 'agTextColumnFilter' }
		end
		defs[#defs + 1] = def
	end
	return defs
end

--- Entry point. Renders the pledge-vehicle grid.
--- @param frame mw.frame
--- @return string
function p.main(frame)
	local results = mw.smw.ask(buildQuery())
	if type(results) ~= 'table' then
		return '<strong class="error">Module:PledgeVehicleGrid: no results from SMW.</strong>'
	end

	local gridOptions = {
		columnDefs = buildColumnDefs(),
		rowData = buildRowData(results),
		-- No pagination: all vehicles in one virtualised, internally-scrolling
		-- grid. Only the visible rows are ever in the DOM.
		pagination = false,
		-- Match the 56px thumbnail height (set in styles.css).
		rowHeight = 56,
		-- Auto-size each column to its content. (Columns also carry an explicit
		-- `w` in COLUMNS, currently unused; switch buildColumnDefs back to it for
		-- deterministic widths.)
		autoSizeStrategy = { type = 'fitCellContents' },
		defaultColDef = {
			sortable = true,
			resizable = true,
		},
	}

	local styles = mw.getCurrentFrame():extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:PledgeVehicleGrid/styles.css' },
	})

	return styles .. '<div class="t-pledge-grid">' .. aggrid.render(gridOptions) .. '</div>'
end

return p
