require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Store = require('Module:Entity/Store')
local bucketLib = require('mw.ext.bucket')

local suite = ScribuntoUnit:new()

local MANIFEST = {
	['%kinds'] = { Vehicle = { 'entity', 'vehicle', 'vehicle_stats' }, Item = { 'entity', 'item_component' } },
	['Uuid'] = { type = 'TEXT', bucket = 'entity', field = 'uuid', index = true },
	['Name'] = { type = 'TEXT', bucket = 'entity', field = 'name' },
	['Size'] = { type = 'INTEGER', bucket = 'entity', field = 'size', index = true },
	['Image'] = { type = 'TEXT', bucket = 'entity', field = 'image' },
	['Effects'] = { type = 'TEXT', bucket = 'entity', field = 'effects', index = true, repeated = true },
	['Mass'] = { type = 'INTEGER', bucket = 'vehicle', field = 'mass' },
	['Role'] = { type = 'TEXT', bucket = 'vehicle', field = 'role', index = true },
	['Scm speed'] = {
		type = 'DOUBLE',
		bucket = { Item = 'item_component', Vehicle = 'vehicle_stats' },
		field = 'scm_speed',
	},
	['Maximum temperature'] = {
		type = 'DOUBLE',
		bucket = 'item_component',
		field = 'maximum_temperature',
	},
	['Modifier laser instability'] = {
		type = 'DOUBLE',
		bucket = 'item_tool',
		field = 'modifier_laser_instability',
	},
}

local COMPANY_MANIFEST = {
	['%kinds'] = { Company = { 'entity', 'company' } },
	Industry = { type = 'TEXT', bucket = 'company', field = 'industry', index = true, repeated = true },
	['Subject type'] = { type = 'TEXT', bucket = 'entity', field = 'subject_type', index = true },
}

-- Mirrors Module:WearableSet/properties.json's shape (not its full field list):
-- the third manifest Store searches, kind-keyed like Vehicle/Item above.
local WEARABLE_MANIFEST = {
	['%kinds'] = { ['Wearable set'] = { 'entity', 'wearable_set' } },
	Classification = { type = 'TEXT', bucket = 'wearable_set', field = 'classification', index = true },
	['Maximum temperature'] = { type = 'DOUBLE', bucket = 'wearable_set', field = 'max_temperature' },
}

-- ScribuntoUnit (pages/module/ScribuntoUnit) has no automatic per-test fixture
-- hook: `runSuite` only invokes functions named `test*`. The runner also never
-- reloads modules between suites, so a bare `Store._internal.setManifests(...)`
-- would leak the fake manifests into every suite that requires Store
-- afterwards. withManifest() installs the fake manifests and a clean bucketLib
-- recorder for the duration of `fn`, then always restores the real manifests
-- (setManifests(nil), which re-triggers the lazy properties.json loads) before
-- propagating any assertion failure from `fn`.
local function withManifest(fn)
	bucketLib._reset()
	Store._internal.setManifests({ MANIFEST, COMPANY_MANIFEST, WEARABLE_MANIFEST })
	local ok, err = pcall(fn)
	Store._internal.setManifests(nil)
	if not ok then
		error(err, 0)
	end
end

function suite:testResolveCoreField()
	withManifest(function()
		local e = Store.resolve('Size')
		self:assertEquals('entity', e.bucket)
		self:assertEquals('size', e.field)
		self:assertEquals('INTEGER', e.type)
		self:assertEquals(false, e.repeated)
	end)
end

function suite:testResolveCrossKindNeedsKind()
	withManifest(function()
		self:assertEquals('vehicle_stats', Store.resolve('Scm speed', 'Vehicle').bucket)
		self:assertEquals('item_component', Store.resolve('Scm speed', 'Item').bucket)
		self:assertEquals(nil, Store.resolve('Scm speed'))
	end)
end

