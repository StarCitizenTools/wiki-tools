require('strict')

--- @module Entity/Facet/Grenade
--- Grenade facet. Thrown FPS ordnance (sub_type Grenade) carries a `grenade`
--- block: damage type, blast damage, and an area-of-effect radius range. Many
--- entries in this sub_type are actually flares / light sticks / rescue lights
--- with an all-null block — the facet collapses for those (renders nothing),
--- leaving them as plain items.

local format = require('Module:Entity/Format')

local p = {}

--- Formats a min/max numeric pair as "lo–hi unit", collapsing to a single value
--- when the bounds are equal or only one is present. Returns nil when neither
--- bound is numeric.
---
--- @param min number|string|nil
--- @param max number|string|nil
--- @param unit string
--- @return string|nil
local function rangeStr(min, max, unit)
	local lo, hi = tonumber(min), tonumber(max)
	if lo == nil and hi == nil then
		return nil
	end
	if lo == nil then
		return format.formatNum(hi) .. ' ' .. unit
	end
	if hi == nil or hi == lo then
		return format.formatNum(lo) .. ' ' .. unit
	end
	return format.formatNum(lo) .. '–' .. format.formatNum(hi) .. ' ' .. unit
end

--- @param apiData table|nil
--- @return boolean
function p.matches(apiData)
	return apiData ~= nil and type(apiData.grenade) == 'table'
end

--- @param apiData table
--- @param args table
--- @return EntitySectionEntry[]
function p.getSections(apiData, args)
	local g = apiData.grenade
	if type(g) ~= 'table' then
		return {}
	end
	local aoe = type(g.aoe) == 'table' and g.aoe or {}

	local items = {}
	local function push(label, content)
		if content ~= nil and content ~= '' then
			table.insert(items, { label = label, content = content })
		end
	end

	push('Damage type', type(g.damage_type) == 'string' and g.damage_type ~= '' and g.damage_type or nil)
	push('Damage', format.formatNum(g.damage))
	local rMin = aoe.min ~= nil and aoe.min or aoe.minimum
	local rMax = aoe.max ~= nil and aoe.max or aoe.maximum
	push('Blast radius', rangeStr(rMin, rMax, 'm'))

	if #items == 0 then
		return {}
	end
	return { { key = 'grenade', label = 'Grenade', collapsible = true, items = items } }
end

--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	local g = apiData.grenade
	if type(g) ~= 'table' then
		return {}
	end
	local aoe = type(g.aoe) == 'table' and g.aoe or {}
	return {
		damage = tonumber(g.damage),
		damage_type = type(g.damage_type) == 'string' and g.damage_type ~= '' and g.damage_type or nil,
		blast_radius = tonumber(aoe.max ~= nil and aoe.max or aoe.maximum),
	}
end

-- Test-only exports. Not part of the public API.
p._internal = {
	rangeStr = rangeStr,
}

return p
