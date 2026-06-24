require('strict')

--- @module Entity/Facet/Util
--- Shared, stateless display helpers extracted from individual facets. Output is
--- byte-identical to the per-facet originals (withUnit x5, titleCase x2, rangeStr x1).

local format = require('Module:Entity/Format')

local p = {}

--- format.formatNum(value) .. unit, or nil for a non-numeric value so
--- SectionBuilder.push drops the row. (Was duplicated in Magazine/Heal/IronSight/Gadget/Vehicle.)
--- @param value number|string|nil
--- @param unit string
--- @return string|nil
function p.withUnit(value, unit)
	local n = tonumber(value)
	if n == nil then
		return nil
	end
	return format.formatNum(n) .. unit
end

--- snake_case/underscored key -> Title Case first word ('jump_speed' -> 'Jump speed').
--- (Was duplicated in Mining/Medical.)
--- @param key string
--- @return string
function p.titleCase(key)
	local s = key:gsub('_', ' ')
	return s:sub(1, 1):upper() .. s:sub(2)
end

--- min/max numeric pair as 'lo–hi unit' (en-dash, space before unit), collapsing
--- to a single value when bounds are equal or only one is present; nil when
--- neither is numeric. (Was Grenade.rangeStr. Distinct from Magazine's em-dash
--- explosionRadius style — keep both.)
--- @param min number|string|nil
--- @param max number|string|nil
--- @param unit string
--- @return string|nil
function p.rangeStr(min, max, unit)
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

--- Canonical shared damage types in stable display order (matches
--- Component.RESIST_ORDER). Armor additionally renders 'impact' (append locally);
--- Vehicle uses 'damage_*' keys and keeps its own table.
--- @type { key: string, label: string, abbr: string }[]
p.DAMAGE_TYPES = {
	{ key = 'physical', label = 'Physical', abbr = 'PHY' },
	{ key = 'energy', label = 'Energy', abbr = 'ENG' },
	{ key = 'thermal', label = 'Thermal', abbr = 'THM' },
	{ key = 'distortion', label = 'Distortion', abbr = 'DST' },
	{ key = 'biochemical', label = 'Biochemical', abbr = 'BIO' },
	{ key = 'stun', label = 'Stun', abbr = 'STN' },
}

--- Ordered raw keys (Component.RESIST_ORDER / DamageFalloff.DAMAGE_TYPES shape).
--- @return string[]
function p.damageKeys()
	local out = {}
	for _, dt in ipairs(p.DAMAGE_TYPES) do
		out[#out + 1] = dt.key
	end
	return out
end

--- key -> label map (Component.RESIST_LABEL shape).
--- @return table<string, string>
function p.damageLabels()
	local out = {}
	for _, dt in ipairs(p.DAMAGE_TYPES) do
		out[dt.key] = dt.label
	end
	return out
end

return p
