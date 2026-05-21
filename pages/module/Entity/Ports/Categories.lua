require('strict')

--- @module Entity/Ports/Categories
--- Category configuration for Entity/Ports.
---
--- Loads categories.json once on require and exposes two pure
--- functions: `lookup` (label → category descriptor) and `deriveLabel`
--- (raw API port → label string).
---
--- The JSON file is keyed by the API's `category_label` string and
--- mirrors the upstream Apiunto layout; sync from:
---   https://github.com/StarCitizenWiki/API/blob/develop/app/Support/Game/HardpointCategory.php
--- When upstream adds / renames / re-buckets a category, update
--- categories.json to match. Unknown labels default to a primary card
--- with order 999 (fail-open); the explicit `collapsed:true` entries
--- route into the single "Other" card at the bottom.

local p = {}

local CATEGORIES_DATA = mw.loadJsonData('Module:Entity/Ports/categories.json')
local CATEGORIES = CATEGORIES_DATA.categories or {}
local TYPE_ALIASES = CATEGORIES_DATA.typeAliases or {}

--- Inserts a space before each capital letter after the first.
--- "ManneuverThruster" → "Manneuver Thruster". "X" → "X".
---
--- @param str string|nil
--- @return string
local function splitCamel(str)
	if type(str) ~= 'string' or str == '' then
		return str or ''
	end
	return (str:gsub('(%l)(%u)', '%1 %2'))
end

--- Resolves an API `category_label` string to a category descriptor.
--- Known labels carry an `order` (primary cards, sorted ascending) or
--- `collapsed:true` (routed into the single "Other" card at the
--- bottom). Unknown / empty labels default to primary with order 999
--- (fail-open — a new CIG category renders as its own card until we
--- catalogue it). `expandIntoTypes` is the vehicle-only per-parent
--- child-type allowlist for the L-tree.
---
--- @param label string|nil  the API's `category_label`, or a derived fallback
--- @return { label: string, order: integer, collapsed: boolean, expandIntoTypes: string[]|nil }
function p.lookup(label)
	if type(label) ~= 'string' or label == '' then
		return { label = 'Other', order = 1000, collapsed = true, expandIntoTypes = nil }
	end
	local entry = CATEGORIES[label]
	if entry then
		return {
			label = label,
			order = tonumber(entry.order) or 999,
			collapsed = entry.collapsed == true,
			expandIntoTypes = entry.expandIntoTypes,
		}
	end
	return { label = label, order = 999, collapsed = false, expandIntoTypes = nil }
end

--- Picks the category label for a port. Prefers the API's own
--- `category_label` (set on vehicle ports from Apiunto). Items
--- typically lack `category_label`, so fall back to the type-aliases
--- table; finally fall back to a CamelCase split of the type itself.
--- Returns "Other" when nothing usable is available.
---
--- @param rawPort table
--- @param compatibleTypes string[]  already-flattened compat slugs
--- @return string
function p.deriveLabel(rawPort, compatibleTypes)
	local apiLabel = rawPort.category_label
	if type(apiLabel) == 'string' and apiLabel ~= '' then
		return apiLabel
	end
	local rawType = type(rawPort.type) == 'string' and rawPort.type ~= '' and rawPort.type or nil
	if rawType and TYPE_ALIASES[rawType] then
		return TYPE_ALIASES[rawType]
	end
	local bareCompat
	if #compatibleTypes > 0 then
		bareCompat = compatibleTypes[1]:match('^[^.]+')
		if bareCompat and TYPE_ALIASES[bareCompat] then
			return TYPE_ALIASES[bareCompat]
		end
	end
	if rawType then
		return splitCamel(rawType)
	end
	if bareCompat and bareCompat ~= '' then
		return splitCamel(bareCompat)
	end
	return 'Other'
end

-- Test-only export. Not part of the public API.
p._internal = {
	splitCamel = splitCamel,
}

return p
