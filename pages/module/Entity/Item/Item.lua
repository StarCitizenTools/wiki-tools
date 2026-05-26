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
	Turret = 'Entity/Item/Turret',
	WeaponPersonal = 'Entity/Item/WeaponPersonal',
	WeaponGun = 'Entity/Item/WeaponGun',
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
			-- `ports` is required so turret / weapon-mount items carry the embedded
			-- equipped gun's `vehicle_weapon` (Entity/Item/Turret reads it) and so
			-- Entity/Ports gets full port detail on item pages. Without it the API
			-- returns a shallow ports array (no port `type`, no `vehicle_weapon`).
			params = { locale = 'en_EN', include = 'related_items,blueprints,vehicles,ports' },
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

--- Class (Military / Civilian / Industrial / Competition / ...) is populated
--- only on graded vehicle components; vehicle weapons and FPS items have
--- none. Returns nil when absent so the row collapses.
---
--- @param apiData table
--- @return string|nil
local function classContent(apiData)
	local class = apiData.class
	if type(class) == 'string' and class ~= '' then
		return class
	end
	return nil
end

--- Grade (A-D) is meaningful only on graded vehicle components - those the
--- API marks with a `class`. Vehicle weapons report a constant grade 'A'
--- with no class, and FPS items have no grade; both get no row. Gating on
--- `class` keeps the constant 'A' off every weapon.
---
--- @param apiData table
--- @return string|nil
local function gradeContent(apiData)
	if classContent(apiData) == nil then
		return nil
	end
	local grade = apiData.grade
	if grade == nil or grade == '' then
		return nil
	end
	return tostring(grade)
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
				{ label = 'Class', content = classContent(apiData) },
				{ label = 'Grade', content = gradeContent(apiData) },
				{
					label = 'Volume',
					content = dim
						and dim.volume_converted
						and (util.formatNum(dim.volume_converted) .. ' ' .. (dim.volume_converted_unit or 'SCU')),
				},
				{
					label = 'Mass',
					content = apiData.mass and (util.formatNum(apiData.mass) .. ' kg'),
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

--- Contributes item-level facet values to structured data: size, grade,
--- class, and the in-game item type. Stored backend-agnostically via
--- Module:Entity/StructuredData. These are facets for querying/tooling;
--- only some (e.g. item_type) are also surfaced as browse categories.
---
--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	return {
		size = apiData.size,
		grade = apiData.grade,
		class = apiData.class,
		item_type = util.getItemType(apiData),
	}
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

-- Test-only exports. Not part of the public API.
p._internal = {
	classContent = classContent,
	gradeContent = gradeContent,
}

return p
