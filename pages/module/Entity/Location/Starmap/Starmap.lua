require('strict')

--- @module Entity/Location/Starmap
--- The ARK starmap records a Location leaf reads: the two bridges its enrich
--- hook calls, lookups inside an attached system payload, and the system names
--- and starmap code a page resolves to.
---
--- For star systems the location record is thin; the substantive data lives in
--- the starmap-derived /api/starsystems endpoint. The two records share no
--- key, so attachStarsystem bridges by name and attaches the record as
--- apiData.starsystem — namespaced, never flat-merged: both payloads carry
--- colliding name/type/description/affiliation keys. Jump points and stars
--- bridge to the starmap differently: by the editor-supplied starmap code, to
--- the /api/celestial-objects endpoint, attached as apiData.celestialobject.
--- The two fetches are mutually exclusive by construction — a page resolves to
--- exactly one leaf, and no leaf calls both.

local api = require('Module:Entity/Api')
local editorial = require('Module:Entity/Editorial')

local p = {}

--- The celestial object in a starsystem payload whose code matches, or nil.
--- Codes are compared case-sensitively and whole: a starmap code is an exact
--- key, and prefix matching would collide (SOL.PLANETS.EARTH against a
--- hypothetical SOL.PLANETS.EARTHII).
--- @param starsystem table|nil
--- @param code string|nil
--- @return table|nil
function p.celestialByCode(starsystem, code)
	if type(starsystem) ~= 'table' or type(code) ~= 'string' or code == '' then
		return nil
	end
	local objects = starsystem.celestial_objects
	if type(objects) ~= 'table' then
		return nil
	end
	for _, obj in ipairs(objects) do
		if type(obj) == 'table' and obj.code == code then
			return obj
		end
	end
	return nil
end

--- The celestial object in a starsystem payload whose name matches, or nil.
--- `types` restricts the candidates to those ARK `type` values, and a body must
--- pass it: Stanton's star is also named "Stanton", so an unrestricted match
--- from a page about a body could land on the star.
---
--- This is how an in-game planet or moon resolves at all. A code is not
--- derivable from a body's name: Hurston's is
--- STANTON.PLANETS.STANTONIHURSTONDYNAMICS, built from the designation and the
--- owning corporation, and the 33 in-game pages carry no `code` arg because
--- they were written from the game API, which has no starmap code. The ARK's
--- own `name` is the body's plain name, so it is the one reliable join.
--- @param starsystem table|nil
--- @param name string|nil
--- @param types table|nil set of accepted ARK `type` values
--- @return table|nil
function p.celestialByName(starsystem, name, types)
	if type(starsystem) ~= 'table' or type(name) ~= 'string' or name == '' then
		return nil
	end
	local objects = starsystem.celestial_objects
	if type(objects) ~= 'table' then
		return nil
	end
	local key = mw.ustring.lower(name)
	for _, obj in ipairs(objects) do
		if type(obj) == 'table' and (types == nil or types[obj.type]) then
			local objName = p.celestialName(obj)
			if objName and mw.ustring.lower(objName) == key then
				return obj
			end
		end
	end
	return nil
end

--- A celestial object's display name: its own `name` when the ARK gives one,
--- else its designation with the alias parenthetical and catalogue decorations
--- stripped. Terra's star is the reason `name` wins: it is "Terra Nova" while
--- the designation is just "Terra". Most objects have no `name` at all, so the
--- designation path is the common one.
---
--- The parenthetical is stripped wherever it sits, not just trailing as
--- systemShortName does it: the ARK embeds a Xi'an alias MID-designation
--- ("Kyuk'ya (Indra) A"), and leaving it in names a page that does not exist.
--- An ARK designation carries no other parentheses.
--- @param obj table|nil
--- @return string|nil
function p.celestialName(obj)
	if type(obj) ~= 'table' then
		return nil
	end
	local name = type(obj.name) == 'string' and obj.name ~= '' and obj.name or nil
	if name then
		return name
	end
	if type(obj.designation) ~= 'string' then
		return nil
	end
	return p.systemShortName((obj.designation:gsub('%s*%b()', '')))
end

--- The object an object orbits, resolved against its own system's object list.
--- The starmap gives only a numeric `parent_id`, so a single-object fetch can
--- never answer this — which is why bodies bridge through attachStarsystem.
--- nil where the ARK records no parent: the eleven planets in multi-star or
--- star-less systems (Goss, Baker, Bacchus, Min) carry `parent_id = null`,
--- because it does not say which sun they orbit.
--- @param starsystem table|nil
--- @param obj table|nil
--- @return table|nil
function p.celestialParent(starsystem, obj)
	local id = type(obj) == 'table' and obj.parent_id or nil
	if id == nil or type(starsystem) ~= 'table' or type(starsystem.celestial_objects) ~= 'table' then
		return nil
	end
	for _, candidate in ipairs(starsystem.celestial_objects) do
		if type(candidate) == 'table' and candidate.id == id then
			return candidate
		end
	end
	return nil
