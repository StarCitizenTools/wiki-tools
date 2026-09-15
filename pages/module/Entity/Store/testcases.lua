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

return suite
