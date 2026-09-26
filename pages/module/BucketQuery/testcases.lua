require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local BucketQuery = require('Module:BucketQuery')
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
-- reloads modules between suites, so a bare `BucketQuery._internal.setManifests(...)`
-- would leak the fake manifests into every suite that requires BucketQuery
-- afterwards. withManifest() installs the fake manifests and a clean bucketLib
-- recorder for the duration of `fn`, then always restores the real manifests
-- (setManifests(nil), which re-triggers the lazy properties.json loads) before
-- propagating any assertion failure from `fn`.
local function withManifest(fn)
	bucketLib._reset()
	BucketQuery._internal.setManifests({ MANIFEST, COMPANY_MANIFEST, WEARABLE_MANIFEST })
	local ok, err = pcall(fn)
	BucketQuery._internal.setManifests(nil)
	if not ok then
		error(err, 0)
	end
end

function suite:testResolveCoreField()
	withManifest(function()
		local e = BucketQuery.resolve('Size')
		self:assertEquals('entity', e.bucket)
		self:assertEquals('size', e.field)
		self:assertEquals('INTEGER', e.type)
		self:assertEquals(false, e.repeated)
	end)
end

function suite:testResolveCrossKindNeedsKind()
	withManifest(function()
		self:assertEquals('vehicle_stats', BucketQuery.resolve('Scm speed', 'Vehicle').bucket)
		self:assertEquals('item_component', BucketQuery.resolve('Scm speed', 'Item').bucket)
		self:assertEquals(nil, BucketQuery.resolve('Scm speed'))
	end)
end

--- The manifest key is the display name autoName(key) produces (underscores
--- become spaces), so the underscored emitter-key spelling must not resolve.
function suite:testResolveMiningModifier()
	withManifest(function()
		local e = BucketQuery.resolve('Modifier laser instability')
		self:assertEquals('item_tool', e.bucket)
		self:assertEquals('modifier_laser_instability', e.field)
		self:assertEquals(nil, BucketQuery.resolve('Modifier laser_instability'))
	end)
end

function suite:testResolveUnknownIsNil()
	withManifest(function()
		self:assertEquals(nil, BucketQuery.resolve('No such property'))
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
		local rows = BucketQuery.query({
			kind = 'Vehicle',
			filters = { 'Category:Ships', { 'Size', 3 } },
			columns = { 'Name', 'Mass', { property = 'Scm speed', as = 'scm' }, { builtin = 'page_name', as = 'page' } },
			limit = 500,
		})
		local chain = bucketLib._chains[1]
		self:assertEquals('entity', chain.bucket)
		self:assertDeepEquals({
			'name',
			'vehicle.mass',
			'vehicle_stats.scm_speed',
			'page_name',
			'vehicle.page_name',
			'vehicle_stats.page_name',
		}, chain.select)
		self:assertDeepEquals({
			{ 'vehicle', 'vehicle.page_name', 'entity.page_name' },
			{ 'vehicle_stats', 'vehicle_stats.page_name', 'entity.page_name' },
		}, chain.join)
		self:assertDeepEquals({ { 'Category:Ships' }, { 'size', '=', 3 } }, chain.where)
		self:assertEquals(500, chain.limit)
		self:assertDeepEquals({ { Name = 'Avenger Titan', Mass = 52000, scm = 262, page = 'Avenger Titan' } }, rows)
	end)
end

function suite:testQueryRootsOnTheGivenPrimary()
	withManifest(function()
		BucketQuery.query({
			primary = 'vehicle',
			kind = 'Vehicle',
			filters = { { 'Role', 'Fighter' } },
			columns = { 'Role', 'Name' },
		})
		local chain = bucketLib._chains[1]
		self:assertEquals('vehicle', chain.bucket)
		-- the primary's own fields stay bare; entity becomes the joined one
		self:assertDeepEquals({ 'role', 'entity.name', 'page_name', 'entity.page_name' }, chain.select)
		self:assertDeepEquals({ { 'entity', 'entity.page_name', 'vehicle.page_name' } }, chain.join)
		self:assertDeepEquals({ { 'role', '=', 'Fighter' } }, chain.where)
	end)
end

