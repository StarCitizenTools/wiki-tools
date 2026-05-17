require('strict')

--- @module Entity/Item
--- Item type module. Extends Base with item-specific properties
--- (size, mass, volume) and the shared item API endpoint.

local util = require('Module:Entity/Util')
local base = require('Module:Entity/Base')

local p = {}

--- @type string
p.parent = 'Entity/Base'

--- Maps API type strings to item subtype module paths. Lives in Item
--- (not in Data.lua) because subtype dispatch is an item-internal
--- concern — Data.lua only needs to know "ask the kind to resolve its
--- own subtype". Add new entries here when creating new item subtypes.
local itemSubtypeMapping = {
	Food = 'Entity/Item/Food',
	Drink = 'Entity/Item/Drink',
	WeaponPersonal = 'Entity/Item/WeaponPersonal',
	-- WeaponGun = 'Entity/Item/WeaponGun',
	-- QuantumDrive = 'Entity/Item/QuantumDrive',
}

--- Formats a short description using the item-family template:
--- "[<prefix>] <type> [by <manufacturer>]". Subtypes (Food, Drink, etc.) can
--- call this to compose a description that matches the item aesthetic, or
--- bypass it entirely and return a custom string from getShortDescription.
---
--- @param typeInfo table
--- @param apiData table
--- @param args table
--- @param prefix string|nil Adjective to prepend (e.g. effect). Cased automatically.
--- @return string
function p.formatShortDescription(typeInfo, apiData, args, prefix)
	local desc = typeInfo.name
	if prefix then
		local lowered = prefix:lower()
		desc = lowered:sub(1, 1):upper() .. lowered:sub(2) .. ' ' .. desc:lower()
	end
	local manufacturer = base.resolveManufacturer(apiData, args)
	if manufacturer then
		desc = desc .. ' by ' .. manufacturer.short
	end
	return desc
end

--- @return EntityApiConfig[]
function p.getApiConfigs()
	return {
		{
			name = 'StarCitizenWikiAPI',
			endpoint = 'items/%s',
			params = { locale = 'en_EN', include = 'related_items,blueprints,vehicles' },
			responseDataPath = 'data',
		},
	}
end

--- Positive identification for items. Items don't carry an explicit
--- type-kind flag at the top level the way vehicles carry
--- `is_vehicle`, so we identify by "the items endpoint returned a
--- record with a uuid." This is safe because Apiunto doesn't follow
--- the items→vehicles 302 redirect, so a vehicle UUID via the items
--- endpoint returns empty/nil data.
---
--- @param apiData table|nil
--- @return boolean
function p.matches(apiData)
	return apiData ~= nil and apiData.uuid ~= nil
end

--- Refines the leaf module from the kind module to a subtype leaf
--- (Food / Drink / WeaponPersonal) when the API `type` matches a
--- known mapping. Returns nil for unknown or missing types, which
--- means "no refinement — use the Item module itself as the leaf."
--- Module:Entity/Data invokes this after kind dispatch.
---
--- @param apiData table|nil
--- @return table|nil The resolved subtype module, or nil
function p.resolveSubtype(apiData)
	local subtype = apiData and apiData.type
	if subtype and itemSubtypeMapping[subtype] then
		return require('Module:' .. itemSubtypeMapping[subtype])
	end
	return nil
end

--- @param apiData table
--- @param args table
--- @return table[] Ordered list of section entries with key field
function p.getSections(apiData, args)
	local dim = apiData.dimension
	local trueDim = dim and dim.true_dimension

	local dimensionContent = nil
	if trueDim then
		dimensionContent = tostring(trueDim.length)
			.. ' x '
			.. tostring(trueDim.width)
			.. ' x '
			.. tostring(trueDim.height)
			.. ' m'
	end

	local manufacturer = base.resolveManufacturer(apiData, args)
	local manufacturerLink = nil
	if manufacturer then
		if manufacturer.page == manufacturer.name then
			manufacturerLink = '[[' .. manufacturer.name .. ']]'
		else
			manufacturerLink = '[[' .. manufacturer.page .. '|' .. manufacturer.name .. ']]'
		end
	end

	return {
		{
			key = 'general',
			items = {
				{
					label = 'Manufacturer',
					content = manufacturerLink,
				},
				{ label = 'Size', content = apiData.size and tostring(apiData.size) },
				{
					label = 'Volume',
					content = dim
						and dim.volume_converted
						and (tostring(dim.volume_converted) .. ' ' .. (dim.volume_converted_unit or 'SCU')),
				},
				{
					label = 'Mass',
					content = apiData.mass and (tostring(apiData.mass) .. ' kg'),
				},
				{ label = 'Dimension', content = dimensionContent },
			},
		},
	}
end

--- Default short description for items: "<type> [by <manufacturer>]".
--- Subtypes may override this to produce a richer description.
---
--- @param apiData table
--- @param args table
--- @param typeInfo table
--- @return string
function p.getShortDescription(apiData, args, typeInfo)
	return p.formatShortDescription(typeInfo, apiData, args, nil)
end

--- @param apiData table
--- @param args table
--- @return EntityItemData[] External site items contributed by this module
function p.getExternalSiteItems(apiData, args)
	local siteDefs = mw.loadJsonData('Module:Entity/Item/communitySites.json')
	local links = util.buildSiteLinks(siteDefs, {
		uuid = args.uuid,
		name = args.name or apiData.name,
	})
	if not links then
		return {}
	end
	return { { label = 'Community sites', content = links } }
end

return p
