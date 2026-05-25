require('strict')

--- @module Entity/PageResolver
--- Resolves entity UUIDs to their canonical wiki pages (and page images) via
--- a single batched mw.smw.ask. Shared by Entity/Related, Entity/UsedBy and
--- Entity/Ports so the resolution lives in one place — the single seam to
--- swap when SMW is replaced (e.g. by Bucket).

local p = {}

--- Resolves UUIDs to pages via one mw.smw.ask over the canonical lowercase
--- `uuid` and legacy capitalized `UUID` properties (mirrors the dual-read in
--- Module:Entity/Data.readSmwUuid). Results are filtered to mainspace,
--- non-subobject pages: subobjects (`Page#hash`) would link to a template-data
--- anchor, and stray non-mainspace stores shouldn't hijack the link. The SMW
--- limit is over-fetched 5× so a UUID that also appears on a subobject isn't
--- truncated to only the subobject. First mainspace match per UUID wins.
--- UUIDs matching no mainspace page are absent from the map; callers fall back
--- to the API name (same possibly-wrong link as before, never worse).
---
--- @param uuids string[]
--- @return table<string, { page: string, image: string|nil }>
function p.resolve(uuids)
	if #uuids == 0 then
		return {}
	end
	local uuidList = table.concat(uuids, '||')
	local results = mw.smw.ask({
		'[[uuid::' .. uuidList .. ']] OR [[UUID::' .. uuidList .. ']]',
		'?uuid#-=uuid',
		'?UUID#-=uuid_legacy',
		'?#-=page',
		'?Page Image#-=image',
		'limit=' .. tostring(#uuids * 5),
	})
	local map = {}
	if type(results) == 'table' then
		for _, row in ipairs(results) do
			local uuid = (type(row.uuid) == 'string' and row.uuid ~= '' and row.uuid)
				or (type(row.uuid_legacy) == 'string' and row.uuid_legacy ~= '' and row.uuid_legacy)
				or nil
			if uuid and type(row.page) == 'string' and row.page ~= '' and not row.page:find('#', 1, true) then
				local title = mw.title.new(row.page)
				if title and title.namespace == 0 then
					local image = nil
					if type(row.image) == 'string' and row.image ~= '' then
						image = row.image:gsub('^File:', '')
					end
					if not map[uuid] then
						map[uuid] = { page = row.page, image = image }
					end
				end
			end
		end
	end
	return map
end

return p
