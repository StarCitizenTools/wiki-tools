require('strict')

--- @module Entity/Item/Beam
--- Tractor beam / towing beam subtype. The beam STATS (force, range, max angle,
--- tether break, heavy-lift) render via the data-driven Module:Entity/Facet/Beam
--- facet — which fires on the shared `tractor_beam` block and so also covers FPS
--- handheld tractor beams. This subtype survives only to own the vehicle beam's
--- size-prefixed short description ("S1 tractor beam by Greycat"); its category and
--- display name come from the type map (Module:Entity/Item/types.json).

local item = require('Module:Entity/Item')

local p = {}

--- @type string
p.parent = 'Entity/Item'

-- Transitional (see Module:Entity/Assembly.callHook): hooks take an EntityHookContext.
p.contextHooks = true

--- Short description prepends the mount size — "S1 tractor beam by Greycat
--- Industrial" — mirroring the other vehicle-component descriptors.
---
--- @param ctx EntityHookContext
--- @return string
function p.getShortDescription(ctx)
	local apiData, args, typeInfo, prefix = ctx.apiData, ctx.args, ctx.typeInfo, ctx.prefix
	local typeName = typeInfo.name
	if apiData.size then
		typeName = 'S' .. tostring(apiData.size) .. ' ' .. typeName:lower()
	end
	return item.formatShortDescription({ name = typeName }, apiData, args, prefix)
end

return p
