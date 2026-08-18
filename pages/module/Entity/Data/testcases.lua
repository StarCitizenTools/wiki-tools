require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Data = require('Module:Entity/Data')
local helpers = Data._internal

local suite = ScribuntoUnit:new()

-- detectFacets (facet registry detection)

function suite:testDetectFacetsConsumable()
	local facets = helpers.detectFacets({ food = {} })
	self:assertEquals(1, #facets)
	self:assertTrue(facets[1].matches({ food = {} }))
end

function suite:testDetectFacetsNoneWhenNoFood()
	self:assertEquals(0, #helpers.detectFacets({}))
end

function suite:testDetectFacetsNilSafe()
	self:assertEquals(0, #helpers.detectFacets(nil))
end

-- resolveLeaf (leaf-module resolution from the matched kind)

function suite:testResolveLeafUsesSubtype()
	local subtype = { name = 'subtype' }
	local kind = {
		resolveSubtype = function()
			return subtype
		end,
	}
	local leaf, err = helpers.resolveLeaf(kind, {}, true)
	self:assertEquals(subtype, leaf)
	self:assertEquals(false, err)
end

function suite:testResolveLeafFallsToKindWhenSubtypeNil()
	local kind = {
		resolveSubtype = function()
			return nil
		end,
	}
	local leaf, err = helpers.resolveLeaf(kind, {}, true)
	self:assertEquals(kind, leaf)
	self:assertEquals(false, err)
end

function suite:testResolveLeafKindWithoutSubtype()
	local kind = {}
	local leaf, err = helpers.resolveLeaf(kind, {}, true)
	self:assertEquals(kind, leaf)
	self:assertEquals(false, err)
end

function suite:testResolveLeafNoMatchWithUuidIsError()
	local leaf, err = helpers.resolveLeaf(nil, {}, true)
	self:assertEquals(require('Module:Entity/Item'), leaf)
	self:assertEquals(true, err)
end

function suite:testResolveLeafNoMatchNoUuidNoError()
	local leaf, err = helpers.resolveLeaf(nil, {}, false)
	self:assertEquals(require('Module:Entity/Item'), leaf)
	self:assertEquals(false, err)
end

-- buildResolverConfig (the single search/<uuid> config, derived from the registry)

function suite:testResolverConfigTargetsSearchEndpoint()
	local config = helpers.buildResolverConfig()
	self:assertEquals('search/%s', config.endpoint)
	self:assertEquals('StarCitizenWikiAPI', config.name)
	self:assertEquals('data', config.responseDataPath)
end

-- The union must cover every kind's includes, or the resolver would return a
-- thinner payload than the kind's own endpoint does.
function suite:testResolverConfigUnionsEveryKindsIncludes()
	local config = helpers.buildResolverConfig()
	local present = {}
	for token in string.gmatch(config.params.include or '', '[^,]+') do
		present[token] = true
	end
	for _, mod in ipairs(require('Module:Entity/Registry').kinds) do
		local params = (mod.getApiConfigs()[1] or {}).params or {}
		for token in string.gmatch(params.include or '', '[^,]+') do
			self:assertTrue(present[token] == true)
		end
	end
end

function suite:testResolverConfigDoesNotRepeatIncludes()
	local config = helpers.buildResolverConfig()
	local seen = {}
	for token in string.gmatch(config.params.include or '', '[^,]+') do
		self:assertEquals(nil, seen[token])
		seen[token] = true
	end
end

-- identifyKind (single payload -> kind, order-independent)

function suite:testIdentifyKindNilSafe()
	self:assertEquals(nil, helpers.identifyKind(nil))
end

function suite:testIdentifyKindVehicle()
	local mod = helpers.identifyKind({ uuid = 'abc', class_name = 'AEGS_Avenger', is_vehicle = false })
	self:assertEquals('Vehicle', mod and mod.name)
end

function suite:testIdentifyKindItem()
	local mod = helpers.identifyKind({ uuid = 'abc', class_name = 'Paint_100i', type = 'Paints' })
	self:assertEquals('Item', mod and mod.name)
end

function suite:testIdentifyKindCommodity()
	local mod = helpers.identifyKind({ uuid = 'abc', box_sizes_scu = { 1, 2 } })
	self:assertEquals('Commodity', mod and mod.name)
end

function suite:testIdentifyKindMission()
	local mod = helpers.identifyKind({ uuid = 'abc', mission_type = 'Delivery' })
	self:assertEquals('Mission', mod and mod.name)
end

-- The resolver also resolves blueprints and starmap locations. Neither is a kind
-- Entity models, so nothing may claim them — Item least of all.
function suite:testIdentifyKindNilForUnmodelledLocation()
	self:assertEquals(nil, helpers.identifyKind({ uuid = 'abc', type = 'PLANET', system = 'Stanton' }))
end

function suite:testIdentifyKindNilForUnmodelledBlueprint()
	self:assertEquals(nil, helpers.identifyKind({ uuid = 'abc', output_class = 'Foo', ingredients = {} }))
end

-- isGenuineRecord (genuine in-game record predicate)

function suite:testGenuineRecordTrueWithUuid()
	self:assertEquals(true, helpers.isGenuineRecord({ uuid = 'abc' }))
end

function suite:testGenuineRecordFalseWithoutUuid()
	self:assertEquals(false, helpers.isGenuineRecord({ is_vehicle = true }))
end

function suite:testGenuineRecordFalseEmpty()
	self:assertEquals(false, helpers.isGenuineRecord({}))
end

function suite:testGenuineRecordFalseEmptyUuid()
	self:assertEquals(false, helpers.isGenuineRecord({ uuid = '' }))
end

-- resolveEditorialKind (args.kind -> opted-in registered kind)

function suite:testEditorialKindResolvesVehicle()
	local kind = helpers.resolveEditorialKind({ kind = 'Vehicle' })
	self:assertEquals('Vehicle', kind and kind.name)
end

function suite:testEditorialKindCaseInsensitive()
	local kind = helpers.resolveEditorialKind({ kind = 'vehicle' })
	self:assertEquals('Vehicle', kind and kind.name)
end

function suite:testEditorialKindNilWhenAbsent()
	self:assertEquals(nil, helpers.resolveEditorialKind({}))
end

function suite:testEditorialKindNilWhenNotOptedIn()
	-- Commodity is registered but does NOT opt into editorial mode.
	self:assertEquals(nil, helpers.resolveEditorialKind({ kind = 'Commodity' }))
end

function suite:testEditorialKindNilWhenUnknown()
	self:assertEquals(nil, helpers.resolveEditorialKind({ kind = 'Nonsense' }))
end

-- kindByName (case-insensitive registry lookup, no editorial gating)

function suite:testKindByNameResolvesLocation()
	local mod = helpers.kindByName('Location')
	self:assertEquals('Location', mod and mod.name)
end

function suite:testKindByNameCaseInsensitive()
	local mod = helpers.kindByName('location')
	self:assertEquals('Location', mod and mod.name)
end

-- Unlike resolveEditorialKind, the lookup itself carries no editorialMode
-- gate: the probeKind trust path may name any registered kind.
function suite:testKindByNameIgnoresEditorialOptIn()
	local mod = helpers.kindByName('Commodity')
	self:assertEquals('Commodity', mod and mod.name)
end

function suite:testKindByNameNilForAbsentOrUnknown()
	self:assertEquals(nil, helpers.kindByName(nil))
	self:assertEquals(nil, helpers.kindByName(''))
	self:assertEquals(nil, helpers.kindByName('Nonsense'))
	self:assertEquals(nil, helpers.kindByName(42))
end

-- resolveLeaf threads args into resolveSubtype

function suite:testResolveLeafThreadsArgsToSubtype()
	local seen
	local subtype = { name = 'sub' }
	local kind = {
		resolveSubtype = function(_, a)
			seen = a
			return subtype
		end,
	}
	local leaf = helpers.resolveLeaf(kind, {}, false, { family = 'ship' })
	self:assertEquals(subtype, leaf)
	self:assertEquals('ship', seen and seen.family)
end

-- parseArgs (frame arg parsing)

local function makeFrame(args, parentArgs)
	return {
		args = args or {},
		getParent = function()
			if parentArgs == nil then
				return nil
			end
			return { args = parentArgs }
		end,
		callParserFunction = function()
			return ''
		end,
	}
end

function suite:testParseArgsStripsEmptyStrings()
	local args = Data.parseArgs(makeFrame({ name = 'Test', blank = '' }))
	self:assertEquals('Test', args.name)
	self:assertEquals(nil, args.blank)
end

function suite:testParseArgsFrameWinsOverParent()
	local args = Data.parseArgs(makeFrame({ name = 'Child' }, { name = 'Parent', extra = 'P' }))
	self:assertEquals('Child', args.name)
	self:assertEquals('P', args.extra)
end

function suite:testParseArgsNoUuidFallsBackToNil()
	self:assertEquals(nil, Data.parseArgs(makeFrame({ name = 'NoUuid' })).uuid)
end

function suite:testParseArgsNoKindReadsSmwUuid()
	-- No |kind= and no wikitext uuid: fall back to the page's stored SMW uuid.
	local frame = makeFrame({ name = 'InGame' })
	frame.callParserFunction = function()
		return 'stored-uuid-1'
	end
	self:assertEquals('stored-uuid-1', Data.parseArgs(frame).uuid)
end

function suite:testParseArgsKindSkipsSmwUuid()
	-- Editorial page (|kind=): must NOT resurrect a stale/placeholder SMW uuid.
	local frame = makeFrame({ name = 'Concept', kind = 'Vehicle' })
	frame.callParserFunction = function()
		return 'stale-placeholder-uuid'
	end
	self:assertEquals(nil, Data.parseArgs(frame).uuid)
end

-- get({}) (public entry point with no uuid — offline safe)

function suite:testGetReturnsTableShape()
	local r = Data.get({})
	self:assertEquals('table', type(r))
	self:assertEquals('table', type(r.apiData))
	self:assertEquals('table', type(r.chain))
	self:assertEquals('table', type(r.facets))
	self:assertEquals('boolean', type(r.hasApiError))
	self:assertEquals('table', type(r.resolved))
	self:assertEquals('table', type(r.editorialData))
	self:assertEquals('boolean', type(r.hasManualApiData))
	self:assertEquals('boolean', type(r.unresolvedReference))
end

function suite:testGetKindDefaultsToItem()
	self:assertEquals('Item', Data.get({}).kind)
end

function suite:testGetEmptyApiDataNoError()
	local r = Data.get({})
	self:assertEquals(false, r.hasApiError)
	self:assertEquals(nil, next(r.apiData))
end

function suite:testGetExposesFamilyAndMatchedKind()
	local r = Data.get({})
	-- No uuid → no match → Item fallback leaf (no p.family) and matchedKind nil.
	self:assertEquals(nil, r.family)
	self:assertEquals(nil, r.matchedKind)
end

-- runEditorialFork (the fork runs the declared kind's enrich)

function suite:testRunEditorialForkCallsEnrichWithArgs()
	local seenArgs
	local stubKind = {
		name = 'Stub',
		enrich = function(apiData, args)
			seenArgs = args
			apiData.marked = true
			return apiData
		end,
	}
	local args = { kind = 'Stub', name = 'Terra system' }
	local apiData, chain = helpers.runEditorialFork(stubKind, args)
	self:assertEquals(true, apiData.marked)
	self:assertEquals('Terra system', seenArgs.name)
	self:assertEquals(stubKind, chain[#chain])
end

function suite:testRunEditorialForkWithoutEnrich()
	local stubKind = { name = 'Stub' }
	local apiData, chain = helpers.runEditorialFork(stubKind, { kind = 'Stub' })
	self:assertEquals(nil, next(apiData))
	self:assertEquals(stubKind, chain[#chain])
end

-- ── probeKind's declared-kind trust path (via p.get) ───────────────────────
--
-- probeKind takes no injection point, but Data holds the Module:Entity/Api
-- module TABLE from the require cache and calls `api.fetchApi` through it
-- (fetchAllApis routes through the same field), so swapping that field is the
-- seam — the same one the Location suite uses for enrich(). Recording which
-- endpoint patterns the stub is asked for is what lets these tests tell the
-- trust path (declared kind's endpoint, no search) from the probe (search
-- first) apart.

--- Run `fn(seen)` with Module:Entity/Api.fetchApi replaced by a stub that
--- marks each requested endpoint pattern in `seen` and answers from
--- `responses` (endpoint pattern → payload; unlisted endpoints answer nil,
--- the soft no-record shape). Always restores the real function, so one
--- failing test cannot poison the rest of the suite.
--- @param responses table<string, table>
--- @param fn fun(seen: table<string, boolean>)
local function withStubbedFetch(responses, fn)
	local api = require('Module:Entity/Api')
	local realFetch = api.fetchApi
	local seen = {}
	api.fetchApi = function(config, _)
		seen[config.endpoint] = true
		return responses[config.endpoint]
	end
	local ok, err = pcall(fn, seen)
	api.fetchApi = realFetch
	if not ok then
		error(err, 0)
	end
end

--- SolarSystem-shaped location record (what locations/<uuid> answers for a
--- star system; trimmed from the live API response).
local function solarSystemRecord()
	return {
		uuid = 'c9c137cf-c520-47ee-9e6d-5d653dfbe201',
		name = 'Stanton System',
		respawn_location_type = 'None',
		type = { name = 'SolarSystem', classification = 'Solar System' },
	}
end

function suite:testDeclaredKindWithUuidSkipsTheResolver()
	withStubbedFetch({ ['locations/%s'] = solarSystemRecord() }, function(seen)
		local r = Data.get({ uuid = 'c9c137cf-c520-47ee-9e6d-5d653dfbe201', kind = 'Location' })
		self:assertEquals('Location', r.kind)
		self:assertEquals(false, r.hasApiError)
		self:assertEquals(false, r.unresolvedReference)
		self:assertEquals(true, seen['locations/%s'])
		self:assertEquals(nil, seen['search/%s'])
	end)
end

function suite:testDeclaredKindLowercaseTakesTheTrustPath()
	withStubbedFetch({ ['locations/%s'] = solarSystemRecord() }, function(seen)
		local r = Data.get({ uuid = 'c9c137cf-c520-47ee-9e6d-5d653dfbe201', kind = 'location' })
		self:assertEquals('Location', r.kind)
		self:assertEquals(nil, seen['search/%s'])
	end)
end

-- A vehicle uuid pasted into {{Location}}: the declared endpoint answers a
-- record the kind can neither match nor refine, so the declaration is NOT
-- trusted and the resolver probe runs exactly as it does today (here it finds
-- nothing, so the page lands in the editorial fork with the uuid flagged
-- unresolved — the vehicle record is never adopted).
function suite:testDeclaredKindGateFailureFallsThroughToProbe()
	local vehicleRecord = { uuid = 'abc', class_name = 'AEGS_Gladius', is_vehicle = true }
	withStubbedFetch({ ['locations/%s'] = vehicleRecord }, function(seen)
		local r = Data.get({ uuid = 'abc', kind = 'Location' })
		self:assertEquals(true, seen['search/%s'])
		self:assertEquals(true, r.unresolvedReference)
		self:assertEquals(nil, r.apiData.uuid)
	end)
end

-- The gate must judge the record ALONE: probeKind hands resolveSubtype an
-- empty args table, never the real args (which carry kind=). A kind whose
-- resolveSubtype accepts kind-declared pages unconditionally — Location
-- defaults them to its StarSystem leaf — would otherwise turn the gate into a
-- tautology: any record would pass because the page declared a kind.
function suite:testDeclaredKindGateStripsArgsFromResolveSubtype()
	local registry = require('Module:Entity/Registry')
	local stubKind = {
		name = 'Gatecheck',
		matches = function()
			return false
		end,
		-- The pathological shape the {} contract exists for: accepts any
		-- record as soon as the caller leaks args carrying kind=.
		resolveSubtype = function(_, args)
			if args and args.kind then
				return { name = 'GatecheckLeaf' }
			end
			return nil
		end,
		getApiConfigs = function()
			return { { name = 'StarCitizenWikiAPI', endpoint = 'gatecheck/%s', params = {} } }
		end,
	}
	table.insert(registry.kinds, stubKind)
	local ok, err = pcall(function()
		withStubbedFetch({ ['gatecheck/%s'] = { uuid = 'abc' } }, function(seen)
			Data.get({ uuid = 'abc', kind = 'Gatecheck' })
			self:assertEquals(true, seen['gatecheck/%s']) -- the trust path fetched the declared endpoint …
			self:assertEquals(true, seen['search/%s']) -- … and the gate failed, so the probe still ran
		end)
	end)
	table.remove(registry.kinds)
	if not ok then
		error(err, 0)
	end
end

-- The gate's second disjunct must be able to ADMIT on its own: a record the
-- kind's matches() rejects but whose shape resolveSubtype refines to a leaf
-- still earns the trust path. This is the mechanism jump points ride —
-- Location.matches() stays SolarSystem-narrow by design — so deleting the
-- resolveSubtype disjunct from the gate must fail here, not silently.
function suite:testDeclaredKindGateAdmitsViaResolveSubtypeAlone()
	local registry = require('Module:Entity/Registry')
	local leaf = { name = 'GateadmitLeaf' }
	local stubKind = {
		name = 'Gateadmit',
		matches = function()
			return false
		end,
		-- Judges the RECORD alone; args are never consulted.
		resolveSubtype = function(data)
			if data.acceptme == true then
				return leaf
			end
			return nil
		end,
		getApiConfigs = function()
			return { { name = 'StarCitizenWikiAPI', endpoint = 'gateadmit/%s', params = {} } }
		end,
	}
	table.insert(registry.kinds, stubKind)
	local ok, err = pcall(function()
		withStubbedFetch({ ['gateadmit/%s'] = { uuid = 'abc', acceptme = true } }, function(seen)
			local r = Data.get({ uuid = 'abc', kind = 'Gateadmit' })
			self:assertEquals('Gateadmit', r.kind)
			self:assertEquals(false, r.hasApiError)
			self:assertEquals(true, seen['gateadmit/%s'])
			self:assertEquals(nil, seen['search/%s'])
		end)
	end)
	table.remove(registry.kinds)
	if not ok then
		error(err, 0)
	end
end

--- Jump-point-shaped location record (what locations/<uuid> answers for a
--- gate; trimmed from the live API response). Typed 'Anomaly' — the token
--- Location.matches() rejects by design.
local function jumpPointRecord()
	return {
		uuid = '80bac534-3e84-4a2d-97c2-3edefa2d5bef',
		name = 'Pyro - Nyx Jump Point',
		respawn_location_type = 'Other',
		type = { name = 'Anomaly', classification = 'Anomaly' },
		system = { name = 'Pyro System' },
	}
end

-- The stub-kind admission test above, incarnated with the REAL Location kind
-- and a real jump-point record: matches() rejects the Anomaly type, so the
-- page renders under Location only because resolveSubtype refines the record
-- to the JumpPoint leaf inside the gate. This is the running proof of the
-- coupling between Data's trust path and Location's dispatch — either side
-- drifting (the gate losing its resolveSubtype disjunct, or Location's suffix
-- predicate changing shape) fails HERE, not only in a per-module suite.
function suite:testDeclaredKindTrustsJumpPointRecordViaResolveSubtype()
	withStubbedFetch({ ['locations/%s'] = jumpPointRecord() }, function(seen)
		local r = Data.get({ uuid = '80bac534-3e84-4a2d-97c2-3edefa2d5bef', kind = 'Location' })
		self:assertEquals('Location', r.kind)
		self:assertEquals(false, r.hasApiError)
		self:assertEquals(false, r.unresolvedReference)
		-- The chain tail IS the JumpPoint leaf module (identity, not name).
		self:assertEquals(require('Module:Entity/Location/JumpPoint'), r.chain[#r.chain])
		self:assertEquals(true, seen['locations/%s'])
		self:assertEquals(nil, seen['search/%s']) -- trust path: the probe never ran
	end)
end

-- No |kind=: today's resolver-first behaviour, untouched. One search fetch
-- answers, and the matched kind's own endpoint is marked fetched (no re-fetch).
function suite:testUuidWithoutKindStillProbesTheResolver()
	withStubbedFetch({ ['search/%s'] = solarSystemRecord() }, function(seen)
		local r = Data.get({ uuid = 'c9c137cf-c520-47ee-9e6d-5d653dfbe201' })
		self:assertEquals('Location', r.kind)
		self:assertEquals(true, seen['search/%s'])
		self:assertEquals(nil, seen['locations/%s'])
	end)
end

return suite
