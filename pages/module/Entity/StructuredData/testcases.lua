require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local SD = require('Module:Entity/StructuredData')

local suite = ScribuntoUnit:new()

function suite:testAutoNameDerivesTheManifestKey()
	self:assertEquals('Health', SD._internal.autoName('health'))
	self:assertEquals('Uuid', SD._internal.autoName('uuid'))
	self:assertEquals('Acquisition kind', SD._internal.autoName('acquisition_kind'))
	self:assertEquals('Modifier resistance', SD._internal.autoName('modifier_resistance'))
	-- Contract: autoName does NOT reconstruct acronym capitalisation; acronyms flatten.
	self:assertEquals('Scm speed', SD._internal.autoName('scm_speed'))
end

local bucketLib = require('mw.ext.bucket')

local FULL = {
	['%doc'] = 'x',
	['%kinds'] = { Vehicle = { 'entity', 'vehicle_stats' }, Item = { 'entity', 'item_weapon', 'item_tool' } },
	['Uuid'] = { type = 'TEXT', bucket = 'entity', field = 'uuid', index = true },
	['Image'] = { type = 'TEXT', bucket = 'entity', field = 'image' },
	['Manufacturer'] = { type = 'PAGE', bucket = 'entity', field = 'manufacturer', index = true },
	['Effects'] = { type = 'TEXT', bucket = 'entity', field = 'effects', index = true, repeated = true },
	['Health'] = { type = 'INTEGER', bucket = 'item_weapon', field = 'health' },
	['Scm speed'] = {
		type = 'DOUBLE',
		bucket = { Item = 'item_component', Vehicle = 'vehicle_stats' },
		field = 'scm_speed',
	},
	['Loaner vehicle'] = {
		type = 'PAGE',
		bucket = 'entity',
		field = 'loaner_vehicle',
		index = true,
		repeated = true,
	},
	['Modifier resistance'] = { type = 'DOUBLE', bucket = 'item_tool', field = 'modifier_resistance' },
}

local function withTitle(namespace, nsText, fn)
	local realGet = mw.title.getCurrentTitle
	mw.title.getCurrentTitle = function()
		return {
			namespace = namespace,
			nsText = nsText,
			text = 'Test',
			fullText = (nsText ~= '' and (nsText .. ':') or '') .. 'Test',
		}
	end
	local ok, err = pcall(fn)
	mw.title.getCurrentTitle = realGet
	if not ok then
		error(err, 0)
	end
end

--- Installs a faithful `mw.title.new` for the duration of fn. The runner's shim
--- builds a title by copying its current-title stub, so `prefixedText` would
--- answer 'Sandbox/Test' whatever it is given. `titles` maps an input to either
--- the resolved title's prefixedText, or a table `{ prefixedText, redirectTarget }`
--- to also stub a redirect (the shim's own `redirectTarget` is nil/false, unlike
--- the wiki's `mw.title`, which exposes it as an `mw.title` for a redirect page
--- or `false` otherwise); an unlisted input echoes with no redirect, and a value
--- holding a `|` is not a legal title, so it is nil as on the wiki. Restored even
--- if fn throws.
--- @param titles table<string, string|table>
--- @param fn fun()
local function withTitleNew(titles, fn)
	local realNew = mw.title.new
	mw.title.new = function(text)
		if type(text) ~= 'string' or text:find('|', 1, true) then
			return nil
		end
		local entry = titles[text]
		if type(entry) == 'table' then
			return { prefixedText = entry.prefixedText or text, redirectTarget = entry.redirectTarget }
		end
		return { prefixedText = entry or text, redirectTarget = false }
	end
	local ok, err = pcall(fn)
	mw.title.new = realNew
	if not ok then
		error(err, 0)
	end
end

local function putsByBucket()
	local out = {}
	for _, put in ipairs(bucketLib._puts) do
		out[put.bucket] = put.data
	end
	return out
end

