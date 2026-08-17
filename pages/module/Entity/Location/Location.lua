require('strict')

--- @module Entity/Location
--- Location kind: entities backed by the game-data /api/locations endpoint
--- (star systems, planets, moons, stations, …). Only the SolarSystem
--- classification is modelled: matches() is deliberately narrow so every other
--- location keeps today's unmatched behavior until its leaf exists. Adding a
--- classification means widening matches() AND giving it a leaf in
--- LOCATION_SUBTYPE_MAP. The starmap attachment is gated separately, by
--- shouldFetchStarsystem — deliberately NOT coupled to matches(), so a planet
--- payload cannot trigger a star-system fetch once matches() widens.
---
--- For star systems the location record is thin; the substantive data lives in
--- the starmap-derived /api/starsystems endpoint. The two records share no
--- key, so enrich() bridges by name and attaches the record as
--- apiData.starsystem — namespaced, never flat-merged: both payloads carry
--- colliding name/type/description/affiliation keys.

local api = require('Module:Entity/Api')
local editorial = require('Module:Entity/Editorial')
local subtypeResolver = require('Module:Entity/SubtypeResolver')

local p = {}

--- Canonical kind name; the Data.get() `result.kind` value sibling renderers
--- branch on (enforced by the Registry conformance test).
p.name = 'Location'

--- Kind-declared pages (Template:Location injects |kind=Location) render
--- through the editorial fork when no location record resolves — the entry
--- path for the ~84 lore systems that exist only in the starmap.
p.editorialMode = true

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

