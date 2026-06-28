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
local AGGridColumns = require('Module:AGGridColumns')
local Util = require('Module:AGGridColumns/Util')

local p = {}

-- Source width in px for the manufacturer brand glyph in the card eyebrow.
local GLYPH_WIDTH = 40

-- Manufacturer display name -> { code, short }, from the maintained
-- Module:Manufacturers/data.json (keyed CODE -> { name, short }). `code` resolves
-- the brand glyph (File:Sc-icon-brand-<code>.svg); `short` is the compact label
-- shown in the card eyebrow. Built once at module load.
local MANUFACTURER = {}
do
	local ok, data = pcall(mw.loadJsonData, 'Module:Manufacturers/data.json')
	if ok and type(data) == 'table' then
		for code, entry in pairs(data) do
			if type(entry) == 'table' and entry.name then
				MANUFACTURER[entry.name] = { code = tostring(code):lower(), short = entry.short }
			end
		end
	end
end

-- Numeric display formats. The extension applies these client-side via Intl on
-- the real number, so the underlying value (and thus sort / filter / set-filter
-- / CSV export) stays numeric -- only the rendered text gains grouping and a
-- unit. `style` is always 'number'; `useGrouping` defaults to true, so thousands
-- separators come for free. Decimals are left unset to preserve each value's
-- natural precision.
local FMT_AUEC = { style = 'number', suffix = ' aUEC' } -- in-game currency
local FMT_USCU = { style = 'number', suffix = ' µSCU' } -- personal inventory / storage capacity
local FMT_METERS = { style = 'number', suffix = ' m' }
local FMT_KG = { style = 'number', suffix = ' kg' }
local FMT_SCU = { style = 'number', suffix = ' SCU' }
local FMT_SPEED = { style = 'number', suffix = ' m/s' }
local FMT_RATE = { style = 'number', suffix = ' °/s' }

-- Production state -> BadgeLua variant. Flight ready is done (success); active /
-- long-term production is in progress (warning); concept is not yet flyable
-- (error). SQ42-only and any unmapped state get the neutral base badge.
local PRODUCTION_VARIANT = {
	['Flight ready'] = 'success',
	['Active production'] = 'warning',
	['Long term production'] = 'warning',
	['In concept'] = 'error',
}

-- Eyebrow resolver for the vehicle card: the manufacturer's short name + brand
-- glyph, parsed from the row's Manufacturer page printout. Consumer-specific
-- (the card kind itself stays generic). Returns nil when there's no manufacturer.
local function manufacturerEyebrow(result)
	local mfrTarget, mfrDisplay = Util.parseLink(result['Manufacturer'])
	if not mfrTarget then
		return nil
	end
	local mfrName = mfrDisplay or mfrTarget
	local info = MANUFACTURER[mfrName]
	local mfrLink = aggrid.link(mfrTarget, mfrName)
	local eyebrow = {
		text = (info and info.short) or mfrName,
		full = mfrName,
		href = mfrLink and mfrLink.href,
	}
	if info and info.code then
		eyebrow.icon = aggrid.thumb('File:Sc-icon-brand-' .. info.code .. '.svg', GLYPH_WIDTH)
	end
	return eyebrow
end

