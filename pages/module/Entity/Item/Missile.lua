require('strict')

--- @module Entity/Item/Missile
--- Missile subtype. Vehicle ordnance fired from a missile rack. Renders the
--- warhead (damage, blast radius) and guidance stats (lock signal type, lock
--- time / range / angle, flight speed and range) from the `missile` block. The
--- lock signal type (Infrared / Cross Section / Electromagnetic) is the missile's
--- defining classification: surfaced in the short description like a gun's weapon
--- type ("S1 infrared missile by Behring") and stored as a queryable facet, not a
--- browse category.
---
--- Torpedoes share this block: the API types them `Missile` with `sub_type`
--- "Torpedo", so they dispatch here too. Their `Ship.Missile.Torpedo`
--- classification routes the category + short-description noun to "torpedo"
--- (classifications.json); this module only swaps the stat-section label.

local format = require('Module:Entity/Format')
local item = require('Module:Entity/Item')
local sectionBuilder = require('Module:Entity/SectionBuilder')

local p = {}

--- @type string
p.parent = 'Entity/Item'

--- Normalizes the API's lock signal type to a readable label by splitting
--- CamelCase: "CrossSection" -> "Cross Section". Single-word values
--- ("Infrared", "Electromagnetic") pass through unchanged. Returns nil for a
--- missing/blank value.
---
--- @param raw string|nil
--- @return string|nil
local function signalLabel(raw)
	if type(raw) ~= 'string' or raw == '' then
		return nil
	end
	return (raw:gsub('(%l)(%u)', '%1 %2'))
end

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

--- @param apiData table
--- @param args table
--- @return table[] Ordered list of section entries with key field
function p.getSections(apiData, args)
	local missile = apiData.missile
	if type(missile) ~= 'table' then
		return {}
	end
	local flight = type(missile.flight) == 'table' and missile.flight or {}

	local items = {}
	sectionBuilder.push(items, 'Signal type', signalLabel(missile.signal_type))
	sectionBuilder.push(items, 'Damage', format.formatNum(missile.damage_total))
	sectionBuilder.push(
		items,
		'Explosion radius',
		rangeStr(missile.explosion_radius_min, missile.explosion_radius_max, 'm')
	)
	sectionBuilder.push(items, 'Lock time', missile.lock_time and (format.formatNum(missile.lock_time) .. ' s'))
	sectionBuilder.push(items, 'Lock range', rangeStr(missile.lock_range_min, missile.lock_range_max, 'm'))
	sectionBuilder.push(items, 'Lock angle', missile.lock_angle and (format.formatNum(missile.lock_angle) .. '°'))
	sectionBuilder.push(items, 'Speed', missile.speed and (format.formatNum(missile.speed) .. ' m/s'))
	sectionBuilder.push(items, 'Range', flight.range and (format.formatNum(flight.range) .. ' m'))

	-- Torpedoes (sub_type "Torpedo") share this block; label the stat group with
	-- the player-facing ordnance kind.
	local label = apiData.sub_type == 'Torpedo' and 'Torpedo' or 'Missile'
	return sectionBuilder.build(sectionBuilder.section({
		key = 'missile',
		label = label,
		items = items,
	}))
end

--- Short description surfaces the lock signal type as the missile's specific
--- kind, mirroring how a gun reads "S1 Laser repeater by X": e.g. "S1 infrared
--- missile by Behring". Falls back to the plain type name when the signal type
--- is absent (dumbfire / unknown). Size is prepended when the API has one.
---
--- @param apiData table
--- @param args table
--- @param typeInfo table
--- @param prefix string|nil
--- @return string
function p.getShortDescription(apiData, args, typeInfo, prefix)
	local missile = apiData.missile
	local signal = type(missile) == 'table' and signalLabel(missile.signal_type) or nil
	local typeName = typeInfo.name:lower()
	if signal then
		typeName = signal:lower() .. ' ' .. typeName
	end
	if apiData.size then
		typeName = 'S' .. tostring(apiData.size) .. ' ' .. typeName
	end
	return item.formatShortDescription({ name = typeName }, apiData, args, prefix)
end

--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	local missile = apiData.missile
	if type(missile) ~= 'table' then
		return {}
	end
	local flight = type(missile.flight) == 'table' and missile.flight or {}
	return {
		signal_type = signalLabel(missile.signal_type),
		warhead_damage = tonumber(missile.damage_total),
		explosion_radius = tonumber(missile.explosion_radius_max),
		lock_time = tonumber(missile.lock_time),
		lock_range = tonumber(missile.lock_range_max),
		lock_angle = tonumber(missile.lock_angle),
		missile_speed = tonumber(missile.speed),
		missile_range = tonumber(flight.range),
	}
end

return p
