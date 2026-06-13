require('strict')

--- @module Entity/Facet/WeaponModifier
--- weapon_modifier facet. Items that modify a weapon when attached or used —
--- FPS weapon attachments (scopes, barrels, …) and the monocular rangefinder
--- gadget — carry a `weapon_modifier` block: optical magnification (`aim`) plus
--- a set of combat multipliers (fire rate, damage, projectile speed, …).
--- Renders a Modifier section; a multiplier shows only when it deviates from 1
--- (a value of 1 is a no-op and would be noise on every attachment).

local format = require('Module:Entity/Format')

local p = {}

--- @param apiData table|nil
--- @return boolean
function p.matches(apiData)
	return apiData ~= nil and type(apiData.weapon_modifier) == 'table'
end

--- A multiplier as "×N", or nil when absent / equal to 1 (no modification).
---
--- @param value number|string|nil
--- @return string|nil
local function mult(value)
	local n = tonumber(value)
	if n == nil or n == 1 then
		return nil
	end
	return '×' .. format.formatNum(n)
end

--- Optical magnification from the `aim` block, e.g. "8×" or "8× / 16×" for a
--- two-stage zoom. Returns nil when there is no zoom beyond 1×.
---
--- @param aim table|nil
--- @return string|nil
local function magnification(aim)
	if type(aim) ~= 'table' then
		return nil
	end
	local z1 = tonumber(aim.zoom_scale)
	local z2 = tonumber(aim.second_zoom_scale)
	local parts = {}
	if z1 and z1 > 1 then
		table.insert(parts, format.formatNum(z1) .. '×')
	end
	if z2 and z2 > 1 and z2 ~= z1 then
		table.insert(parts, format.formatNum(z2) .. '×')
	end
	if #parts == 0 then
		return nil
	end
	return table.concat(parts, ' / ')
end

--- @param apiData table
--- @param args table
--- @return EntitySectionEntry[]
function p.getSections(apiData, args)
	local wm = apiData.weapon_modifier
	if type(wm) ~= 'table' then
		return {}
	end

	local items = {}
	local function push(label, content)
		if content ~= nil and content ~= '' then
			table.insert(items, { label = label, content = content })
		end
	end

	push('Magnification', magnification(wm.aim))
	push('Fire rate', mult(wm.fire_rate_multiplier))
	push('Damage', mult(wm.damage_multiplier))
	push('Damage over time', mult(wm.damage_over_time_multiplier))
	push('Projectile speed', mult(wm.projectile_speed_multiplier))
	push('Ammo cost', mult(wm.ammo_cost_multiplier))
	push('Heat generation', mult(wm.heat_generation_multiplier))
	push('Sound radius', mult(wm.sound_radius_multiplier))
	push('Charge time', mult(wm.charge_time_multiplier))

	if #items == 0 then
		return {}
	end
	return { { key = 'weapon_modifier', label = 'Modifier', collapsible = true, items = items } }
end

--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	local wm = apiData.weapon_modifier
	if type(wm) ~= 'table' then
		return {}
	end
	local aim = type(wm.aim) == 'table' and wm.aim or {}
	local zoom = tonumber(aim.zoom_scale)
	-- Only store a meaningful (>1) magnification.
	return { magnification = (zoom and zoom > 1) and zoom or nil }
end

-- Test-only exports. Not part of the public API.
p._internal = {
	mult = mult,
	magnification = magnification,
}

return p
