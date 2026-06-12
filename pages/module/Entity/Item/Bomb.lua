require('strict')

--- @module Entity/Item/Bomb
--- Bomb subtype. Vehicle ordnance dropped from a bomb rack — unguided, so there
--- is no signal/lock block like a missile. Renders the warhead from the `bomb`
--- block: total explosion damage, blast radius, arming time, and the maximum drop
--- angle. Bombs also carry a durability block, so the Component facet renders the
--- hardware stats (health, resistance) alongside this section.

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

--- Formats a min/max numeric pair as "lo–hi unit", collapsing to a single value
--- when the bounds are equal or only one is present. Returns nil when neither
--- bound is numeric (e.g. the size 10 Colossus reports null radii).
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

--- Rounds a numeric damage value to a whole number (the API reports fractional
--- totals like 568296.99). Returns nil for non-numeric input.
---
--- @param value number|string|nil
--- @return number|nil
local function roundDamage(value)
	local n = tonumber(value)
	if n == nil then
		return nil
	end
	return math.floor(n + 0.5)
end

--- @param apiData table
--- @param args table
--- @return table[] Ordered list of section entries with key field
function p.getSections(apiData, args)
	local bomb = apiData.bomb
	if type(bomb) ~= 'table' then
		return {}
	end
	local explosion = type(bomb.explosion) == 'table' and bomb.explosion or {}
	local delays = type(bomb.delays) == 'table' and bomb.delays or {}

	local damage = roundDamage(bomb.damage_total)
	-- Radii live on the block directly or under `explosion`; prefer whichever is set.
	local rMin = bomb.explosion_radius_min ~= nil and bomb.explosion_radius_min or explosion.radius_min
	local rMax = bomb.explosion_radius_max ~= nil and bomb.explosion_radius_max or explosion.radius_max
	local arm = bomb.arm_time ~= nil and bomb.arm_time or delays.arm_time

	local items = {}
	pushItem(items, 'Damage', damage and format.formatNum(damage))
	pushItem(items, 'Explosion radius', rangeStr(rMin, rMax, 'm'))
	pushItem(items, 'Arm time', arm and (format.formatNum(arm) .. ' s'))
	pushItem(items, 'Drop angle', bomb.maximum_drop_angle and (format.formatNum(bomb.maximum_drop_angle) .. '°'))

	if #items == 0 then
		return {}
	end

	return {
		{
			key = 'bomb',
			label = 'Bomb',
			items = items,
		},
	}
end

--- Short description prepends the size to the bomb type — "S10 bomb by FireStorm
--- Kinetics" — mirroring the missile / gun descriptors. Size is omitted only when
--- the API has none.
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
	local bomb = apiData.bomb
	if type(bomb) ~= 'table' then
		return {}
	end
	local explosion = type(bomb.explosion) == 'table' and bomb.explosion or {}
	local delays = type(bomb.delays) == 'table' and bomb.delays or {}
	local rMax = bomb.explosion_radius_max ~= nil and bomb.explosion_radius_max or explosion.radius_max
	local arm = bomb.arm_time ~= nil and bomb.arm_time or delays.arm_time
	return {
		warhead_damage = roundDamage(bomb.damage_total),
		explosion_radius = tonumber(rMax),
		arm_time = tonumber(arm),
		drop_angle = tonumber(bomb.maximum_drop_angle),
	}
end

return p
