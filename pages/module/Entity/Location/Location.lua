require('strict')

--- @module Entity/Location
--- Location kind: entities backed by the game-data /api/locations endpoint
--- (star systems, planets, moons, stations, …). Slice 1 models only the
--- SolarSystem classification: matches() is deliberately narrow so every other
--- location keeps today's unmatched behavior until its leaf exists. Widening
--- matches() is the per-slice switch.
---
--- For star systems the location record is thin; the substantive data lives in
--- the starmap-derived /api/starsystems endpoint. The two records share no
--- key, so enrich() bridges by name and attaches the record as
--- apiData.starsystem — namespaced, never flat-merged: both payloads carry
--- colliding name/type/description/affiliation keys.

local api = require('Module:Entity/Api')
local subtypeResolver = require('Module:Entity/SubtypeResolver')

local p = {}

--- Canonical kind name; the Data.get() `result.kind` value sibling renderers
--- branch on (enforced by the Registry conformance test).
p.name = 'Location'

--- @type string
p.parent = 'Entity/Base'

--- API location type.name → leaf module path (SubtypeResolver adds 'Module:').
local LOCATION_SUBTYPE_MAP = {
	SolarSystem = 'Entity/Location/StarSystem',
}

--- RSI starmap affiliation code (lowercased) → display data. `label` is the
--- display/link name, ported from the legacy Module:System/i18n.json
--- (val_affiliation_*); every label is an existing wiki page, so callers may
--- link them as [[label]]. `short` (falling back to label) is the compact
--- form used in short descriptions AND stored as the SMW `Affiliation` value —
--- it matches the vocabulary the ~266 pre-Entity pages already store
--- ('UEE', 'Unclaimed'), so queries keep one bucket.
p.AFFILIATIONS = {
	uee = { label = 'United Empire of Earth', short = 'UEE' },
	unc = { label = 'Unclaimed' },
	banu = { label = 'Banu Protectorate' },
	xian = { label = "Xi'an Empire" },
	vncl = { label = 'Vanduul' },
	dev = { label = 'Developing' },
}

--- First affiliation entry for a starmap record, or nil. The single accessor
--- every consumer (link row, categories, SMW, short description) goes
--- through.
--- @param starsystem table|nil
--- @return { label: string, short: string|nil }|nil
function p.affiliationEntry(starsystem)
	local affiliation = type(starsystem) == 'table'
			and type(starsystem.affiliation) == 'table'
			and starsystem.affiliation[1]
		or nil
	local code = affiliation and type(affiliation.code) == 'string' and affiliation.code:lower() or nil
	return code and p.AFFILIATIONS[code] or nil
end

--- RSI starmap system type → infobox display label + browse category. The
--- category names match the live category tree, which kept the legacy
--- "Single Star" casing.
p.SYSTEM_TYPES = {
	SINGLE_STAR = { label = 'Single star system', category = 'Single Star systems' },
	BINARY = { label = 'Binary star system', category = 'Binary systems' },
	TRINARY = { label = 'Trinary star system', category = 'Trinary systems' },
}

--- @return EntityApiConfig[]
function p.getApiConfigs()
	return {
		{
			name = 'StarCitizenWikiAPI',
			endpoint = 'locations/%s',
			params = { locale = 'en_EN' },
			responseDataPath = 'data',
		},
	}
end

--- Positive identification, deliberately narrow for slice 1: a location
--- signature (`respawn_location_type`, a field no item, vehicle, commodity,
--- mission, or blueprint record carries, plus the classification table)
--- restricted to SolarSystem. Nil-safe, strict boolean, order-independent —
--- the search resolver offers one payload of any kind to every matches().
---
--- @param apiData table|nil
--- @return boolean
function p.matches(apiData)
	return apiData ~= nil
		and apiData.respawn_location_type ~= nil
		and type(apiData.type) == 'table'
		and apiData.type.name == 'SolarSystem'
end

--- Refine to the classification leaf (Item-style token dispatch).
--- @param apiData table
--- @param args table
--- @return table|nil leaf module
function p.resolveSubtype(apiData, args)
	local token = type(apiData.type) == 'table' and apiData.type.name or nil
	return subtypeResolver.resolve(token, LOCATION_SUBTYPE_MAP)
end

