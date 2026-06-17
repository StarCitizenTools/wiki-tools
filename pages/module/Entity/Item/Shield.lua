require('strict')

--- @module Entity/Item/Shield
--- Shield generator subtype. Projects the vehicle's shield bubble. The Component
--- facet renders the generator hardware's shared stats (health, EM / IR,
--- resistance) off the durability block; this adds the shield-performance rows:
--- shield HP, regeneration, the regen delays, and the shield bubble's
--- per-damage-type absorption and resistance.

local format = require('Module:Entity/Format')
local sectionBuilder = require('Module:Entity/SectionBuilder')

local p = {}

--- @type string
p.parent = 'Entity/Item'

-- Damage types shown in the absorption / resistance rows, in a stable order.
local DAMAGE_ORDER = { 'physical', 'energy', 'thermal', 'distortion', 'biochemical', 'stun' }
local DAMAGE_LABEL = {
	physical = 'Physical',
	energy = 'Energy',
	thermal = 'Thermal',
	distortion = 'Distortion',
	biochemical = 'Biochemical',
	stun = 'Stun',
}

--- Formats a per-damage-type map of `{ min, max }` factors (0..1) as a compact
--- "Type X%" / "Type lo–hi%" list, joined with " · ". The min/max spread is the
--- shield's unhardened..hardened range; equal bounds collapse to one value. Only
--- types for which `keep(lo, hi)` is true are listed, so the row shows just the
--- meaningful entries (and the whole row collapses to nil when none qualify).
---
--- @param map table|nil  per-type { min = number, max = number }
--- @param keep fun(lo: number, hi: number): boolean
--- @return string|nil
local function formatDamageMap(map, keep)
	if type(map) ~= 'table' then
		return nil
	end
	local parts = {}
	for _, key in ipairs(DAMAGE_ORDER) do
		local entry = map[key]
		if type(entry) == 'table' then
			local lo, hi = tonumber(entry.min), tonumber(entry.max)
			if lo and hi and keep(lo, hi) then
				local loPct = math.floor(lo * 100 + 0.5)
				local hiPct = math.floor(hi * 100 + 0.5)
				local text = loPct == hiPct and (loPct .. '%') or (loPct .. '–' .. hiPct .. '%')
				table.insert(parts, DAMAGE_LABEL[key] .. ' ' .. text)
			end
		end
	end
	if #parts == 0 then
		return nil
	end
	return table.concat(parts, ' · ')
end

--- @param apiData table
--- @param args table
--- @return table[] Ordered list of section entries with key field
function p.getSections(apiData, args)
	local shield = apiData.shield
	if type(shield) ~= 'table' then
		return {}
	end

	local items = {}

	-- regen_delay carries the pause before the shield starts recharging:
	-- `damage` after any hit, `downed` (longer) after a full depletion.
	local delay = type(shield.regen_delay) == 'table' and shield.regen_delay or {}

	sectionBuilder.push(items, 'Shield HP', shield.max_health and format.formatNum(shield.max_health))
	sectionBuilder.push(items, 'Regeneration', shield.regen_rate and (format.formatNum(shield.regen_rate) .. ' HP/s'))
	sectionBuilder.push(items, 'Regen delay', delay.damage and (format.formatNum(delay.damage) .. ' s'))
	sectionBuilder.push(items, 'Downed delay', delay.downed and (format.formatNum(delay.downed) .. ' s'))
	-- Absorption: fraction of each damage type the shield intercepts. Types it
	-- fully absorbs (max >= 1) are the default and omitted; the row surfaces the
	-- types that partially bypass to the hull (e.g. physical on most shields).
	sectionBuilder.push(
		items,
		'Absorption',
		formatDamageMap(shield.absorption, function(_, hi)
			return hi < 1
		end)
	)
	-- Resistance: damage reduction on what the shield absorbs. Only types with
	-- some resistance (max > 0) are listed.
	sectionBuilder.push(
		items,
		'Resistance',
		formatDamageMap(shield.resistance, function(_, hi)
			return hi > 0
		end)
	)

	return sectionBuilder.build(sectionBuilder.section({
		key = 'shield',
		label = 'Shield',
		items = items,
	}))
end

--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	local shield = apiData.shield
	if type(shield) ~= 'table' then
		return {}
	end
	local delay = type(shield.regen_delay) == 'table' and shield.regen_delay or {}
	return {
		shield_health = tonumber(shield.max_health),
		shield_regeneration = tonumber(shield.regen_rate),
		shield_regen_delay = tonumber(delay.damage),
	}
end

-- Test-only exports. Not part of the public API.
p._internal = {
	formatDamageMap = formatDamageMap,
}

return p