--- Installs FULL as the module-level manifest for a store() test, runs fn, and
--- unconditionally restores real-manifest lazy-loading afterward (even if fn or
--- an assertion inside it throws), so a failing test can't leave fake state
--- installed for later suites.
--- @param fn fun()
local function withStore(fn)
	SD._internal.setManifest(FULL)
	local ok, err = pcall(fn)
	SD._internal.setManifest(nil)
	if not ok then
		error(err, 0)
	end
end

--- Makes every `bucketLib(name)` call return a builder whose `put` errors, to
--- exercise store()'s Bucket failure path; restores the real callable
--- metamethod afterward, even if fn throws.
--- @param fn fun()
local function withBucketPutError(fn)
	local mt = getmetatable(bucketLib)
	local realCall = mt.__call
	mt.__call = function()
		return {
			put = function()
				error('boom')
			end,
		}
	end
	local ok, err = pcall(fn)
	mt.__call = realCall
	if not ok then
		error(err, 0)
	end
end

function suite:testSplitRoutesByKindAndReportsForeign()
	local puts, unregistered = SD._internal.splitByBucket(
		FULL,
		{ uuid = 'u', scm_speed = 262, health = 5, modifier_resistance = 3, unknown_key = 1 },
		'Vehicle'
	)
	self:assertDeepEquals({ uuid = 'u' }, puts.entity)
	self:assertDeepEquals({ scm_speed = 262 }, puts.vehicle_stats)
	self:assertEquals(nil, puts.item_weapon)
	table.sort(unregistered)
	self:assertDeepEquals({ 'health', 'modifier_resistance', 'unknown_key' }, unregistered)
end

function suite:testSplitItemGetsMiningModifierColumn()
	local puts = SD._internal.splitByBucket(FULL, { modifier_resistance = 3, health = 5 }, 'Item')
	self:assertDeepEquals({ modifier_resistance = 3 }, puts.item_tool)
	self:assertDeepEquals({ health = 5 }, puts.item_weapon)
end

function suite:testSplitNormalisesValues()
	withTitleNew({}, function()
		local puts =
			SD._internal.splitByBucket(FULL, { effects = 'Toxic', manufacturer = '[[Aegis Dynamics]]' }, 'Item')
		self:assertDeepEquals({ 'Toxic' }, puts.entity.effects)
		self:assertEquals('Aegis Dynamics', puts.entity.manufacturer)
	end)
end

function suite:testSplitRepeatedPageStripsEachElement()
	withTitleNew({}, function()
		local puts =
			SD._internal.splitByBucket(FULL, { loaner_vehicle = { '[[Cutter]]', '[[Aurora MR|Aurora]]' } }, 'Item')
		self:assertDeepEquals({ 'Cutter', 'Aurora MR' }, puts.entity.loaner_vehicle)
	end)
end

function suite:testSplitRepeatedValuesAreDistinctInOrder()
	local puts = SD._internal.splitByBucket(FULL, { effects = { 'Toxic', 'Hydrating', 'Toxic' } }, 'Item')
	self:assertDeepEquals({ 'Toxic', 'Hydrating' }, puts.entity.effects)
end

function suite:testSplitPageWithPipeOutsideBracketsUntouched()
	-- mw.title.new rejects a `|`, so the raw value survives through the fallback.
	withTitleNew({}, function()
		local puts = SD._internal.splitByBucket(FULL, { manufacturer = 'A|B' }, 'Item')
		self:assertEquals('A|B', puts.entity.manufacturer)
	end)
end

function suite:testSplitPageTakesMediaWikiNormalisedTitle()
	withTitleNew({ microTech = 'MicroTech' }, function()
		local puts = SD._internal.splitByBucket(FULL, { manufacturer = 'microTech' }, 'Item')
		self:assertEquals('MicroTech', puts.entity.manufacturer)
	end)
end

function suite:testSplitPageFollowsRedirectToTarget()
	withTitleNew({
		['Ferron System'] = { prefixedText = 'Ferron System', redirectTarget = { prefixedText = 'Ferron system' } },
	}, function()
		local puts = SD._internal.splitByBucket(FULL, { manufacturer = '[[Ferron System]]' }, 'Item')
		self:assertEquals('Ferron system', puts.entity.manufacturer)
	end)
