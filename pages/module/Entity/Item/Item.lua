require('strict')

--- @module Entity/Item
--- Item type module. Extends Base with item-specific properties
--- (size, mass, volume) and the shared item API endpoint.

local format = require('Module:Entity/Format')
local base = require('Module:Entity/Base')

local p = {}

--- Canonical kind name; the Data.get() `result.kind` value sibling renderers
--- branch on. Every kind declares one (enforced by the Registry conformance test).
p.name = 'Item'

--- @type string
p.parent = 'Entity/Base'

--- Maps API type strings to item subtype module paths. Lives in Item
--- (not in Data.lua) because subtype dispatch is an item-internal
--- concern — Data.lua only needs to know "ask the kind to resolve its
--- own subtype". Add new entries here when creating new item subtypes.
---
--- Food / Drink are intentionally absent: they are handled by the
--- data-driven consumable facet (Module:Entity/Facet/Consumable), not a
--- subtype leaf. Their subtitle + category still resolve via types.json.
local itemSubtypeMapping = {
	Module = 'Entity/Item/Module',
	Turret = 'Entity/Item/Turret',
	WeaponPersonal = 'Entity/Item/WeaponPersonal',
	WeaponAttachment = 'Entity/Item/WeaponAttachment',
	FPS_Consumable = 'Entity/Item/FPSConsumable',
	Misc = 'Entity/Item/Misc',
	WeaponGun = 'Entity/Item/WeaponGun',
	PowerPlant = 'Entity/Item/PowerPlant',
	Cooler = 'Entity/Item/Cooler',
	Shield = 'Entity/Item/Shield',
	QuantumDrive = 'Entity/Item/QuantumDrive',
	JumpDrive = 'Entity/Item/JumpModule',
	Radar = 'Entity/Item/Radar',
	EMP = 'Entity/Item/EMP',
	QuantumInterdictionGenerator = 'Entity/Item/QuantumInterdictionGenerator',
	FlightController = 'Entity/Item/FlightController',
	Missile = 'Entity/Item/Missile',
	WeaponMissile = 'Entity/Item/Missile',
	Bomb = 'Entity/Item/Bomb',
	MissileLauncher = 'Entity/Item/Rack',
	BombLauncher = 'Entity/Item/Rack',
	TractorBeam = 'Entity/Item/Beam',
	TowingBeam = 'Entity/Item/Beam',
	MiningModifier = 'Entity/Item/MiningModule',
	WeaponMining = 'Entity/Item/WeaponMining',
	SalvageModifier = 'Entity/Item/Scraper',
	SalvageHead = 'Entity/Item/SalvageHead',
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
--- @param args table|nil  Unused (item subtype dispatches on apiData.type); present for kind-contract parity.
--- @return table|nil The resolved subtype module, or nil
function p.resolveSubtype(apiData, args)
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

--- Extracts the in-game "Item Type" label from an entity's description_data
--- (e.g. "Laser Repeater"). This is the specific item type as shown in-game,
--- distinct from the API `type` (WeaponGun) and `sub_type` (Gun) fields.
--- Returns nil when absent.
---
--- @param apiData table|nil
--- @return string|nil
local function getItemType(apiData)
	local descData = apiData and apiData.description_data
	if type(descData) ~= 'table' then
		return nil
	end
	for _, entry in ipairs(descData) do
		if entry.name == 'Item Type' or entry.name == 'Type' then
			return entry.value or entry.type
		end
	end
	return nil
end

--- Extracts an item's volume from `apiData.dimension`, normalized to µSCU
--- (microSCU) as a number. Reads `volume_converted` + `volume_converted_unit`
--- (the precision-preserving pair the API uses for display) rather than the
--- raw `dimension.volume` field — that one rounds to 0 for sub-SCU items
--- like a 1 µSCU PDC. Returns nil when there's no volume data or when the
--- unit is something we don't recognize (refuse rather than guess).
---
--- Matches the display code in treating a missing `volume_converted_unit` as SCU.
---
--- @param apiData table|nil
--- @return number|nil  volume in µSCU
local function getVolume(apiData)
	local dim = apiData and apiData.dimension
	if type(dim) ~= 'table' then
		return nil
	end
	local v = tonumber(dim.volume_converted)
	if not v then
		return nil
	end
	local unit = dim.volume_converted_unit or 'SCU'
	if unit == 'SCU' then
		return math.floor(v * 1000000 + 0.5)
	end
	if unit == 'µSCU' then
		return v
	end
	return nil
end

--- @param apiData table
--- @param args table
--- @return table[] Ordered list of section entries with key field
function p.getSections(apiData, args)
	local manufacturer = base.resolveManufacturer(apiData, args)
	local manufacturerLink = nil
	if manufacturer then
		if manufacturer.page == manufacturer.name then
			manufacturerLink = '[[' .. manufacturer.name .. ']]'
		else
			manufacturerLink = '[[' .. manufacturer.page .. '|' .. manufacturer.name .. ']]'
		end
	end

	-- Volume, mass, and the dimension diagram are now rendered by the dimension
	-- facet (Module:Entity/Facet/Dimensions) as a section above Metadata.
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
			},
		},
	}
