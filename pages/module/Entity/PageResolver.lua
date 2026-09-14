require('strict')

--- @module Entity/PageResolver
--- Resolves entity UUIDs to their canonical wiki pages (and infobox images)
--- from the Bucket `entity` table. Shared by Entity/Related, Entity/UsedBy and
--- Entity/Ports so the resolution lives in one place. Rows exist only for
--- main-namespace pages, so no namespace or subobject filtering is needed here.

local store = require('Module:Entity/Store')

local p = {}

--- UUIDs matching no page are absent from the map; callers fall back to the
--- API name (same possibly-wrong link as before, never worse). A Bucket
--- infrastructure failure is treated the same way: an empty map, so every
--- caller falls back rather than the page erroring.
---
--- @param uuids string[]
--- @return table<string, { page: string, image: string|nil }>
function p.resolve(uuids)
	if #uuids == 0 then
		return {}
	end
	local ok, map = pcall(store.resolveUuids, uuids)
	if not ok then
		return {}
	end
	return map
end

return p
