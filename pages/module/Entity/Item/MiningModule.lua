require('strict')

--- @module Entity/Item/MiningModule
--- Mining module subtype (API type "MiningModifier"). A mining module slots into a
--- mining laser and alters its behaviour. The `mining_modifier` stat block is
--- rendered by the data-driven Mining facet (Module:Entity/Facet/Mining), which
--- fires on any entity carrying that block — vehicle modules and handheld FPS
--- mining gadgets alike. This subtype now contributes only the size-prefixed short
--- description ("S1 mining module by …"); the Component facet renders durability
--- alongside.

local item = require('Module:Entity/Item')

local p = {}

--- @type string
p.parent = 'Entity/Item'

--- Short description prepends the mount size — "S1 mining module by Musashi
--- Industrial & Starflight Concern" — mirroring the other component descriptors.
---
--- @param apiData table
--- @param args table
--- @param typeInfo table
--- @param prefix string|nil
--- @return string
function p.getShortDescription(apiData, args, typeInfo, prefix)
	local typeName = typeInfo.name
	if apiData.size then
		typeName = 'S' .. tostring(apiData.size) .. ' ' .. typeName:lower()
	end
	return item.formatShortDescription({ name = typeName }, apiData, args, prefix)
end

return p
