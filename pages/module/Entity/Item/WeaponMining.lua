require('strict')

--- @module Entity/Item/WeaponMining
--- Mining laser head subtype (API type "WeaponMining"). The mining laser head is
--- the swappable laser fitted to a mining arm / turret; it accepts mining modules
--- (Module:Entity/Item/MiningModule) in its module slots. Renders the
--- `mining_laser` block: laser power range, module slots, optimal / maximum range,
--- extraction throughput, then every built-in effect in the variable `modifier_map`
--- (resistance, laser instability, …) as a signed percentage — the same effect
--- vocabulary the modules modify. Heads carry a durability block, so the Component
--- facet renders. The effect helpers mirror Entity/Item/MiningModule.

local format = require('Module:Entity/Format')
local item = require('Module:Entity/Item')

local p = {}

--- @type string
p.parent = 'Entity/Item'

--- Appends a label/content pair only when content is non-empty.
---
--- @param items table[]
--- @param label string
--- @param content string|nil
local function pushItem(items, label, content)
	if content ~= nil and content ~= '' then
		table.insert(items, { label = label, content = content })
	end
end

--- Title-cases a snake_case modifier key: "laser_instability" -> "Laser instability".
---
--- @param key string
--- @return string
local function titleCase(key)
	local s = key:gsub('_', ' ')
	return s:sub(1, 1):upper() .. s:sub(2)
end

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

--- Formats a numeric modifier as a signed percentage, rounded to one decimal.
--- "+25%", "−35%". Returns nil for non-numeric input.
---
--- @param value number|string|nil
--- @return string|nil
local function signedPct(value)
	local n = toNumber(value)
	if n == nil then
		return nil
	end
	local rounded = math.floor(math.abs(n) * 10 + 0.5) / 10
	if n < 0 then
		rounded = -rounded
	end
	local sign = rounded >= 0 and '+' or ''
	return sign .. format.formatNum(rounded) .. '%'
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
		pushItem(items, 'Mining power', format.formatNum(pmin) .. ' – ' .. format.formatNum(pmax))
	elseif pmax then
		pushItem(items, 'Mining power', format.formatNum(pmax))
	end

	pushItem(items, 'Module slots', formatStat(ml.module_slots))
	pushItem(items, 'Optimal range', formatStat(ml.optimal_range, ' m'))
	pushItem(items, 'Maximum range', formatStat(ml.maximum_range, ' m'))
	pushItem(items, 'Extraction rate', formatStat(ml.extraction_throughput))

	-- Built-in modifier_map effects vary per head; render each, sorted for a stable order.
	local map = type(ml.modifier_map) == 'table' and ml.modifier_map or {}
	local keys = {}
	for k in pairs(map) do
		table.insert(keys, k)
	end
	table.sort(keys)
	for _, k in ipairs(keys) do
		pushItem(items, titleCase(k), signedPct(map[k]))
	end

	if #items == 0 then
		return {}
	end

	return {
		{
			key = 'mining_laser',
			label = 'Mining laser',
			items = items,
		},
	}
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
