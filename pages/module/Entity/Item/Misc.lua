require('strict')

--- @module Entity/Item/Misc
--- Misc subtype (API type "Misc"): a catch-all type whose sub_type carries the
--- real distinction. Routes wall-mounted picture / sign flair (sub_type
--- "Flair_Wall_Picture") to the Wall flair browse category — the API types these
--- as Misc rather than Flair_Wall, so the generic types.json Misc mapping would
--- otherwise miss them and the catalogue (Category:Hab and hangar items) would
--- not pick them up. Renders no section of its own.

local p = {}

--- @type string
p.parent = 'Entity/Item'

--- @type table<string, { name: string, category: string }>
local subTypeInfo = {
	Flair_Wall_Picture = { name = 'Wall flair', category = 'Wall flair' },
}

--- Routes a Misc sub_type to its display name + browse category. Returns nil for
--- an unknown sub_type so the generic types.json Misc mapping applies.
---
--- @param apiData table
--- @param args table
--- @return { name: string, category: string }|nil
function p.getTypeInfo(apiData, args)
	local sub = apiData and apiData.sub_type
	return sub and subTypeInfo[sub] or nil
end

return p
