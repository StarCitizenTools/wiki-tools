require('strict')

--- @module Entity/Item/Module
--- Vehicle module subtype. Items with API type=="Module" are equipped to a
--- vehicle to change its function (e.g. Aurora Mk II combat/cargo modules,
--- Apollo medical-bay modules, Retaliator front/rear modules). Resolves the
--- owning vehicle(s) and contributes the vehicle link(s), the vehicle
--- category (primary structural bucket) plus a shared `Vehicle modules` type
--- bucket, a "for the <vehicle>" short description, and a queryable `vehicle`
--- structured-data property.
---
--- JumpDrive / MiningModifier display as "Jump module" / "Mining module" but
--- carry their own distinct API `type` strings, so only Aurora/Apollo/
--- Retaliator-style vehicle modules (type=="Module") route here.

local item = require('Module:Entity/Item')

local p = {}

--- @type string
p.parent = 'Entity/Item'

--- Resolves the owning vehicle name(s) for a module. Prefers the API
--- `vehicles` relation (the Item endpoint includes it) — each entry's `name`
--- is the real wiki vehicle title, and a module shared across variants lists
--- them all (e.g. an Apollo module returns both `Apollo Medivac` and
--- `Apollo Triage`). Falls back to `related_items.set_name` only when
--- `vehicles` is empty, which is the case for some modules (Aurora,
--- Retaliator return an empty `vehicles` array). Returns an ordered,
--- de-duplicated list of non-empty names, or {} when nothing resolves.
--- Nil-safe.
---
--- @param apiData table|nil
--- @return string[]
local function resolveVehicles(apiData)
	local out, seen = {}, {}
	local vehicles = apiData and apiData.vehicles
	if type(vehicles) == 'table' then
		for _, v in ipairs(vehicles) do
			local name = type(v) == 'table' and v.name or nil
			if type(name) == 'string' and name ~= '' and not seen[name] then
				seen[name] = true
				table.insert(out, name)
			end
		end
	end
	if #out == 0 then
		local related = apiData and apiData.related_items
		local setName = type(related) == 'table' and related.set_name or nil
		if type(setName) == 'string' and setName ~= '' then
			table.insert(out, setName)
		end
	end
	return out
end

--- Display metadata. Each owning vehicle's eponymous category is a structural
--- bucket for the module — the first is primary, any others (variants a module
--- is shared across) ride along as `categories` extras, so the module lands in
--- every owning vehicle's category. Every vehicle module also joins the shared
--- `Vehicle modules` type bucket. A module with no resolvable vehicle falls
--- back to `Vehicle modules` as its primary bucket.
---
--- @param apiData table
--- @param args table
--- @return table { name, category, categories }
function p.getTypeInfo(apiData, args)
	local vehicles = resolveVehicles(apiData)
	if #vehicles == 0 then
		return { name = 'Vehicle module', category = 'Vehicle modules' }
	end
	local extras = {}
	for i = 2, #vehicles do
		extras[#extras + 1] = vehicles[i]
	end
	extras[#extras + 1] = 'Vehicle modules'
	return { name = 'Vehicle module', category = vehicles[1], categories = extras }
end

--- Adds a Vehicle row linking the owning vehicle(s) to the General section
--- (Assembly.mergeSections appends it after Item's rows; chain is root-first).
--- Pluralises the label when a module serves more than one vehicle. Collapses
--- when no vehicle resolves.
---
--- @param apiData table
--- @param args table
--- @return EntitySectionEntry[]
function p.getSections(apiData, args)
	local vehicles = resolveVehicles(apiData)
	if #vehicles == 0 then
		return {}
	end
	local links = {}
	for _, name in ipairs(vehicles) do
		links[#links + 1] = '[[' .. name .. ']]'
	end
	return {
		{
			key = 'general',
			items = {
				{
					label = #vehicles > 1 and 'Vehicles' or 'Vehicle',
					content = table.concat(links, ', '),
				},
			},
		},
	}
end

--- Short description tuned for modules: "Vehicle module for the <vehicle>"
--- (Oxford-joined when more than one). Falls back to Item's
--- "<type> by <manufacturer>" form when no vehicle resolves.
---
--- @param apiData table
--- @param args table
--- @param typeInfo table
--- @param prefix string|nil
--- @return string
function p.getShortDescription(apiData, args, typeInfo, prefix)
	local vehicles = resolveVehicles(apiData)
	if #vehicles > 0 then
		return 'Vehicle module for the ' .. mw.text.listToText(vehicles)
	end
	return item.getShortDescription(apiData, args, typeInfo, prefix)
end

--- Stores the owning vehicle(s) as a queryable property so a vehicle page can
--- list its modules in the reverse direction later. A single vehicle stores a
--- scalar; multiple store a list (multi-valued). Omitted when none resolve.
---
--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	local vehicles = resolveVehicles(apiData)
	if #vehicles == 0 then
		return {}
	end
	return { vehicle = #vehicles == 1 and vehicles[1] or vehicles }
end

-- Test-only exports. Not part of the public API.
p._internal = {
	resolveVehicles = resolveVehicles,
}

return p
