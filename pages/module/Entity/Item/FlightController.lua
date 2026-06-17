require('strict')

--- @module Entity/Item/FlightController
--- Flight blade subtype. A flight blade plugs into a vehicle's computer port and
--- tunes its flight model — top speeds and angular velocity. The three variants
--- trade maneuverability (PHB) against speed (TSB) off a Standard baseline, and
--- that trade-off shows in these numbers. Boosted values are appended in
--- parentheses, e.g. "226 (520) m/s" for SCM (boost) speed and "68 (82) °/s" for
--- pitch. There is no durability block, so no Component facet fires.

local format = require('Module:Entity/Format')
local sectionBuilder = require('Module:Entity/SectionBuilder')

local p = {}

--- @type string
p.parent = 'Entity/Item'

--- Formats a base value with its boosted counterpart appended in parentheses:
--- "226 (520) m/s". Drops the parenthetical when there is no boosted value, and
--- returns nil when there is no base value so the row collapses.
---
--- @param base number|nil
--- @param boosted number|nil
--- @param unit string
--- @return string|nil
local function baseBoost(base, boosted, unit)
	local b = tonumber(base)
	if b == nil then
		return nil
	end
	local out = format.formatNum(b)
	local boost = tonumber(boosted)
	if boost ~= nil then
		out = out .. ' (' .. format.formatNum(boost) .. ')'
	end
	return out .. ' ' .. unit
end

--- @param apiData table
--- @param args table
--- @return table[] Ordered list of section entries with key field
function p.getSections(apiData, args)
	local fc = apiData.flight_controller
	if type(fc) ~= 'table' then
		return {}
	end

	local items = {}

	-- Forward boost is the SCM speed's "boosted" counterpart, so it rides in the
	-- SCM row's parenthetical rather than getting a row of its own.
	sectionBuilder.push(items, 'SCM speed', baseBoost(fc.scm_speed, fc.boost_speed_forward, 'm/s'))
	sectionBuilder.push(items, 'Max speed', fc.max_speed and (format.formatNum(fc.max_speed) .. ' m/s'))
	sectionBuilder.push(items, 'Pitch', baseBoost(fc.pitch, fc.pitch_boosted, '°/s'))
	sectionBuilder.push(items, 'Yaw', baseBoost(fc.yaw, fc.yaw_boosted, '°/s'))
	sectionBuilder.push(items, 'Roll', baseBoost(fc.roll, fc.roll_boosted, '°/s'))

	return sectionBuilder.build(sectionBuilder.section({
		key = 'flight_controller',
		label = 'Flight performance',
		items = items,
	}))
end

--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	local fc = apiData.flight_controller
	if type(fc) ~= 'table' then
		return {}
	end
	return {
		scm_speed = tonumber(fc.scm_speed),
		boost_speed = tonumber(fc.boost_speed_forward),
		max_speed = tonumber(fc.max_speed),
		pitch = tonumber(fc.pitch),
		pitch_boosted = tonumber(fc.pitch_boosted),
		yaw = tonumber(fc.yaw),
		yaw_boosted = tonumber(fc.yaw_boosted),
		roll = tonumber(fc.roll),
		roll_boosted = tonumber(fc.roll_boosted),
	}
end

return p
