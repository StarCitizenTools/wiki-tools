require('strict')

--- @module Entity/StructuredData
--- Stores an Entity page's structured data in Bucket, from the main namespace
--- only, split into one put per table by Module:Entity/properties.json.
---
--- One Entity page writes at most one row per bucket, from `Module:Entity`,
--- `store`'s only caller, except in the `%rows` buckets, where `storeRows`
--- writes one row per thing the page has several of (a vehicle's cargo grids).
--- A page whose kind never resolved is stored with
--- `kind = nil`: its entity-routable keys are still written (e.g. an item with
--- no uuid), so a Bucket query over the whole category still finds it, and the
--- keys that need a kind to route are written nowhere.
---
--- `putBuckets` and `shape` are exported for callers that build their own rows
--- outside the kind/manifest split above: `Module:Company` shapes its own
--- manifest entries and writes them through the same put loop.

--- Bucket's callable library. Resolved when a query runs, never at module load:
--- requiring `mw.ext.bucket` returns a fresh, non-callable copy of the library on
--- the wiki, and the bare `bucket` global fails the undeclared-global scan.
--- @return table
local function bucketLib()
	return mw.ext.bucket
end

local p = {}

local PROPERTIES_PAGE = 'Module:Entity/properties.json'

local manifest = nil

local function getManifest()
	if manifest == nil then
		manifest = mw.loadJsonData(PROPERTIES_PAGE)
	end
	return manifest
end

--- The manifest key for an emitter key: underscores to spaces, first letter
--- upper-cased. properties.json is keyed by these display names, so every
--- lookup goes through here.
--- @param key string
--- @return string
local function autoName(key)
	local spaced = key:gsub('_', ' ')
	return (spaced:gsub('^%l', string.upper))
end

--- The Bucket entry for an emitter key, looked up by its display name. nil when
--- the key is not a Bucket field.
--- @param m table
--- @param key string
--- @return table|nil entry { bucket = string, field, type, repeated }
local function bucketEntry(m, key)
	local entry = m[autoName(key)]
	if type(entry) == 'table' and entry.field then
		return entry
	end
	return nil
end

--- Extracts a bare page title from a `[[Target]]` or `[[Target|Display]]`
--- wikitext link and normalises it the way MediaWiki does ("microTech" ->
--- "MicroTech"), so a PAGE column holds one spelling per page. A `|` outside
--- brackets is plain content, not a link display split, and makes a title
--- MediaWiki rejects; such a value is kept verbatim. A redirect is followed to
--- its target, so a query for the canonical page also matches rows written
--- through one of its redirects. Reading `redirectTarget` costs no expensive
--- parser call, but it does register the target as a template dependency, one
--- templatelinks edge per PAGE value: editing a manufacturer or a patch page
--- therefore queues a refresh of every page naming it.
--- @param v any
--- @return any
local function pageTitle(v)
	if type(v) ~= 'string' then
		return v
	end
	local inner = v:match('^%[%[:?(.-)%]%]$')
	if inner then
		v = inner:match('^([^|]*)') or inner
	end
	local t = mw.title.new(v)
	if not t then
		return v
	end
	local target = t.redirectTarget
	if target then
		t = target
	end
	return t.prefixedText
end

--- Shapes a value for Bucket: repeated fields are arrays of distinct values
--- in first-occurrence order (each element stripped to a bare title when the
--- field is PAGE); non-repeated PAGE fields are bare titles, everything else
--- passes through.
--- @param entry table manifest entry: { type, repeated, ... }
--- @param v any raw emitter value
--- @return any
local function bucketValue(entry, v)
	if entry.repeated then
		local list = (type(v) == 'table') and v or { v }
		local out, seen = {}, {}
		for _, item in ipairs(list) do
			if entry.type == 'PAGE' then
				item = pageTitle(item)
			end
			if item ~= nil and not seen[item] then
				seen[item] = true
				out[#out + 1] = item
			end
		end
		return out
	end
	if type(v) == 'table' then
		v = v[1]
	end
	if entry.type == 'PAGE' then
		v = pageTitle(v)
	end
	return v
end

--- The buckets a manifest meta key (`%kinds` or `%rows`) lists for a kind, as
--- a set, seeded with `seed`.
--- @param m table decoded properties.json
--- @param metaKey string
--- @param kind string|nil
--- @param seed table<string, boolean>
--- @return table<string, boolean>
local function bucketsFor(m, metaKey, kind, seed)
	local allowed = seed
	local lists = m[metaKey]
	if type(lists) == 'table' and kind and type(lists[kind]) == 'table' then
		for _, b in ipairs(lists[kind]) do
			allowed[b] = true
		end
	end
	return allowed
end

--- Splits emitter data into one table per bucket in `allowed`.
--- @param m table decoded properties.json
--- @param data table<string, any>
--- @param allowed table<string, boolean>
--- @return table<string, table> puts bucket -> field -> value
--- @return string[] unregistered keys that reach no allowed bucket
local function routeByBucket(m, data, allowed)
	local puts, unregistered = {}, {}
	local function put(bucket, entry, v)
		puts[bucket] = puts[bucket] or {}
		puts[bucket][entry.field] = bucketValue(entry, v)
	end
	for k, v in pairs(data) do
		local entry = bucketEntry(m, k)
		local bucket = entry and entry.bucket
		-- `migrateTo` names the table a property is moving to: it is written there
		-- as well while readers still read `bucket`, so the new column is full
		-- before the manifest points readers at it.
		local target = entry and entry.migrateTo
		local routed = false
		if v ~= nil and type(bucket) == 'string' and allowed[bucket] then
			put(bucket, entry, v)
			routed = true
		end
		if v ~= nil and type(target) == 'string' and allowed[target] then
			put(target, entry, v)
			routed = true
		end
		if not routed then
			unregistered[#unregistered + 1] = k
		end
	end
	return puts, unregistered
end

--- Splits a page's one-row data into one table per bucket the kind may write:
--- `entity` and the kind's `%kinds` buckets.
--- @param m table decoded properties.json
--- @param data table<string, any>
--- @param kind string|nil kind name; nil allows only the entity bucket
--- @return table<string, table> puts bucket -> field -> value
--- @return string[] unregistered keys that reach no bucket for this kind
local function splitByBucket(m, data, kind)
	return routeByBucket(m, data, bucketsFor(m, '%kinds', kind, { entity = true }))
end

--- Writes one put per bucket, only from the main namespace.
--- @param rows table<string, table<string, any>> bucket -> field -> shaped value
--- @return string|nil error
function p.putBuckets(rows)
	if mw.title.getCurrentTitle().namespace ~= 0 then
		return nil
	end
	local ok, err = pcall(function()
		for bucket, fields in pairs(rows) do
			bucketLib()(bucket).put(fields)
		end
	end)
	if not ok then
		return 'Bucket storage failed: ' .. tostring(err)
	end
	return nil
end

p.shape = bucketValue

--- Stores structured data for the current page. Called only by `Module:Entity`,
--- for the page's own canonical row.
--- @param data table<string, any> Flat snake_case key -> value
--- @param kind string|nil Entity kind name (Vehicle, Item, ...), selects the buckets the page may write.
---   nil when the page's kind never resolved: the entity-routable keys are still written, and the rest
---   are NOT reported as unregistered, since without a kind whether they route is unknowable, not a
---   manifest gap.
--- @return boolean success
--- @return string|nil error
--- @return string[]|nil unregistered Emitter keys absent from properties.json for this kind
function p.store(data, kind)
	local unregistered = nil
	if mw.title.getCurrentTitle().namespace == 0 then
		local puts, missing = splitByBucket(getManifest(), data, kind)
		if kind ~= nil and #missing > 0 then
			unregistered = missing
		end
		local err = p.putBuckets(puts)
		if err then
			return false, err, unregistered
		end
	end
	return true, nil, unregistered
end

--- Stores the rows of the tables a kind writes several rows to per page, its
--- `%rows` buckets, one put per row. A key reaches only a `%rows` bucket: a
--- second row in a one-row table would break every reader that takes the
--- page's row to be its only one. Called only by `Module:Entity`.
--- @param rows EntityStructuredRow[]
--- @param kind string|nil nil writes nothing and reports nothing, as `store` does for its by-kind keys
--- @return boolean success
--- @return string|nil error
--- @return string[]|nil unregistered Row keys that reach no `%rows` bucket of the kind
function p.storeRows(rows, kind)
	if mw.title.getCurrentTitle().namespace ~= 0 or kind == nil or type(rows) ~= 'table' then
		return true, nil, nil
	end
	local m = getManifest()
	local allowed = bucketsFor(m, '%rows', kind, {})
	local unregistered, seen = {}, {}
	local ok, err = pcall(function()
		for _, row in ipairs(rows) do
			local puts, missing = routeByBucket(m, type(row.data) == 'table' and row.data or {}, allowed)
			for _, key in ipairs(missing) do
				if not seen[key] then
					seen[key] = true
					unregistered[#unregistered + 1] = key
				end
			end
			for bucket, fields in pairs(puts) do
				bucketLib()(bucket).sub(tostring(row.sub)).put(fields)
			end
		end
	end)
	local reported = unregistered[1] and unregistered or nil
	if not ok then
		return false, 'Bucket storage failed: ' .. tostring(err), reported
	end
	return true, nil, reported
end

-- Test-only exports.
p._internal = {
	autoName = autoName,
	splitByBucket = splitByBucket,
	setManifest = function(mf)
		manifest = mf
	end,
}

return p
