require('strict')

--- @module Entity/UsedBy
--- Renders the list of vehicles that have this item (typically a vehicle
--- component such as a quantum drive, shield generator, or weapon)
--- installed in their loadout. Inverse of Module:Entity/Related: Related
--- shows variants/set pieces of an item, UsedBy shows the hosts of an
--- item.
---
--- Sibling renderer parallel to Module:Entity/Related — consumes
--- Module:Entity/Data so it shares Apiunto's cache with the Entity
--- infobox and any other Entity-family template on the page. Tile
--- rendering is delegated to Module:Tiles (image + label + fakelink
--- wikilink).
---
--- Items only today (reads apiData.vehicles, populated by the
--- vehicles include on the items endpoint). Non-item entities render
--- the empty-state placeholder. The container always renders so the
--- page layout stays stable.

local data = require('Module:Entity/Data')
local Tiles = require('Module:Tiles')

local p = {}

local EMPTY_STATE_MESSAGE = 'No vehicles known to use this item.'
-- Vehicle hero shots are typically landscape; 16:9 keeps them in the
-- right shape across all column widths.
local TILE_ASPECT_RATIO = '16 / 9'

--- Builds rows from the API's vehicles array. Each row is
--- `{ name, uuid, primary, secondary, sortKey }` where primary is the
--- vehicle name and secondary is the in-game role (e.g.
--- `Medium Fighter`). Sorted by manufacturer code then by name so
--- vehicles from the same brand cluster naturally in the grid without
--- needing explicit subheadings.
---
--- @param vehicles table[]|nil
--- @return { name: string, uuid: string|nil, primary: string, secondary: string, sortKey: string }[]
local function buildRows(vehicles)
	local rows = {}
	if type(vehicles) ~= 'table' then
		return rows
	end
	for _, vehicle in ipairs(vehicles) do
		if vehicle.name then
			-- Manufacturer can be a table (current API shape) or absent
			-- on older entries; fall back to empty so the sort still
			-- orders unbranded entries consistently at the front.
			local manufacturerCode = ''
			if type(vehicle.manufacturer) == 'table' and type(vehicle.manufacturer.code) == 'string' then
				manufacturerCode = vehicle.manufacturer.code
			end
			table.insert(rows, {
				name = vehicle.name,
				uuid = vehicle.uuid,
				primary = vehicle.name,
				secondary = vehicle.role or '',
				sortKey = manufacturerCode .. '|' .. vehicle.name,
			})
		end
	end
	table.sort(rows, function(a, b)
		return a.sortKey < b.sortKey
	end)
	return rows
end

--- Collects unique uuids from rows, preserving first-seen order.
---
--- @param rows { uuid: string|nil }[]
--- @return string[]
local function collectUuids(rows)
	local seen = {}
	local out = {}
	for _, row in ipairs(rows) do
		if row.uuid and not seen[row.uuid] then
			seen[row.uuid] = true
			table.insert(out, row.uuid)
		end
	end
	return out
end

--- Resolves vehicle uuids to their wiki pages and page images via a
--- single mw.smw.ask query against the `uuid` property. Matches both
--- the canonical lowercase `uuid` and the legacy capitalized `UUID`
--- for compatibility with pages that haven't been re-rendered under
--- the new schema. Results filtered to mainspace, non-subobject pages.
--- See Module:Entity/Related.resolveItemPages for the same pattern;
--- duplicated here pending extraction of a shared resolver helper.
---
--- @param uuids string[]
--- @return table<string, { page: string, image: string|nil }>
local function resolveVehiclePages(uuids)
	if #uuids == 0 then
		return {}
	end
	local uuidList = table.concat(uuids, '||')
	local results = mw.smw.ask({
		'[[uuid::' .. uuidList .. ']] OR [[UUID::' .. uuidList .. ']]',
		'?uuid#-=uuid',
		'?UUID#-=uuid_legacy',
		'?#-=page',
		'?Page Image#-=image',
		'limit=' .. tostring(#uuids * 5),
	})
	local map = {}
	if type(results) == 'table' then
		for _, row in ipairs(results) do
			local uuid = (type(row.uuid) == 'string' and row.uuid ~= '' and row.uuid)
				or (type(row.uuid_legacy) == 'string' and row.uuid_legacy ~= '' and row.uuid_legacy)
				or nil
			if uuid and type(row.page) == 'string' and row.page ~= '' and not row.page:find('#', 1, true) then
				local title = mw.title.new(row.page)
				if title and title.namespace == 0 then
					local image = nil
					if type(row.image) == 'string' and row.image ~= '' then
						image = row.image:gsub('^File:', '')
					end
					if not map[uuid] then
						map[uuid] = { page = row.page, image = image }
					end
				end
			end
		end
	end
	return map
end

--- Shapes internal rows into the Tiles row schema.
---
--- @param rows { name: string, uuid: string|nil, primary: string, secondary: string }[]
--- @param pageMap table<string, { page: string, image: string|nil }>
--- @return TilesRow[]
local function toTilesRows(rows, pageMap)
	local tilesRows = {}
	for _, row in ipairs(rows) do
		local resolved = row.uuid and pageMap[row.uuid] or nil
		table.insert(tilesRows, {
			page = (resolved and resolved.page) or row.name,
			linkLabel = row.name,
			image = resolved and resolved.image or nil,
			primary = row.primary,
			secondary = row.secondary,
		})
	end
	return tilesRows
end

--- Renders the empty-state placeholder.
---
--- @return string
local function renderEmpty()
	local styles = mw.getCurrentFrame():extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:Entity/UsedBy/styles.css' },
	})
	local empty = mw.html.create('p'):addClass('t-entity-usedby-empty'):wikitext(EMPTY_STATE_MESSAGE)
	return styles .. tostring(empty)
end

--- Main entry point.
---
--- @param frame table
--- @return string
function p.main(frame)
	local args = data.parseArgs(frame)
	local result = data.get(args)

	if result.hasApiError then
		return renderEmpty()
	end

	local rows = buildRows(result.apiData.vehicles)
	if #rows == 0 then
		return renderEmpty()
	end

	local pageMap = resolveVehiclePages(collectUuids(rows))
	return Tiles.render({
		rows = toTilesRows(rows, pageMap),
		aspectRatio = TILE_ASPECT_RATIO,
	})
end

return p
