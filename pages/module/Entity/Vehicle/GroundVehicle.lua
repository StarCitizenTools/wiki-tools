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

-- Transitional (see Module:Entity/Assembly.callHook): hooks take an EntityHookContext.
p.contextHooks = true

--- @param ctx EntityHookContext
--- @return { name: string, category: string }
function p.getTypeInfo(ctx)
	return { name = 'Ground vehicle', category = 'Ground vehicles' }
end

--- @param ctx EntityHookContext
--- @return string
function p.getShortDescription(ctx)
	return vehicle.formatShortDescription(ctx.apiData, ctx.args, ctx.resolved, 'ground vehicle', true)
end

--- Pledge browse category for non-ship vehicles ("Pledge vehicles"); ground
--- vehicles and gravlevs carry no meaningful ship-matrix size, so no size
--- bucket.
--- @param ctx EntityHookContext
--- @return string[]
function p.getCategories(ctx)
	local apiData, resolved = ctx.apiData, ctx.resolved
	if vehicle.hasPledgePrice(apiData, resolved) then
		return { 'Pledge vehicles' }
	end
	return {}
end

return p
