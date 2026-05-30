require('strict')

--- @module Entity/Commodity/Mining
--- Pure mining-stat helpers for the Commodity kind: the acquisition label
--- (kind + raw `methods` → "Ship mining" / "Harvesting" / etc), the
--- laser-mining test, and the quality range. No I/O — split out of
--- Module:Entity/Commodity so the kind module keeps only its contract + hooks.

local p = {}

local KIND_VERBS = { mineable = 'mining', harvestable = 'harvesting', salvage = 'salvage' }

-- API `methods` tokens → display label. `Harvestable` is intentionally absent:
-- it merely restates the harvesting verb, so it's dropped (a harvestable then
-- reads as plain "Harvesting"). Unknown tokens pass through unchanged.
local METHOD_LABELS = { ['Ship'] = 'Ship', ['FPS'] = 'FPS', ['Ground Vehicle'] = 'Vehicle' }

-- Methods that use the laser-mining minigame, where signature / instability /
-- resistance are meaningful. FPS and harvestable acquisition don't, so those
-- stats (all zero / nil there) are suppressed for them.
local LASER_METHODS = { ['Ship'] = true, ['Ground Vehicle'] = true }

--- Acquisition label from kind + the raw record's `methods` list, e.g.
--- "Ship mining", "FPS mining", "Vehicle mining", "Harvesting". All methods are
--- joined (commodities are single-method today, but the data permits more).
---
--- @param raw table|nil
--- @param kind string|nil
--- @return string|nil
function p.acquisitionLabel(raw, kind)
	if not kind or kind == 'remains' then
		return nil
	end
	local verb = KIND_VERBS[kind] or kind
	local labels = {}
	for _, m in ipairs(raw and raw.methods or {}) do
		local label = METHOD_LABELS[m] or (m ~= 'Harvestable' and m or nil)
		if label then
			labels[#labels + 1] = label
		end
	end
	if #labels > 0 then
		return table.concat(labels, ', ') .. ' ' .. verb
	end
	return verb:gsub('^%l', string.upper)
end

--- @param raw table|nil
--- @return boolean
function p.isLaserMining(raw)
	for _, m in ipairs(raw and raw.methods or {}) do
		if LASER_METHODS[m] then
			return true
		end
	end
	return false
end

--- Min/max quality across the raw record's locations, as "min–max".
--- @param raw table|nil
--- @return string|nil
function p.qualityRange(raw)
	local locs = raw and raw.locations
	if type(locs) ~= 'table' or not locs[1] then
		return nil
	end
	local lo, hi
	for _, l in ipairs(locs) do
		if l.quality_min and (not lo or l.quality_min < lo) then
			lo = l.quality_min
		end
		if l.quality_max and (not hi or l.quality_max > hi) then
			hi = l.quality_max
		end
	end
	if not lo or not hi then
		return nil
	end
	return tostring(lo) .. '–' .. tostring(hi)
end

return p
