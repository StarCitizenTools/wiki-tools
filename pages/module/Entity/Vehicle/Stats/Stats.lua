require('strict')

--- @module Entity/Vehicle/Stats
--- Vehicle Stats sub-builder: four keyless subsection tabs —
--- Flight (speed + agility), Hull (HP + armor resistance tiles + signature
--- labels), Hydrogen (fuel), Quantum (QD). Ships/gravlevs use speed.*; ground
--- vehicles fall back to drive.*.

local format = require('Module:Entity/Format')
local progressTiles = require('Module:ProgressTiles')
local sectionBuilder = require('Module:Entity/SectionBuilder')
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
	local usage = type(fuel.usage) == 'table' and fuel.usage or {}
	local quantum = type(apiData.quantum) == 'table' and apiData.quantum or {}

	-- Flight tab: speed + agility. Ships/gravlevs use speed.*; ground vehicles drive.*.
	local statsItems = {}
	sectionBuilder.push(statsItems, 'SCM speed', Util.withUnit(ed:value('scm_speed', speed.scm), ' m/s'))
	local maxSpeed = ed:value('max_speed', speed.max)
	if maxSpeed == nil then
		maxSpeed = roundInt(drive.max_speed_ms)
	end
	sectionBuilder.push(statsItems, 'Max speed', Util.withUnit(maxSpeed, ' m/s'))
	sectionBuilder.push(statsItems, 'Reverse speed', Util.withUnit(roundInt(drive.reverse_speed_ms), ' m/s'))
	sectionBuilder.push(statsItems, 'Roll rate', Util.withUnit(agility.roll, ' \194\176/s'))
	sectionBuilder.push(statsItems, 'Pitch rate', Util.withUnit(agility.pitch, ' \194\176/s'))
	sectionBuilder.push(statsItems, 'Yaw rate', Util.withUnit(agility.yaw, ' \194\176/s'))

	-- Hull tab: HP rows + armor resistance tiles + signature labels.
	local hull = {}
	sectionBuilder.push(hull, 'Hull', Util.withUnit(apiData.health, ' HP'))
	sectionBuilder.push(hull, 'Shield', Util.withUnit(apiData.shield_hp, ' HP'))
	local tiles = {}
	for _, dt in ipairs(vehicleUtil.DAMAGE_TYPES) do
		local pct = statFormat.resistancePercent(armor[dt.key])
		if pct ~= nil then
			tiles[#tiles + 1] = { value = pct, label = dt.abbr, title = dt.label }
		end
	end
	if tiles[1] ~= nil then
		hull[#hull + 1] = { content = progressTiles.render({ tiles = tiles }), class = 't-infobox-item--block' }
	end
	sectionBuilder.push(hull, 'Infrared', signatureLabel(armor.signal_infrared))
	sectionBuilder.push(hull, 'Electromagnetic', signatureLabel(armor.signal_electromagnetic))
	sectionBuilder.push(hull, 'Cross-section', signatureLabel(armor.signal_cross_section))

	-- Hydrogen tab: fuel capacity, intake, per-thruster usage.
	local hydrogen = {}
	sectionBuilder.push(hydrogen, 'Capacity', Util.withUnit(fuel.capacity, ''))
	sectionBuilder.push(hydrogen, 'Intake rate', positiveUnit(fuel.intake_rate, ''))
	sectionBuilder.push(hydrogen, 'Main', positiveUnit(usage.main, ''))
	sectionBuilder.push(hydrogen, 'Retro', positiveUnit(usage.retro, ''))
	sectionBuilder.push(hydrogen, 'VTOL', positiveUnit(usage.vtol, ''))
	sectionBuilder.push(hydrogen, 'Maneuvering', positiveUnit(usage.maneuvering, ''))

	-- Quantum tab: QD speed, range, spool, fuel.
	local qSpeed = tonumber(quantum.quantum_speed)
	local quantumItems = {}
	sectionBuilder.push(
		quantumItems,
		'Quantum speed',
		qSpeed and (format.formatNum(qSpeed / QUANTUM_SPEED_DIVISOR) .. ' Mm/s') or nil
	)
	sectionBuilder.push(
		quantumItems,
		'Quantum range',
		scaledUnit(quantum.quantum_range, QUANTUM_RANGE_DIVISOR, ' Gm', 1)
	)
	sectionBuilder.push(quantumItems, 'Spool time', Util.withUnit(quantum.quantum_spool_time, ' s'))
	sectionBuilder.push(quantumItems, 'Quantum fuel', Util.withUnit(quantum.quantum_fuel_capacity, ''))

	-- Assemble tabs: Flight | Hull | Hydrogen | Quantum (raw {label, items}, NO key).
	local statsTabs = {}
	if statsItems[1] ~= nil then
		statsTabs[#statsTabs + 1] = { label = 'Flight', items = statsItems }
	end
	if hull[1] ~= nil then
		statsTabs[#statsTabs + 1] = { label = 'Hull', items = hull }
	end
	if hydrogen[1] ~= nil then
		statsTabs[#statsTabs + 1] = { label = 'Hydrogen', items = hydrogen }
	end
	if quantumItems[1] ~= nil then
		statsTabs[#statsTabs + 1] = { label = 'Quantum', items = quantumItems }
	end
	return statsTabs[1] and sectionBuilder.section({ key = 'stats', label = 'Stats', sections = statsTabs }) or nil
end

return p
