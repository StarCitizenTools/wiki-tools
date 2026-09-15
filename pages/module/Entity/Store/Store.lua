require('strict')

--- @module Entity/Store
--- The one module that knows which Bucket table and column each Entity or
--- Company property lives in. Every query has `entity` as the primary bucket
--- and one join per other bucket a column or filter touches. A filter on a
--- joined bucket makes that join INNER (Bucket's behaviour, not a choice
--- here): that is the "has this value" semantics a filter means. Properties
--- resolve against `Module:Entity/properties.json` then `Module:Company/properties.json`
--- then `Module:WearableSet/properties.json`, the caller's kind (when given)
--- searched first. Rows come back keyed by the
--- requested display name (or alias) with typed values: numbers, bare page
--- titles, arrays for repeated fields; a field the row does not have is
--- absent.

--- Bucket's callable library. Resolved when a query runs, never at module load:
--- requiring `mw.ext.bucket` returns a fresh, non-callable copy of the library on
--- the wiki, and the bare `bucket` global fails the undeclared-global scan.
--- @return table
local function bucketLib()
	return mw.ext.bucket
end

local p = {}

-- Default base table. A spec may name another with `primary`, for a table whose
-- subject is not an Entity page: a filter on a joined bucket makes that join
-- INNER, so rooting on `entity` would drop every page with no Entity row.
local PRIMARY = 'entity'
local DEFAULT_LIMIT = 1000
local UUID_BATCH = 50

-- Manifests are searched in this order; a kind's own manifest is searched first
-- when the caller names a kind.
local MANIFEST_TITLES =
	{ 'Module:Entity/properties.json', 'Module:Company/properties.json', 'Module:WearableSet/properties.json' }

local manifests = nil

local function getManifests()
	if manifests == nil then
		manifests = {}
		for i, title in ipairs(MANIFEST_TITLES) do
			manifests[i] = mw.loadJsonData(title)
		end
	end
	return manifests
end

local function listsKind(m, kind)
	local kinds = m['%kinds']
	return type(kinds) == 'table' and kinds[kind] ~= nil
end