function suite:testQueryDefaultsToTheEntityPrimary()
	withManifest(function()
		BucketQuery.query({ kind = 'Vehicle', filters = { { 'Role', 'Fighter' } }, columns = { 'Role', 'Name' } })
		local chain = bucketLib._chains[1]
		self:assertEquals('entity', chain.bucket)
		self:assertDeepEquals({ 'vehicle.role', 'name', 'page_name', 'vehicle.page_name' }, chain.select)
		self:assertDeepEquals({ { 'vehicle', 'vehicle.page_name', 'entity.page_name' } }, chain.join)
		self:assertDeepEquals({ { 'vehicle.role', '=', 'Fighter' } }, chain.where)
	end)
end

function suite:testQueryJoinsEachBucketOnce()
	withManifest(function()
		BucketQuery.query({ kind = 'Vehicle', filters = { 'Category:Ships' }, columns = { 'Mass', 'Mass' } })
		self:assertEquals(1, #bucketLib._chains[1].join)
	end)
end

function suite:testQueryFilterOnJoinedBucketAddsJoin()
	withManifest(function()
		BucketQuery.query({ kind = 'Vehicle', filters = { { 'Role', 'Combat' } }, columns = { 'Name' } })
		local chain = bucketLib._chains[1]
		self:assertDeepEquals({ { 'vehicle', 'vehicle.page_name', 'entity.page_name' } }, chain.join)
		self:assertDeepEquals({ { 'vehicle.role', '=', 'Combat' } }, chain.where)
	end)
end

function suite:testQueryJoinsColumnsBeforeFiltersOnce()
	withManifest(function()
		BucketQuery.query({ kind = 'Vehicle', filters = { { 'Mass', '>', 100 } }, columns = { 'Scm speed', 'Mass' } })
		local chain = bucketLib._chains[1]
		self:assertDeepEquals({
			{ 'vehicle_stats', 'vehicle_stats.page_name', 'entity.page_name' },
			{ 'vehicle', 'vehicle.page_name', 'entity.page_name' },
		}, chain.join)
		self:assertDeepEquals({ { 'vehicle.mass', '>', 100 } }, chain.where)
	end)
end

--- A cooler and a settlement whose titles differ only in case both join the
--- settlement's vehicle row, because Bucket's join ignores case.
local function caseTwins(extra)
	local frostbite = { page_name = 'Frostbite', name = 'Frostbite', ['vehicle.page_name'] = 'Frostbite' }
	local cooler = { page_name = 'FrostBite', name = 'FrostBite', ['vehicle.page_name'] = 'Frostbite' }
	for key, value in pairs(extra or {}) do
		frostbite[key], cooler[key] = value, value
	end
	return cooler, frostbite
end

function suite:testQueryDropsCaseMismatchedInnerJoin()
	withManifest(function()
		local cooler, frostbite = caseTwins({ ['vehicle.role'] = 'Settlement' })
		bucketLib._setRows('entity', { cooler, frostbite })
		local rows = BucketQuery.query({
			filters = { { 'Role', 'Settlement' } },
			columns = { 'Name', 'Role' },
		})
		self:assertDeepEquals({ { Name = 'Frostbite', Role = 'Settlement' } }, rows)
	end)
end

function suite:testQueryKeepsCaseMismatchedLeftJoinWithoutItsFields()
	withManifest(function()
		local cooler = caseTwins({ ['vehicle.mass'] = 100 })
		bucketLib._setRows('entity', { cooler })
		local rows = BucketQuery.query({ filters = { 'Category:Coolers' }, columns = { 'Name', 'Mass' } })
		self:assertDeepEquals({ { Name = 'FrostBite' } }, rows)
	end)
end

function suite:testQueryDropsCaseMismatchedLeftJoinBesideTheMatchedRow()
	withManifest(function()
		local cooler, frostbite = caseTwins({ ['vehicle.mass'] = 100 })
		local coolerAlone = { page_name = 'FrostBite', name = 'FrostBite' }
		bucketLib._setRows('entity', { cooler, frostbite, coolerAlone })
		local rows = BucketQuery.query({ columns = { 'Name', 'Mass' } })
		self:assertDeepEquals({ { Name = 'Frostbite', Mass = 100 }, { Name = 'FrostBite' } }, rows)
	end)
end

function suite:testQueryHasValueOperator()
	withManifest(function()
		BucketQuery.query({ filters = { { 'Effects', '+' } }, columns = { 'Name' } })
		local w = bucketLib._chains[1].where[1]
		self:assertEquals('not', w.op)
		self:assertDeepEquals({ 'effects', '&&NULL&&' }, w[1])
	end)
end

function suite:testQueryNotEqualOperator()
	withManifest(function()
		BucketQuery.query({ filters = { { 'Size', '!=', 3 } }, columns = { 'Name' } })
		self:assertDeepEquals({ { 'size', '!=', 3 } }, bucketLib._chains[1].where)
	end)
end

function suite:testQueryRejectsRelationalOnText()
	withManifest(function()
		local ok, err = pcall(BucketQuery.query, { filters = { { 'Name', '>', 'A' } }, columns = { 'Name' } })
		self:assertFalse(ok)
		self:assertTrue(tostring(err):find("BucketQuery: 'Name' is not numeric", 1, true) ~= nil)
	end)
end

function suite:testQueryRejectsNotEqualOnRepeated()
	withManifest(function()
		local ok, err = pcall(BucketQuery.query, { filters = { { 'Effects', '!=', 'Toxic' } }, columns = { 'Name' } })
		self:assertFalse(ok)
		self:assertTrue(tostring(err):find("cannot be applied to the repeated property 'Effects'", 1, true) ~= nil)
	end)
end

function suite:testQueryRejectsUnknownOperator()
	withManifest(function()
		local ok, err = pcall(BucketQuery.query, { filters = { { 'Size', '~', 3 } }, columns = { 'Name' } })
		self:assertFalse(ok)
		self:assertTrue(tostring(err):find("BucketQuery: unknown operator '~'", 1, true) ~= nil)
	end)
end

function suite:testResolveCompanyProperty()
	withManifest(function()
		self:assertEquals('company', BucketQuery.resolve('Industry').bucket)
		self:assertEquals('entity', BucketQuery.resolve('Subject type', 'Company').bucket)
	end)
end

--- `Classification` exists only in the third (WearableSet) manifest, so it
--- resolves regardless of search order.
function suite:testResolveWearableSetOnlyProperty()
	withManifest(function()
		local e = BucketQuery.resolve('Classification')
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
		self:assertEquals('item_component', BucketQuery.resolve('Maximum temperature').bucket)
		local e = BucketQuery.resolve('Maximum temperature', 'Wearable set')
		self:assertEquals('wearable_set', e.bucket)
		self:assertEquals('max_temperature', e.field)
	end)
end

function suite:testNeedsKind()
	withManifest(function()
		self:assertTrue(BucketQuery.needsKind('Scm speed'))
		self:assertFalse(BucketQuery.needsKind('Size'))
		self:assertFalse(BucketQuery.needsKind('Bogus'))
	end)
end

function suite:testQueryRejectsUnknownColumn()
	withManifest(function()
		local ok, err = pcall(BucketQuery.query, { filters = { 'Category:Ships' }, columns = { 'Bogus' } })
		self:assertFalse(ok)
		self:assertTrue(tostring(err):find("BucketQuery: unknown property 'Bogus'", 1, true) ~= nil)
	end)
end

function suite:testQueryOrFilter()
	withManifest(function()
		BucketQuery.query({
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
		BucketQuery.query({ filters = { 'Category:Ships' }, columns = { 'Name' } })
		self:assertEquals(1000, bucketLib._chains[1].limit)
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
		BucketQuery._internal.setManifests({ MANIFEST })
		BucketQuery.query({ filters = { { 'Size', 3 } }, columns = { 'Name' } })
		BucketQuery._internal.setManifests(nil)
		self:assertEquals(1, #secondRecorder._chains)
		self:assertEquals(0, #bucketLib._chains)
	end)
	mw.ext.bucket = originalMwExtBucket
	if not ok then
		error(err, 0)
	end
end

--- Resolves against the real manifests (no withManifest fixture), the same way
--- the ClassStats/Stats/Overview/Profile suites exercise BucketQuery.resolve for
--- Vehicle: confirms Module:WearableSet/properties.json is actually wired
--- into MANIFEST_TITLES, not just the fixture above.
function suite:testResolveWearableSetRealManifest()
	local e = BucketQuery.resolve('Radiation scrub rate', 'Wearable set')
	self:assertEquals('wearable_set', e.bucket)
	self:assertEquals('radiation_scrub_rate', e.field)
end

return suite
