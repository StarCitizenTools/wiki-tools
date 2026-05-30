require('strict')

--- @module Entity/TypeResolver
--- Resolves an entity's display metadata (typeInfo + display name) from the
--- curated classification map (Ship.* paths) with a fallback to the type map
--- (types.json). Pure apart from mw.loadJsonData of the curated tables.

local p = {}

--- Resolves an item's `classification` path (item-endpoint only) to curated
--- display metadata via Module:Entity/Item/classifications.json, by most-specific
--- matching prefix: try the full path, then drop trailing `.segment`s. Only
--- `Ship.*` paths are consulted; returns nil otherwise (callers fall back to the
--- type map). The API's generated `classification_label` is intentionally unused.
---
--- @param classification string|nil
--- @return table|nil { name, category }
local function resolveClassification(classification)
	if type(classification) ~= 'string' or classification:sub(1, 5) ~= 'Ship.' then
		return nil
	end
	local map = mw.loadJsonData('Module:Entity/Item/classifications.json')
	local path = classification
	while path and path ~= '' do
		local entry = map[path]
		if type(entry) == 'table' then
			return entry
		end
		path = path:match('^(.*)%.[^.]+$')
	end
	return nil
end

--- Resolves display metadata (typeInfo + display name). For items the curated
--- classification map wins (most-specific Ship.* prefix); otherwise falls back to
--- the type map (types.json) — which covers FPS items and any kind without a
--- mapped classification (e.g. vehicles, whose endpoint has no `classification`).
---
--- @param apiType string|nil
--- @param classification string|nil
--- @return table|nil typeInfo
--- @return string|nil displayType Display name (falls back to apiType when unmapped)
function p.resolve(apiType, classification)
	local typeInfo = resolveClassification(classification)
	if not typeInfo then
		local types = mw.loadJsonData('Module:Entity/Item/types.json')
		typeInfo = types[apiType]
	end
	return typeInfo, typeInfo and typeInfo.name or apiType
end

-- Test-only exports. Not part of the public API.
p._internal = {
	resolveClassification = resolveClassification,
}

return p
