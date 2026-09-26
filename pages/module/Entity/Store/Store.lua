require('strict')

--- @module Entity/Store
--- Entity's own view of the Bucket store: the current page's uuid, one stored
--- value for the current page, and the uuid-to-page and page-to-summary lookups
--- the Entity renderers need. Everything here roots on the `entity` bucket
--- literally, which is what makes it Entity's rather than shared.
---
--- The generic layer -- which table and column a property lives in, and how a
--- query is built from property names -- is Module:BucketQuery. `resolve`,
--- `needsKind` and `query` are re-exported here so Entity's own callers have one
--- module to reach for; a consumer that is NOT Entity code should require
--- Module:BucketQuery directly rather than reaching into this namespace.

local BucketQuery = require('Module:BucketQuery')

--- Bucket's callable library. Resolved when a query runs, never at module load:
--- requiring `mw.ext.bucket` returns a fresh, non-callable copy of the library on
--- the wiki, and the bare `bucket` global fails the undeclared-global scan.
--- @return table
local function bucketLib()
	return mw.ext.bucket
end

local p = {}

-- Every query below is about Entity pages, so the bucket is named, not defaulted.
local PRIMARY = 'entity'

-- One `where` per uuid, so a batch is bounded by Bucket's condition budget
-- rather than by the caller's list length.
local UUID_BATCH = 50

-- Re-exported from Module:BucketQuery; see the note above on which module a
-- consumer should require.
p.resolve = BucketQuery.resolve
p.needsKind = BucketQuery.needsKind
p.query = BucketQuery.query

--- One page's row from `bucket`, or nil for a page off the main namespace:
--- Bucket rows exist only for main-namespace pages, so without this guard a
--- same-titled Talk:/Template:/... page would match the mainspace entity's
--- row, and `title.text` equals `page_name` only for namespace 0. Wrapped in
--- `pcall`: a Bucket infrastructure failure (rate limit, timeout) degrades to
--- nil rather than red-erroring the page, which is also the documented answer
--- for "no row yet".
--- @param title table|nil a mw.title
--- @param bucket string
--- @param field string
--- @return table|nil
local function rowFor(title, bucket, field)
	if not title or title.namespace ~= 0 then
		return nil
	end
	local ok, raw = pcall(function()
		return bucketLib()(bucket).select(field).where({ 'page_name', '=', title.text }).limit(1).run()
	end)
	if not ok then
		return nil
	end
	return type(raw) == 'table' and raw[1] or nil
end

--- The current page's own row from `bucket`; shared by selfUuid, selfValue and
--- selfValues so they do not duplicate the query.
--- @param bucket string
--- @param field string
--- @return table|nil
local function selfRow(bucket, field)
	return rowFor(mw.title.getCurrentTitle(), bucket, field)
end

--- The uuid stored for the current page, available after its first link
--- update. Runs on every {{Entity}} invocation.
--- @return string|nil
function p.selfUuid()
	local row = selfRow(PRIMARY, 'uuid')
	if row and type(row.uuid) == 'string' and row.uuid ~= '' then
		return row.uuid
	end
	return nil
end

--- The current page's own stored value of `displayName` (resolved through
--- resolve(), so a per-kind property needs `kind`), nil until its first link
--- update has run. nil when `displayName` does not resolve, or when the row's
--- value is neither a non-empty string nor a number (e.g. a repeated field's
--- array, or absent).
--- @param displayName string
--- @param kind string|nil
--- @return string|number|nil
function p.selfValue(displayName, kind)
	local entry = p.resolve(displayName, kind)
	if entry == nil then
		return nil
	end
	local row = selfRow(entry.bucket, entry.field)
	local value = row and row[entry.field]
	if type(value) == 'string' and value ~= '' then
		return value
	end
	if type(value) == 'number' then
		return value
	end
	return nil
end

