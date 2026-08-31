require('strict')

--- @module Entity/Facet/WeaponModifier
--- weapon_modifier facet. Items that modify a weapon when attached or used —
--- FPS weapon attachments (scopes, barrels, suppressors, …) and the monocular
--- rangefinder gadget — carry a `weapon_modifier` block. This facet is the single
--- comprehensive renderer of that block: optical magnification (`aim`), the flat
--- combat multipliers (fire rate, damage, projectile speed, …), and the nested
--- handling sub-tables (`recoil`, `spread`) that barrels/compensators alter.
--- Every multiplier shows only when it deviates from 1 (a value of 1 is a no-op
--- and would be noise on every attachment), so an item renders only the rows it
--- actually changes. Guns do NOT carry this block (their spread/recoil live in
--- `personal_weapon`), so the facet stays scoped to attachments + the rangefinder.

local format = require('Module:Entity/Format')
local sectionBuilder = require('Module:Entity/SectionBuilder')

local p = {}

--- Mining modules are excluded: they carry a `weapon_modifier` block whose only
--- non-neutral field is `damage_multiplier`, which is the mining laser's power and
--- is rendered by Entity/Facet/Mining under CIG's own name for it. Matching here too
--- would repeat that one number as a second row, "Damage ×1.35".
---
--- @param apiData table|nil
--- @return boolean
function p.matches(apiData)
	if apiData == nil or type(apiData.weapon_modifier) ~= 'table' then
		return false
	end
	return type(apiData.mining_modifier) ~= 'table'
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

--- A multiplier as "×N", coloured by whether the modification is a buff or nerf:
--- multipliers pivot at 1, and `goodDirection` says which side is good (e.g. a
--- recoil ×0.8 is good = 'lower', a damage ×1.2 is good = 'higher'). nil at 1/absent.
---
--- @param value number|string|nil
--- @param goodDirection string 'higher' | 'lower'
--- @return string|nil
local function coloredMult(value, goodDirection)
	local text = mult(value)
	if text == nil then
		return nil
	end
	return format.colorByDirection(text, value, 1, goodDirection)
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

--- The four spread multipliers (min / max / first-attack / per-attack) are
--- near-always equal, so collapse them to one "×N". When they genuinely differ,
--- show the distinct non-1 values joined, so nothing is silently hidden. Returns
--- nil when every spread multiplier is absent or 1.
---
--- @param spread table|nil
--- @return string|nil
local function spreadMult(spread)
	if type(spread) ~= 'table' then
		return nil
	end
	local seen, ordered = {}, {}
	for _, key in ipairs({ 'min_multiplier', 'max_multiplier', 'first_attack_multiplier', 'per_attack_multiplier' }) do
		local n = tonumber(spread[key])
		if n ~= nil and n ~= 1 then
			local label = '×' .. format.formatNum(n)
			if not seen[label] then
				seen[label] = true
				table.insert(ordered, label)
			end
		end
	end
	if #ordered == 0 then
		return nil
	end
	return table.concat(ordered, ' / ')
end

--- spreadMult, coloured. Spread is lower-is-better (less spread is good) and the four
--- multipliers move together, so colour the whole string by the first non-1 value.
---
--- @param spread table|nil
--- @return string|nil
local function coloredSpread(spread)
	local text = spreadMult(spread)
	if text == nil then
		return nil
	end
	for _, key in ipairs({ 'max_multiplier', 'min_multiplier', 'first_attack_multiplier', 'per_attack_multiplier' }) do
		local n = tonumber(spread[key])
		if n ~= nil and n ~= 1 then
			return format.colorByDirection(text, n, 1, 'lower')
		end
	end
	return text
end

--- @param apiData table
--- @param args table
--- @return EntitySectionEntry[]
function p.getSections(apiData, args)
	local wm = apiData.weapon_modifier
	if type(wm) ~= 'table' then
		return {}
	end
	local recoil = type(wm.recoil) == 'table' and wm.recoil or {}

	local items = {}

	-- Magnification is a spec figure, not a buff/nerf, so it is left uncoloured.
	-- Every other row is a multiplier coloured green/red by its good direction:
	-- more damage / fire rate / speed / recovery is good; less recoil / spread /
	-- heat / ammo cost / sound / charge / ADS time is good.
	sectionBuilder.push(items, 'Magnification', magnification(wm.aim))
	sectionBuilder.push(items, 'Fire rate', coloredMult(wm.fire_rate_multiplier, 'higher'))
	sectionBuilder.push(items, 'Damage', coloredMult(wm.damage_multiplier, 'higher'))
	sectionBuilder.push(items, 'Damage over time', coloredMult(wm.damage_over_time_multiplier, 'higher'))
	sectionBuilder.push(items, 'Projectile speed', coloredMult(wm.projectile_speed_multiplier, 'higher'))
	sectionBuilder.push(items, 'Ammo cost', coloredMult(wm.ammo_cost_multiplier, 'lower'))
	sectionBuilder.push(items, 'Heat generation', coloredMult(wm.heat_generation_multiplier, 'lower'))
	sectionBuilder.push(items, 'Sound radius', coloredMult(wm.sound_radius_multiplier, 'lower'))
	sectionBuilder.push(items, 'Charge time', coloredMult(wm.charge_time_multiplier, 'lower'))
	-- Nested handling sub-tables — the player-meaningful effect of barrels.
	sectionBuilder.push(items, 'Recoil', coloredMult(recoil.multiplier, 'lower'))
	sectionBuilder.push(items, 'Recoil recovery', coloredMult(recoil.decay_multiplier, 'higher'))
	sectionBuilder.push(items, 'Spread', coloredSpread(wm.spread))
	sectionBuilder.push(
		items,
		'Spread recovery',
		coloredMult(type(wm.spread) == 'table' and wm.spread.decay_multiplier or nil, 'higher')
	)
	-- ADS speed penalty/bonus (compensators slow the aim-down-sights transition).
	sectionBuilder.push(
		items,
		'ADS time',
		coloredMult(type(wm.aim) == 'table' and wm.aim.zoom_time_scale or nil, 'lower')
	)

	return sectionBuilder.build(
		sectionBuilder.section({ key = 'weapon_modifier', label = 'Modifier', collapsible = true, items = items })
	)
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
	spreadMult = spreadMult,
}

return p