local COLUMNS = {
	{
		field = 'vehicle',
		header = 'Vehicle',
		kind = 'card',
		titleLabel = 'Name',
		imageLabel = 'Image',
		eyebrow = manufacturerEyebrow,
		filter = 'aggridSet',
		width = 300,
	},
	{ field = 'career', header = 'Career', kind = 'text', label = 'Career', filter = 'aggridSet', width = 110 },
	{ field = 'role', header = 'Role', kind = 'text', label = 'Role', filter = 'aggridSet', width = 180 },
	{ field = 'size', header = 'Size', kind = 'number', label = 'Size', filter = 'aggridSet', width = 80 },
	{
		field = 'storeSize',
		header = 'Store size',
		kind = 'text',
		label = 'Store size',
		filter = 'aggridSet',
		width = 100,
	},
	{
		field = 'production',
		header = 'Production state',
		kind = 'badge',
		label = 'Production state',
		variants = PRODUCTION_VARIANT,
		filter = 'aggridSet',
		width = 200,
	},
	{
		field = 'availability',
		header = 'Pledge availability',
		kind = 'text',
		label = 'Pledge availability',
		filter = 'aggridSet',
		width = 140,
	},
	{
		field = 'pledge',
		header = 'Pledge',
		kind = 'stackedValue',
		curLabel = 'Pledge',
		origLabel = 'Orig pledge',
		width = 90,
	},
	{
		field = 'warbond',
		header = 'Warbond',
		kind = 'stackedValue',
		curLabel = 'Warbond',
		origLabel = 'Orig warbond',
		width = 90,
	},
	{ field = 'loaner', header = 'Loaner', kind = 'linkList', label = 'Loaner', width = 160 },
	{
		field = 'avgPrice',
		header = 'Avg purchase',
		kind = 'number',
		label = 'Avg purchase',
		format = FMT_AUEC,
		width = 105,
	},
	{
		field = 'avgRental',
		header = 'Avg daily rental',
		kind = 'number',
		label = 'Avg daily rental',
		format = FMT_AUEC,
		width = 105,
	},
	{ field = 'length', header = 'Length', kind = 'number', label = 'Length', format = FMT_METERS, width = 80 },
	{ field = 'width', header = 'Width', kind = 'number', label = 'Width', format = FMT_METERS, width = 80 },
	{ field = 'height', header = 'Height', kind = 'number', label = 'Height', format = FMT_METERS, width = 80 },
	{ field = 'mass', header = 'Mass', kind = 'number', label = 'Mass', format = FMT_KG, width = 90 },
	{ field = 'minCrew', header = 'Min crew', kind = 'number', label = 'Min crew', width = 80 },
	{ field = 'maxCrew', header = 'Max crew', kind = 'number', label = 'Max crew', width = 80 },
	{ field = 'inventory', header = 'Inventory', kind = 'number', label = 'Inventory', format = FMT_USCU, width = 110 },
	{ field = 'cargo', header = 'Cargo', kind = 'number', label = 'Cargo', format = FMT_SCU, width = 80 },
	{ field = 'scm', header = 'SCM speed', kind = 'number', label = 'SCM speed', format = FMT_SPEED, width = 85 },
	{ field = 'maxSpeed', header = 'Max speed', kind = 'number', label = 'Max speed', format = FMT_SPEED, width = 90 },
	{ field = 'roll', header = 'Roll', kind = 'number', label = 'Roll', format = FMT_RATE, width = 75 },
	{ field = 'pitch', header = 'Pitch', kind = 'number', label = 'Pitch', format = FMT_RATE, width = 75 },
	{ field = 'yaw', header = 'Yaw', kind = 'number', label = 'Yaw', format = FMT_RATE, width = 75 },
	{ field = 'conceptDate', header = 'Concept date', kind = 'text', label = 'Concept date', width = 110 },
}

local function buildQuery()
	return {
		'[[:+]] [[Category:Pledge ships||Pledge vehicles]]',
		'?Page Image=Image',
		'?=Name',
		'?Manufacturer',
		'?Career',
		'?Role',
		'?Size#-=Size',
		'?Ship matrix size=Store size',
		'?Production state#-=Production state',
		'?Pledge availability#-=Pledge availability',
		'?Pledge price#-=Pledge',
		'?Original pledge price#-=Orig pledge',
		'?Warbond pledge price#-=Warbond',
		'?Original warbond pledge price#-=Orig warbond',
		'?Loaner vehicle=Loaner',
		'?Average purchase price#-=Avg purchase',
		'?Average rental price#-=Avg daily rental',
		'?Entity length#-=Length',
		'?Entity width#-=Width',
		'?Entity height#-=Height',
		'?Mass#-=Mass',
		'?Minimum crew#-=Min crew',
		'?Maximum crew#-=Max crew',
		'?Storage capacity#-=Inventory',
		'?Cargo capacity#-=Cargo',
		'?Scm speed#-=SCM speed',
		'?Max speed#-=Max speed',
		'?Roll rate#-=Roll',
		'?Pitch rate#-=Pitch',
		'?Yaw rate#-=Yaw',
		'?Concept announcement date#-=Concept date',
		'mainlabel=-',
		'limit=1000',
	}
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
		columnDefs = AGGridColumns.buildColumnDefs(COLUMNS),
		rowData = AGGridColumns.buildRowData(results, COLUMNS),
		-- Themed global search box wired to AG Grid's quick filter (client-side over
		-- the loaded rows).
		quickSearch = true,
		-- No pagination: all vehicles in one virtualised, internally-scrolling
		-- grid. Only the visible rows are ever in the DOM.
		pagination = false,
		-- Row height tuned to the card cell (thumbnail + two text lines).
		rowHeight = 64,
		-- Auto-size plain columns to their content. The custom-rendered columns
		-- (card, stacked prices, badges) opt out via suppressAutoSize and use their `w`.
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
