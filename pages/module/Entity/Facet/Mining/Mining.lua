require('strict')

--- @module Entity/Facet/Mining
--- Mining facet. Fires on any entity carrying a `mining_modifier` block — a vehicle
--- mining module (API type "MiningModifier") and a handheld FPS mining gadget
--- ("Gadget" / "Mining.Gadget") share its shape — and renders the module type,
--- laser power modifier, charges, duration, then the `modifier_map` effects.
--- Mining laser heads carry the same effect vocabulary under `mining_laser`, so
--- Entity/Item/WeaponMining renders its rows through pushModifierRows() too.

local format = require('Module:Entity/Format')
local sectionBuilder = require('Module:Entity/SectionBuilder')
local Util = require('Module:Entity/Facet/Util')

local p = {}

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

--- The mining effects, in the game's display order. `good` is the direction that
--- helps the miner, per the in-game stat descriptions; nil leaves a row uncoloured.
--- `negate` flips the API's value first — see DUPLICATE_OF_FILTER.
---
--- Labels are the game's `hud_mining_modifier_*` strings, not the API key names:
--- the game says "Instability" for `laser_instability` and "Optimal Charge Window"
--- for `optimal_charge_window_size`. Don't "fix" them back to match the keys.
---
--- @type { key: string, label: string, good: string|nil, negate: boolean|nil, facetKey: string|nil }[]
p.MODIFIER_EFFECTS = {
	{ key = 'laser_instability', label = 'Instability', good = 'lower' },
	{ key = 'resistance', label = 'Resistance', good = 'lower' },
	{ key = 'shatter_damage', label = 'Shatter damage', good = 'lower' },
	{ key = 'optimal_charge_window_size', label = 'Optimal charge window', good = 'higher' },
	{ key = 'overcharge_rate', label = 'Overcharge rate', good = 'lower' },
	{ key = 'optimal_charge_rate', label = 'Optimal charge rate', good = 'higher' },
	{ key = 'cluster_factor', label = 'Cluster factor', good = 'higher' },
	{
		key = 'all_charge_rates',
		label = 'Inert material level',
		good = 'lower',
		negate = true,
		facetKey = 'inert_materials',
	},
}

--- `all_charge_rates` and `inert_materials` are one game value (`filterModifier`)
--- reaching the API twice, with only the laser-head copy of `inert_materials`
--- negated — a head arrives as +30 / −30, a module as +20 / +20. Neither name is
--- the game's: the item card calls it "Inert Material Level" and states it as a
--- reduction ("-20%" where the API says +20), filtering being able only to remove.
--- So one row is rendered, from `all_charge_rates` negated, and `inert_materials`
--- is dropped.
---
--- @type table<string, boolean>
local DUPLICATE_OF_FILTER = { inert_materials = true }

--- The two laser-power stats CIG names on a module's item card. `power_modifier` is
--- one number for both: it carries whichever beam the module's first UI-visible
--- modifier targets, so on its own it cannot say which. `description_data` names
--- them, in absolute form ("135%", not "+35%").
---
--- @type { name: string, label: string, facetKey: string }[]
local POWER_STATS = {
	{ name = 'Mining Laser Power', label = 'Mining laser power', facetKey = 'modifier_mining_laser_power' },
	{
		name = 'Extraction Laser Power',
		label = 'Extraction laser power',
		facetKey = 'modifier_extraction_laser_power',
	},
}

--- Resolves the laser-power stats to `{ [facetKey] = <signed percentage> }`, so the
--- rows and the stored facets cannot disagree about which beam a number belongs to.
---
--- `description_data` names each beam; `power_modifier` does not, carrying whichever
--- one the module's first UI-visible modifier targets. Clearcut / Deluge / Overrun
--- get an empty `description_data`, so they fall back to
--- `weapon_modifier.damage_multiplier` — always the fracture beam, hence always
--- mining laser power. Deluge and Overrun also carry an extraction figure that
--- reaches no API field; it is dropped rather than mislabelled.
---
--- @param apiData table
--- @return table<string, number>
function p.powerFacets(apiData)
	local data = {}
	local dd = type(apiData.description_data) == 'table' and apiData.description_data or {}
	for _, stat in ipairs(POWER_STATS) do
		for _, entry in ipairs(dd) do
			if type(entry) == 'table' and entry.name == stat.name then
				local pct = toNumber(entry.value)
				if pct ~= nil then
					data[stat.facetKey] = pct - 100
				end
				break
			end
		end
	end
	if next(data) ~= nil then
		return data
	end

	local wm = type(apiData.weapon_modifier) == 'table' and apiData.weapon_modifier or {}
	local multiplier = toNumber(wm.damage_multiplier)
	if multiplier ~= nil and multiplier ~= 1 then
		data[POWER_STATS[1].facetKey] = (multiplier - 1) * 100
	end
	return data