--- The manifest key is the display name autoName(key) produces (underscores
--- become spaces), so the underscored emitter-key spelling must not resolve.
function suite:testResolveMiningModifier()
	withManifest(function()
		local e = Store.resolve('Modifier laser instability')
		self:assertEquals('item_tool', e.bucket)
		self:assertEquals('modifier_laser_instability', e.field)
		self:assertEquals(nil, Store.resolve('Modifier laser_instability'))
	end)
end

function suite:testResolveUnknownIsNil()
	withManifest(function()
		self:assertEquals(nil, Store.resolve('No such property'))
	end)
end

function suite:testQueryBuildsPrimaryPlusJoins()
	withManifest(function()
		bucketLib._setRows('entity', {
			{
				page_name = 'Avenger Titan',
				name = 'Avenger Titan',
				['vehicle.mass'] = 52000,
				['vehicle_stats.scm_speed'] = 262,
			},
		})
		local rows = Store.query({
			kind = 'Vehicle',
			filters = { 'Category:Ships', { 'Size', 3 } },
			columns = { 'Name', 'Mass', { property = 'Scm speed', as = 'scm' }, { builtin = 'page_name', as = 'page' } },
			limit = 500,
		})
		local chain = bucketLib._chains[1]
		self:assertEquals('entity', chain.bucket)
		self:assertDeepEquals({ 'name', 'vehicle.mass', 'vehicle_stats.scm_speed', 'page_name' }, chain.select)
		self:assertDeepEquals({
			{ 'vehicle', 'vehicle.page_name', 'entity.page_name' },
			{ 'vehicle_stats', 'vehicle_stats.page_name', 'entity.page_name' },
		}, chain.join)
		self:assertDeepEquals({ { 'Category:Ships' }, { 'size', '=', 3 } }, chain.where)
		self:assertEquals(500, chain.limit)
		self:assertDeepEquals({ { Name = 'Avenger Titan', Mass = 52000, scm = 262, page = 'Avenger Titan' } }, rows)
	end)
end

