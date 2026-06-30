require('strict')

--- @module Entity/Vehicle/Stats
--- Vehicle Stats sub-builder: keyless subsection tabs mirroring the Overview ring
--- axes — Offense (DPS + missiles), Defense (HP + armor), Mobility (SCM speed +
--- agility), Travel (max/quantum speed + fuel), Stealth (signatures). So the ring
--- and its detail tab share a name and contents. Ships/gravlevs use speed.*; ground
--- vehicles fall back to drive.*. Comparable rows render as PercentileBar items
--- (with a rank) when a cohort is available.

local classStats = require('Module:Entity/Vehicle/ClassStats')
local format = require('Module:Entity/Format')
local overview = require('Module:Entity/Vehicle/Stats/Overview')
local percentileBar = require('Module:Entity/Vehicle/Stats/PercentileBar')
local progressTiles = require('Module:ProgressTiles')
local sectionBuilder = require('Module:Entity/SectionBuilder')
local standing = require('Module:Entity/Vehicle/Stats/Standing')
local statFormat = require('Module:Entity/StatFormat')
local Util = require('Module:Entity/Facet/Util')
local vehicleUtil = require('Module:Entity/Vehicle/Util')

local QUANTUM_SPEED_DIVISOR = 1000000
local QUANTUM_RANGE_DIVISOR = 1000000000

local p = {}

--- A scaled numeric value with a unit, rounded to `decimals`. nil when non-numeric.
--- @return string|nil
local function scaledUnit(value, divisor, unit, decimals)
	local n = tonumber(value)
	if n == nil then
		return nil
	end
	local scaled = n / (divisor or 1)
	if decimals and decimals > 0 then
		local mult = 10 ^ decimals
		scaled = math.floor(scaled * mult + 0.5) / mult
	else
		scaled = math.floor(scaled + 0.5)
	end
	return format.formatNum(scaled) .. unit
end

--- A positive-only numeric value with a unit: drops when nil or <= 0.
--- @return string|nil
local function positiveUnit(value, unit)
	local n = tonumber(value)
	if n == nil or n <= 0 then
		return nil
	end
	return format.formatNum(n) .. unit
end

--- Round a possibly-fractional number to the nearest integer (drive speeds are
--- derived floats). nil-safe.
--- @return number|nil
local function roundInt(value)
	local n = tonumber(value)
	if n == nil then
		return nil
	end
	return math.floor(n + 0.5)
end

--- Signed-% signature label from a multiplier (1.13 -> "+13%"), colored by sign
--- (higher signature = worse). nil when absent or exactly 1.0.
--- @return string|nil
local function signatureLabel(mult)
	local m = tonumber(mult)
	if m == nil then
		return nil
	end
	local pct = math.floor((m - 1) * 100 + 0.5)
	if pct == 0 then
		return nil
	end
	local sign = pct > 0 and '+' or '\226\136\146' -- U+2212 minus
	local color = pct > 0 and 'var(--color-destructive)' or 'var(--color-success)'
	return tostring(mw.html.create('span'):css('color', color):wikitext(sign .. math.abs(pct) .. '%'))
end

--- Stealth value cell: the (already effective) signature, thousands-grouped, with the
--- armor signal multiplier appended as a colored signed-% suffix — e.g. "2,451 (−40%)"
--- — so the armor's contribution is visible in the figure the bar and ring rank. Just
--- the value when the multiplier is absent or neutral (1.0). nil value → nil (the row
--- is skipped by percentileRow).
--- @param value number|nil  effective signature (raw × armor multiplier)
--- @param modifier any  armor signal multiplier for this axis
--- @return string|nil
local function stealthValueText(value, modifier)
	if value == nil then
		return nil
	end
	local text = format.formatNum(roundInt(value))
	local label = signatureLabel(modifier)
	if label ~= nil then
		text = text .. ' (' .. label .. ')'
	end
	return text
end

