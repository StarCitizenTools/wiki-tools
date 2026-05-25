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
local PageResolver = require('Module:Entity/PageResolver')
local Tiles = require('Module:Tiles')

local p = {}

local EMPTY_STATE_MESSAGE = 'No vehicles known to use this item.'
-- Vehicle hero shots are typically landscape; 16:9 keeps them in the
-- right shape across all column widths.
local TILE_ASPECT_RATIO = '16 / 9'
-- 16:9 at the Tiles default 120px floor gives 67px-tall tiles — too
-- small to read the vehicle name. 200px lifts the floor so each tile
-- stays at ~113px tall while still fitting 4–6 columns at typical
-- desktop widths.
local TILE_MIN_WIDTH = '200px'

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

	local pageMap = PageResolver.resolve(collectUuids(rows))
	return Tiles.render({
		rows = toTilesRows(rows, pageMap),
		aspectRatio = TILE_ASPECT_RATIO,
		tileMinWidth = TILE_MIN_WIDTH,
	})
end

return p
