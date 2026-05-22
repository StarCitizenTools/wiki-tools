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

-- Canonical wiki vocabulary for raw item-type slugs, owned by Entity/Item.
-- Used as the second-tier fallback in `deriveLabel` so unmapped item-port
-- types (Char_Armor_Backpack, WeaponPersonal, Gadget, FPS_*, …) render with
-- their proper wiki names instead of the raw camelCase / snake_case slug.
-- Format per entry: `{ name = singular, category = plural }`. We read
-- `.category` for the card title.
local ITEM_TYPES = mw.loadJsonData('Module:Entity/Item/types.json')

--- Humanises a type slug for display when nothing in the curated tables
--- matches: replaces `_` with space, then inserts a space before each
--- camelCase boundary. "Char_Armor_Backpack" → "Char Armor Backpack";
--- "ManneuverThruster" → "Manneuver Thruster"; "X" → "X".
---
--- Strictly a last-resort fallback — the curated tables (typeAliases in
--- categories.json, then Module:Entity/Item/types.json) should cover all
--- production slugs.
---
--- @param str string|nil
--- @return string
local function splitCamel(str)
	if type(str) ~= 'string' or str == '' then
		return str or ''
	end
	local s = str:gsub('_', ' ')
	return (s:gsub('(%l)(%u)', '%1 %2'))
end

--- Looks up a raw type slug in the canonical item-type vocabulary
--- (Module:Entity/Item/types.json). Returns the `.category` field
--- (plural — "Backpacks", "Personal weapons") when present, nil otherwise.
---
--- @param slug string|nil  raw type slug
--- @return string|nil
local function itemTypeCategory(slug)
	if type(slug) ~= 'string' or slug == '' then
		return nil
	end
	local entry = ITEM_TYPES[slug]
	if entry and type(entry.category) == 'string' and entry.category ~= '' then
		return entry.category
	end
	return nil
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

--- Picks the category label for a port. Cascade:
---
---   1. API `category_label` (vehicle ports only — Apiunto resolves it
---      server-side from CIG metadata). Wins outright when present.
---   2. `typeAliases` in `categories.json` — curated overrides for
---      vehicle-side routing (TurretBase → "Manned Turrets",
---      MissileLauncher → "Missile & Bomb Racks", etc.) that
---      intentionally diverge from the item-type vocabulary.
---   3. `Module:Entity/Item/types.json` — canonical wiki item-type
---      vocabulary, owned by Entity/Item. Covers the rest
---      (Char_Armor_*, FPS_*, Gadget, WeaponPersonal, …).
---   4. `splitCamel(slug)` — last-resort humanisation for slugs not
---      catalogued anywhere. Renders snake_case + camelCase as words.
---   5. "Other" — when there's literally no slug to work with.
---
--- Each step tries `rawPort.type` first, then the bare type extracted
--- from `compatibleTypes[1]` (the part before the first dot in slugs
--- like `WeaponPersonal.Medium`).
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
	local bareCompat
	if #compatibleTypes > 0 then
		bareCompat = compatibleTypes[1]:match('^[^.]+')
	end
	-- Curated overrides (vehicle-side routing).
	if rawType and TYPE_ALIASES[rawType] then
		return TYPE_ALIASES[rawType]
	end
	if bareCompat and TYPE_ALIASES[bareCompat] then
		return TYPE_ALIASES[bareCompat]
	end
	-- Canonical wiki item-type vocabulary.
	local itemLabel = itemTypeCategory(rawType) or itemTypeCategory(bareCompat)
	if itemLabel then
		return itemLabel
	end
	-- Last-resort humanisation.
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
	itemTypeCategory = itemTypeCategory,
}

return p
