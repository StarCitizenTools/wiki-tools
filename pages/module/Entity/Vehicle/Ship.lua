require('strict')

--- @module Entity/Vehicle/Ship
--- Spacecraft family subtype: structural category + short-desc noun. Stat
--- sections are owned by the Vehicle common link and gate on data-presence.

local vehicle = require('Module:Entity/Vehicle')

local p = {}

--- @type string
p.parent = 'Entity/Vehicle'

--- @type string
--- Family discriminator read by Vehicle.getCategories (replaces a module-identity
--- comparison) and available to any future carried-family logic.
p.family = 'ship'

--- @param apiData table
--- @param args table
--- @return { name: string, category: string }
function p.getTypeInfo(apiData, args)
	return { name = 'Spacecraft', category = 'Ships' }
end

--- @param apiData table
--- @param args table
--- @param typeInfo table
--- @param prefix string|nil
--- @param resolved table|nil
--- @return string
function p.getShortDescription(apiData, args, typeInfo, prefix, resolved)
	return vehicle.formatShortDescription(apiData, args, resolved, 'ship', false)
end

return p
