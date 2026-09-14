require('strict')

--- @module Entity/StructuredData
--- Stores an Entity page's structured data in Bucket, from the main namespace
--- only, split into one put per table by Module:Entity/properties.json.
---
--- One Entity page writes at most one row per bucket, from `Module:Entity`,
--- `store`'s only caller. A page whose kind never resolved is stored with
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
--- @return table|nil entry { bucket = string|table, field, type, repeated }
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

--- Splits emitter data into one table per bucket the kind may write.
--- @param m table decoded properties.json
--- @param data table<string, any>
--- @param kind string|nil kind name; nil allows only the entity bucket
--- @return table<string, table> puts bucket -> field -> value
--- @return string[] unregistered keys that reach no bucket for this kind
local function splitByBucket(m, data, kind)
	local allowed = { entity = true }
	local kinds = m['%kinds']
	if type(kinds) == 'table' and kind and type(kinds[kind]) == 'table' then
		for _, b in ipairs(kinds[kind]) do
			allowed[b] = true
		end
	end
	local puts, unregistered = {}, {}
	for k, v in pairs(data) do
		local entry = bucketEntry(m, k)
		local bucket = entry and entry.bucket
		if type(bucket) == 'table' then
			bucket = kind and bucket[kind] or nil
		end
		if type(bucket) == 'string' and allowed[bucket] and v ~= nil then
			puts[bucket] = puts[bucket] or {}
			puts[bucket][entry.field] = bucketValue(entry, v)
		else
			unregistered[#unregistered + 1] = k
		end
	end
	return puts, unregistered
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

-- Test-only exports.
p._internal = {
	autoName = autoName,
	splitByBucket = splitByBucket,
	setManifest = function(mf)
		manifest = mf
	end,
}

return p
