require('strict')

-- PledgeVehicleGrid: renders the List of pledge vehicles as an AG Grid via the
-- AGGrid extension. Sources every pledge vehicle from Bucket (Module:BucketQuery),
-- reshapes the results into AG Grid rowData, and returns the grid: virtualised
-- rows, rich cells (linked names, thumbnails, loaner link-lists), REST-served data.
--
-- Rows come from Module:BucketQuery as typed values (numbers, bare page titles,
-- arrays for the loaner list), which the AGGridColumns kinds take as they are.
--
-- An empty result and a Store failure (rate limit, bad manifest) are both
-- contained here and reported as "no pledge vehicles stored": Bucket's
-- per-user API limiter also answers empty when throttled, so on a live
-- article that message can mean a transient rate limit rather than missing
-- data.

local aggrid = require('mw.ext.aggrid')
local AGGridColumns = require('Module:AGGridColumns')
local Util = require('Module:AGGridColumns/Util')
local bucketQuery = require('Module:BucketQuery')

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
-- glyph, read from the row's Manufacturer page value. Consumer-specific
-- (the card kind itself stays generic). Returns nil when there's no manufacturer.
local function manufacturerEyebrow(result)
	local mfrTarget, mfrDisplay = Util.pageTarget(result['Manufacturer'])
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

-- "Added in version" is a page reference (the canonical Update: patch). This is a
-- vehicle-only grid, so the column shows just the version label: strip the
-- "Update:Star Citizen " / "Star Citizen " prefix the page value carries
-- ("Update:Star Citizen Alpha 3.24.3" -> "Alpha 3.24.3"). nil when absent.
local function flightReadyLabel(value)
	local target = Util.pageTarget(value)
	if not target or target == '' then
		return nil
	end
	return (target:gsub('^Update:', ''):gsub('^Star Citizen ', ''))
end

local COLUMNS = {
	{
		field = 'vehicle',
		header = 'Vehicle',
		kind = 'card',
		titleLabel = 'Name',
		imageLabel = 'Image',
		displayLabel = 'DisplayName',
		eyebrow = manufacturerEyebrow,
		filter = 'aggridSet',
		width = 300,
	},
	{ field = 'type', header = 'Type', kind = 'text', label = 'Type', filter = 'aggridSet', width = 130 },
	{ field = 'career', header = 'Career', kind = 'text', label = 'Career', filter = 'aggridSet', width = 110 },
	-- Role is a repeated Bucket field: a valueList renders each role and lets the
	-- set filter offer them separately, the same shape RentalVehicleGrid uses.
	{ field = 'role', header = 'Role', kind = 'valueList', label = 'Role', filter = 'aggridSet', width = 180 },
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
	{ field = 'conceptDate', header = 'Concept date', kind = 'date', label = 'Concept date' },
	{
		field = 'flightReady',
		header = 'Flight ready',
		kind = 'text',
		label = 'Flight ready',
		filter = 'aggridSet',
		width = 110,
	},
}

-- One Store column per grid label; the label is the result key the column
-- kinds read, so the COLUMNS table above is unchanged. DisplayName backs the
-- card's displayLabel: Store's page_name builtin is the bare title and does
-- not carry a page's {{DISPLAYTITLE}}.
local SPEC_COLUMNS = {
	{ builtin = 'page_name', as = 'Name' },
	{ property = 'Name', as = 'DisplayName' },
	{ property = 'Image', as = 'Image' },
	{ property = 'Manufacturer', as = 'Manufacturer' },
	{ property = 'Subject type', as = 'Type' },
	{ property = 'Career', as = 'Career' },
	{ property = 'Role', as = 'Role' },
	{ property = 'Size', as = 'Size' },
	{ property = 'Ship matrix size', as = 'Store size' },
	{ property = 'Production state', as = 'Production state' },
	{ property = 'Pledge availability', as = 'Pledge availability' },
	{ property = 'Pledge price', as = 'Pledge' },
	{ property = 'Original pledge price', as = 'Orig pledge' },
	{ property = 'Warbond pledge price', as = 'Warbond' },
	{ property = 'Original warbond pledge price', as = 'Orig warbond' },
	{ property = 'Loaner vehicle', as = 'Loaner' },
	{ property = 'Average purchase price', as = 'Avg purchase' },
	{ property = 'Average rental price', as = 'Avg daily rental' },
	{ property = 'Entity length', as = 'Length' },
	{ property = 'Entity width', as = 'Width' },
	{ property = 'Entity height', as = 'Height' },
	{ property = 'Mass', as = 'Mass' },
	{ property = 'Minimum crew', as = 'Min crew' },
	{ property = 'Maximum crew', as = 'Max crew' },
	{ property = 'Storage capacity', as = 'Inventory' },
	{ property = 'Cargo capacity', as = 'Cargo' },
	{ property = 'Scm speed', as = 'SCM speed' },
	{ property = 'Max speed', as = 'Max speed' },
	{ property = 'Roll rate', as = 'Roll' },
	{ property = 'Pitch rate', as = 'Pitch' },
	{ property = 'Yaw rate', as = 'Yaw' },
	{ property = 'Concept announcement date', as = 'Concept date' },
	{ property = 'Added in version', as = 'Flight ready' },
}

local function buildSpec()
	return {
		kind = 'Vehicle',
		filters = { { any = { 'Category:Pledge ships', 'Category:Pledge vehicles' } } },
		columns = SPEC_COLUMNS,
		limit = 1000,
	}
end

--- Entry point. Renders the pledge-vehicle grid.
--- @param frame mw.frame
--- @return string
function p.main(frame)
	local ok, results = pcall(bucketQuery.query, buildSpec())
	if not ok or #results == 0 then
		return '<strong class="error">Module:PledgeVehicleGrid: no pledge vehicles stored.</strong>'
	end

	-- Pre-clean the "Added in version" Page value to a bare version label for the
	-- "Flight ready" column (the text kind otherwise renders the full page title).
	for _, result in ipairs(results) do
		result['Flight ready'] = flightReadyLabel(result['Flight ready'])
	end

	local gridOptions = {
		columnDefs = AGGridColumns.buildColumnDefs(COLUMNS),
		rowData = AGGridColumns.buildRowData(results, COLUMNS),
		-- Themed global search box wired to AG Grid's quick filter (client-side over
		-- the loaded rows).
		quickSearch = true,
		-- Toolbar button that reopens the grid in a full-window modal, for the wide
		-- column set.
		expand = true,
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

-- Test-only exports. Not part of the public API.
p._internal = { buildSpec = buildSpec, flightReadyLabel = flightReadyLabel, columns = COLUMNS }

return p