end

--- Pushes the laser-power rows, preferring the named `description_data` entries.
--- Clearcut / Deluge / Overrun get an empty `description_data`, so they fall back to
--- `weapon_modifier.damage_multiplier` — always the fracture beam, hence always
--- mining laser power. Deluge and Overrun also carry an extraction figure that
--- reaches no API field; it is dropped rather than mislabelled.
---
--- @param items EntityItemData[]
--- @param apiData table
local function pushPowerRows(items, apiData)
	local facets = p.powerFacets(apiData)
	for _, stat in ipairs(POWER_STATS) do
		local delta = facets[stat.facetKey]
		if delta ~= nil then
			sectionBuilder.push(items, stat.label, format.colorBySign(signedPct(delta), delta))
		end
	end
end

--- The `modifier_map` effects as flat `modifier_<effect>` facets, carrying the same
--- corrections the rows carry: the duplicated filter figure is dropped and its
--- survivor negated, under the established `inert_materials` name. Storage and
--- display therefore cannot drift apart.
---
--- @param map table<string, number|string>|nil
--- @return table<string, number>
function p.modifierFacets(map)
	local data = {}
	if type(map) ~= 'table' then
		return data
	end

	local handled = {}
	for k in pairs(DUPLICATE_OF_FILTER) do
		handled[k] = true
	end
	for _, effect in ipairs(p.MODIFIER_EFFECTS) do
		handled[effect.key] = true
		local n = toNumber(map[effect.key])
		if n ~= nil then
			data['modifier_' .. (effect.facetKey or effect.key)] = effect.negate and -n or n
		end
	end

	for k, v in pairs(map) do
		if not handled[k] then
			local n = toNumber(v)
			if n ~= nil then
				data['modifier_' .. k] = n
			end
		end
	end

	return data
end

--- Pushes one row per `modifier_map` effect, MODIFIER_EFFECTS first. Keys outside
--- that table still render — auto-titled, uncoloured, sorted — so an effect the API
--- adds later surfaces without a code change.
---
--- @param items EntityItemData[]  the row accumulator
--- @param map table<string, number|string>|nil  a modifier_map block
--- @return EntityItemData[] items
function p.pushModifierRows(items, map)
	if type(map) ~= 'table' then
		return items
	end

	local seen = {}
	for k in pairs(DUPLICATE_OF_FILTER) do
		seen[k] = true
	end
	for _, effect in ipairs(p.MODIFIER_EFFECTS) do
		seen[effect.key] = true
		local n = toNumber(map[effect.key])
		if n ~= nil then
			if effect.negate then
				n = -n
			end
			local text = signedPct(n)
			if effect.good then
				text = format.colorByDirection(text, n, 0, effect.good)
			end
			sectionBuilder.push(items, effect.label, text)
		end
	end

	local extras = {}
	for k in pairs(map) do
		if not seen[k] then
			extras[#extras + 1] = k
		end
	end
	table.sort(extras)
	for _, k in ipairs(extras) do
		sectionBuilder.push(items, Util.titleCase(k), signedPct(map[k]))
	end

	return items
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
	sectionBuilder.push(items, 'Type', m.type)
	pushPowerRows(items, apiData)
	local charges = tonumber(m.charges)
	if charges and charges > 0 then
		sectionBuilder.push(items, 'Charges', format.formatNum(charges))
	end
	local duration = tonumber(m.duration)
	if duration and duration > 0 then
		sectionBuilder.push(items, 'Duration', format.formatNum(duration) .. ' s')
	end

	p.pushModifierRows(items, m.modifier_map)

	return sectionBuilder.build(sectionBuilder.section({
		key = 'mining',
		label = 'Mining',
		collapsible = true,
		items = items,
	}))
end

--- Mining facets for querying / the type index table: the module type, each laser
--- beam's power modifier, charges + duration for active modules, and every
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
	local charges = tonumber(m.charges)
	local duration = tonumber(m.duration)
	local data = {
		mining_type = m.type,
		charges = (charges and charges > 0) and charges or nil,
		duration = (duration and duration > 0) and duration or nil,
	}

	-- The two beams are stored separately. The API's own `power_modifier` is NOT
	-- stored: it is whichever beam happened to come first, so a query on it compares
	-- fracture power against extraction power without saying so.
	for k, v in pairs(p.powerFacets(apiData)) do
		data[k] = v
	end
	for k, v in pairs(p.modifierFacets(m.modifier_map)) do
		data[k] = v
	end

	return data
end

-- Test-only exports. Not part of the public API.
p._internal = {
	toNumber = toNumber,
	signedPct = signedPct,
	titleCase = Util.titleCase,
}

return p
