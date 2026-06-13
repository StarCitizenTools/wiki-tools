require('strict')

--- @module Entity/Facet/IronSight
--- Iron sight / optic facet. Weapon sights (reflex, holographic, telescopic)
--- carry a top-level `iron_sight` block describing their ranging behaviour:
--- maximum zeroing range, the range increment per step, and the auto-zeroing
--- time. Telescopic scopes populate these; reflex sights leave them null, so each
--- row renders only when present. Optical magnification is NOT rendered here — it
--- lives in `weapon_modifier.aim` and is owned by the WeaponModifier facet, so a
--- scope shows its zoom under "Modifier" and its ranging under "Sight" without
--- either facet reaching into the other's block.

local format = require('Module:Entity/Format')

local p = {}

--- @param apiData table|nil
--- @return boolean
function p.matches(apiData)
	return apiData ~= nil and type(apiData.iron_sight) == 'table'
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

--- @param apiData table
--- @param args table
--- @return table[] Ordered list of section entries with key field
function p.getSections(apiData, args)
	local s = apiData.iron_sight
	if type(s) ~= 'table' then
		return {}
	end

	local items = {}
	local function push(label, content)
		if content ~= nil and content ~= '' then
			table.insert(items, { label = label, content = content })
		end
	end

	push('Max range', withUnit(s.max_range, ' m'))
	push('Range increment', withUnit(s.range_increment, ' m'))
	push('Auto-zeroing', withUnit(s.auto_zeroing_time, ' s'))

	if #items == 0 then
		return {}
	end

	return {
		{
			key = 'iron_sight',
			label = 'Sight',
			collapsible = true,
			items = items,
		},
	}
end

--- The ranging stats as numeric facets for the Iron sights index table. (Optical
--- magnification is stored by the WeaponModifier facet.)
---
--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	local s = apiData.iron_sight
	if type(s) ~= 'table' then
		return {}
	end
	return {
		max_range = tonumber(s.max_range),
		range_increment = tonumber(s.range_increment),
	}
end

return p