--- Push a percentile bar row: the stat's displayed value + where the ship places
--- in its size class on that stat (the bar fills to the percentile, labelled with
--- the rank). Degrades to a plain row when no cohort. `invert` ranks
--- lower-as-better (the Stealth signatures), matching the Stealth ring.
--- @param items table[]  accumulator
--- @param label string
--- @param value number|nil  the ship's numeric value for this stat
--- @param valueText string|nil  the displayed value (with unit)
--- @param statKey string|nil  the cohort column to rank against
--- @param rows table[]|nil  classStats.cohortRows result
--- @param invert boolean|nil  rank lower-as-better (signatures/emissions)
local function percentileRow(items, label, value, valueText, statKey, rows, invert)
	if valueText == nil then
		return
	end
	local pct, rank = nil, nil
	if rows ~= nil and statKey ~= nil and value ~= nil then
		local cohortValues = {}
		local hasPeer = false -- a cohort member whose value differs from the ship's
		for _, row in ipairs(rows) do
			local v = row[statKey]
			if v ~= nil then
				cohortValues[#cohortValues + 1] = v
				if v ~= value then
					hasPeer = true
				end
			end
		end
		-- Only rank against a real distribution. If the ship is the lone member with
		-- this stat (e.g. the only missile carrier in its class) or the whole cohort is
		-- tied at its value, the percentile collapses to a vacuous 50 and the rank to a
		-- vacuous 1st — show a plain value instead of a contradictory "1st at 50%" bar.
		if hasPeer then
			if invert then
				local negated = {}
				for i, v in ipairs(cohortValues) do
					negated[i] = -v
				end
				pct = classStats.percentile(negated, -value)
			else
				pct = classStats.percentile(cohortValues, value)
			end
			rank = standing.position(cohortValues, value, invert)
		end
	end
	items[#items + 1] = percentileBar.item({ label = label, valueText = valueText, percentile = pct, rank = rank })
end

--- @param apiData table
--- @param args table
--- @param ed table  Editorial.view
--- @return table|nil
function p.build(apiData, args, ed)
	local speed = type(apiData.speed) == 'table' and apiData.speed or {}
	local agility = type(apiData.agility) == 'table' and apiData.agility or {}
	local drive = type(apiData.drive) == 'table' and apiData.drive or {}
	local armor = type(apiData.armor) == 'table' and apiData.armor or {}
	local fuel = type(apiData.fuel) == 'table' and apiData.fuel or {}
	local quantum = type(apiData.quantum) == 'table' and apiData.quantum or {}
	local weaponry = type(apiData.weaponry) == 'table' and apiData.weaponry or {}

	-- Cohort data for percentile ranking (nil in headless/non-ship context).
	local fam = (apiData.is_spaceship and 'ship') or (apiData.is_gravlev and 'gravlev') or 'ground'
	local size = tonumber(apiData.size_class)
	local cohortRows = classStats.cohortRows(fam, size)

	-- Offense tab: pilot/crew DPS + missiles.
	local firepower = {}
	percentileRow(
		firepower,
		'Pilot DPS',
		tonumber(weaponry.pilot_dps),
		positiveUnit(weaponry.pilot_dps, ''),
		'pilot_dps',
		cohortRows
	)
	percentileRow(
		firepower,
		'Crew DPS',
		tonumber(weaponry.turret_dps),
		positiveUnit(weaponry.turret_dps, ''),
		'turret_dps',
		cohortRows
	)
	local missiles = type(weaponry.missiles) == 'table' and weaponry.missiles or {}
	local missileDmg = type(missiles.damage) == 'table' and tonumber(missiles.damage.total) or nil
	if missileDmg ~= nil then
		-- The salvo's total damage. The missile count is omitted: it is uninformative
		-- and inconsistent with the gun DPS rows, which don't show gun counts either.
		percentileRow(firepower, 'Missiles', missileDmg, format.formatNum(missileDmg), 'missile_damage', cohortRows)
	end

	-- Defense tab: hull + shield + armor deflection thresholds + per-type resistance
	-- tiles. Deflection is split into its physical and energy thresholds — the mean
	-- behind the ring score reads as a value matching neither, so it is not shown.
	local defense = {}
	percentileRow(defense, 'Hull', tonumber(apiData.health), Util.withUnit(apiData.health, ' HP'), 'health', cohortRows)
	percentileRow(
		defense,
		'Shield',
		tonumber(apiData.shield_hp),
		Util.withUnit(apiData.shield_hp, ' HP'),
		'shield_hp',
		cohortRows
	)
	local deflection = type(armor.deflection) == 'table' and armor.deflection or {}
	percentileRow(
		defense,
		'Physical deflection',
		tonumber(deflection.physical),
		positiveUnit(roundInt(deflection.physical), ''),
		'physical_deflection',
		cohortRows
	)
	percentileRow(
		defense,
		'Energy deflection',
		tonumber(deflection.energy),
		positiveUnit(roundInt(deflection.energy), ''),
		'energy_deflection',
		cohortRows
	)
	local tiles = {}
	for _, dt in ipairs(vehicleUtil.DAMAGE_TYPES) do
		local pct = statFormat.resistancePercent(armor[dt.key])
		if pct ~= nil then
			tiles[#tiles + 1] = { value = pct, label = dt.abbr, title = dt.label }
		end
	end
	if tiles[1] ~= nil then
		defense[#defense + 1] = { content = progressTiles.render({ tiles = tiles }), class = 't-infobox-item--block' }
	end

	-- Mobility tab: SCM speed + agility rates + reverse speed.
	local mobility = {}
	local scmValue = ed:value('scm_speed', speed.scm)
	percentileRow(mobility, 'SCM speed', tonumber(scmValue), Util.withUnit(scmValue, ' m/s'), 'scm_speed', cohortRows)
	percentileRow(
		mobility,
		'Pitch rate',
		tonumber(agility.pitch),
		Util.withUnit(agility.pitch, ' \194\176/s'),
		'pitch_rate',
		cohortRows
	)
	percentileRow(
		mobility,
		'Yaw rate',
		tonumber(agility.yaw),
		Util.withUnit(agility.yaw, ' \194\176/s'),
		'yaw_rate',
		cohortRows
	)
	percentileRow(
		mobility,
		'Roll rate',
		tonumber(agility.roll),
		Util.withUnit(agility.roll, ' \194\176/s'),
		'roll_rate',
		cohortRows
	)
	sectionBuilder.push(mobility, 'Reverse speed', Util.withUnit(roundInt(drive.reverse_speed_ms), ' m/s'))

	-- Travel tab: max speed + quantum drive + fuel/endurance.
	local travel = {}
	local maxSpeed = ed:value('max_speed', speed.max)
	if maxSpeed == nil then
		maxSpeed = roundInt(drive.max_speed_ms)
	end
	percentileRow(travel, 'Max speed', tonumber(maxSpeed), Util.withUnit(maxSpeed, ' m/s'), 'max_speed', cohortRows)
	local qSpeed = tonumber(quantum.quantum_speed)
	local qSpeedGm = qSpeed and (qSpeed / QUANTUM_SPEED_DIVISOR) or nil
	percentileRow(
		travel,
		'Quantum speed',
		qSpeedGm,
		qSpeed and (format.formatNum(qSpeedGm) .. ' Mm/s') or nil,
		'quantum_speed',
		cohortRows
	)
	local qRangeRaw = tonumber(quantum.quantum_range)
	local qRangeGm = qRangeRaw and (qRangeRaw / QUANTUM_RANGE_DIVISOR) or nil
	percentileRow(
		travel,
		'Quantum range',
		qRangeGm,
		scaledUnit(quantum.quantum_range, QUANTUM_RANGE_DIVISOR, ' Gm', 1),
		'quantum_range',
		cohortRows
	)
	percentileRow(
		travel,
		'Spool time',
		tonumber(quantum.quantum_spool_time),
		Util.withUnit(quantum.quantum_spool_time, ' s'),
		'quantum_spool_time',
		cohortRows,
		true -- a faster spool is better
	)
	percentileRow(
		travel,
		'Quantum fuel',
		tonumber(quantum.quantum_fuel_capacity),
		Util.withUnit(quantum.quantum_fuel_capacity, ''),
		'quantum_fuel',
		cohortRows
	)
	percentileRow(
		travel,
		'Hydrogen fuel',
		tonumber(fuel.capacity),
		Util.withUnit(fuel.capacity, ''),
		'hydrogen_fuel',
		cohortRows
	)

	-- Stealth tab. IR and EM are effective signatures (raw × the armor signal multiplier;
	-- lower = better), ranked against the size class like the ring. Each value carries its
	-- multiplier as a colored signed-% suffix, e.g. "884 (−40%)".
	local stealth = {}
	local irEffective = vehicleUtil.effectiveIrEmission(apiData)
	percentileRow(
		stealth,
		'IR',
		irEffective,
		stealthValueText(irEffective, armor.signal_infrared),
		'ir_emission',
		cohortRows,
		true
	)
	local emEffective = vehicleUtil.effectiveEmEmission(apiData)
	percentileRow(
		stealth,
		'EM',
		emEffective,
		stealthValueText(emEffective, armor.signal_electromagnetic),
		'em_emission',
		cohortRows,
		true
	)
	-- Cross-section is broken out per axis (length / width / height) instead of the single
	-- mean: the spread is shape information the mean hides — a flat, wide hull is nearly
	-- invisible head-on but exposed broadside — telling players how to angle. Shown as
	-- plain values; the mean still drives the ring score (per-axis cohort ranking would
	-- need stored per-axis properties). The armor multiplier applies to all three axes.
	local cs = type(apiData.cross_section) == 'table' and apiData.cross_section or {}
	for _, axis in ipairs({ 'length', 'width', 'height' }) do
		local eff = vehicleUtil.applySignatureModifier(tonumber(cs[axis]), armor.signal_cross_section)
		percentileRow(stealth, 'CS (' .. axis .. ')', eff, stealthValueText(eff, armor.signal_cross_section))
	end

	-- Assemble tabs: Overview | Offense | Defense | Mobility | Travel | Stealth
	-- (mirroring the Overview ring axes; raw {label, items}, NO key).
	local statsTabs = {}
	local overviewTab = overview.build(apiData, args, ed)
	if overviewTab ~= nil then
		statsTabs[#statsTabs + 1] = overviewTab
	end
	if firepower[1] ~= nil then
		statsTabs[#statsTabs + 1] = { label = 'Offense', items = firepower }
	end
	if defense[1] ~= nil then
		statsTabs[#statsTabs + 1] = { label = 'Defense', items = defense }
	end
	if mobility[1] ~= nil then
		statsTabs[#statsTabs + 1] = { label = 'Mobility', items = mobility }
	end
	if travel[1] ~= nil then
		statsTabs[#statsTabs + 1] = { label = 'Travel', items = travel }
	end
	if stealth[1] ~= nil then
		statsTabs[#statsTabs + 1] = { label = 'Stealth', items = stealth }
	end
	return statsTabs[1] and sectionBuilder.section({ key = 'stats', label = 'Stats', sections = statsTabs }) or nil
end

return p