--- The current page's own stored values for a REPEATED property, as a list.
--- A repeated field comes back as an array, which selfValue deliberately
--- rejects, so a caller that wants one needs this instead. nil until the page's
--- first link update has run, and nil when the row holds no usable value.
--- @param displayName string
--- @param kind string|nil
--- @return string[]|nil
function p.selfValues(displayName, kind)
	local entry = p.resolve(displayName, kind)
	if entry == nil then
		return nil
	end
	local row = selfRow(entry.bucket, entry.field)
	local value = row and row[entry.field]
	if type(value) ~= 'table' then
		return nil
	end
	local out = {}
	for _, item in ipairs(value) do
		if type(item) == 'string' and item ~= '' then
			out[#out + 1] = item
		end
	end
	return out[1] and out or nil
end

--- Another page's stored value of `displayName` (resolved through resolve(),
--- so a per-kind property needs `kind`), nil when the page is not in the main
--- namespace, has no row, or holds neither a non-empty string nor a number.
--- @param page string|nil
--- @param displayName string
--- @param kind string|nil
--- @return string|number|nil
function p.pageValue(page, displayName, kind)
	if type(page) ~= 'string' or page == '' then
		return nil
	end
	local entry = p.resolve(displayName, kind)
	if entry == nil then
		return nil
	end
	-- Rows are keyed by the page a redirect lands on: StructuredData stores a
	-- PAGE value as its redirect target. Reading `redirectTarget` loads the
	-- page and records a templatelinks edge to it, so editing the target page
	-- queues a refresh of every page naming it here (for the CURRENT page,
	-- Scribunto instead varies the cached render by that page's revision
	-- SHA1, rather than adding that edge).
	local title = mw.title.new(page)
	if title and title.redirectTarget then
		title = title.redirectTarget
	end
	local row = rowFor(title, entry.bucket, entry.field)
	local value = row and row[entry.field]
	if type(value) == 'string' and value ~= '' then
		return value
	end
	if type(value) == 'number' then
		return value
	end
	return nil
end

--- Maps uuids to their page and infobox image. Bucket rows exist only for
--- main-namespace pages (the write-side rule), so no namespace check is needed.
--- @param uuids string[]
--- @return table<string, { page: string, image: string|nil }>
function p.resolveUuids(uuids)
	local map = {}
	for start = 1, #uuids, UUID_BATCH do
		local conds = {}
		for i = start, math.min(start + UUID_BATCH - 1, #uuids) do
			conds[#conds + 1] = { 'uuid', '=', uuids[i] }
		end
		-- 2x headroom: a duplicate-uuid page (a known live condition) needs a
		-- second slot per uuid before a batch starts truncating.
		local raw = bucketLib()(PRIMARY)
			.select('uuid', 'page_name', 'image')
			.where(bucketLib().Or(unpack(conds)))
			.limit(#conds * 2)
			.run()
		for _, r in ipairs(type(raw) == 'table' and raw or {}) do
			if type(r.uuid) == 'string' and type(r.page_name) == 'string' and not map[r.uuid] then
				local image = r.image
				if type(image) ~= 'string' or image == '' then
					image = nil
				end
				map[r.uuid] = { page = r.page_name, image = image }
			end
		end
	end
	return map
end

--- Rows for the given page titles (vehicle readers): manufacturer, role and
--- image keyed by page name. Batches of UUID_BATCH equalities; a Bucket
--- failure yields an empty map for that batch, contained in `pcall` here
--- rather than left to the caller (unlike resolveUuids).
--- @param names string[]
--- @return table<string, { name: string|nil, manufacturer: string|nil, role: string|nil, image: string|nil }>
function p.resolvePages(names)
	local map = {}
	for start = 1, #names, UUID_BATCH do
		local conds = {}
		for i = start, math.min(start + UUID_BATCH - 1, #names) do
			conds[#conds + 1] = { 'page_name', '=', names[i] }
		end
		local ok, raw = pcall(function()
			return bucketLib()(PRIMARY)
				.select('page_name', 'name', 'manufacturer', 'image', 'vehicle.role')
				.join('vehicle', 'vehicle.page_name', PRIMARY .. '.page_name')
				.where(bucketLib().Or(unpack(conds)))
				.limit(#conds)
				.run()
		end)
		for _, r in ipairs((ok and type(raw) == 'table') and raw or {}) do
			if type(r.page_name) == 'string' then
				map[r.page_name] =
					{ name = r.name, manufacturer = r.manufacturer, role = r['vehicle.role'], image = r.image }
			end
		end
	end
	return map
end

-- Test-only exports. Not part of the public API. The manifest override lives on
-- Module:BucketQuery, which owns the manifests; it is re-exported so a suite
-- testing Entity's helpers does not need to require both modules.
p._internal = {
	setManifests = BucketQuery._internal.setManifests,
}

return p
