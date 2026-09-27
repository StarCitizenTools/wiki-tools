require('strict')

--- @module BucketQuery
--- The one module that knows which Bucket table and column each declared
--- property lives in, and the only one that builds a Bucket query from property
--- names. Domain-agnostic: the property manifests it searches are listed in
--- `Module:BucketQuery/manifests.json`, so adding a domain is a data edit and
--- this module names none of them.
---
--- A query roots on `primary` (default `entity`) and takes one join per other
--- bucket a column or filter touches. A filter on a joined bucket makes that
--- join INNER (Bucket's behaviour, not a choice here): that is the "has this
--- value" semantics a filter means, and it is why a table whose subject is not
--- an Entity page must set its own `primary` rather than rooting on `entity`.
---
--- Rows come back keyed by the requested display name (or alias) with typed
--- values: numbers, bare page titles, arrays for repeated fields; a field the
--- row does not have is absent.
---
--- Entity's own view of the store, including the current page's uuid and the
--- uuid-to-page lookups, is Module:Entity/Store, which requires this module.

--- Bucket's callable library. Resolved when a query runs, never at module load:
--- requiring `mw.ext.bucket` returns a fresh, non-callable copy of the library on
--- the wiki, and the bare `bucket` global fails the undeclared-global scan.
--- @return table
local function bucketLib()
	return mw.ext.bucket
end

local p = {}

-- Default base table, for the Entity data that is most of what is queried here.
-- A spec names another with `primary` when its subject is not an Entity page:
-- the join a filter forces is INNER, so rooting on `entity` would drop every
-- row with no Entity counterpart instead of failing.
local PRIMARY = 'entity'
local DEFAULT_LIMIT = 1000

-- The registry of property manifests, in search order, and the manifest each
-- kind is declared in. Data rather than a list here, and the same file the
-- Bucket schema generator reads, so a new domain is registered once instead of
-- in two hardcoded lists that can drift apart.
local REGISTRY_PAGE = 'Module:BucketQuery/manifests.json'

--- Where manifests come from: the registry's titles and kind map, loaded one at
--- a time as a search reaches them. Every manifest a page loads becomes a
--- dependency of that page and is re-parsed with it on every edit, so a search
--- stops at the first manifest that answers rather than loading them all.
--- @class BucketQuerySource
--- @field titles table manifest keys in search order
--- @field kinds table<string, any> kind name -> the key of the manifest declaring it
--- @field load fun(key: any): table

--- @type BucketQuerySource|nil
local source = nil

--- @return BucketQuerySource
local function getSource()
	if source == nil then
		local registry = mw.loadJsonData(REGISTRY_PAGE)
		source = { titles = registry.manifests, kinds = registry.kinds or {}, load = mw.loadJsonData }
	end
	return source
end

--- Calls `visit` on each manifest in search order, the one declaring `kind`
--- first, and returns the first non-nil result. Read with ipairs, never # or
--- next: mw.loadJsonData's tables break both.
--- @param kind string|nil
--- @param visit fun(manifest: table): any
--- @return any
local function search(kind, visit)
	local src = getSource()
	local own = kind and src.kinds[kind]
	if own ~= nil then
		local found = visit(src.load(own))
		if found ~= nil then
			return found
		end
	end
	for _, key in ipairs(src.titles) do
		if key ~= own then
			local found = visit(src.load(key))
			if found ~= nil then
				return found
			end
		end
	end
	return nil
end

--- @class BucketQueryEntry
--- @field bucket string
--- @field field string
--- @field type string PAGE|TEXT|INTEGER|DOUBLE|BOOLEAN
--- @field repeated boolean

local function resolveIn(m, displayName)
	local entry = m[displayName]
	if type(entry) == 'table' and entry.field then
		return { bucket = entry.bucket, field = entry.field, type = entry.type, repeated = entry.repeated == true }
	end
	return nil
end

--- Resolves a property display name to its bucket and field, searching the
--- registered manifests in the registry's order, the one the registry's `kinds`
--- names for `kind` first, and stopping at the first that declares it. `kind`
--- only orders the search: it matters for a name two manifests declare.
--- @param displayName string
--- @param kind string|nil Kind name the manifests disambiguate on (Vehicle, Item, Company, ...)
--- @return BucketQueryEntry|nil
function p.resolve(displayName, kind)
	return search(kind, function(m)
		return resolveIn(m, displayName)
	end)
end

--- @class BucketQueryColumn
--- @field property string|nil display name
--- @field builtin string|nil page_name | page_name_sub
--- @field as string|nil result key (defaults to property or builtin)

--- @class BucketQuerySpec
--- @field primary string|nil base table the query roots on; defaults to `entity`
--- @field kind string|nil
--- @field filters table list of: 'Category:X' | { property, value } | { property, op, value } | { any = { ... } }
--- @field columns table list of string|BucketQueryColumn
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
		error("BucketQuery: unknown property '" .. tostring(property) .. "'")
	end
	if entry.bucket ~= (spec.primary or PRIMARY) and not joins.seen[entry.bucket] then
		joins.seen[entry.bucket] = true
		joins[#joins + 1] = entry.bucket
	end
	return entry
end

local function condition(spec, f, joins, filtered)
	if type(f) == 'string' then
		return { f } -- category selector, table form so it can sit beside field conditions
	end
	if type(f) ~= 'table' then
		error('BucketQuery: bad filter ' .. tostring(f))
	end
	if f.any then
		local parts = {}
		for i, sub in ipairs(f.any) do
			if type(sub) == 'string' then
				parts[i] = sub
			else
				parts[i] = condition(spec, sub, joins, filtered)
			end
		end
		return bucketLib().Or(unpack(parts))
	end
	local property, op, value = f[1], f[2], f[3]
	if value == nil and op ~= '+' then
		op, value = '=', op
	end
	local entry = resolveOrError(spec, property, joins)
	filtered[entry.bucket] = true
	local selector = selectorFor(entry, spec.primary or PRIMARY)
	if op == '+' then
		return bucketLib().Not({ selector, bucketLib().Null() })
	end
	if RELATIONAL[op] then
		if not NUMERIC[entry.type] then
			error("BucketQuery: '" .. property .. "' is not numeric")
		end
	elseif op == '!=' then
		if entry.repeated then
			error("BucketQuery: '!=' cannot be applied to the repeated property '" .. property .. "'")
		end
	elseif op ~= '=' then
		error("BucketQuery: unknown operator '" .. tostring(op) .. "'")
	end
	return { selector, op, value }
end

--- Bucket matches a join key through the database collation, which ignores
--- case, so a joined row can belong to a page whose title differs from the
--- primary's only in case (the FrostBite cooler beside the Frostbite
--- settlement). Each joined bucket's own page_name is selected so the pair can
--- be told apart. A mismatch on a filtered (INNER) join drops the row. On an
--- unfiltered (LEFT) join the row stays with that bucket's fields left out,
--- unless the same page also came back correctly matched.
--- @return table[] { row = raw row, without = set of buckets whose fields to omit }
local function matchJoinCase(raw, joins, filtered)
	local matched, items = {}, {}
	for _, r in ipairs(raw) do
		local page, without, inner = r.page_name, nil, false
		for _, bucket in ipairs(joins) do
			local other = r[bucket .. '.page_name']
			if page ~= nil and other ~= nil and other ~= page then
				without = without or {}
				without[bucket] = true
				inner = inner or filtered[bucket] == true
			end
		end
		if without == nil then
			if page ~= nil then
				matched[page] = true
			end
			items[#items + 1] = { row = r }
		elseif not inner then
			items[#items + 1] = { row = r, without = without, page = page }
		end
	end
	local kept = {}
	for _, item in ipairs(items) do
		if item.without == nil or not matched[item.page] then
			kept[#kept + 1] = item
		end
	end
	return kept
end

--- Runs one query against the primary bucket, joining any other bucket a
--- column or filter touches. Errors (not nil) on an unknown property or a bad
--- operator, so a wrong column name or filter fails the render loudly instead
--- of rendering an empty column.
--- @param spec BucketQuerySpec
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
	local conds, filtered = {}, {}
	for i, f in ipairs(spec.filters or {}) do
		conds[i] = condition(spec, f, joins, filtered)
	end
	if joins[1] then
		local guards = { 'page_name' }
		for _, bucket in ipairs(joins) do
			guards[#guards + 1] = bucket .. '.page_name'
		end
		for _, selector in ipairs(guards) do
			if not keys[selector] then
				selectors[#selectors + 1] = selector
			end
		end
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
	for _, item in ipairs(matchJoinCase(type(raw) == 'table' and raw or {}, joins, filtered)) do
		local row = {}
		for selector, keyList in pairs(keys) do
			local bucket = selector:match('^([^.]+)%.')
			if not (item.without and bucket and item.without[bucket]) then
				for _, key in ipairs(keyList) do
					row[key] = item.row[selector]
				end
			end
		end
		rows[#rows + 1] = row
	end
	return rows
end

--- @class BucketQueryInternal
--- @field setManifests fun(list: table[]|nil) Test-only manifest override, searched in list order with each manifest's %kinds as the kind map; nil restores the registry.

-- Test-only exports. Not part of the public API.
--- @type BucketQueryInternal
p._internal = {
	setManifests = function(list)
		if list == nil then
			source = nil
			return
		end
		local titles, kinds = {}, {}
		for i, m in ipairs(list) do
			titles[i] = i
			for kind in pairs(type(m['%kinds']) == 'table' and m['%kinds'] or {}) do
				kinds[kind] = kinds[kind] or i
			end
		end
		source = {
			titles = titles,
			kinds = kinds,
			load = function(i)
				return list[i]
			end,
		}
	end,
}

return p
