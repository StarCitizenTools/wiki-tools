require('strict')

--- @module Entity/Item/Radar
--- Radar subtype. Detects ships and ground vehicles by their signatures. The
--- Component facet renders the shared hardware stats off the durability block;
--- this adds the detection rows — signature sensitivity (IR / EM / cross-section
--- share one rating, so infrared is representative), resource-signature
--- sensitivity, cooldown, and the aim-assist range.

local format = require('Module:Entity/Format')
local sectionBuilder = require('Module:Entity/SectionBuilder')

local p = {}

--- @type string
p.parent = 'Entity/Item'

--- Formats a 0..1 sensitivity coefficient as a percentage (0.9 -> "90%").
---
--- @param value number|nil
--- @return string|nil
local function pct(value)
	local n = tonumber(value)
	if n == nil then
		return nil
	end
	return math.floor(n * 100 + 0.5) .. '%'
end

--- @param apiData table
--- @param args table
--- @return table[] Ordered list of section entries with key field
function p.getSections(apiData, args)
	local radar = apiData.radar
	if type(radar) ~= 'table' then
		return {}
	end
	local sensitivity = type(radar.sensitivity) == 'table' and radar.sensitivity or {}
	local aim = type(radar.aim_assist) == 'table' and radar.aim_assist or {}

	local items = {}

	-- IR / cross-section / electromagnetic share one signature-sensitivity
	-- rating; infrared is representative.
	sectionBuilder.push(items, 'Sensitivity', pct(sensitivity.infrared))
	sectionBuilder.push(items, 'Resource sensitivity', pct(sensitivity.resource))
	sectionBuilder.push(items, 'Cooldown', radar.cooldown and (format.formatNum(radar.cooldown) .. ' s'))
	sectionBuilder.push(
		items,
		'Aim assist range',
		aim.distance_max_assignment and (format.formatNum(aim.distance_max_assignment) .. ' m')
	)

	return sectionBuilder.build(sectionBuilder.section({
		key = 'radar',
		label = 'Radar',
		items = items,
	}))
end

--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	local radar = apiData.radar
	if type(radar) ~= 'table' then
		return {}
	end
	local sensitivity = type(radar.sensitivity) == 'table' and radar.sensitivity or {}
	local aim = type(radar.aim_assist) == 'table' and radar.aim_assist or {}
	return {
		radar_sensitivity = tonumber(sensitivity.infrared),
		radar_resource_sensitivity = tonumber(sensitivity.resource),
		radar_cooldown = tonumber(radar.cooldown),
		radar_aim_assist_range = tonumber(aim.distance_max_assignment),
	}
end

return p