end

--- Spec-style short description for graded vehicle components — the ones the
--- API marks with a `class` (power plants, coolers, shields, quantum drives,
--- ...): e.g. "S3 Gr. A military power plant by Amon & Reese Co.". Returns nil
--- when the item isn't a graded component (missing class, grade, or size), so
--- the caller falls back to the generic item descriptor. Gating on classContent
--- keeps this off vehicle weapons and FPS items, which carry no class.
---
--- @param typeInfo table
--- @param apiData table
--- @param args table
--- @return string|nil
function p.formatGradedShortDescription(typeInfo, apiData, args)
	local class = classContent(apiData)
	local grade = gradeContent(apiData)
	local size = apiData.size
	if not (class and grade and size) then
		return nil
	end
	local desc = 'S' .. tostring(size) .. ' Gr. ' .. grade .. ' ' .. class:lower() .. ' ' .. typeInfo.name:lower()
	local manufacturer = base.resolveManufacturer(apiData, args)
	if manufacturer then
		desc = desc .. ' by ' .. manufacturer.short
	end
	return desc
end

--- Default short description for items: graded vehicle components get the
--- spec-style descriptor (formatGradedShortDescription); everything else gets
--- "[<prefix>] <type> [by <manufacturer>]". The optional prefix is supplied by
--- a matching facet (e.g. the consumable facet's effects adjective) and composed
--- by formatShortDescription.
---
--- @param apiData table
--- @param args table
--- @param typeInfo table
--- @param prefix string|nil
--- @return string
function p.getShortDescription(apiData, args, typeInfo, prefix)
	return p.formatGradedShortDescription(typeInfo, apiData, args)
		or p.formatShortDescription(typeInfo, apiData, args, prefix)
end

--- An item's base-variant flag (`is_base_variant`): true for the canonical
--- piece, false for a colorway / edition variant of it. Returned only when the
--- API carries the boolean (most items do), so items without the concept store
--- nothing. A generic item facet — it lets index tables filter the colorway
--- explosion (armor / clothing) down to base pieces.
---
--- @param apiData table
--- @return boolean|nil
local function baseVariant(apiData)
	if type(apiData.is_base_variant) == 'boolean' then
		return apiData.is_base_variant
	end
	return nil
end

--- Contributes item-level facet values to structured data: size, grade,
--- class, the in-game item type, volume (in µSCU), the base-variant flag, and
--- the rarity tier. Stored backend-agnostically via Module:Entity/StructuredData.
--- These are facets for querying/tooling, not browse categories — the structural
--- category is classification-driven (Module:Entity/Data.resolveClassification →
--- classifications.json).
---
--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	return {
		size = apiData.size,
		grade = apiData.grade,
		class = apiData.class,
		item_type = getItemType(apiData),
		volume = getVolume(apiData),
		base_variant = baseVariant(apiData),
		rarity = apiData.rarity,
	}
end

--- @param apiData table
--- @param args table
--- @return EntityItemData[] External site items contributed by this module
function p.getExternalSiteItems(apiData, args)
	local siteDefs = mw.loadJsonData('Module:Entity/Item/communitySites.json')
	local links = format.buildSiteLinks(siteDefs, {
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
	getItemType = getItemType,
	getVolume = getVolume,
}

return p
