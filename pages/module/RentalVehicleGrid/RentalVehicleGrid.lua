require('strict')

local p = {}

-- Initialize Apiunto (Wiki extension to fetch remote API data during page parse)
local api = mw.ext.Apiunto

-- Load native Wiki modules
local manufacturers = require('Module:Manufacturers')
local Date = require('Module:Date')._Date
local aggrid = require('mw.ext.aggrid')
local AGGridColumns = require('Module:AGGridColumns')
local Store = require('Module:Entity/Store')

-- Cache resolved manufacturers to avoid redundant lookups
local manufacturerCache = {}

-- Cache resolved redirects to avoid redundant mw.title.new lookups
local redirectCache = {}

-- Helper: Safe JSON decoder that handles UEX response wrapping
local function parseData(rawData)
	if not rawData then
		return nil
	end
	local decoded = nil
	if type(rawData) == 'string' then
		local success, result = pcall(mw.text.jsonDecode, rawData)
		if success then
			decoded = result
		end
	elseif type(rawData) == 'table' then
		decoded = rawData
	end
	return decoded and (decoded.data or decoded) or nil
end

-- Helper: Convert version strings to numeric tables for robust comparison
local function parseVersion(vStr)
	if not vStr or type(vStr) ~= 'string' then
		return { 0, 0, 0, 0 }
	end
	local major, minor, patch, build = vStr:match('^(%d+)%.(%d+)%.(%d+)%-live%.(%d+)')
	if not major then
		major, minor, patch = vStr:match('^(%d+)%.(%d+)%.(%d+)')
		build = vStr:match('(%d+)$')
	end
	return {
		tonumber(major) or 0,
		tonumber(minor) or 0,
		tonumber(patch) or 0,
		tonumber(build) or 0,
	}
end

-- Helper: Numeric comparator for semantic versions
local function isVersionGreater(v1, v2)
	for i = 1, 4 do
		if v1[i] > v2[i] then
			return true
		end
		if v1[i] < v2[i] then
			return false
		end
	end
	return false
end

-- Helper: Safe date comparison supporting timestamps or ISO strings
local function isDateGreater(d1, d2)
	if not d1 then
		return false
	end
	if not d2 then
		return true
	end

	local n1, n2 = tonumber(d1), tonumber(d2)
	if n1 and n2 then
		return n1 > n2
	end
	return tostring(d1) > tostring(d2)
end

-- Helper: Formats timestamp or ISO date to wiki localized format via Module:Date
local function formatDateString(rawDateVal)
	if not rawDateVal then
		return '--'
	end
	local numDate = tonumber(rawDateVal)
	local success, dObj

	if numDate then
		-- Convert Unix timestamp to Julian Date
		local jd = 2440587.5 + numDate / 86400
		success, dObj = pcall(Date, 'juliandate', jd)
	else
		-- Parse ISO date (YYYY-MM-DD) and format via Module:Date
		local y, m, d = tostring(rawDateVal):match('^(%d+)%-%s*(%d+)%-%s*(%d+)')
		if y then
			success, dObj = pcall(Date, { year = tonumber(y), month = tonumber(m), day = tonumber(d) })
		end
	end

	if success and dObj then
		local successFormat, formatted = pcall(function()
			return dObj:text('%B %-d %-Y')
		end)
		if successFormat and formatted then
			return formatted
		end
	end

	return tostring(rawDateVal)
end

-- Helper: Normalizes keys for lookup matching
local function normalizeKey(str)
	if not str then
		return ''
	end
	return mw.text.trim(tostring(str)):lower()
end

-- Helper: Automatically resolve redirect pages (e.g. "Dragonfly Black" -> "Dragonfly") via Scribunto mw.title
local function resolveRedirect(pageName)
	if not pageName or pageName == '' then
		return pageName
	end
	if redirectCache[pageName] then
		return redirectCache[pageName]
	end

	local resolved = pageName
	local success, title = pcall(mw.title.new, pageName)
	if success and title then
		if title.isRedirect then
			local target = title.redirectTarget
			if target and target.prefixedText then
				resolved = target.prefixedText
			end
		end
	end
	redirectCache[pageName] = resolved
	return resolved
end

-- Helper: Splits combined roles (e.g. "Gunship / Light Freight") into a table list
local function splitRoles(val)
	if not val then
		return nil
	end
	local roles = {}
	local function addParts(str)
		for part in str:gmatch('[^/,]+') do
			part = mw.text.trim(part)
			if part ~= '' and part ~= '--' then
				table.insert(roles, part)
			end
		end
	end

	addParts(val)
	return #roles > 0 and roles or nil
end

