require('strict')

--- @module Entity/Vehicle/Ship
--- Spacecraft family subtype: structural category + short-desc noun. Stat
--- sections are owned by the Vehicle common link and gate on data-presence.

local vehicle = require('Module:Entity/Vehicle')
local vehicleUtil = require('Module:Entity/Vehicle/Util')
local lang = mw.language.getContentLanguage()

local p = {}

--- @type string
p.parent = 'Entity/Vehicle'

--- @type string
--- Family token: dispatched by Vehicle.resolveSubtype and named by a curated
--- |family= on record-less pages.
p.family = 'ship'

--- @param ctx EntityHookContext
--- @return { name: string, category: string }
function p.getTypeInfo(ctx)
	return { name = 'Spacecraft', category = 'Ships' }
end

--- @param ctx EntityHookContext
--- @return string
function p.getShortDescription(ctx)
	return vehicle.formatShortDescription(ctx.apiData, ctx.args, ctx.resolved, 'ship', false)
end

--- Ship-only browse categories: the ship-matrix size bucket ("Large ships",
--- the curated |size= wins over the API) and "Pledge ships".
--- @param ctx EntityHookContext
--- @return string[]
function p.getCategories(ctx)
	local apiData, args, resolved = ctx.apiData, ctx.args, ctx.resolved
	local cats = {}
	local size = vehicleUtil.matrixSize(apiData, args)
	if size then
		cats[#cats + 1] = lang:ucfirst(size) .. ' ships'
	end
	if vehicle.hasPledgePrice(apiData, resolved) then
		cats[#cats + 1] = 'Pledge ships'
	end
	return cats
end

return p
