require('strict')

--- @module Entity/PageResolver
--- Resolves entity UUIDs to their canonical wiki pages (and page images) via
--- batched mw.smw.ask queries. Shared by Entity/Related, Entity/UsedBy and
--- Entity/Ports so the resolution lives in one place — the single seam to
--- swap when SMW is replaced (e.g. by Bucket).

local p = {}

--- Runs one single-property batched ask and folds its mainspace, non-subobject
--- matches into `map` (first match per UUID wins; later calls never overwrite).
--- Subobjects (`Page#hash`) would link to a template-data anchor, and stray
--- non-mainspace stores shouldn't hijack the link, so both are skipped. The SMW
--- limit is over-fetched 5× so a UUID that also appears on a subobject isn't
--- truncated to only the subobject.
---
--- Each property is queried on its own rather than as one `[[uuid::…]] OR
--- [[UUID::…]]` disjunction: SMW degrades a combined OR to match *every*
--- subject (capped at the 2000-row limit) when the leading disjunct names an
--- unregistered property — which lowercase `uuid` is until pages migrate to the
--- new Entity schema. A single-property condition resolves correctly whatever
--- the property's registration state, so this is order- and migration-proof.
---
--- @param map table<string, { page: string, image: string|nil }>
--- @param property string SMW property name to match UUIDs against
--- @param uuidList string `||`-joined UUID values
--- @param limit string row limit (string form for the ask param)
local function collect(map, property, uuidList, limit)
	local results = mw.smw.ask({
		'[[' .. property .. '::' .. uuidList .. ']]',
		'?' .. property .. '#-=uuid',
		'?#-=page',
		'?Page Image#-=image',
		'limit=' .. limit,
	})
	if type(results) ~= 'table' then
		return
	end
	for _, row in ipairs(results) do
		local uuid = type(row.uuid) == 'string' and row.uuid ~= '' and row.uuid or nil
		if
			uuid
			and not map[uuid]
			and type(row.page) == 'string'
			and row.page ~= ''
			and not row.page:find('#', 1, true)
		then
			local title = mw.title.new(row.page)
			if title and title.namespace == 0 then
				local image = nil
				if type(row.image) == 'string' and row.image ~= '' then
					image = row.image:gsub('^File:', '')
				end
				map[uuid] = { page = row.page, image = image }
			end
		end
	end
end

--- Resolves UUIDs to pages over the canonical lowercase `uuid` and legacy
--- capitalized `UUID` properties (mirrors the dual-read in
--- Module:Entity/Data.readSmwUuid). The new `uuid` property is queried first so
--- a migrated page's value wins over any stale legacy `UUID` store. UUIDs
--- matching no mainspace page are absent from the map; callers fall back to the
--- API name (same possibly-wrong link as before, never worse).
---
--- @param uuids string[]
--- @return table<string, { page: string, image: string|nil }>
function p.resolve(uuids)
	if #uuids == 0 then
		return {}
	end
	local uuidList = table.concat(uuids, '||')
	local limit = tostring(#uuids * 5)
	local map = {}
	collect(map, 'uuid', uuidList, limit)
	collect(map, 'UUID', uuidList, limit)
	return map
end

return p