-- Helper: Resolve manufacturer details using Module:Manufacturers
local function resolveManufacturer(name)
	if type(name) ~= 'string' or name == '' or name == '--' then
		return '--', '--', '--'
	end
	local key = name:lower()

	local cache = manufacturerCache[key]
	if cache then
		return cache.code, cache.page, cache.short
	end

	local resolved = manufacturers.resolve(name)
	local entry
	if resolved then
		entry = {
			code = resolved.code or '--',
			page = resolved.page or '--',
			short = resolved.name or resolved.short or '--',
		}
	else
		entry = { code = name, page = name, short = name }
	end
	manufacturerCache[key] = entry
	return entry.code, entry.page, entry.short
end

-- Helper: Determine location keys from terminal data
local function getTerminalLocationKeys(terminal, rental)
	if terminal and (terminal.id_city or 0) > 0 and terminal.city_name and terminal.city_name ~= '' then
		return { terminal.city_name }
	end

	local name = ((terminal and terminal.fullname) or (rental and rental.terminal_name) or ''):lower()
	local matched = {}

	local isVantage = name:find('vantage')
		or (
			terminal
			and ((terminal.company_name or ''):lower():find('vantage') or (terminal.name or ''):lower():find('vantage'))
		)
	if isVantage then
		table.insert(matched, 'Refinery Deck')
	end

	local isTraveler = name:find('traveler')
		or (
			terminal
			and (
				(terminal.company_name or ''):lower():find('traveler')
				or (terminal.name or ''):lower():find('traveler')
			)
		)
	if isTraveler then
		if (tonumber(terminal and terminal.is_shop_vehicle) or 0) == 0 then
			table.insert(matched, 'Cargo Deck')
		end
	end

	return #matched > 0 and matched or { '--' }
end

-- Helper: Compile list of unique rentable ship names to target our Store query
local function getUniqueShipNames(db)
	local shipNamesMap = {}
	local shipNames = {}
	for _, rental in ipairs(db.prices) do
		local vehicleId = rental.id_vehicle
		if vehicleId then
			local vehicleSpec = db.vehicles[vehicleId] or {}
			local shipName = vehicleSpec.name or rental.vehicle_name
			if shipName and shipName ~= '' then
				local targetName = resolveRedirect(shipName)
				if not shipNamesMap[targetName] then
					shipNamesMap[targetName] = true
					table.insert(shipNames, targetName)
				end
			end
		end
	end
	return shipNames
end

-- Helper: Updates running highest version and latest date modified
local function updateHighestMetadata(spec, highestParsed, highestVersionStr, highestDateVal)
	local ver = spec.game_version or spec.version
	if ver then
		local parsed = parseVersion(ver)
		if isVersionGreater(parsed, highestParsed) then
			highestParsed = parsed
			highestVersionStr = ver
		end
	end

	local dateVal = spec.date_modified
	if dateVal and (not highestDateVal or isDateGreater(dateVal, highestDateVal)) then
		highestDateVal = dateVal
	end
	return highestParsed, highestVersionStr, highestDateVal
end

-- Fetch UEX API datasets
local function getCoreDatabase()
	if not api then
		return nil, 'Error: Apiunto extension not loaded.'
	end

	local ok1, rawPrices = pcall(api.fetch, 'UEX', 'vehicles_rentals_prices_all')
	local ok2, rawVehicles = pcall(api.fetch, 'UEX', 'vehicles')
	local ok3, rawTerminals = pcall(api.fetch, 'UEX', 'terminals')

	if not ok1 then
		return nil, 'Error: Failed to fetch pricing. Apiunto: ' .. tostring(rawPrices)
	end
	if not ok2 then
		return nil, 'Error: Failed to fetch vehicles. Apiunto: ' .. tostring(rawVehicles)
	end

	local pricesList = parseData(rawPrices)
	local vehiclesList = parseData(rawVehicles)
	local terminalsList = parseData(rawTerminals) or {}

	if not pricesList or not vehiclesList then
		return nil, 'Error: UEX data successfully returned, but structures could not be parsed as valid JSON.'
	end

	local vehiclesById = {}
	for _, vehicle in ipairs(vehiclesList) do
		if vehicle.id then
			vehiclesById[vehicle.id] = vehicle
		end
	end

	local terminalsById = {}
	for _, terminal in ipairs(terminalsList) do
		if terminal.id then
			terminalsById[terminal.id] = terminal
		end
	end

	return {
		prices = pricesList,
		vehicles = vehiclesById,
		terminals = terminalsById,
	}
end

--- Maps Module:Entity/Store's resolvePages rows (bare titles, keyed by page
--- name) to this module's lookup shape (manufacturer, role, image, keyed by
--- normalizeKey(page)).
--- @param rows table<string, { name: string|nil, manufacturer: string|nil, role: string|nil, image: string|nil }>
--- @return table<string, { manufacturer: string|nil, role: string|nil, image: string|nil }>
local function mapWikiShips(rows)
	local wikiShips = {}
	for page, row in pairs(rows) do
		wikiShips[normalizeKey(page)] = {
			manufacturer = row.manufacturer,
			role = row.role,
			image = row.image,
		}
	end
	return wikiShips