--- Editorial affiliation text → an AFFILIATIONS-shaped entry. Canonical names
--- resolve to their table entry, matched on code, label or short after
--- normalizing case and punctuation, so the legacy arg spellings land in one
--- bucket ('Xi'An' → the xian entry, 'UEE' → uee). Anything else passes
--- through as free text: the starmap vocabulary has no code for the
--- affiliations only lore knows (Kr'Thak, Unknown), and the legacy template
--- accepted them, so the kind must too. A free-text entry keeps the editor's
--- markup for display (they choose whether [[Kr'Thak]] links; auto-linking
--- would paint 'Unknown' red) while `label` carries the delinked text for the
--- category and the stored value.
--- @param text any
--- @return { label: string, short: string|nil, display: string|nil }|nil
function p.affiliationFromText(text)
	if type(text) ~= 'string' or mw.text.trim(text) == '' then
		return nil
	end
	text = mw.text.trim(text)
	local plain = editorial.toSmwValue(text)
	local key = plain:lower():gsub('[^%w]', '')
	for code, entry in pairs(p.AFFILIATIONS) do
		local label = entry.label:lower():gsub('[^%w]', '')
		local short = entry.short and entry.short:lower():gsub('[^%w]', '') or nil
		if key == code or key == label or key == short then
			return entry
		end
	end
	return { label = plain, display = text }
end

--- RSI starmap system type → infobox display label + browse category. The
--- category names match the live category tree, which kept the legacy
--- "Single Star" casing.
p.SYSTEM_TYPES = {
	SINGLE_STAR = { label = 'Single star system', category = 'Single Star systems' },
	BINARY = { label = 'Binary star system', category = 'Binary systems' },
	-- The live tree kept the legacy "Trinary Star" casing (Category:Trinary
	-- systems does not exist). Latent until the no-record trinary pages
	-- (GJ 667, UDS-2943-01-22) migrated: no starmap-backed system is trinary.
	TRINARY = { label = 'Trinary star system', category = 'Trinary Star systems' },
}

--- Editorial system-type text → normalized starmap code + SYSTEM_TYPES entry.
--- The legacy {{System}} pages hand-set the raw codes with case drift
--- ('SINGLE_STAR', 'TRINARY', 'Trinary'), so normalize case and separators
--- before the lookup. Unrecognized text resolves to nothing: a typo'd code
--- must not invent a type row, a category, or an SMW value.
--- @param text any
--- @return string|nil code normalized starmap code ('TRINARY')
--- @return { label: string, category: string }|nil entry
function p.systemTypeEntry(text)
	if type(text) ~= 'string' or text == '' then
		return nil, nil
	end
	local code = mw.text.trim(text):upper():gsub('[%s%-]+', '_')
	local entry = p.SYSTEM_TYPES[code]
	if not entry then
		return nil, nil
	end
	return code, entry
end

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

--- Positive identification, deliberately narrow: a location
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

--- Should this payload get the starmap starsystem attachment? True for a
--- SolarSystem location record (uuid path) and for a kind-declared page (the
--- editorial fork, where apiData is empty). Deliberately NOT coupled to
--- matches(): when matches() widens to planets, planet payloads must not
--- trigger starsystem fetches.
--- @param apiData table
--- @param args table|nil
--- @return boolean
local function shouldFetchStarsystem(apiData, args)
	if type(apiData.type) == 'table' and apiData.type.name == 'SolarSystem' then
		return true
	end
	return args ~= nil and args.kind ~= nil
end

--- The starmap lookup name: explicit override, then the location record's
--- name, then the editor's display name, then the page title.
--- @param apiData table
--- @param args table|nil
--- @return string|nil
local function resolveLookupName(apiData, args)
	if args and type(args.starmapname) == 'string' and args.starmapname ~= '' then
		return args.starmapname
	end
	if type(apiData.name) == 'string' and apiData.name ~= '' then
		return apiData.name
	end
	if args and type(args.name) == 'string' and args.name ~= '' then
		return args.name
	end
	return mw.title.getCurrentTitle().text
end

--- Plain lowercase key for a system name: trailing " System" stripped. This
--- key drives BOTH the filter query and result selection; it is URL-encoded
--- only where it enters the endpoint.
--- @param name string|nil
--- @return string|nil
local function plainKey(name)
	if type(name) ~= 'string' or name == '' then
		return nil
	end
	local key = name:gsub('%s+[Ss]ystem$', ''):lower()
	if key == '' then
		return nil
	end
	return key
end

--- The row for a plain key from a filter[name] result list. filter[name] is a
--- substring match, so short names can return several rows: prefer the exact
--- name, then the Xi'an "<name> (<alias>)" form, then the first row.
--- @param results table
--- @param key string
--- @return table|nil
local function pickStarsystem(results, key)
	for _, row in ipairs(results) do
		if type(row.name) == 'string' and row.name:lower() == key then
			return row
		end
	end
	for _, row in ipairs(results) do
		if type(row.name) == 'string' and row.name:lower():sub(-(#key + 2)) == '(' .. key .. ')' then
			return row
		end
	end
	return results[1]
end

--- Statuses where the ARK has not published a survey: M (UEE Military
--- Classified, the Vanduul-held systems) and N (probe data incomplete).
--- @type table<string, boolean>
local UNPUBLISHED_SURVEY = { M = true, N = true }

--- Drop the ARK's withheld-survey aggregate, which is a stub rather than a set
--- of measurements. Every unpublished system with no catalogued bodies carries
--- the *same* block — the twelve Vanduul systems all report population 1.08 and
--- economy 0.12 with a size of 0, 1 or 7, and the three incomplete-probe systems
--- report straight zeros. One value repeated across twelve systems is a template
--- default, not twelve measurements, so none of it may reach the infobox or SMW:
--- left alone these pages claim a 7 AU extent and a 0.1/10 economy for space
--- nobody has surveyed, and store a `System size` that satisfies a "smaller than
--- N AU" query.
---
--- The test is "no catalogued bodies AND the survey is unpublished" rather than
--- the tempting shorter ones, both of which are wrong on live data:
---   * `size <= 0` misses the four stubs that report 1 or 7 AU.
---   * "no bodies" alone would strip Gurzil, which is published with no bodies
---     and a real 4.2 AU extent.
---   * status alone would strip Caliban (5.89), Orion (5), Virgil (16) and
---     Oretani (36.91), which are unpublished but properly catalogued.
--- Stars are deliberately excluded from the body count: the stub block claims one
--- star, so counting it would disable the rule entirely. A zero size is dropped
--- unconditionally as well — it is never a measurement, whatever the status. An
--- editorial `|size=` override still wins wherever an editor knows better.
---
--- @param record table|nil starmap record; mutated in place
--- @return table|nil record the same record, for call chaining
local function normalizeAggregates(record)
	local aggregated = type(record) == 'table' and record.aggregated or nil
	if type(aggregated) ~= 'table' then
		return record
	end
	if (tonumber(aggregated.size) or 0) <= 0 then
		aggregated.size = nil
	end
	local bodies = (tonumber(aggregated.planets) or 0)
		+ (tonumber(aggregated.moons) or 0)
		+ (tonumber(aggregated.stations) or 0)
	if bodies == 0 and UNPUBLISHED_SURVEY[record.status] then
		aggregated.size = nil
		aggregated.population = nil
		aggregated.economy = nil
	end
	return record
end

--- Attach the starmap starsystem record as apiData.starsystem: for SolarSystem
--- location records (uuid path) and for kind-declared lore pages (the
--- editorial fork). Soft-fails: on a fetch error or an empty result the record
--- stays absent and the infobox renders what it has.
---
--- @param apiData table
--- @param args table|nil
--- @return table apiData
function p.enrich(apiData, args)
	if not shouldFetchStarsystem(apiData, args) then
		return apiData
	end
	local key = plainKey(resolveLookupName(apiData, args))
	if not key then
		return apiData
	end
	-- locale rides the endpoint, NOT `params`: Apiunto appends params as
	-- `?query`, which after an endpoint that already carries `?filter[…]`
	-- produces a second `?` that corrupts the include value.
	local data = api.fetchApi({
		name = 'StarCitizenWikiAPI',
		endpoint = 'starsystems?filter[name]=%s&include=celestialObjects&locale=en_EN',
		responseDataPath = 'data',
	}, mw.uri.encode(key, 'QUERY'))
	if type(data) == 'table' and data[1] ~= nil then
		apiData.starsystem = normalizeAggregates(pickStarsystem(data, key))
	end
	return apiData
end

--- Refine to the classification leaf (Item-style token dispatch). A
--- kind-declared page without a location record defaults to the StarSystem
--- leaf — the only subtype until the planets slice adds a |family=-style
--- dispatch arg.
--- @param apiData table
--- @param args table
--- @return table|nil leaf module
function p.resolveSubtype(apiData, args)
	local token = type(apiData.type) == 'table' and apiData.type.name or nil
	if token == nil and args and args.kind then
		token = 'SolarSystem'
	end
	return subtypeResolver.resolve(token, LOCATION_SUBTYPE_MAP)
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
		-- Pure-editorial identity fields for the systems the starmap does not
		-- list (Hyoton, Krell, Ophos, …): the record supplies affiliation and
		-- type for everything else, so these only ever fill that gap — or, per
		-- the house rule, override a record the editor knows to be wrong. No
		-- smw key: the leaf stores both itself, through the same resolvers the
		-- display uses (affiliationFromText / systemTypeEntry), so a free-text
		-- affiliation and its stored value cannot disagree. `type` is the
		-- legacy {{System}} arg name.
		affiliation = { arg = 'affiliation' },
		systemtype = { arg = { 'systemtype', 'type' } },
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

--- The system-type entry for a page: the editorial value when one resolved
--- (hand value beats starmap, the house rule), else the starmap record's.
--- Single accessor so the type row, categories, SMW and short description
--- cannot disagree.
--- @param starsystem table|nil
--- @param resolved table|nil
--- @return string|nil code
--- @return { label: string, category: string }|nil entry
function p.resolveSystemType(starsystem, resolved)
	local code, entry = p.systemTypeEntry(editorial.view(resolved):value('systemtype'))
	if entry then
		return code, entry
	end
	-- The record's raw code is returned even when SYSTEM_TYPES has no entry
	-- for it: an unmapped code still stores faithfully (a future ARK type
	-- should degrade to no label/category, not vanish from SMW).
	local recordType = type(starsystem) == 'table' and starsystem.type or nil
	return recordType, recordType and p.SYSTEM_TYPES[recordType] or nil
end

--- The affiliation entry for a page: editorial first (same precedence as
--- resolveSystemType), else the starmap record's.
--- @param starsystem table|nil
--- @param resolved table|nil
--- @return { label: string, short: string|nil, display: string|nil }|nil
function p.resolveAffiliation(starsystem, resolved)
	return p.affiliationFromText(editorial.view(resolved):value('affiliation')) or p.affiliationEntry(starsystem)
end

--- Category parity with the legacy Module:System beyond the `Systems` bucket
--- (the leaf's typeInfo.category supplies that one): the system-type and
--- affiliation trees. A free-text affiliation categorizes as
--- `<text> systems` exactly as the legacy template did (Kr'Thak systems,
--- Unknown systems — both live categories).
--- @param apiData table
--- @param args table|nil
--- @param resolved table|nil
--- @return string[]
function p.getCategories(apiData, args, resolved)
	local categories = {}
	local starsystem = type(apiData.starsystem) == 'table' and apiData.starsystem or nil
	local _, typeEntry = p.resolveSystemType(starsystem, resolved)
	if typeEntry then
		categories[#categories + 1] = typeEntry.category
	end
	local affiliation = p.resolveAffiliation(starsystem, resolved)
	if affiliation then
		categories[#categories + 1] = affiliation.label .. ' systems'
	end
	return categories
end

-- Test-only exports. Not part of the public API.
p._internal = {
	shouldFetchStarsystem = shouldFetchStarsystem,
	resolveLookupName = resolveLookupName,
	plainKey = plainKey,
	pickStarsystem = pickStarsystem,
	normalizeAggregates = normalizeAggregates,
	LOCATION_SUBTYPE_MAP = LOCATION_SUBTYPE_MAP,
}

return p
