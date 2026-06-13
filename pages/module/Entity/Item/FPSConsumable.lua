require('strict')

--- @module Entity/Item/FPSConsumable
--- FPS consumable subtype (API type "FPS_Consumable"): medical injector pens
--- (sub_type Medical / MedPack), the OxyPen (OxygenCap), and hacking cryptokeys
--- (sub_type Hacking). Renders no section of its own — the Medical and Hacking
--- facets (and the Consumable facet, for the food-block OxyPen) do that; this
--- subtype only routes each sub_type to its browse category, since the resolver
--- ignores FPS.* classifications and types.json keys only the base type.

local p = {}

--- @type string
p.parent = 'Entity/Item'

--- @type table<string, { name: string, category: string }>
local subTypeInfo = {
	Medical = { name = 'Medical consumable', category = 'Medical consumables' },
	MedPack = { name = 'Medical consumable', category = 'Medical consumables' },
	OxygenCap = { name = 'Medical consumable', category = 'Medical consumables' },
	Hacking = { name = 'Cryptokey', category = 'Cryptokeys' },
}

--- Routes each FPS_Consumable sub_type to its display name + browse category.
--- Returns nil for an unknown sub_type so the generic types.json mapping applies.
---
--- @param apiData table
--- @param args table
--- @return { name: string, category: string }|nil
function p.getTypeInfo(apiData, args)
	local sub = apiData and apiData.sub_type
	return sub and subTypeInfo[sub] or nil
end

return p