end

--- Query Bucket for ship properties via Module:Entity/Store.
--- @param shipNames string[]
--- @return table<string, { manufacturer: string|nil, role: string|nil, image: string|nil }>
local function fetchWikiShipProperties(shipNames)
	if not shipNames or #shipNames == 0 then
		return {}
	end

	return mapWikiShips(Store.resolvePages(shipNames))
end

-- Generate table footer containing update metadata and partner badge
local function createTableFooter(versionStr, dateStr)
	local displayVersion = '--'
	if versionStr and versionStr ~= 'Unknown Version' then
		local cleaned = versionStr:match('^([%d%.]+)')
		displayVersion = cleaned and ('Alpha ' .. cleaned) or versionStr
	end

	local displayDate = dateStr or '--'

	local container = mw.html
		.create('div')
		:css('display', 'flex')
		:css('flex-wrap', 'wrap')
		:css('align-items', 'center')
		:css('gap', '1em')
		:css('margin-top', '0.65em')
		:css('font-size', '0.85em')
		:css('color', '#a2a9b1')

	container
		:tag('div')
		:css('display', 'flex')
		:css('align-items', 'center')
		:wikitext('[[File:Powered by UEX.png|class=metadata|link=https://uexcorp.space|140px|powered by UEX]]')

	container
		:tag('div')
		:css('font-style', 'italic')
		:wikitext(string.format('Last updated: %s • Star Citizen %s', displayDate, displayVersion))

	return container
end

-- Helper: Build the location eyebrow (Location Name) for the ship card column
local function locationEyebrow(result)
	local name = result['locKey']
	if type(name) ~= 'string' or name == '' then
		return nil
	end
	local link = aggrid.link(name, name)
	return { text = name, full = name, href = link and link.href }
end