end

function suite:testSplitPageNonRedirectStubUnchanged()
	withTitleNew({
		['Aegis Dynamics'] = { prefixedText = 'Aegis Dynamics', redirectTarget = false },
	}, function()
		local puts = SD._internal.splitByBucket(FULL, { manufacturer = '[[Aegis Dynamics]]' }, 'Item')
		self:assertEquals('Aegis Dynamics', puts.entity.manufacturer)
	end)
end

function suite:testStoreMainNamespaceWritesTheRow()
	bucketLib._reset()
	withStore(function()
		withTitle(0, '', function()
			local ok = SD.store({ uuid = 'u', image = 'X.png' }, 'Vehicle')
			self:assertTrue(ok)
			self:assertDeepEquals({ entity = { uuid = 'u', image = 'X.png' } }, putsByBucket())
		end)
	end)
end

function suite:testStoreOtherNamespaceWritesNothing()
	bucketLib._reset()
	withStore(function()
		withTitle(2, 'User', function()
			local ok = SD.store({ uuid = 'u' }, 'Vehicle')
			self:assertTrue(ok)
			self:assertEquals(0, #bucketLib._puts)
		end)
	end)
end

--- Module:Entity passes the kind that actually matched, so a page whose kind
--- never resolved (e.g. no uuid) is stored with kind = nil: it still writes its
--- entity-routable keys, and the by-kind key ('health') reaches no bucket at all
--- rather than being routed as an Item. 'health' is not reported as unregistered
--- either, since without a kind whether it routes is unknowable, not a manifest
--- gap.
function suite:testStoreWithoutKindWritesEntityRowOnly()
	bucketLib._reset()
	withStore(function()
		withTitle(0, '', function()
			local ok, _err, unregistered = SD.store({ uuid = 'u', health = 5 }, nil)
			self:assertTrue(ok)
			self:assertEquals(nil, unregistered)
			self:assertDeepEquals({ entity = { uuid = 'u' } }, putsByBucket())
		end)
	end)
end

function suite:testStoreBucketFailureIsReported()
	bucketLib._reset()
	withStore(function()
		withTitle(0, '', function()
			withBucketPutError(function()
				local ok, err = SD.store({ uuid = 'u' }, 'Vehicle')
				self:assertFalse(ok)
				self:assertTrue(err:match('^Bucket storage failed') ~= nil)
			end)
		end)
	end)
end

--- Callers outside store() (Module:Company) rely on this guard directly: a
--- call from a non-main-namespace page (e.g. a doc/sandbox render) must not
--- reach Bucket at all.
function suite:testPutBucketsOtherNamespaceSkipsBucket()
	bucketLib._reset()
	withTitle(2, 'User', function()
		local err = SD.putBuckets({ entity = { uuid = 'u' } })
		self:assertEquals(nil, err)
		self:assertEquals(0, #bucketLib._puts)
	end)
end

function suite:testPutBucketsWritesOnePutPerBucket()
	bucketLib._reset()
	withTitle(0, '', function()
		local err = SD.putBuckets({ entity = { uuid = 'u' }, company = { name = 'X' } })
		self:assertEquals(nil, err)
		self:assertDeepEquals({ entity = { uuid = 'u' }, company = { name = 'X' } }, putsByBucket())
	end)
end

function suite:testPutBucketsFailureIsReported()
	bucketLib._reset()
	withTitle(0, '', function()
		withBucketPutError(function()
			local err = SD.putBuckets({ entity = { uuid = 'u' } })
			self:assertTrue(err:match('^Bucket storage failed') ~= nil)
		end)
	end)
end

function suite:testShapeIsExportedBucketValue()
	self:assertDeepEquals({ 'a', 'b' }, SD.shape({ type = 'TEXT', repeated = true }, { 'a', 'b' }))
	self:assertEquals('a', SD.shape({ type = 'TEXT' }, { 'a', 'b' }))
end

return suite
