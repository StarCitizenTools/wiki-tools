require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Data = require('Module:Entity/Data')
local helpers = Data._internal
local assembly = require('Module:Entity/Assembly')

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

-- Kind identification (which registered kind claims a payload). The declared-kind
-- gate offers a record of ANY kind to a single kind's matches(), so every
-- matches() must be positive and order-independent: the probe walks the
-- registry, but nothing may depend on being asked first.

--- The first registered kind whose matches() accepts the payload, or nil.
--- @param apiData table|nil
--- @return table|nil
local function claimingKind(apiData)
	for _, mod in ipairs(require('Module:Entity/Registry').kinds) do
		if mod.matches(apiData) then
			return mod
		end
	end
	return nil
end

function suite:testClaimNilSafe()
	self:assertEquals(nil, claimingKind(nil))
end

function suite:testClaimVehicle()
	local mod = claimingKind({ uuid = 'abc', class_name = 'AEGS_Avenger', is_vehicle = false })
	self:assertEquals('Vehicle', mod and mod.name)
end

function suite:testClaimItem()
	local mod = claimingKind({ uuid = 'abc', class_name = 'Paint_100i', type = 'Paints' })
	self:assertEquals('Item', mod and mod.name)
end

function suite:testClaimCommodity()
	local mod = claimingKind({ uuid = 'abc', box_sizes_scu = { 1, 2 } })
	self:assertEquals('Commodity', mod and mod.name)
end

function suite:testClaimMission()
	local mod = claimingKind({ uuid = 'abc', mission_type = 'Delivery' })
	self:assertEquals('Mission', mod and mod.name)
end

-- The API also serves blueprints and starmap locations by uuid. Neither is a kind
-- Entity models, so nothing may claim them — Item least of all.
function suite:testClaimNilForUnmodelledLocation()
	self:assertEquals(nil, claimingKind({ uuid = 'abc', type = 'PLANET', system = 'Stanton' }))
end

function suite:testClaimNilForUnmodelledBlueprint()
	self:assertEquals(nil, claimingKind({ uuid = 'abc', output_class = 'Foo', ingredients = {} }))
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

function suite:testParseArgsNoKindReadsStoredUuid()
	-- No |kind= and no wikitext uuid: fall back to the uuid the page stored in Bucket.
	local bucketLib = require('mw.ext.bucket')
	bucketLib._reset()
	bucketLib._setRows('entity', { { uuid = 'stored-uuid-1' } })
	local frame = makeFrame({ name = 'InGame' })
	frame.callParserFunction = function()
		error('parseArgs must not call #show any more')
	end
	self:assertEquals('stored-uuid-1', Data.parseArgs(frame).uuid)
end

