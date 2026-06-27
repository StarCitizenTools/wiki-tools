require('strict')

--- @module Entity/Vehicle/Stats/Profile
--- Computes the 5-axis class-percentile score for a ship from its apiData and
--- the size-class cohort provided by Module:Entity/Vehicle/ClassStats.
---
--- Axes: Offense / Defense / Mobility / Travel / Stealth.
--- Each axis score = mean of its components' class-percentiles (weight-free).
--- Stealth components are inverted (lower emission = higher score).
--- Axes with no component data are omitted. Returns {} when no cohort.

local classStats = require('Module:Entity/Vehicle/ClassStats')
local format = require('Module:Entity/Format')
local standing = require('Module:Entity/Vehicle/Stats/Standing')
local vehicleUtil = require('Module:Entity/Vehicle/Util')

local p = {}

--- Numeric deep-getter: path(t, 'a', 'b') → t.a.b as a number, or nil.
--- @param t table
--- @return number|nil
local function path(t, ...)
	local cur = t
	for _, key in ipairs({ ... }) do
		if type(cur) ~= 'table' then
			return nil
		end
		cur = cur[key]
	end
	return tonumber(cur)
end

--- Coerce to number, nil when non-numeric.
--- @param x any
--- @return number|nil
local function n(x)
	return tonumber(x)
end

--- Axis definitions: ordered list of { key, label, components }.
--- Each component: { stat, value = function(apiData)->number|nil, invert? }
--- @type table[]
local AXES = {
	{
		key = 'offense',
		label = 'Offense',
		components = {
			{
				stat = 'sustained_dps',
				value = function(apiData)
					local wp = type(apiData.weaponry) == 'table' and apiData.weaponry or {}
					local pilot = n(wp.pilot_sustained_dps)
					local turret = n(wp.turret_sustained_dps)
					if pilot == nil and turret == nil then
						return nil
					end
					local total = (pilot or 0) + (turret or 0)
					return total > 0 and total or nil
				end,
			},
			{
				-- Non-scored: missile/torpedo alpha is burst, not sustained DPS, so it
				-- is shown beside the ring for context and never enters the score.
				stat = 'alpha_payload',
				annotation = true,
				value = function(apiData)
					local total = path(apiData, 'weaponry', 'missiles', 'damage', 'total')
					return (total and total > 0) and total or nil
				end,
				valueText = function(apiData, value)
					local s = format.formatNum(math.floor(value + 0.5))
					local count = path(apiData, 'weaponry', 'missiles', 'count')
					if count and count > 0 then
						local rounded = math.floor(count + 0.5)
						s = s .. ' (' .. format.formatNum(rounded) .. (rounded == 1 and ' shot)' or ' shots)')
					end
					return s
				end,
			},
		},
	},
	{
		key = 'defense',
		label = 'Defense',
		components = {
			{
				stat = 'shield_hp',
				value = function(apiData)
					return n(apiData.shield_hp)
				end,
			},
			{
				stat = 'health',
				value = function(apiData)
					return n(apiData.health)
				end,
			},
			{
				stat = 'armor_deflection',
				value = function(apiData)
					return vehicleUtil.meanDeflection(apiData.armor)
				end,
			},
		},
	},
	{
		key = 'mobility',
		label = 'Mobility',
		components = {
			{
				stat = 'scm_speed',
				value = function(apiData)
					return path(apiData, 'speed', 'scm')
				end,
			},
			{
				stat = 'pitch_rate',
				value = function(apiData)
					return path(apiData, 'agility', 'pitch')
				end,
			},
			{
				stat = 'yaw_rate',
				value = function(apiData)
					return path(apiData, 'agility', 'yaw')
				end,
			},
			{
				stat = 'roll_rate',
				value = function(apiData)
					return path(apiData, 'agility', 'roll')
				end,
			},
		},
	},
	{
		key = 'travel',
		label = 'Travel',
		components = {
			{
				stat = 'max_speed',
				value = function(apiData)
					return path(apiData, 'speed', 'max')
				end,
			},
			{
				stat = 'quantum_speed',
				value = function(apiData)
					local v = path(apiData, 'quantum', 'quantum_speed')
					return v and (v / 1e6) or nil
				end,
			},
			{
				stat = 'quantum_range',
				value = function(apiData)
					local v = path(apiData, 'quantum', 'quantum_range')
					return v and (v / 1e9) or nil
				end,
			},
		},
	},
	{
		key = 'stealth',
		label = 'Stealth',
		components = {
			{
				stat = 'ir_emission',
				value = function(apiData)
					return path(apiData, 'emission', 'ir')
				end,
				invert = true,
			},
			{
				stat = 'em_emission',
				value = function(apiData)
					return path(apiData, 'emission', 'em_max')
				end,
				invert = true,
			},
			{
				stat = 'cross_section',
				value = function(apiData)
					return vehicleUtil.meanCrossSection(apiData.cross_section)
				end,
				invert = true,
			},
		},
	},
}

