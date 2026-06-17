require('strict')

--- @module Entity/Item/EMP
--- EMP generator subtype (API type "EMP"). Charges up and unleashes a distortion
--- pulse that disables nearby ships. The Component facet renders the shared
--- hardware stats off the durability block; this adds the pulse stats — radius,
--- distortion damage, charge time, active duration, and cooldown.

local format = require('Module:Entity/Format')
local sectionBuilder = require('Module:Entity/SectionBuilder')

local p = {}

--- @type string
p.parent = 'Entity/Item'

--- @param apiData table
--- @param args table
--- @return table[] Ordered list of section entries with key field
function p.getSections(apiData, args)
	local emp = apiData.emp
	if type(emp) ~= 'table' then
		return {}
	end

	local items = {}

	sectionBuilder.push(items, 'EMP radius', emp.emp_radius and (format.formatNum(emp.emp_radius) .. ' m'))
	sectionBuilder.push(items, 'Distortion damage', emp.distortion_damage and format.formatNum(emp.distortion_damage))
	sectionBuilder.push(items, 'Charge time', emp.charge_duration and (format.formatNum(emp.charge_duration) .. ' s'))
	sectionBuilder.push(items, 'Duration', emp.unleash_duration and (format.formatNum(emp.unleash_duration) .. ' s'))
	sectionBuilder.push(items, 'Cooldown', emp.cooldown_duration and (format.formatNum(emp.cooldown_duration) .. ' s'))

	return sectionBuilder.build(sectionBuilder.section({
		key = 'emp',
		label = 'EMP',
		items = items,
	}))
end

--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	local emp = apiData.emp
	if type(emp) ~= 'table' then
		return {}
	end
	return {
		emp_radius = tonumber(emp.emp_radius),
		emp_distortion_damage = tonumber(emp.distortion_damage),
		emp_charge_time = tonumber(emp.charge_duration),
		emp_duration = tonumber(emp.unleash_duration),
		emp_cooldown = tonumber(emp.cooldown_duration),
	}
end

return p
