require('strict')

--- @module Entity/StatFormat
--- Central display-scale registry for numeric stats rendered as bars or ranges.
--- Keeps the min/max axis bounds and unit for each stat in one place so facets
--- stop hardcoding them and a new rich-formatted stat just adds one entry here
--- instead of scattering scales across facets.
---
--- Maxes are hand-set round numbers with a little headroom — cheaper and far
--- lower-churn than live SMW max queries on every render; refresh them from SMW
--- (e.g. a maintenance pass) if drift becomes an issue.

local p = {}

--- @class StatScale
--- @field min number Axis / scale lower bound.
--- @field max number Axis / scale upper bound.
--- @field unit string|nil Display unit appended to values (e.g. "REM"). Optional.

--- @type table<string, StatScale>
local SCALES = {
	temperature = { min = -250, max = 250, unit = '°C' },
	radiation_capacity = { min = 0, max = 55000, unit = 'REM' },
	radiation_dissipation = { min = 0, max = 260, unit = 'REM/s' },
}

--- The display scale for a stat key, or nil when none is registered.
---
--- @param key string
--- @return StatScale|nil
function p.get(key)
	return SCALES[key]
end

--- Resistance percent from a "damage taken" multiplier: 1.0 = full damage (0%),
--- 0.6 = 40% resistant. Whole-number percent, or nil for a non-numeric input.
--- @param multiplier any
--- @return number|nil
function p.resistancePercent(multiplier)
	local mult = tonumber(multiplier)
	if mult == nil then
		return nil
	end
	return math.floor((1 - mult) * 100 + 0.5)
end

return p
