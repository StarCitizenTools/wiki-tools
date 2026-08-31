require('strict')

--- @module Entity/Item/WeaponMining
--- Mining laser head subtype (API type "WeaponMining") — the swappable laser fitted
--- to a mining arm / turret, accepting mining modules in its slots. Renders the
--- `mining_laser` block: laser power range, module slots, ranges, extraction
--- throughput, then its built-in `modifier_map` effects. Those are the same
--- vocabulary the modules modify, so the rows come from
--- Entity/Facet/Mining.pushModifierRows rather than a second copy here.

local format = require('Module:Entity/Format')
local item = require('Module:Entity/Item')
local mining = require('Module:Entity/Facet/Mining')
local sectionBuilder = require('Module:Entity/SectionBuilder')

local p = {}

--- @type string
p.parent = 'Entity/Item'

--- Coerces a value to a number, tolerating the API's occasional string forms
--- (e.g. "1850", or a percent like "-80%"). Returns nil for non-numeric input.
---
--- @param value number|string|nil
--- @return number|nil
local function toNumber(value)
	local n = tonumber(value)
	if n == nil and type(value) == 'string' then
		n = tonumber((value:gsub('%%', '')))
	end
	return n
end

--- Formats a plain numeric stat, returning nil when absent so the row collapses.
---
--- @param value number|string|nil
--- @param suffix string|nil  appended after the number (e.g. " m")
--- @return string|nil
local function formatStat(value, suffix)
	local n = toNumber(value)
	if n == nil then
		return nil
	end
	return format.formatNum(n) .. (suffix or '')
end

--- @param apiData table
--- @param args table
--- @return table[] Ordered list of section entries with key field
function p.getSections(apiData, args)
	local ml = apiData.mining_laser
	if type(ml) ~= 'table' then
		return {}
	end

	local items = {}

	-- Laser power is a min-max range; show both when present.
	local lp = type(ml.laser_power) == 'table' and ml.laser_power or {}
	local pmin = toNumber(lp.min) or toNumber(lp.minimum)
	local pmax = toNumber(lp.max) or toNumber(lp.maximum)
	if pmin and pmax then
		sectionBuilder.push(items, 'Mining power', format.formatNum(pmin) .. ' – ' .. format.formatNum(pmax))
	elseif pmax then
		sectionBuilder.push(items, 'Mining power', format.formatNum(pmax))
	end

	sectionBuilder.push(items, 'Module slots', formatStat(ml.module_slots))
	sectionBuilder.push(items, 'Optimal range', formatStat(ml.optimal_range, ' m'))
	sectionBuilder.push(items, 'Maximum range', formatStat(ml.maximum_range, ' m'))
	sectionBuilder.push(items, 'Extraction rate', formatStat(ml.extraction_throughput))

	mining.pushModifierRows(items, ml.modifier_map)

	return sectionBuilder.build(sectionBuilder.section({
		key = 'mining_laser',
		label = 'Mining laser',
		items = items,
	}))
end

--- Short description prepends the mount size — "S1 mining laser head by Greycat
--- Industrial" — mirroring the other component descriptors.
---
--- @param apiData table
--- @param args table
--- @param typeInfo table
--- @param prefix string|nil
--- @return string
function p.getShortDescription(apiData, args, typeInfo, prefix)
	local typeName = typeInfo.name
	if apiData.size then
		typeName = 'S' .. tostring(apiData.size) .. ' ' .. typeName:lower()
	end
	return item.formatShortDescription({ name = typeName }, apiData, args, prefix)
end

--- Contributes mining-laser facets for the type index: power range (min + max),
--- module slots, optimal / maximum range, extraction throughput, and every
--- built-in `modifier_map` effect as a numeric `Modifier <effect>` property (the
--- same naming the modules use, so heads and modules compare on equal terms).
---
--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	local ml = apiData.mining_laser
	if type(ml) ~= 'table' then
		return {}
	end
	local lp = type(ml.laser_power) == 'table' and ml.laser_power or {}
	local data = {
		mining_power_min = toNumber(lp.min) or toNumber(lp.minimum),
		mining_power_max = toNumber(lp.max) or toNumber(lp.maximum),
		module_slots = toNumber(ml.module_slots),
		optimal_range = toNumber(ml.optimal_range),
		maximum_range = toNumber(ml.maximum_range),
		extraction_throughput = toNumber(ml.extraction_throughput),
	}

	local map = type(ml.modifier_map) == 'table' and ml.modifier_map or {}
	for k, v in pairs(map) do
		local n = toNumber(v)
		if n ~= nil then
			data['modifier_' .. k] = n
		end
	end

	return data
end

return p