function suite:testQueryJoinsEachBucketOnce()
	withManifest(function()
		Store.query({ kind = 'Vehicle', filters = { 'Category:Ships' }, columns = { 'Mass', 'Mass' } })
		self:assertEquals(1, #bucketLib._chains[1].join)
	end)
end

function suite:testQueryFilterOnJoinedBucketAddsJoin()
	withManifest(function()
		Store.query({ kind = 'Vehicle', filters = { { 'Role', 'Combat' } }, columns = { 'Name' } })
		local chain = bucketLib._chains[1]
		self:assertDeepEquals({ { 'vehicle', 'vehicle.page_name', 'entity.page_name' } }, chain.join)
		self:assertDeepEquals({ { 'vehicle.role', '=', 'Combat' } }, chain.where)
	end)
end

function suite:testQueryJoinsColumnsBeforeFiltersOnce()
	withManifest(function()
		Store.query({ kind = 'Vehicle', filters = { { 'Mass', '>', 100 } }, columns = { 'Scm speed', 'Mass' } })
		local chain = bucketLib._chains[1]
		self:assertDeepEquals({
			{ 'vehicle_stats', 'vehicle_stats.page_name', 'entity.page_name' },
			{ 'vehicle', 'vehicle.page_name', 'entity.page_name' },
		}, chain.join)
		self:assertDeepEquals({ { 'vehicle.mass', '>', 100 } }, chain.where)
	end)
end

function suite:testQueryHasValueOperator()
	withManifest(function()
		Store.query({ filters = { { 'Effects', '+' } }, columns = { 'Name' } })
		local w = bucketLib._chains[1].where[1]
		self:assertEquals('not', w.op)
		self:assertDeepEquals({ 'effects', '&&NULL&&' }, w[1])
	end)
end

function suite:testQueryNotEqualOperator()
	withManifest(function()
		Store.query({ filters = { { 'Size', '!=', 3 } }, columns = { 'Name' } })
		self:assertDeepEquals({ { 'size', '!=', 3 } }, bucketLib._chains[1].where)
	end)
end

function suite:testQueryRejectsRelationalOnText()
	withManifest(function()
		local ok, err = pcall(Store.query, { filters = { { 'Name', '>', 'A' } }, columns = { 'Name' } })
		self:assertFalse(ok)
		self:assertTrue(tostring(err):find("Store: 'Name' is not numeric", 1, true) ~= nil)
	end)
end

function suite:testQueryRejectsNotEqualOnRepeated()
	withManifest(function()
		local ok, err = pcall(Store.query, { filters = { { 'Effects', '!=', 'Toxic' } }, columns = { 'Name' } })
		self:assertFalse(ok)
		self:assertTrue(tostring(err):find("cannot be applied to the repeated property 'Effects'", 1, true) ~= nil)
	end)
end

function suite:testQueryRejectsUnknownOperator()
	withManifest(function()
		local ok, err = pcall(Store.query, { filters = { { 'Size', '~', 3 } }, columns = { 'Name' } })
		self:assertFalse(ok)
		self:assertTrue(tostring(err):find("Store: unknown operator '~'", 1, true) ~= nil)
	end)
end

function suite:testResolveCompanyProperty()
	withManifest(function()
		self:assertEquals('company', Store.resolve('Industry').bucket)
		self:assertEquals('entity', Store.resolve('Subject type', 'Company').bucket)
	end)
end

--- `Classification` exists only in the third (WearableSet) manifest, so it
--- resolves regardless of search order.
function suite:testResolveWearableSetOnlyProperty()
	withManifest(function()
		local e = Store.resolve('Classification')
		self:assertEquals('wearable_set', e.bucket)
		self:assertEquals('classification', e.field)
	end)
end

--- `Maximum temperature` is declared in both the Entity and WearableSet
--- manifests (different bucket, different field): without `kind` it resolves
--- Entity-first, same as any other cross-manifest name; `kind = 'Wearable set'`
--- reorders WearableSet's manifest first.
function suite:testResolveMaximumTemperatureByKind()
	withManifest(function()
		self:assertEquals('item_component', Store.resolve('Maximum temperature').bucket)
		local e = Store.resolve('Maximum temperature', 'Wearable set')
		self:assertEquals('wearable_set', e.bucket)
		self:assertEquals('max_temperature', e.field)
	end)
end

function suite:testNeedsKind()
	withManifest(function()
		self:assertTrue(Store.needsKind('Scm speed'))
		self:assertFalse(Store.needsKind('Size'))
		self:assertFalse(Store.needsKind('Bogus'))
	end)
end

function suite:testQueryRejectsUnknownColumn()
	withManifest(function()
		local ok, err = pcall(Store.query, { filters = { 'Category:Ships' }, columns = { 'Bogus' } })
		self:assertFalse(ok)
		self:assertTrue(tostring(err):find("Store: unknown property 'Bogus'", 1, true) ~= nil)
	end)
end

function suite:testQueryOrFilter()
	withManifest(function()
		Store.query({
			filters = { { any = { 'Category:Pledge ships', 'Category:Pledge vehicles' } } },
			columns = { 'Name' },
		})
		local w = bucketLib._chains[1].where[1]
		self:assertEquals('or', w.op)
		self:assertEquals('Category:Pledge ships', w[1])
	end)
end

function suite:testQueryDefaultLimit()
	withManifest(function()
		Store.query({ filters = { 'Category:Ships' }, columns = { 'Name' } })
		self:assertEquals(1000, bucketLib._chains[1].limit)
	end)
end

function suite:testSelfUuid()
	withManifest(function()
		bucketLib._setRows('entity', { { uuid = 'abc-123' } })
		self:assertEquals('abc-123', Store.selfUuid())
		local chain = bucketLib._chains[1]
		self:assertDeepEquals({ { 'page_name', '=', 'Test' } }, chain.where)
		self:assertEquals(1, chain.limit)
	end)
end

function suite:testSelfUuidMissing()
	withManifest(function()
		self:assertEquals(nil, Store.selfUuid())
	end)
end

--- selfUuid runs on every {{Entity}} invocation; a Bucket infrastructure
--- failure must degrade to nil (already a valid answer), not error the page.
function suite:testSelfUuidContainsBucketFailure()
	withManifest(function()
		bucketLib._failNext = true
		self:assertEquals(nil, Store.selfUuid())
	end)
end

--- The write side only ever puts rows for main-namespace pages, so a Talk:/
--- Template:/... page sharing a mainspace entity's title text must not read
--- that entity's uuid as its own.
function suite:testSelfUuidNonMainNamespaceIsNil()
	withManifest(function()
		bucketLib._setRows('entity', { { uuid = 'abc-123' } })
		local originalGetCurrentTitle = mw.title.getCurrentTitle
		mw.title.getCurrentTitle = function()
			return { namespace = 2, nsText = 'User', text = 'Test', fullText = 'User:Test' }
		end
		local ok, err = pcall(function()
			self:assertEquals(nil, Store.selfUuid())
			self:assertEquals(0, #bucketLib._chains)
		end)
		mw.title.getCurrentTitle = originalGetCurrentTitle
		if not ok then
			error(err, 0)
		end
	end)
end

function suite:testSelfValue()
	withManifest(function()
		bucketLib._setRows('wearable_set', { { classification = 'Heavy armor' } })
		self:assertEquals('Heavy armor', Store.selfValue('Classification'))
		local chain = bucketLib._chains[1]
		self:assertEquals('wearable_set', chain.bucket)
		self:assertDeepEquals({ 'classification' }, chain.select)
		self:assertDeepEquals({ { 'page_name', '=', 'Test' } }, chain.where)
		self:assertEquals(1, chain.limit)
	end)
end

function suite:testSelfValueMissing()
	withManifest(function()
		self:assertEquals(nil, Store.selfValue('Classification'))
	end)
end

--- selfValue is a best-effort caller like selfUuid: a Bucket infrastructure
--- failure must degrade to nil, not error the page.
function suite:testSelfValueContainsBucketFailure()
	withManifest(function()
		bucketLib._failNext = true
		self:assertEquals(nil, Store.selfValue('Classification'))
	end)
end

--- An unresolvable displayName is nil with no query attempted, the same as an
--- unresolvable kind for resolve() itself.
function suite:testSelfValueUnresolvableIsNil()
	withManifest(function()
		self:assertEquals(nil, Store.selfValue('No such property'))
		self:assertEquals(0, #bucketLib._chains)
	end)
end

function suite:testResolveUuidsBatchesAndMaps()
	withManifest(function()
		bucketLib._setRows('entity', {
			{ uuid = 'u1', page_name = 'A', image = 'A.png' },
			{ uuid = 'u2', page_name = 'B' },
		})
		local uuids = {}
		for i = 1, 60 do
			uuids[i] = 'u' .. i
		end
		local map = Store.resolveUuids(uuids)
		self:assertEquals(2, #bucketLib._chains)
		self:assertEquals(50, #bucketLib._chains[1].where[1])
		self:assertDeepEquals({ page = 'A', image = 'A.png' }, map.u1)
		self:assertDeepEquals({ page = 'B' }, map.u2)
		self:assertEquals(nil, map.u3)
	end)
end

function suite:testResolveUuidsEmpty()
	withManifest(function()
		self:assertDeepEquals({}, Store.resolveUuids({}))
		self:assertEquals(0, #bucketLib._chains)
	end)
end

function suite:testResolvePagesMapsJoinedFields()
	withManifest(function()
		bucketLib._setRows('entity', {
			{
				page_name = 'Avenger Titan',
				name = 'Avenger Titan',
				manufacturer = 'Aegis Dynamics',
				image = 'Avenger Titan.png',
				['vehicle.role'] = 'Combat',
			},
			{ page_name = 'Freelancer', name = 'Freelancer' },
		})
		local map = Store.resolvePages({ 'Avenger Titan', 'Freelancer' })
		local chain = bucketLib._chains[1]
		self:assertDeepEquals({ 'page_name', 'name', 'manufacturer', 'image', 'vehicle.role' }, chain.select)
		self:assertDeepEquals({ { 'vehicle', 'vehicle.page_name', 'entity.page_name' } }, chain.join)
		self:assertDeepEquals(
			{ name = 'Avenger Titan', manufacturer = 'Aegis Dynamics', role = 'Combat', image = 'Avenger Titan.png' },
			map['Avenger Titan']
		)
		self:assertDeepEquals({ name = 'Freelancer' }, map['Freelancer'])
	end)
end

function suite:testResolvePagesBatches()
	withManifest(function()
		local names = {}
		for i = 1, 51 do
			names[i] = 'Page ' .. i
		end
		Store.resolvePages(names)
		self:assertEquals(2, #bucketLib._chains)
		self:assertEquals(50, #bucketLib._chains[1].where[1])
		self:assertEquals(50, bucketLib._chains[1].limit)
		self:assertEquals(1, #bucketLib._chains[2].where[1])
		self:assertEquals(1, bucketLib._chains[2].limit)
	end)
end

function suite:testResolvePagesEmpty()
	withManifest(function()
		self:assertDeepEquals({}, Store.resolvePages({}))
		self:assertEquals(0, #bucketLib._chains)
	end)
end

--- Each batch is its own pcall, unlike resolveUuids (loud, contained by its
--- caller): a Bucket failure on one batch must still yield an empty map, not
--- a red error, since two readers call this directly with no pcall of their own.
function suite:testResolvePagesContainsBucketFailure()
	withManifest(function()
		bucketLib._failNext = true
		self:assertDeepEquals({}, Store.resolvePages({ 'Avenger Titan' }))
	end)
end

--- Store must resolve `mw.ext.bucket` fresh on every call, not cache the table
--- `require('mw.ext.bucket')` returned at module load. Swap in a second, distinct
--- recorder as mw.ext.bucket and confirm the chain lands there, not on the
--- module-load-time recorder the suites hold as `bucketLib`.
function suite:testUsesMwExtBucketNotRequire()
	local originalMwExtBucket = mw.ext.bucket
	local secondRecorder = { _chains = {} }
	local function secondBuilder(name)
		local chain = { bucket = name, select = {}, where = {}, limit = nil }
		secondRecorder._chains[#secondRecorder._chains + 1] = chain
		local b = {}
		function b.select(...)
			for _, s in ipairs({ ... }) do
				chain.select[#chain.select + 1] = s
			end
			return b
		end
		function b.where(...)
			for _, w in ipairs({ ... }) do
				chain.where[#chain.where + 1] = w
			end
			return b
		end
		function b.limit(n)
			chain.limit = n
			return b
		end
		function b.run()
			return {}
		end
		return b
	end
	setmetatable(secondRecorder, {
		__call = function(_, name)
			return secondBuilder(name)
		end,
	})

	bucketLib._reset()
	mw.ext.bucket = secondRecorder
	local ok, err = pcall(function()
		Store.selfUuid()
		self:assertEquals(1, #secondRecorder._chains)
		self:assertEquals(0, #bucketLib._chains)
	end)
	mw.ext.bucket = originalMwExtBucket
	if not ok then
		error(err, 0)
	end
end

--- Resolves against the real manifests (no withManifest fixture), the same way
--- the ClassStats/Stats/Overview/Profile suites exercise Store.resolve for
--- Vehicle: confirms Module:WearableSet/properties.json is actually wired
--- into MANIFEST_TITLES, not just the fixture above.
function suite:testResolveWearableSetRealManifest()
	local e = Store.resolve('Radiation scrub rate', 'Wearable set')
	self:assertEquals('wearable_set', e.bucket)
	self:assertEquals('radiation_scrub_rate', e.field)
end

return suite