function suite:testParseArgsKindSkipsStoredUuid()
	-- Editorial page (|kind=): must NOT resurrect a stale/placeholder stored uuid.
	local bucketLib = require('mw.ext.bucket')
	bucketLib._reset()
	bucketLib._setRows('entity', { { uuid = 'stale-placeholder-uuid' } })
	local args = Data.parseArgs(makeFrame({ name = 'Concept', kind = 'Vehicle' }))
	self:assertEquals(nil, args.uuid)
	self:assertEquals(0, #bucketLib._chains)
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

-- ctx nil rules and pipeline order (EntityHookContext's docstring contract):
-- fields are filled in pipeline order, so a hook that runs early sees the
-- later ones as nil. An editorial kind is registered temporarily
-- (registry.kinds has no injection seam otherwise; args.uuid is absent so the
-- probe never iterates the real registry, making the insert safe) so its
-- hooks can record the ctx they were actually called with.
function suite:testHookContextNilRulesAndPipelineOrder()
	local captured = {}
	local stubKind = {
		name = 'StubHookOrder',
		editorialMode = true,
		family = 'stubfamily',
		matches = function()
			return false
		end,
		getApiConfigs = function()
			return {}
		end,
		enrich = function(ctx)
			captured.enrich = { resolved = ctx.resolved, typeInfo = ctx.typeInfo }
			return ctx.apiData
		end,
		getTypeInfo = function(ctx)
			captured.getTypeInfo = { resolved = ctx.resolved }
			return { name = 'Stub type' }
		end,
		getCategories = function(ctx)
			captured.getCategories = { resolved = ctx.resolved, typeInfo = ctx.typeInfo }
			return {}
		end,
		-- Not called by Data.get itself (Infobox/Entity call these later,
		-- leaf-first, through result.ctx) — invoked manually below to check the
		-- fully-populated ctx they'd actually receive downstream.
		getSections = function(ctx)
			captured.getSections = { typeInfo = ctx.typeInfo, resolved = ctx.resolved }
			return {}
		end,
		getStructuredData = function(ctx)
			captured.getStructuredData = { typeInfo = ctx.typeInfo }
			return {}
		end,
	}

	local registry = require('Module:Entity/Registry')
	table.insert(registry.kinds, stubKind)
	local ok, err = pcall(function()
		local result = Data.get({ kind = 'StubHookOrder' })

		-- enrich runs before resolved/typeInfo exist on ctx at all.
		self:assertEquals(nil, captured.enrich.resolved)
		self:assertEquals(nil, captured.enrich.typeInfo)

		-- getTypeInfo runs before the editorial-manifest resolve step.
		self:assertEquals(nil, captured.getTypeInfo.resolved)

		-- getCategories runs after resolved is set but before typeInfo is.
		self:assertEquals('table', type(captured.getCategories.resolved))
		self:assertEquals(nil, captured.getCategories.typeInfo)
		-- ctx.resolved carries the SAME table p.get ultimately assigns to
		-- result.resolved.
		self:assertEquals(result.ctx.resolved, captured.getCategories.resolved)
		self:assertEquals(result.resolved, captured.getCategories.resolved)

		self:assertEquals(result.typeInfo, result.ctx.typeInfo)
		self:assertEquals('Stub type', result.ctx.typeInfo.name)
		self:assertEquals('StubHookOrder', result.ctx.kind)
		self:assertEquals('stubfamily', result.ctx.family)

		assembly.callHook(stubKind, 'getSections', result.ctx)
		assembly.callHook(stubKind, 'getStructuredData', result.ctx)
		self:assertEquals('Stub type', captured.getSections.typeInfo.name)
		self:assertEquals(result.ctx.resolved, captured.getSections.resolved)
		self:assertEquals('Stub type', captured.getStructuredData.typeInfo.name)
	end)

	for i, mod in ipairs(registry.kinds) do
		if mod == stubKind then
			table.remove(registry.kinds, i)
			break
		end
	end
	if not ok then
		error(err, 0)
	end
end

-- runEditorialFork (the fork runs the rebuilt chain's enrich hooks)

function suite:testRunEditorialForkCallsEnrichWithArgs()
	local seenArgs
	local stubKind = {
		name = 'Stub',
		enrich = function(ctx)
			seenArgs = ctx.args
			ctx.apiData.marked = true
			return ctx.apiData
		end,
	}
	local args = { kind = 'Stub', name = 'Terra system' }
	local ctx, chain = helpers.runEditorialFork(stubKind, args)
	self:assertEquals(true, ctx.apiData.marked)
	self:assertEquals('Terra system', seenArgs.name)
	self:assertEquals(stubKind, chain[#chain])
end

function suite:testRunEditorialForkWithoutEnrich()
	local stubKind = { name = 'Stub' }
	local ctx, chain = helpers.runEditorialFork(stubKind, { kind = 'Stub' })
	self:assertEquals(nil, next(ctx.apiData))
	self:assertEquals(stubKind, chain[#chain])
end

-- ── probeKind's declared-kind trust path (via p.get) ───────────────────────
--
-- probeKind takes no injection point, but Data holds the Module:Entity/Api
-- module TABLE from the require cache and calls `api.fetchApi` through it
-- (fetchAllApis routes through the same field), so swapping that field is the
-- seam — the same one the Location suite uses for enrich(). Recording which
-- endpoint patterns the stub is asked for is what lets these tests tell the
-- trust path (declared kind's endpoint only) from the probe (registry walk,
-- items first) apart.

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

--- Starmap record as StarSystem.enrich attaches it (trimmed).
local function starsystemRecord()
	return {
		code = 'STANTON',
		type = 'SINGLE_STAR',
		status = 'P',
		aggregated = { size = 4.85, population = 10, economy = 10 },
		affiliation = { { code = 'uee', name = 'UEE' } },
		celestial_objects = { { type = 'STAR', sub_type = { name = 'Main Sequence-Dwarf-G' } }, { type = 'PLANET' } },
	}
end

function suite:testDeclaredKindWithUuidSkipsTheProbe()
	withStubbedFetch({ ['locations/%s'] = solarSystemRecord() }, function(seen)
		local r = Data.get({ uuid = 'c9c137cf-c520-47ee-9e6d-5d653dfbe201', kind = 'Location' })
		self:assertEquals('Location', r.kind)
		self:assertEquals(false, r.hasApiError)
		self:assertEquals(false, r.unresolvedReference)
		self:assertEquals(true, seen['locations/%s'])
		self:assertEquals(nil, seen['items/%s']) -- the probe (items first) never ran
	end)
end

function suite:testDeclaredKindLowercaseTakesTheTrustPath()
	withStubbedFetch({ ['locations/%s'] = solarSystemRecord() }, function(seen)
		local r = Data.get({ uuid = 'c9c137cf-c520-47ee-9e6d-5d653dfbe201', kind = 'location' })
		self:assertEquals('Location', r.kind)
		self:assertEquals(nil, seen['items/%s'])
	end)
end

-- A vehicle uuid pasted into {{Location}}: the declared endpoint answers a
-- record the kind does not match, so the declaration is NOT trusted and the
-- probe walks the registry (here every endpoint answers nothing, so the page
-- lands in the editorial fork with the uuid flagged unresolved — the vehicle
-- record is never adopted).
function suite:testDeclaredKindGateFailureFallsThroughToProbe()
	local vehicleRecord = { uuid = 'abc', class_name = 'AEGS_Gladius', is_vehicle = true }
	withStubbedFetch({ ['locations/%s'] = vehicleRecord }, function(seen)
		local r = Data.get({ uuid = 'abc', kind = 'Location' })
		self:assertEquals(true, seen['items/%s'])
		self:assertEquals(true, r.unresolvedReference)
		self:assertEquals(nil, r.apiData.uuid)
	end)
end

--- Jump-point-shaped location record (what locations/<uuid> answers for a
--- gate; trimmed from the live API response). Typed 'Anomaly', a token
--- shared with non-gate records (wreck sites) that Location.matches()
--- rejects; the name suffix is what admits a gate specifically.
local function jumpPointRecord()
	return {
		uuid = '80bac534-3e84-4a2d-97c2-3edefa2d5bef',
		name = 'Pyro - Nyx Jump Point',
		respawn_location_type = 'Other',
		type = { name = 'Anomaly', classification = 'Anomaly' },
		system = 'Pyro System', -- plain string: the live field shape (not an embedded record)
	}
end

-- The real Location kind with a real jump-point record: matches() claims the
-- gate outright, so the declared path admits it with no admission disjunct in
-- the gate. Either side drifting — Location.matches narrowing, or the gate
-- growing a second condition — fails HERE.
function suite:testDeclaredKindTrustsJumpPointRecordViaMatches()
	withStubbedFetch({ ['locations/%s'] = jumpPointRecord() }, function(seen)
		local r = Data.get({ uuid = '80bac534-3e84-4a2d-97c2-3edefa2d5bef', kind = 'Location' })
		self:assertEquals('Location', r.kind)
		self:assertEquals(false, r.hasApiError)
		self:assertEquals(false, r.unresolvedReference)
		-- The chain tail IS the JumpPoint leaf module (identity, not name).
		self:assertEquals(require('Module:Entity/Location/JumpPoint'), r.chain[#r.chain])
		self:assertEquals(true, seen['locations/%s'])
		self:assertEquals(nil, seen['items/%s']) -- trust path: the probe never ran
	end)
end

-- No |kind=: the probe walks the registry in order, fetching each kind's typed
-- endpoint until one claims the record. Never the API's search resolver: its
-- cache key could not coincide with the declared path's typed fetch.
function suite:testUuidWithoutKindProbesTypedEndpointsInRegistryOrder()
	withStubbedFetch({ ['locations/%s'] = solarSystemRecord() }, function(seen)
		local r = Data.get({ uuid = 'c9c137cf-c520-47ee-9e6d-5d653dfbe201' })
		self:assertEquals('Location', r.kind)
		self:assertEquals(false, r.hasApiError) -- misses on non-matching kinds don't count
		for _, endpoint in ipairs({ 'items/%s', 'vehicles/%s', 'commodities/%s', 'missions/%s', 'locations/%s' }) do
			self:assertEquals(true, seen[endpoint])
		end
		self:assertEquals(nil, seen['search/%s'])
	end)
end

-- The probe short-circuits on the first claim, so an item (the dominant kind,
-- registered first) costs exactly one fetch.
function suite:testUuidWithoutKindStopsAtFirstClaim()
	local itemRecord = { uuid = 'abc', class_name = 'BEHR_P4AR', type = 'WeaponPersonal' }
	withStubbedFetch({ ['items/%s'] = itemRecord }, function(seen)
		local r = Data.get({ uuid = 'abc' })
		self:assertEquals('Item', r.kind)
		self:assertEquals(true, seen['items/%s'])
		self:assertEquals(nil, seen['vehicles/%s'])
	end)
end

-- ── promoted chain hooks (enrich / getCategories / getEditorialManifest) ────

-- enrich runs on every link root-to-leaf: the JumpPoint leaf's enrich (not the
-- kind's) attaches the celestial object on a declared-kind page.
function suite:testLeafEnrichRunsOnTheChain()
	local celestial = { code = 'PYRO.JUMPPOINTS.NYX', designation = 'Pyro - Nyx', type = 'JUMPPOINT' }
	withStubbedFetch({ ['locations/%s'] = jumpPointRecord(), ['celestial-objects/%s'] = celestial }, function(seen)
		local r = Data.get({
			uuid = '80bac534-3e84-4a2d-97c2-3edefa2d5bef',
			kind = 'Location',
			starmapcode = 'PYRO.JUMPPOINTS.NYX',
		})
		self:assertEquals(true, seen['celestial-objects/%s'])
		self:assertEquals('Pyro - Nyx', r.apiData.celestialobject.designation)
		self:assertEquals(nil, r.apiData.starsystem)
	end)
end

-- getCategories is collected from every link: the StarSystem leaf's type and
-- affiliation categories reach typeInfo.categories, and the leaf's manifest
-- fragment (size) is merged into the editorial layer.
function suite:testLeafCategoriesAndManifestReachTheResult()
	local endpoint = 'starsystems?filter[name]=%s&include=celestialObjects&locale=en_EN'
	withStubbedFetch({ ['locations/%s'] = solarSystemRecord(), [endpoint] = { starsystemRecord() } }, function()
		local r = Data.get({ uuid = 'c9c137cf-c520-47ee-9e6d-5d653dfbe201', kind = 'Location', size = '5' })
		local cats = {}
		for _, c in ipairs(r.typeInfo.categories or {}) do
			cats[c] = true
		end
		self:assertEquals(true, cats['Single Star systems'])
		self:assertEquals(true, cats['United Empire of Earth systems'])
		self:assertEquals(5, r.resolved.size.value)
		self:assertEquals('override', r.resolved.size.source)
	end)
end

-- The editorial fork runs the chain's enrich too: a kind-declared lore system
-- with no record still fetches its starmap record through the StarSystem leaf.
function suite:testEditorialForkRunsLeafEnrich()
	local endpoint = 'starsystems?filter[name]=%s&include=celestialObjects&locale=en_EN'
	withStubbedFetch({ [endpoint] = { starsystemRecord() } }, function(seen)
		local r = Data.get({ kind = 'Location', name = 'Stanton system' })
		self:assertEquals(true, seen[endpoint])
		self:assertEquals('STANTON', r.apiData.starsystem.code)
		self:assertEquals('Location', r.kind)
	end)
end

-- Base supplies the sibling renderers' generic payloads (the items
-- endpoint's own blocks); a kind or leaf overrides leaf-first.
function suite:testBaseSuppliesSiblingPayloadDefaults()
	local chain = assembly.buildChain(require('Module:Entity/Item'))
	local apiData =
		{ related_items = { set_items = {} }, blueprint = { { key = 'bp' } }, ports = { { name = 'hardpoint' } } }
	local ctx = { apiData = apiData, args = {} }
	local related = assembly.resolveMostSpecific(chain, 'getRelated', nil, ctx)
	self:assertEquals(apiData.related_items, related.items)
	self:assertEquals(nil, related.cargo)
	local blueprints = assembly.resolveMostSpecific(chain, 'getBlueprints', nil, ctx)
	self:assertEquals(apiData.blueprint, blueprints.blueprints)
	self:assertEquals(nil, blueprints.ingredient)
	local ports = assembly.resolveMostSpecific(chain, 'getPorts', nil, ctx)
	self:assertEquals(apiData.ports, ports.ports)
	self:assertEquals(nil, ports.narrowChildren)
end

return suite