--- Display metadata per component stat, used to label the breakdown tooltip and
--- format the ship's value (unit suffix; `decimals` rounds, default 0 → integer).
--- @type table<string, { label: string, unit: string?, decimals: number? }>
local COMPONENT_META = {
	sustained_dps = { label = 'Sustained DPS' },
	alpha_payload = { label = 'Alpha payload' },
	shield_hp = { label = 'Shield', unit = ' HP' },
	health = { label = 'Hull', unit = ' HP' },
	armor_deflection = { label = 'Armor deflection' },
	scm_speed = { label = 'SCM speed', unit = ' m/s' },
	pitch_rate = { label = 'Pitch rate', unit = ' \194\176/s' },
	yaw_rate = { label = 'Yaw rate', unit = ' \194\176/s' },
	roll_rate = { label = 'Roll rate', unit = ' \194\176/s' },
	max_speed = { label = 'Max speed', unit = ' m/s' },
	quantum_speed = { label = 'Quantum speed', unit = ' Mm/s' },
	quantum_range = { label = 'Quantum range', unit = ' Gm', decimals = 1 },
	ir_emission = { label = 'IR emission' },
	em_emission = { label = 'EM emission' },
	cross_section = { label = 'Cross-section' },
}

--- Format a component's value for the tooltip: round to `decimals` (default 0),
--- group thousands, append the unit.
--- @param value number
--- @param unit string|nil
--- @param decimals number|nil
--- @return string
local function formatValue(value, unit, decimals)
	local rounded
	if decimals and decimals > 0 then
		local mult = 10 ^ decimals
		rounded = math.floor(value * mult + 0.5) / mult
	else
		rounded = math.floor(value + 0.5)
	end
	return format.formatNum(rounded) .. (unit or '')
end

--- Extract cohort values for a stat key. 'sustained_dps' sums pilot+turret
--- sustained DPS per row (dropping a zero total, matching the ship side); any
--- other key (shield_hp, health, armor_deflection, scm_speed, …) reads the row
--- column directly. Only rows with the value present contribute.
--- @param rows table[]  decoded cohort rows from ClassStats.cohortRows
--- @param statKey string
--- @return number[]
local function cohortValuesFor(rows, statKey)
	local values = {}
	if statKey == 'sustained_dps' then
		for _, row in ipairs(rows) do
			local pilot = row.pilot_sustained_dps
			local turret = row.turret_sustained_dps
			if pilot ~= nil or turret ~= nil then
				-- Match the ship-side derivation: drop a zero total (an unarmed
				-- member is "no firepower", not a 0-DPS data point).
				local total = (pilot or 0) + (turret or 0)
				if total > 0 then
					values[#values + 1] = total
				end
			end
		end
	else
		for _, row in ipairs(rows) do
			local v = row[statKey]
			if v ~= nil then
				values[#values + 1] = v
			end
		end
	end
	return values
end

--- Compute the 5-axis class-percentile scores for a ship, each with the
--- per-component breakdown that produced it (for the explanatory tooltip).
--- @param apiData table  the ship's raw API data
--- @param family string  'ship' | 'ground' | 'gravlev'
--- @param size number|string|nil  numeric size class
--- @return table[]  ordered list of { key, label, score, cohortSize, components }
---   where components = { { label, valueText, percentile, rank }, ... }: each
---   scored stat with its percentile (feeds the ring's mean score) and its rank
---   (1 = best, shown in the tooltip); a non-scored annotation (e.g. missile
---   alpha) carries `annotation = true` and neither. Empty when no cohort.
function p.axisScores(apiData, family, size)
	local rows = classStats.cohortRows(family, size)
	if rows == nil then
		return {}
	end
	local cohortSize = #rows

	local result = {}
	for _, axis in ipairs(AXES) do
		local sum, count = 0, 0
		local components = {}
		for _, comp in ipairs(axis.components) do
			local value = comp.value(apiData)
			if value ~= nil then
				local meta = COMPONENT_META[comp.stat] or {}
				if comp.annotation then
					-- Shown in the breakdown for context; never ranked or scored.
					components[#components + 1] = {
						label = meta.label or comp.stat,
						valueText = comp.valueText and comp.valueText(apiData, value)
							or formatValue(value, meta.unit, meta.decimals),
						annotation = true,
					}
				else
					local cohortValues = cohortValuesFor(rows, comp.stat)
					local pct
					if comp.invert then
						local negated = {}
						for i, v in ipairs(cohortValues) do
							negated[i] = -v
						end
						pct = classStats.percentile(negated, -value)
					else
						pct = classStats.percentile(cohortValues, value)
					end
					if pct ~= nil then
						sum = sum + pct
						count = count + 1
						components[#components + 1] = {
							label = meta.label or comp.stat,
							valueText = formatValue(value, meta.unit, meta.decimals),
							percentile = pct, -- feeds the ring's mean-percentile score
							rank = standing.position(cohortValues, value, comp.invert), -- shown in the tooltip
						}
					end
				end
			end
		end
		if count > 0 then
			result[#result + 1] = {
				key = axis.key,
				label = axis.label,
				score = math.floor(sum / count + 0.5),
				cohortSize = cohortSize,
				components = components,
			}
		end
	end
	return result
end

return p
