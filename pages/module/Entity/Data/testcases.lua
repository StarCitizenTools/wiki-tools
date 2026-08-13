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

return suite
