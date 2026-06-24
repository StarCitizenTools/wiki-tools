require('strict')

--- @module Entity/Facet/Heal
--- Healing facet. Any entity carrying a healing-beam mode (`mode.type ==
--- 'healingbeam'`) gets its heal stats surfaced: healing rate, beam range, and
--- sensor range. The mode appears with the same shape on handheld medical devices
--- (the CureLife ParaMed family, a `personal_weapon`), multi-tools with a repair /
--- heal beam, and any vehicle medical beam (`vehicle_weapon`), so this one
--- data-driven facet covers them all rather than being tied to one sub_type.
---
--- A device may carry twin Heal / SelfHeal modes with identical stats; the first
--- healing-beam mode is taken since the rendered figures match.

local format = require('Module:Entity/Format')
local sectionBuilder = require('Module:Entity/SectionBuilder')
local Util = require('Module:Entity/Facet/Util')

local p = {}

--- Finds the first healing-beam mode in a modes array.
---
--- @param modes table|nil
--- @return table|nil
local function findHealMode(modes)
	if type(modes) ~= 'table' then
		return nil
	end
	for _, mode in ipairs(modes) do
		if mode.type == 'healingbeam' then
			return mode
		end
	end
	return nil
end

--- The healing-beam mode on this entity, scanning whichever weapon block is
--- present (FPS medical devices / multi-tools vs vehicle medical beams). Top-level
--- blocks only.
---
--- @param apiData table|nil
--- @return table|nil
local function healModeOf(apiData)
	if type(apiData) ~= 'table' then
		return nil
	end
	local pw = apiData.personal_weapon
	if type(pw) == 'table' then
		local mode = findHealMode(pw.modes)
		if mode then
			return mode
		end
	end
	local vw = apiData.vehicle_weapon
	if type(vw) == 'table' then
		local mode = findHealMode(vw.modes)
		if mode then
			return mode
		end
	end
	return nil
end

--- Data-driven match: presence of a healing-beam mode in either weapon block.
---
--- @param apiData table|nil
--- @return boolean
function p.matches(apiData)
	return healModeOf(apiData) ~= nil
end

--- @param apiData table
--- @param args table
--- @return table[] Ordered list of section entries with key field
function p.getSections(apiData, args)
	local heal = healModeOf(apiData)
	if type(heal) ~= 'table' then
		return {}
	end

	local items = {}

	sectionBuilder.push(items, 'Healing rate', Util.withUnit(heal.healing_per_second, '/s'))
	sectionBuilder.push(items, 'Range', Util.withUnit(heal.max_distance, ' m'))
	sectionBuilder.push(items, 'Sensor range', Util.withUnit(heal.max_sensor_distance, ' m'))

	return sectionBuilder.build(sectionBuilder.section({
		key = 'heal',
		label = 'Healing',
		collapsible = true,
		items = items,
	}))
end

-- Test-only exports. Not part of the public API.
p._internal = {
	findHealMode = findHealMode,
	healModeOf = healModeOf,
}

return p