--- The manifests to search for `kind`, the kind's own first.
--- @param kind string|nil
--- @return table[]
local function manifestsFor(kind)
	local all = getManifests()
	if kind == nil then
		return all
	end
	local ordered = {}
	for _, m in ipairs(all) do
		if listsKind(m, kind) then
			ordered[#ordered + 1] = m
		end
	end
	for _, m in ipairs(all) do
		if not listsKind(m, kind) then
			ordered[#ordered + 1] = m
		end
	end
	return ordered
end

--- @class StoreEntry
--- @field bucket string
--- @field field string
--- @field type string PAGE|TEXT|INTEGER|DOUBLE|BOOLEAN
--- @field repeated boolean

local function resolveIn(m, displayName, kind)
	local entry = m[displayName]
	if type(entry) == 'table' and entry.field then
		local bucket = entry.bucket
		if type(bucket) == 'table' then
			bucket = kind and bucket[kind] or nil
		end
		if type(bucket) ~= 'string' then
			return nil
		end
		return { bucket = bucket, field = entry.field, type = entry.type, repeated = entry.repeated == true }
	end
	return nil
end

--- Resolves a property display name to its bucket and field, searching
--- `Module:Entity/properties.json` then `Module:Company/properties.json` then
--- `Module:WearableSet/properties.json` (the manifest listing `kind` under
--- `%kinds` first, when `kind` is given). A
--- property whose manifest bucket is keyed by kind needs `kind`; without it
--- such a property is unresolvable (nil), never guessed.
--- @param displayName string
--- @param kind string|nil Entity kind name (Vehicle, Item, ...) or Company
--- @return StoreEntry|nil
function p.resolve(displayName, kind)
	for _, m in ipairs(manifestsFor(kind)) do
		local entry = resolveIn(m, displayName, kind)
		if entry then
			return entry
		end
	end
	return nil
end

--- True when the property's bucket depends on the kind, so resolve() needs one.
--- @param displayName string
--- @return boolean
function p.needsKind(displayName)
	for _, m in ipairs(getManifests()) do
		local entry = m[displayName]
		if type(entry) == 'table' and type(entry.bucket) == 'table' then
			return true
		end
	end
	return false
end

--- @class StoreColumn
--- @field property string|nil display name
--- @field builtin string|nil page_name | page_name_sub
--- @field as string|nil result key (defaults to property or builtin)

--- @class StoreSpec
--- @field primary string|nil base table the query roots on; defaults to `entity`
--- @field kind string|nil
--- @field filters table list of: 'Category:X' | { property, value } | { property, op, value } | { any = { ... } }
--- @field columns table list of string|StoreColumn
--- @field limit number|nil

local NUMERIC = { INTEGER = true, DOUBLE = true }
local RELATIONAL = { ['<'] = true, ['<='] = true, ['>'] = true, ['>='] = true }

--- The primary's own fields are selected bare; every other bucket's are
--- qualified. Defaults rather than trusting the caller: a nil primary would
--- qualify every selector, which Bucket accepts and which then silently changes
--- what a query returns.
local function selectorFor(entry, primary)
	if entry.bucket == (primary or PRIMARY) then
		return entry.field
	end
	return entry.bucket .. '.' .. entry.field
end

--- Resolves a property or errors naming it, and records its bucket in `joins`.
local function resolveOrError(spec, property, joins)
	local entry = p.resolve(property, spec.kind)
	if entry == nil then
		error("Store: unknown property '" .. tostring(property) .. "'")
	end
	if entry.bucket ~= (spec.primary or PRIMARY) and not joins.seen[entry.bucket] then
		joins.seen[entry.bucket] = true
		joins[#joins + 1] = entry.bucket
	end
	return entry
end

local function condition(spec, f, joins)
	if type(f) == 'string' then
		return { f } -- category selector, table form so it can sit beside field conditions
	end
	if type(f) ~= 'table' then
		error('Store: bad filter ' .. tostring(f))
	end
	if f.any then
		local parts = {}
		for i, sub in ipairs(f.any) do
			if type(sub) == 'string' then
				parts[i] = sub
			else
				parts[i] = condition(spec, sub, joins)
			end
		end
		return bucketLib().Or(unpack(parts))
	end
	local property, op, value = f[1], f[2], f[3]
	if value == nil and op ~= '+' then
		op, value = '=', op
	end
	local entry = resolveOrError(spec, property, joins)
	local selector = selectorFor(entry, spec.primary or PRIMARY)
	if op == '+' then
		return bucketLib().Not({ selector, bucketLib().Null() })
	end
	if RELATIONAL[op] then
		if not NUMERIC[entry.type] then
			error("Store: '" .. property .. "' is not numeric")
		end
	elseif op == '!=' then
		if entry.repeated then
			error("Store: '!=' cannot be applied to the repeated property '" .. property .. "'")
		end
	elseif op ~= '=' then
		error("Store: unknown operator '" .. tostring(op) .. "'")
	end
	return { selector, op, value }
end

--- Runs one query against the primary bucket, joining any other bucket a
--- column or filter touches. Errors (not nil) on an unknown property or a bad
--- operator, so a wrong column name or filter fails the render loudly instead
--- of rendering an empty column.
--- @param spec StoreSpec
--- @return table[] rows keyed by result key
function p.query(spec)
	local primary = spec.primary or PRIMARY
	local selectors, keys, joins = {}, {}, { seen = {} }
	for _, col in ipairs(spec.columns or {}) do
		local selector, key
		if type(col) == 'string' then
			col = { property = col }
		end
		if col.builtin then
			selector, key = col.builtin, col.as or col.builtin
		else
			local entry = resolveOrError(spec, col.property, joins)
			selector, key = selectorFor(entry, primary), col.as or col.property
		end
		if not keys[selector] then
			selectors[#selectors + 1] = selector
			keys[selector] = {}
		end
		table.insert(keys[selector], key)
	end
	local conds = {}
	for i, f in ipairs(spec.filters or {}) do
		conds[i] = condition(spec, f, joins)
	end
	local q = bucketLib()(primary).select(unpack(selectors))
	for _, bucket in ipairs(joins) do
		q = q.join(bucket, bucket .. '.page_name', primary .. '.page_name')
	end
	if #conds > 0 then
		q = q.where(unpack(conds))
	end
	q = q.limit(spec.limit or DEFAULT_LIMIT)
	local raw = q.run()
	local rows = {}
	for _, r in ipairs(type(raw) == 'table' and raw or {}) do
		local row = {}
		for selector, keyList in pairs(keys) do
			for _, key in ipairs(keyList) do
				row[key] = r[selector]
			end
		end
		rows[#rows + 1] = row
	end
	return rows
end

--- The current page's own row from `bucket`, or nil off the main namespace: Bucket
--- rows exist only for main-namespace pages (see resolveUuids), so without this
--- guard a same-titled Talk:/Template:/... page would match the mainspace
--- entity's row. `title.text` is provably equal to `page_name` for namespace 0
--- (no prefix to strip, so text/prefixedText/fullText coincide). Wrapped in
--- `pcall`: a Bucket infrastructure failure (rate limit, timeout) degrades to
--- nil rather than red-erroring the page, the documented answer for "no row
--- yet" besides. Shared by selfUuid and selfValue so the two do not duplicate
--- the query.
--- @param bucket string
--- @param field string
--- @return table|nil
local function selfRow(bucket, field)
	local title = mw.title.getCurrentTitle()
	if title.namespace ~= 0 then
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

--- @class StoreInternal
--- @field setManifests fun(list: table[]|nil) Test-only manifest override; nil restores the lazy load of `MANIFEST_TITLES`.

-- Test-only exports. Not part of the public API.
--- @type StoreInternal
p._internal = {
	setManifests = function(list)
		manifests = list
	end,
}

return p
