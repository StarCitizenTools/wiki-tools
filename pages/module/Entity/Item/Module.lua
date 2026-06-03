require('strict')

--- @module Entity/Item/Module
--- Vehicle module subtype. Items with API type=="Module" are equipped to a
--- vehicle to change its function (e.g. Aurora Mk II combat/cargo modules,
--- Retaliator front/rear modules). Resolves the owning vehicle from
--- related_items.set_name and contributes the vehicle link, the vehicle
--- category (the most-specific structural bucket) plus a shared
--- `Vehicle modules` type bucket, a "for the <vehicle>" short description,
--- and a queryable `vehicle` structured-data property.
---
--- JumpDrive / MiningModifier display as "Jump module" / "Mining module" but
--- carry their own distinct API `type` strings, so only Aurora/Retaliator-style
--- vehicle modules (type=="Module") route here.

local item = require('Module:Entity/Item')

local p = {}

--- @type string
p.parent = 'Entity/Item'

--- Resolves the owning vehicle's display/page name from the module's
--- related-items set. set_name is the only reliable signal — the items
--- endpoint's `vehicles` include comes back empty for modules. Returns nil
--- when absent or empty. Nil-safe.
---
--- @param apiData table|nil
--- @return string|nil
local function resolveSetName(apiData)
	local related = apiData and apiData.related_items
	local setName = type(related) == 'table' and related.set_name or nil
	if type(setName) == 'string' and setName ~= '' then
		return setName
	end
	return nil
end

--- Display metadata. When the module belongs to a vehicle set, the vehicle's
--- eponymous category is the module's primary structural bucket — we trust
--- set_name directly for now, deferring the wiki's category-naming
--- inconsistency (e.g. `Aegis Dynamics Retaliator` vs `Aurora Mk II`). Every
--- vehicle module also joins the shared `Vehicle modules` category (the
--- type-level browse bucket), contributed as a `categories` extra so it sits
--- alongside the vehicle category rather than replacing it. A module with no
--- resolvable set falls back to `Vehicle modules` as its primary bucket.
---
--- @param apiData table
--- @param args table
--- @return table { name, category, categories }
function p.getTypeInfo(apiData, args)
	local setName = resolveSetName(apiData)
	if setName then
		return { name = 'Vehicle module', category = setName, categories = { 'Vehicle modules' } }
	end
	return { name = 'Vehicle module', category = 'Vehicle modules' }
end

--- Adds a Vehicle row linking the owning vehicle to the General section
--- (Assembly.mergeSections appends it after Item's rows; chain is root-first).
--- Collapses when the module has no set.
---
--- @param apiData table
--- @param args table
--- @return EntitySectionEntry[]
function p.getSections(apiData, args)
	local setName = resolveSetName(apiData)
	if not setName then
		return {}
	end
	return {
		{
			key = 'general',
			items = {
				{ label = 'Vehicle', content = '[[' .. setName .. ']]' },
			},
		},
	}
end

--- Short description tuned for modules: "Vehicle module for the <vehicle>".
--- Falls back to Item's "<type> by <manufacturer>" form when there's no set.
---
--- @param apiData table
--- @param args table
--- @param typeInfo table
--- @param prefix string|nil
--- @return string
function p.getShortDescription(apiData, args, typeInfo, prefix)
	local setName = resolveSetName(apiData)
	if setName then
		return 'Vehicle module for the ' .. setName
	end
	return item.getShortDescription(apiData, args, typeInfo, prefix)
end

--- Stores the owning vehicle as a queryable property so a vehicle page can
--- list its modules in the reverse direction later. Omitted when absent.
---
--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	local setName = resolveSetName(apiData)
	if not setName then
		return {}
	end
	return { vehicle = setName }
end

-- Test-only exports. Not part of the public API.
p._internal = {
	resolveSetName = resolveSetName,
}

return p
