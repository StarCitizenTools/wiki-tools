require('strict')

--- @module Entity/Vehicle/GroundVehicle
--- Ground vehicle family subtype: structural category + short-desc noun. Stat
--- sections are owned by the Vehicle common link and gate on data-presence.

local vehicle = require('Module:Entity/Vehicle')

local p = {}

--- @type string
p.parent = 'Entity/Vehicle'

--- @type string
--- Family token: dispatched by Vehicle.resolveSubtype and named by a curated
--- |family= on record-less pages.
p.family = 'ground'

--- @param apiData table
--- @param args table
--- @return { name: string, category: string }
function p.getTypeInfo(apiData, args)
	return { name = 'Ground vehicle', category = 'Ground vehicles' }
end

--- @param apiData table
--- @param args table
--- @param typeInfo table
--- @param prefix string|nil
--- @param resolved table|nil
--- @return string
function p.getShortDescription(apiData, args, typeInfo, prefix, resolved)
	return vehicle.formatShortDescription(apiData, args, resolved, 'ground vehicle', true)
end

--- Pledge browse category for non-ship vehicles ("Pledge vehicles"); ground
--- vehicles and gravlevs carry no meaningful ship-matrix size, so no size
--- bucket.
--- @param apiData table
--- @param args table
--- @param resolved table|nil
--- @return string[]
function p.getCategories(apiData, args, resolved)
	if vehicle.hasPledgePrice(apiData, resolved) then
		return { 'Pledge vehicles' }
	end
	return {}
end

return p
