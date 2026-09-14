require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Related = require('Module:Entity/Related')
local Store = require('Module:Entity/Store')
local bucketLib = require('mw.ext.bucket')

local suite = ScribuntoUnit:new()

-- Minimal fake manifest for the vehicle-series queries: Series/Role live on
-- the joined `vehicle` bucket, Name/Image on the primary `entity` bucket,
-- mirroring the real Module:Entity/properties.json split.
local MANIFEST = {
	['%kinds'] = { Vehicle = { 'entity', 'vehicle' } },
	['Name'] = { type = 'TEXT', bucket = 'entity', field = 'name' },
	['Image'] = { type = 'TEXT', bucket = 'entity', field = 'image' },
	['Series'] = { type = 'TEXT', bucket = 'vehicle', field = 'series', index = true },
	['Role'] = { type = 'TEXT', bucket = 'vehicle', field = 'role', index = true },
}

--- Installs the fake manifest + a clean bucket recorder for `fn`, always
--- restoring the real manifests afterward. Mirrors Store/testcases.lua's
--- withManifest so a bucketLib leak can't cross into another suite.
local function withManifest(fn)
	bucketLib._reset()
	Store._internal.setManifests({ MANIFEST })
	local ok, err = pcall(fn)
	Store._internal.setManifests(nil)
	if not ok then
		error(err, 0)
	end
end

-- boxDimensions()

function suite:testBoxDimensionsStandardSizes()
	local d1 = Related._internal.boxDimensions(1)
	self:assertEquals(1.25, d1[1])
	self:assertEquals(1.25, d1[2])
	self:assertEquals(1.25, d1[3])
	local d32 = Related._internal.boxDimensions(32)
	self:assertEquals(10, d32[1])
	self:assertEquals(2.5, d32[2])
	self:assertEquals(2.5, d32[3])
end

-- 0.125 SCU is the smallest *standard* container (1/8 SCU box, 0.5 m cube),
-- added to BOX_DIMENSIONS when CIG introduced the 1/8 box line.
function suite:testBoxDimensionsEighthScuIsStandard()
	local d = Related._internal.boxDimensions(0.125)
	self:assertEquals(0.5, d[1])
	self:assertEquals(0.5, d[2])
	self:assertEquals(0.5, d[3])
end

-- A genuinely non-standard size (not a CIG cargo container) returns nil.
function suite:testBoxDimensionsNonStandardSizeReturnsNil()
	self:assertEquals(nil, Related._internal.boxDimensions(3))
end

-- queryVehicleVariants()

function suite:testQueryVehicleVariantsBuildsStoreSpecAndSortsByName()
	withManifest(function()
		bucketLib._setRows('entity', {
			{ page_name = 'Aurora MR', name = 'Aurora MR', image = 'AuroraMR.png', ['vehicle.role'] = 'Multi-role' },
			{ page_name = 'Aurora ES', name = 'Aurora ES', image = 'AuroraES.png', ['vehicle.role'] = 'Starter' },
		})
		local rows = Related._internal.queryVehicleVariants('Aurora')
		local chain = bucketLib._chains[1]
		self:assertEquals('entity', chain.bucket)
		self:assertDeepEquals({ 'page_name', 'name', 'vehicle.role', 'image' }, chain.select)
		self:assertDeepEquals({ { 'vehicle', 'vehicle.page_name', 'entity.page_name' } }, chain.join)
		self:assertDeepEquals({ { 'vehicle.series', '=', 'Aurora' } }, chain.where)
		self:assertEquals(100, chain.limit)
		self:assertEquals(2, #rows)
		self:assertEquals('Aurora ES', rows[1].name)
		self:assertEquals('Aurora MR', rows[2].name)
	end)
end

function suite:testQueryVehicleVariantsEmptyOnStoreFailure()
	withManifest(function()
		bucketLib._failNext = true
		self:assertDeepEquals({}, Related._internal.queryVehicleVariants('Aurora'))
	end)
end

-- toVehicleTilesRows()

function suite:testToVehicleTilesRowsShapesRowsAndMarksCurrentPage()
	local rows = {
		{ page = 'Aurora ES', name = 'Aurora ES', role = 'Starter', image = 'AuroraES.png' },
		{ page = 'Aurora MR', name = 'Aurora MR', role = 'Multi-role', image = 'AuroraMR.png' },
	}
	local tilesRows = Related._internal.toVehicleTilesRows(rows, 'Aurora MR')
	self:assertEquals('Aurora ES', tilesRows[1].page)
	self:assertEquals('Aurora ES', tilesRows[1].linkLabel)
	self:assertEquals('AuroraES.png', tilesRows[1].image)
	self:assertEquals('Aurora ES', tilesRows[1].primary)
	self:assertEquals('Starter', tilesRows[1].secondary)
	self:assertFalse(tilesRows[1].selected)
	self:assertTrue(tilesRows[2].selected)
end

-- renderVehicleVariants()

function suite:testRenderVehicleVariantsEmptyForFewerThanTwoRows()
	withManifest(function()
		bucketLib._setRows('entity', {
			{ page_name = 'Aurora MR', name = 'Aurora MR', image = 'AuroraMR.png', ['vehicle.role'] = 'Multi-role' },
		})
		local html = Related._internal.renderVehicleVariants('Aurora', 'Aurora MR')
		self:assertStringContains('t-entity-related-empty', html, true)
	end)
end

-- Tiles.render is exercised as a stub or for real depending on which other
-- suites the runner has discovered in this invocation (Module:Tiles/testcases
-- proves the `selected` → t-tiles__tile--selected wiring on its own), so this
-- only asserts what Related itself controls: the section renders, not the
-- empty state.
function suite:testRenderVehicleVariantsRendersSectionForTwoRows()
	withManifest(function()
		bucketLib._setRows('entity', {
			{ page_name = 'Aurora MR', name = 'Aurora MR', image = 'AuroraMR.png', ['vehicle.role'] = 'Multi-role' },
			{ page_name = 'Aurora ES', name = 'Aurora ES', image = 'AuroraES.png', ['vehicle.role'] = 'Starter' },
		})
		local html = Related._internal.renderVehicleVariants('Aurora', 'Aurora MR')
		self:assertNotStringContains('t-entity-related-empty', html, true)
		self:assertStringContains('Variants', html, true)
	end)
end

return suite
