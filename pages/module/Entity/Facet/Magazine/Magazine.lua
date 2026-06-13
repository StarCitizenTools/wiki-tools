require('strict')

--- @module Entity/Facet/Magazine
--- Magazine facet. A magazine / battery / canister (FPS weapon attachment,
--- sub_type "Magazine") carries a top-level `magazine` block (ammo capacity) plus
--- an `ammunition` block describing the rounds it feeds. Renders the capacity and
--- the ammo's performance: muzzle velocity, range, and damage. Two ammo shapes
--- are handled — ballistic/energy rounds expose `impact_damage_map`; missile /
--- explosive mags expose `detonation_damage_map` + an `explosion_radius` — so the
--- damage row branches on whichever is present. Missile-launcher mags report a
--- zero `max_ammo_count`, so the Capacity row is suppressed when it is 0/absent.

local format = require('Module:Entity/Format')

local p = {}

--- @param apiData table|nil
--- @return boolean
function p.matches(apiData)
	return apiData ~= nil and type(apiData.magazine) == 'table'
end

--- @param value number|string|nil
--- @param unit string
--- @return string|nil
local function withUnit(value, unit)
	local n = tonumber(value)
	if n == nil then
		return nil
	end
	return format.formatNum(n) .. unit
end

--- Formats a damage map ({ physical = 42.5 } / { energy = 18 }) as a type-tagged
--- string ("Physical 42.5", joined with " · " for multi-type rounds). Keys sorted
--- for a stable order. Returns nil when the map is empty / absent.
---
--- @param map table|nil
--- @return string|nil
local function damageString(map)
	if type(map) ~= 'table' then
		return nil
	end
	local keys = {}
	for k in pairs(map) do
		table.insert(keys, k)
	end
	table.sort(keys)
	local parts = {}
	for _, k in ipairs(keys) do
		local n = tonumber(map[k])
		if n ~= nil then
			local typeName = k:sub(1, 1):upper() .. k:sub(2)
			table.insert(parts, typeName .. ' ' .. format.formatNum(n))
		end
	end
	if #parts == 0 then
		return nil
	end
	return table.concat(parts, ' · ')
end

--- The {min, max} explosion radius as "0.5 — 4 m" (em-dash range, matching the
--- Seat facet's range style), or "4 m" when the bounds are equal / only max is
--- present. Returns nil when absent.
---
--- @param radius table|nil
--- @return string|nil
local function explosionRadius(radius)
	if type(radius) ~= 'table' then
		return nil
	end
	local min = tonumber(radius.min)
	local max = tonumber(radius.max)
	if max == nil then
		return nil
	end
	if min == nil or min == max then
		return format.formatNum(max) .. ' m'
	end
	return format.formatNum(min) .. ' — ' .. format.formatNum(max) .. ' m'
end

--- @param apiData table
--- @param args table
--- @return table[] Ordered list of section entries with key field
function p.getSections(apiData, args)
	local mag = apiData.magazine
	if type(mag) ~= 'table' then
		return {}
	end
	local ammo = type(apiData.ammunition) == 'table' and apiData.ammunition or {}

	local items = {}
	local function push(label, content)
		if content ~= nil and content ~= '' then
			table.insert(items, { label = label, content = content })
		end
	end

	local capacity = tonumber(mag.max_ammo_count)
	if capacity and capacity > 0 then
		push('Capacity', format.formatNum(capacity))
	end
	push('Velocity', withUnit(ammo.speed, ' m/s'))
	push('Range', withUnit(ammo.range, ' m'))
	-- Ballistic/energy rounds carry impact_damage_map; missiles carry
	-- detonation_damage_map (+ an explosion radius).
	push('Damage', damageString(ammo.impact_damage_map or ammo.detonation_damage_map))
	push('Explosion radius', explosionRadius(ammo.explosion_radius))

	if #items == 0 then
		return {}
	end

	return {
		{
			key = 'magazine',
			label = 'Magazine',
			collapsible = true,
			items = items,
		},
	}
end

--- Magazine facets for the Magazines index table: capacity + ammo velocity /
--- range, and total damage (summed across the active damage map) as numeric
--- facets.
---
--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	local mag = apiData.magazine
	if type(mag) ~= 'table' then
		return {}
	end
	local ammo = type(apiData.ammunition) == 'table' and apiData.ammunition or {}
	local capacity = tonumber(mag.max_ammo_count)

	local damageTotal = nil
	local map = type(ammo.impact_damage_map) == 'table' and ammo.impact_damage_map
		or (type(ammo.detonation_damage_map) == 'table' and ammo.detonation_damage_map or nil)
	if type(map) == 'table' then
		for _, v in pairs(map) do
			local n = tonumber(v)
			if n ~= nil then
				damageTotal = (damageTotal or 0) + n
			end
		end
	end

	-- Reuse the shared weapon-ammo properties (Ammo / Muzzle velocity / Max range
	-- / Damage) rather than minting magazine-only duplicates, so the index sorts
	-- numerically against the same declared properties guns use.
	return {
		ammo = (capacity and capacity > 0) and capacity or nil,
		muzzle_velocity = tonumber(ammo.speed),
		max_range = tonumber(ammo.range),
		damage = damageTotal,
	}
end

-- Test-only exports. Not part of the public API.
p._internal = {
	damageString = damageString,
	explosionRadius = explosionRadius,
}

return p