end

--- A system name reduced to its bare form: a trailing " System"/" system"
--- stripped, whitespace trimmed ("Pyro System" → "Pyro", "Nyx" → "Nyx").
--- This is the short form the short description uses; page links and stored
--- values append the lowercase " system" suffix to it ("Pyro system"), the
--- wiki's canonical system page-name form.
--- @param name any
--- @return string|nil
function p.systemShortName(name)
	if type(name) ~= 'string' then
		return nil
	end
	-- Strip the starmap's naming decorations before the ' System' suffix: an
	-- alias parenthetical ("Kyuk'ya (Indra)") and the Vanduul catalogue form
	-- (VS-9 "Vulture"). Both appear in celestial designations and neither is a
	-- wiki page name, so leaving one in renders a red link, files a bogus
	-- "<alias> system" category and stores a junk System value. Defence in
	-- depth for the fallback paths; a gate page's own canonical name is the
	-- primary source (see the JumpPoint leaf's titleSystems).
	-- Order matters: the ' System' suffix is stripped from the UNTRIMMED string
	-- so a bare ' System' collapses to empty (nil) rather than surviving as the
	-- word 'System'.
	local short = name:match('^%s*VS%-%d+%s*"(.+)"%s*$') or name
	short = short:gsub('%s+[Ss]ystem$', '') -- before the parenthetical: "Yā'mon (Hadur) System"
	short = mw.text.trim((short:gsub('%s*%b()%s*$', '')))
	if short == '' then
		return nil
	end
	return short
end

--- The gate's entry system (short form) from the location record. The live
--- locations endpoint serves `system` as a plain string ("Pyro System"); the
--- table-with-name shape is tolerated defensively in case the API ever
--- upgrades the field to an embedded record.
--- @param apiData table
--- @return string|nil
function p.entrySystem(apiData)
	local system = apiData.system
	if type(system) == 'table' then
		system = system.name
	end
	return p.systemShortName(system)
end

--- The gate's entry system for ANY jump-point page: the location record's
--- system when one exists, else the first side of the celestial designation.
--- The designation is entry-first for the object's own system by starmap
--- convention (every observed object under <SYS>.JUMPPOINTS.* leads with
--- <SYS>'s name), which is what lets a record-less |family=jumppoint page
--- (the starmap-only tunnels) still know which system it sits in — feeding
--- the System row, the destination disambiguation, the entry-system category
--- and the stored System property alike.
--- @param apiData table
--- @return string|nil
function p.gateEntrySystem(apiData)
	local entry = p.entrySystem(apiData)
	if entry then
		return entry
	end
	local celestial = type(apiData.celestialobject) == 'table' and apiData.celestialobject or nil
	local designation = celestial and celestial.designation or nil
	if type(designation) ~= 'string' then
		return nil
	end
	local sideA = designation:match('^(.-)%s+%-%s+')
	return sideA and p.systemShortName(mw.text.trim(sideA)) or nil
end

--- The name of the subject this page is about: explicit override, then the
--- location record's name, then the editor's display name, then the page
--- title. It is the starmap lookup key for a system page and the body's own
--- name for a planet or moon, which is why it is public.
--- @param apiData table
--- @param args table|nil
--- @return string|nil
function p.subjectName(apiData, args)
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

--- The attached starmap SYSTEM payload, or nil. A leaf that bridges by system
--- namespaces it here rather than flat on apiData.
--- @param apiData table|nil
--- @return table|nil
function p.starsystemOf(apiData)
	return type(apiData) == 'table' and type(apiData.starsystem) == 'table' and apiData.starsystem or nil
end

--- A leaf's own editorial arg, RAW. Raw because the hooks that read these run
--- before editorial resolution, and the leaf's manifest is passed in because
--- each leaf owns its own arg aliases.
--- @param args table|nil
--- @param manifest table the leaf's getEditorialManifest() fragment
--- @param key string
--- @return string|nil
function p.manifestArg(args, manifest, key)
	local entry = type(manifest) == 'table' and manifest[key] or nil
	return entry and editorial.rawArg(args, entry) or nil
end

--- The system a page belongs to: the record's own, else the editorial arg.
--- NOT the starmap code's first segment, which is not always the system.
--- @param apiData table
--- @param args table|nil
--- @param manifest table
--- @return string|nil
function p.systemNameFrom(apiData, args, manifest)
	local fromRecord = p.entrySystem(apiData)
	if fromRecord then
		return fromRecord
	end
	return p.systemShortName(p.manifestArg(args, manifest, 'system'))
end

--- The starmap code to publish: the editor's arg when there is one, else the
--- resolved object's own.
--- @param args table|nil
--- @param manifest table
--- @param obj table|nil the leaf's already-resolved celestial object
--- @return string|nil
function p.resolvedStarmapCode(args, manifest, obj)
	local code = p.manifestArg(args, manifest, 'starmapcode')
	if type(code) == 'string' and code ~= '' then
		return code
	end
	code = obj and obj.code or nil
	return type(code) == 'string' and code ~= '' and code or nil
end

--- Plain lowercase key for a system name: trailing " System" stripped. This
--- key drives BOTH the filter query and result selection; it is URL-encoded
--- only where it enters the endpoint.
--- @param name string|nil
--- @return string|nil
local function plainKey(name)
	-- One suffix-stripper: p.systemShortName owns the ' System' handling (and
	-- trims); this is just its lowercased form for the filter[name] URL key.
	local short = p.systemShortName(name)
	return short and short:lower() or nil
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
--- default, not twelve measurements, so none of it may reach the infobox or the store:
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

--- Attach the starmap celestial-object record as apiData.celestialobject: the
--- JumpPoint leaf's enrich. The bridge key is the editor-supplied starmap
--- code (the leaf reads it from its manifest entry); no code, no fetch.
--- Soft-fails: on a fetch error or an empty result the record stays absent
--- and the infobox renders what it has.
---
--- @param apiData table
--- @param code string|nil
--- @return table apiData
function p.attachCelestialObject(apiData, code)
	if type(code) ~= 'string' or code == '' then
		return apiData
	end
	-- `include=starsystem` names the object's system authoritatively, which is
	-- the only reliable way to get it: the code's own first segment is a code,
	-- not a name, and starsystems' filter[name] does not accept codes (KYUKYA,
	-- RILA, THUSUNG and KAPARI all miss). The included record is compact
	-- ({ id, code, name }) — the zone and aggregate fields live on the full
	-- starsystems record that attachStarsystem fetches.
	-- locale rides the endpoint, NOT `params`: Apiunto appends params as
	-- `?query`, which after an endpoint that already carries `?include=` would
	-- produce a second `?` and corrupt the include value.
	local data = api.fetchApi({
		name = 'StarCitizenWikiAPI',
		endpoint = 'celestial-objects/%s?include=starsystem&locale=en_EN',
		responseDataPath = 'data',
	}, code)
	if type(data) == 'table' and next(data) ~= nil then
		apiData.celestialobject = data
	end
	return apiData
end

--- Attach the starmap star-system record as apiData.starsystem: the
--- StarSystem leaf's enrich, for SolarSystem records (uuid path) and for
--- kind-declared lore pages (the editorial fork, apiData empty). Soft-fails:
--- on a fetch error or an empty result the record stays absent and the
--- infobox renders what it has.
---
--- `name`, when given, names the system outright and wins over every heuristic
--- in p.subjectName. A leaf whose subject is NOT the system must pass it:
--- for a planet or moon `apiData.name` is the body's own name, so the default
--- chain would look up a system called "Hurston" and attach nothing.
--- @param apiData table
--- @param args table|nil
--- @param name string|nil explicit system name
--- @return table apiData
function p.attachStarsystem(apiData, args, name)
	local key = plainKey(name or p.subjectName(apiData, args))
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

--- The ARK starmap code carried by an attached celestial-object record, else
--- the raw |starmapcode=/|code= arg the fetch would have used — so a page
--- whose fetch soft-failed still gets the button and metadata row keyed by the
--- code the editor supplied. Shared by the two leaves that bridge by code
--- (JumpPoint, Star); the empty case is rejected once, here.
--- @param apiData table
--- @param fallback string|nil the raw starmap-code arg
--- @return string|nil
function p.celestialStarmapCode(apiData, fallback)
	local celestial = type(apiData.celestialobject) == 'table' and apiData.celestialobject or nil
	local code = celestial and celestial.code or nil
	if type(code) == 'string' and code ~= '' then
		return code
	end
	return type(fallback) == 'string' and fallback ~= '' and fallback or nil
end

-- Test-only exports. Not part of the public API.
p._internal = {
	plainKey = plainKey,
	pickStarsystem = pickStarsystem,
	normalizeAggregates = normalizeAggregates,
}

return p