--- Starsystems filter key for a location name: strip a trailing " System",
--- lowercase, URL-encode. "Stanton System" → "stanton". nil for a non-string
--- or empty name.
--- @param name string|nil
--- @return string|nil
local function deriveFilterKey(name)
	if type(name) ~= 'string' or name == '' then
		return nil
	end
	local key = name:gsub('%s+[Ss]ystem$', ''):lower()
	if key == '' then
		return nil
	end
	return mw.uri.encode(key, 'QUERY')
end

--- Attach the starmap starsystem record for SolarSystem locations as
--- apiData.starsystem. Runs after the chain is built (Data.get step 6) and
--- before editorial resolution, so the manifest's apiPath fields can point
--- into it. Soft-fails: on a fetch error or an empty result the record stays
--- absent and the infobox renders location-only rows.
---
--- @param apiData table
--- @return table apiData
function p.enrich(apiData)
	local key = deriveFilterKey(apiData.name)
	if not key or not p.matches(apiData) then
		return apiData
	end
	-- locale rides the endpoint, NOT `params`: Apiunto appends params as
	-- `?query`, which after an endpoint that already carries `?filter[…]`
	-- produces a second `?` that corrupts the include value.
	local data = api.fetchApi({
		name = 'StarCitizenWikiAPI',
		endpoint = 'starsystems?filter[name]=%s&include=celestialObjects&locale=en_EN',
		responseDataPath = 'data',
	}, key)
	-- The list endpoint wraps results in a `data` ARRAY; [1] is the match and
	-- an empty array is a miss.
	if type(data) == 'table' and data[1] ~= nil then
		apiData.starsystem = data[1]
	end
	return apiData
end

--- Location editorial manifest: field → { arg, smw?, apiPath?, transform? }.
--- discoveredin/discoveredby/historicalnames/population are API-absent
--- (pure-editorial). size overlaps the starmap aggregated size attached by
--- enrich. startypes carries no apiPath because its API value is derived from
--- the celestial-object list — the section builder passes the computed value
--- as the editorial view's fallback instead.
--- @return table
function p.getEditorialManifest()
	return {
		discoveredin = { arg = 'discoveredin', smw = 'Discovered in' },
		discoveredby = { arg = 'discoveredby', smw = 'Discovered by' },
		historicalnames = { arg = 'historicalnames' },
		population = { arg = 'population' },
		size = { arg = 'size', smw = 'System size', apiPath = 'starsystem.aggregated.size', transform = 'number' },
		startypes = { arg = 'startypes' },
		-- Object-count overrides (the legacy {{System}} arg names): hand counts
		-- beat the starmap-derived celestial_objects tallies (e.g. Stanton lists
		-- 24 stations counting rest stops; the starmap MANMADE tally is 6). No
		-- smw key: the leaf's getStructuredData stores the resolved counts
		-- itself, so display and storage cannot disagree.
		planets = { arg = 'planets', transform = 'number' },
		satellites = { arg = 'satellites', transform = 'number' },
		asteroidbelts = { arg = 'asteroidbelts', transform = 'number' },
		asteroidfields = { arg = 'asteroidfields', transform = 'number' },
		anomalies = { arg = 'anomalies', transform = 'number' },
		stations = { arg = 'stations', transform = 'number' },
		jumppoints = { arg = 'jumppoints', transform = 'number' },
		blackholes = { arg = 'blackholes', transform = 'number' },
		pois = { arg = 'pois', transform = 'number' },
	}
end

--- Category parity with the legacy Module:System beyond the `Systems` bucket
--- (the leaf's typeInfo.category supplies that one): the system-type and
--- affiliation trees.
--- @param apiData table
--- @return string[]
function p.getCategories(apiData)
	local categories = {}
	local starsystem = type(apiData.starsystem) == 'table' and apiData.starsystem or nil
	if not starsystem then
		return categories
	end
	local typeInfo = p.SYSTEM_TYPES[starsystem.type]
	if typeInfo then
		categories[#categories + 1] = typeInfo.category
	end
	local affiliation = p.affiliationEntry(starsystem)
	if affiliation then
		categories[#categories + 1] = affiliation.label .. ' systems'
	end
	return categories
end

-- Test-only exports. Not part of the public API.
p._internal = {
	deriveFilterKey = deriveFilterKey,
	LOCATION_SUBTYPE_MAP = LOCATION_SUBTYPE_MAP,
}

return p