-- MODULE ENTRY POINT: MASTER RENTAL TABLE (AGGrid)
function p.master_table(frame)
	local db, err = getCoreDatabase()
	if not db then
		return tostring(mw.html.create('div'):addClass('error'):wikitext(err or 'Failed to load database'))
	end

	-- Compile list of unique rentable ship names to target our Store query
	local shipNames = getUniqueShipNames(db)
	local wikiShips = fetchWikiShipProperties(shipNames)

	local seen = {}

	for _, rental in ipairs(db.prices) do
		local vehicleId = rental.id_vehicle
		if vehicleId then
			local vehicleSpec = db.vehicles[vehicleId] or {}
			local terminalSpec = db.terminals[rental.id_terminal] or {}
			local locKeys = getTerminalLocationKeys(terminalSpec, rental)

			for _, locKey in ipairs(locKeys) do
				if locKey ~= '--' and locKey ~= '' then
					local uniqKey = vehicleId .. '_' .. locKey
					local existing = seen[uniqKey]

					local currentPrice = tonumber(rental.price_rent) or 0
					local existingPrice = existing and (tonumber(existing.rental.price_rent) or 0) or 0

					if not existing or (currentPrice > 0 and (existingPrice == 0 or currentPrice < existingPrice)) then
						local shipName = vehicleSpec.name or rental.vehicle_name or '--'
						local targetName = resolveRedirect(shipName)

						local wikiData = wikiShips[normalizeKey(targetName)] or {}
						local compCode, compPage, compShort = resolveManufacturer(wikiData.manufacturer)
						local role = splitRoles(wikiData.role)

						seen[uniqKey] = {
							rental = rental,
							vehicleSpec = vehicleSpec,
							locKey = locKey,
							companyCode = compCode,
							companyPage = compPage,
							companyShort = compShort,
							name = shipName,
							role = role,
						}
					end
				end
			end
		end
	end

	local displayList = {}
	local highestVersionStr = 'Unknown Version'
	local highestParsed = { 0, 0, 0, 0 }
	local highestDateVal = nil

	for _, item in pairs(seen) do
		highestParsed, highestVersionStr, highestDateVal =
			updateHighestMetadata(item.vehicleSpec, highestParsed, highestVersionStr, highestDateVal)
		table.insert(displayList, item)
	end

	table.sort(displayList, function(a, b)
		if a.name ~= b.name then
			return a.name < b.name
		end
		if a.locKey ~= b.locKey then
			return a.locKey < b.locKey
		end
		return a.companyShort < b.companyShort
	end)

	local FMT_AUEC = { style = 'number', suffix = ' aUEC' }

	local columns = {
		{
			field = 'ship',
			header = 'Ship / Location',
			kind = 'card',
			titleLabel = 'Name',
			imageLabel = 'Image',
			eyebrow = locationEyebrow,
			filter = 'aggridSet',
			filterOn = 'eyebrow',
			width = 240,
			minWidth = 180,
			flex = 1,
			sort = 'asc',
		},
		{ field = 'shipName', header = 'Ship Name', kind = 'text', label = 'Name', hide = true },
		{
			field = 'company',
			header = 'Manufacturer',
			kind = 'link',
			label = 'Manufacturer',
			filter = 'aggridSet',
			width = 190,
			minWidth = 140,
		},
		{
			field = 'locationName',
			header = 'Location',
			kind = 'text',
			label = 'locKey',
			filter = 'aggridSet',
			hide = true,
		},
		{
			field = 'role',
			header = 'Role',
			kind = 'valueList',
			label = 'Role',
			filter = 'aggridSet',
			width = 120,
			minWidth = 90,
		},
	}
	table.insert(columns, {
		field = 'price1d',
		header = '1 Day Price',
		kind = 'number',
		format = FMT_AUEC,
		label = 'price1d',
		filter = 'agNumberColumnFilter',
		width = 125,
		minWidth = 90,
	})
	table.insert(columns, {
		field = 'price3d',
		header = '3 Days (-10%)',
		kind = 'number',
		format = FMT_AUEC,
		label = 'price3d',
		filter = 'agNumberColumnFilter',
		width = 125,
		minWidth = 90,
	})
	table.insert(columns, {
		field = 'price7d',
		header = '7 Days (-25%)',
		kind = 'number',
		format = FMT_AUEC,
		label = 'price7d',
		filter = 'agNumberColumnFilter',
		width = 125,
		minWidth = 90,
	})

	local results = {}
	for _, item in ipairs(displayList) do
		local price1d = tonumber(item.rental.price_rent)
		local price3d, price7d

		if price1d and price1d > 0 then
			price3d = math.floor(price1d * 3 * 0.90 + 0.5)
			price7d = math.floor(price1d * 7 * 0.75 + 0.5)
		else
			price1d = nil
		end

		local targetName = resolveRedirect(item.name)
		local wikiData = wikiShips[normalizeKey(targetName)] or {}

		local image = wikiData.image

		local result = {
			-- [[Target|Display]] markup, not a bare title: it carries a target and a
			-- different display name, and the link kind's single `label` key has no
			-- other way to carry both.
			Manufacturer = item.companyPage ~= '--' and ('[[' .. item.companyPage .. '|' .. item.companyShort .. ']]')
				or nil,
			companyName = item.companyShort ~= '--' and item.companyShort or nil,
			Name = item.name ~= '--' and item.name or nil,
			Image = image,
			Role = item.role,
			locKey = item.locKey ~= '--' and item.locKey or nil,
			price1d = price1d,
			price3d = price3d,
			price7d = price7d,
		}
		table.insert(results, result)
	end

	local colDefs = AGGridColumns.buildColumnDefs(columns)
	local specMap = {}
	for _, spec in ipairs(columns) do
		specMap[spec.field] = spec
	end
	for _, def in ipairs(colDefs) do
		local spec = specMap[def.field]
		if spec then
			if spec.width then
				def.width = spec.width
			end
			if spec.minWidth then
				def.minWidth = spec.minWidth
			end
			if spec.flex then
				def.flex = spec.flex
			end
			if spec.hide ~= nil then
				def.hide = spec.hide
			end
			if spec.sort then
				def.sort = spec.sort
			end
		end
	end

	local rowHeight = 64

	local gridOptions = {
		columnDefs = colDefs,
		rowData = AGGridColumns.buildRowData(results, columns),
		quickSearch = true,
		includeHiddenColumnsInQuickFilter = true,
		pagination = false,
		rowHeight = rowHeight,
		autoSizeStrategy = { type = 'fitGridWidth' },
		defaultColDef = { sortable = true, resizable = true, wrapText = true, autoHeight = true },
	}

	local styles = frame:extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:RentalVehicleGrid/styles.css' },
	})

	local footer = createTableFooter(highestVersionStr, formatDateString(highestDateVal))

	local mediaSize = rowHeight - 12
	local wrapperStyle = 'width: 100%; --scw-entitycard-media-size: ' .. mediaSize .. 'px;'

	return styles
		.. '<div class="t-pledge-grid" style="'
		.. wrapperStyle
		.. '">'
		.. aggrid.render(gridOptions)
		.. '</div>'
		.. tostring(footer)
end

function p.main(frame)
	return p.master_table(frame)
end

-- Test-only exports. Not part of the public API.
--- @class RentalVehicleGridInternal
--- @field mapWikiShips fun(rows: table): table
p._internal = {
	mapWikiShips = mapWikiShips,
}

return p
