require('strict')

--- @module Entity/Vehicle/Capacity
--- Vehicle Capacity sub-builder: crew range, cargo (SCU), personal inventory (µSCU).

local format = require('Module:Entity/Format')
local sectionBuilder = require('Module:Entity/SectionBuilder')
local Util = require('Module:Entity/Facet/Util')

local p = {}

--- Crew as "min–max" (en dash) or a single value. nil when neither present.
--- @return string|nil
local function crewRange(minV, maxV)
	minV, maxV = tonumber(minV), tonumber(maxV)
	if minV and maxV and minV ~= maxV then
		return format.formatNum(minV) .. '\226\128\147' .. format.formatNum(maxV)
	end
	if minV or maxV then
		return format.formatNum(minV or maxV)
	end
	return nil
end

--- @param apiData table
--- @param args table
--- @param ed table  Editorial.view
--- @return table
function p.build(apiData, args, ed)
	local crew = type(apiData.crew) == 'table' and apiData.crew or {}
	local capacity = {}
	sectionBuilder.push(capacity, 'Crew', crewRange(ed:value('crew_min', crew.min), ed:value('crew_max', crew.max)))
	sectionBuilder.push(capacity, 'Cargo', Util.withUnit(ed:value('cargo_capacity', apiData.cargo_capacity), ' SCU'))
	-- Personal stowage (the API's `vehicle_inventory`, in µSCU — same unit as the
	-- item Inventory facet's scu_converted); labelled "Inventory" in the infobox.
	sectionBuilder.push(capacity, 'Inventory', Util.withUnit(apiData.vehicle_inventory, ' µSCU'))
	return sectionBuilder.section({ key = 'capacity', label = 'Capacity', items = capacity })
end

return p
