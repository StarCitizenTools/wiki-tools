require('strict')

--- @module Entity/Item/MiningModule
--- Mining module subtype (API type "MiningModifier"). A mining module slots into a
--- mining laser and alters its behaviour. Renders the `mining_modifier` block: the
--- module type (Active / Passive), the laser power modifier, and — for active
--- modules — charges and duration, followed by every effect in the variable
--- `modifier_map` (resistance, shatter damage, instability, …) rendered as a
--- signed percentage. The map keys are auto-titled, so new effects surface without
--- code changes. Modules carry a durability block, so the Component facet renders.

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

--- Title-cases a snake_case modifier key: "shatter_damage" -> "Shatter damage".
---
--- @param key string
--- @return string
local function titleCase(key)
	local s = key:gsub('_', ' ')
	return s:sub(1, 1):upper() .. s:sub(2)
end

--- Formats a numeric modifier as a signed percentage, rounded to one decimal to
--- shed float noise (0.35 * 100 = 34.9999…). "+15.5%", "-30%". Returns nil for
--- non-numeric input.
---
--- @param value number|string|nil
--- @return string|nil
local function signedPct(value)
	local n = tonumber(value)
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

--- @param apiData table
--- @param args table
--- @return table[] Ordered list of section entries with key field
function p.getSections(apiData, args)
	local m = apiData.mining_modifier
	if type(m) ~= 'table' then
		return {}
	end

	local items = {}
	pushItem(items, 'Type', m.type)
	if m.power_modifier ~= nil then
		pushItem(items, 'Power', signedPct(tonumber(m.power_modifier) * 100))
	end
	local charges = tonumber(m.charges)
	if charges and charges > 0 then
		pushItem(items, 'Charges', format.formatNum(charges))
	end
	local duration = tonumber(m.duration)
	if duration and duration > 0 then
		pushItem(items, 'Duration', format.formatNum(duration) .. ' s')
	end

	-- The modifier_map effects vary per module; render each, sorted for a stable order.
	local map = type(m.modifier_map) == 'table' and m.modifier_map or {}
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
			key = 'mining_modifier',
			label = 'Mining module',
			items = items,
		},
	}
end

--- Short description prepends the mount size — "S1 mining module by Musashi
--- Industrial & Starflight Concern" — mirroring the other component descriptors.
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

--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	local m = apiData.mining_modifier
	if type(m) ~= 'table' then
		return {}
	end
	local power = tonumber(m.power_modifier)
	return {
		mining_type = m.type,
		power_modifier = power and (math.floor(power * 1000 + 0.5) / 10) or nil,
		charges = tonumber(m.charges),
		duration = tonumber(m.duration),
	}
end

return p
