require('strict')

--- @module Entity/Facet/Mining
--- Mining facet. Any entity carrying a `mining_modifier` block — a vehicle mining
--- module (API type "MiningModifier") or a handheld FPS mining gadget (type
--- "Gadget", classification "Mining.Gadget") — gets its mining behaviour
--- surfaced: the module type (Active / Passive), the laser power modifier, charges
--- and duration for active modules, then every effect in the variable
--- `modifier_map` (resistance, laser instability, cluster factor, …) as a signed
--- percentage. The map keys are auto-titled, so new effects surface without code
--- changes. The block shape is identical across vehicle modules and FPS mining
--- gadgets, so this one data-driven facet covers both — replacing the rendering
--- that used to live in the MiningModule subtype.

local format = require('Module:Entity/Format')

local p = {}

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

--- Coerces a modifier value to a number, tolerating the API's occasional
--- string-with-percent form ("-80%" instead of -80). Returns nil for input that
--- isn't numeric even after stripping a trailing percent sign.
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

--- Formats a numeric modifier as a signed percentage, rounded to one decimal to
--- shed float noise (0.35 * 100 = 34.9999…). "+15.5%", "-30%". Returns nil for
--- non-numeric input.
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

--- Data-driven match: presence of the `mining_modifier` block.
---
--- @param apiData table|nil
--- @return boolean
function p.matches(apiData)
	return apiData ~= nil and type(apiData.mining_modifier) == 'table'
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
	-- power_modifier is a 0-1 fraction (×100 for %); it can be null on passive
	-- modules, so coerce first and skip when absent. It is a signed bonus/penalty
	-- about a 0 baseline (more laser power is good), so colour it green/red by sign.
	local power = toNumber(m.power_modifier)
	if power ~= nil then
		pushItem(items, 'Power', format.colorBySign(signedPct(power * 100), power))
	end
	local charges = tonumber(m.charges)
	if charges and charges > 0 then
		pushItem(items, 'Charges', format.formatNum(charges))
	end
	local duration = tonumber(m.duration)
	if duration and duration > 0 then
		pushItem(items, 'Duration', format.formatNum(duration) .. ' s')
	end

	-- The modifier_map effects vary per item; render each, sorted for a stable order.
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
			key = 'mining',
			label = 'Mining',
			collapsible = true,
			items = items,
		},
	}
end

--- Mining facets for querying / the type index table: the module type, the power
--- modifier (as a percentage), charges + duration for active modules, and every
--- `modifier_map` effect as a numeric `Modifier <effect>` property (e.g. "Modifier
--- resistance" = 15.5). The effect facets are dynamic, so new effects become
--- queryable without code changes, and the `Modifier <effect>` naming reuses the
--- legacy index's property names.
---
--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	local m = apiData.mining_modifier
	if type(m) ~= 'table' then
		return {}
	end
	local power = toNumber(m.power_modifier)
	local charges = tonumber(m.charges)
	local duration = tonumber(m.duration)
	local data = {
		mining_type = m.type,
		power_modifier = power and (math.floor(power * 1000 + 0.5) / 10) or nil,
		charges = (charges and charges > 0) and charges or nil,
		duration = (duration and duration > 0) and duration or nil,
	}

	local map = type(m.modifier_map) == 'table' and m.modifier_map or {}
	for k, v in pairs(map) do
		local n = toNumber(v)
		if n ~= nil then
			data['modifier_' .. k] = n
		end
	end

	return data
end

-- Test-only exports. Not part of the public API.
p._internal = {
	toNumber = toNumber,
	signedPct = signedPct,
	titleCase = titleCase,
}

return p
