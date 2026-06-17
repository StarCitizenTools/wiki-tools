require('strict')

--- @module Entity/Item/QuantumDrive
--- Quantum drive subtype. Drives a ship's interstellar quantum travel. The
--- Component facet renders the shared hardware stats (health, EM / IR,
--- resistance) off the durability block; this adds the quantum-travel rows from
--- the drive's standard jump mode — quantum speed, spool time, cooldown — plus
--- the fuel requirement.

local format = require('Module:Entity/Format')
local sectionBuilder = require('Module:Entity/SectionBuilder')

local p = {}

--- @type string
p.parent = 'Entity/Item'

--- Quantum speed as a display string. Prefers the API's preformatted value
--- (e.g. "231 Mm/s"); falls back to converting the raw m/s drive speed to Mm/s,
--- the unit the game and community use.
---
--- @param jump table
--- @return string|nil
local function speedDisplay(jump)
	if type(jump.drive_speed_formatted) == 'string' and jump.drive_speed_formatted ~= '' then
		return jump.drive_speed_formatted
	end
	local raw = tonumber(jump.drive_speed)
	if raw then
		return format.formatNum(raw / 1000000) .. ' Mm/s'
	end
	return nil
end

--- @param apiData table
--- @param args table
--- @return table[] Ordered list of section entries with key field
function p.getSections(apiData, args)
	local qd = apiData.quantum_drive
	if type(qd) ~= 'table' then
		return {}
	end
	-- standard_jump is the primary interplanetary travel mode; spline_jump is the
	-- slower intra-system mode and is left out of the headline rows.
	local jump = type(qd.standard_jump) == 'table' and qd.standard_jump or {}

	local items = {}

	sectionBuilder.push(items, 'Quantum speed', speedDisplay(jump))
	sectionBuilder.push(items, 'Spool time', jump.spool_up_time and (format.formatNum(jump.spool_up_time) .. ' s'))
	sectionBuilder.push(items, 'Cooldown', jump.cooldown_time and (format.formatNum(jump.cooldown_time) .. ' s'))
	sectionBuilder.push(
		items,
		'Fuel requirement',
		qd.quantum_fuel_requirement and format.formatNum(qd.quantum_fuel_requirement)
	)

	return sectionBuilder.build(sectionBuilder.section({
		key = 'quantum_drive',
		label = 'Quantum drive',
		items = items,
	}))
end

--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	local qd = apiData.quantum_drive
	if type(qd) ~= 'table' then
		return {}
	end
	local jump = type(qd.standard_jump) == 'table' and qd.standard_jump or {}
	local speed = tonumber(jump.drive_speed)
	return {
		-- Stored in Mm/s (the unit the game/community use) so the index sorts and
		-- reads cleanly rather than showing raw m/s.
		quantum_speed = speed and (speed / 1000000) or nil,
		quantum_spool_time = tonumber(jump.spool_up_time),
		quantum_cooldown = tonumber(jump.cooldown_time),
		quantum_fuel_requirement = tonumber(qd.quantum_fuel_requirement),
	}
end

return p
