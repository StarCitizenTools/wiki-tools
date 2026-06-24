require('strict')

--- @module Entity/Facet/Grenade
--- Grenade facet. Thrown FPS ordnance (sub_type Grenade) carries a `grenade`
--- block: damage type, blast damage, and an area-of-effect radius range. Many
--- entries in this sub_type are actually flares / light sticks / rescue lights
--- with an all-null block — the facet collapses for those (renders nothing),
--- leaving them as plain items.

local format = require('Module:Entity/Format')
local sectionBuilder = require('Module:Entity/SectionBuilder')
local Util = require('Module:Entity/Facet/Util')

local p = {}

--- @param apiData table|nil
--- @return boolean
function p.matches(apiData)
	return apiData ~= nil and type(apiData.grenade) == 'table'
end

--- @param apiData table
--- @param args table
--- @return EntitySectionEntry[]
function p.getSections(apiData, args)
	local g = apiData.grenade
	if type(g) ~= 'table' then
		return {}
	end
	local aoe = type(g.aoe) == 'table' and g.aoe or {}

	local items = {}

	sectionBuilder.push(
		items,
		'Damage type',
		type(g.damage_type) == 'string' and g.damage_type ~= '' and g.damage_type or nil
	)
	sectionBuilder.push(items, 'Damage', format.formatNum(g.damage))
	local rMin = aoe.min ~= nil and aoe.min or aoe.minimum
	local rMax = aoe.max ~= nil and aoe.max or aoe.maximum
	sectionBuilder.push(items, 'Blast radius', Util.rangeStr(rMin, rMax, 'm'))

	return sectionBuilder.build(
		sectionBuilder.section({ key = 'grenade', label = 'Grenade', collapsible = true, items = items })
	)
end

--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	local g = apiData.grenade
	if type(g) ~= 'table' then
		return {}
	end
	local aoe = type(g.aoe) == 'table' and g.aoe or {}
	return {
		damage = tonumber(g.damage),
		damage_type = type(g.damage_type) == 'string' and g.damage_type ~= '' and g.damage_type or nil,
		blast_radius = tonumber(aoe.max ~= nil and aoe.max or aoe.maximum),
	}
end

-- Test-only exports. Not part of the public API.
p._internal = {
	rangeStr = Util.rangeStr,
}

return p
