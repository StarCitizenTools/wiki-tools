require('strict')

--- @module Entity/Item/WeaponAttachment
--- Weapon attachment subtype (API type "WeaponAttachment"). Attachments don't
--- share a single stat block — each sub_type carries its own, rendered by a
--- data-driven facet: Magazine (magazine/ammunition), IronSight (iron_sight
--- ranging) + WeaponModifier (magnification), Barrel (weapon_modifier recoil /
--- spread), BottomAttachment (laser_pointer / flashlight), and Utility (multi-tool
--- heads — no per-attachment stats, the function lives on the base tool). So this
--- subtype renders no section of its own; it exists only to route each sub_type to
--- its browse category via getTypeInfo (the resolver only honours Ship.*
--- classifications, not FPS.WeaponAttachment.*).

local p = {}

--- @type string
p.parent = 'Entity/Item'

--- @type table<string, { name: string, category: string }>
local subTypeInfo = {
	Magazine = { name = 'Magazine', category = 'Magazines' },
	IronSight = { name = 'Optic', category = 'Optics attachments' },
	Barrel = { name = 'Barrel attachment', category = 'Barrel attachments' },
	BottomAttachment = { name = 'Underbarrel attachment', category = 'Underbarrel attachments' },
	Utility = { name = 'Multi-Tool attachment', category = 'Multi-Tool attachments' },
}

--- Routes each attachment sub_type to its display name + browse category. Returns
--- nil for an unrecognized sub_type so the generic types.json mapping (→
--- "Attachments") applies as a fallback.
---
--- @param apiData table
--- @param args table
--- @return { name: string, category: string }|nil
function p.getTypeInfo(apiData, args)
	local sub = apiData and apiData.sub_type
	return sub and subTypeInfo[sub] or nil
end

return p
