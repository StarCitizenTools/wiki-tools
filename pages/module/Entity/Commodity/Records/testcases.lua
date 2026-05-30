require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Records = require('Module:Entity/Commodity/Records')

local suite = ScribuntoUnit:new()

-- findHarvestableUuid (edible-commodity enrichment)

function suite:testFindHarvestableUuidPicksHarvestable()
	local items = {
		{ uuid = 'cargo-1', sub_type = 'Cargo' },
		{ uuid = 'harv-1', sub_type = 'Harvestable' },
	}
	self:assertEquals('harv-1', Records._internal.findHarvestableUuid(items))
end

function suite:testFindHarvestableUuidIgnoresCargoOnly()
	local items = {
		{ uuid = 'cargo-1', sub_type = 'Cargo' },
		{ uuid = 'cargo-2', sub_type = 'Cargo' },
	}
	self:assertEquals(nil, Records._internal.findHarvestableUuid(items))
end

function suite:testFindHarvestableUuidFirstWhenMultiple()
	local items = {
		{ uuid = 'harv-1', sub_type = 'Harvestable' },
		{ uuid = 'harv-2', sub_type = 'Harvestable' },
	}
	self:assertEquals('harv-1', Records._internal.findHarvestableUuid(items))
end

function suite:testFindHarvestableUuidNilOrEmpty()
	self:assertEquals(nil, Records._internal.findHarvestableUuid(nil))
	self:assertEquals(nil, Records._internal.findHarvestableUuid({}))
end

function suite:testFindHarvestableUuidSkipsHarvestableWithoutUuid()
	-- A harvestable stub missing its uuid is skipped; iteration continues.
	local items = {
		{ sub_type = 'Harvestable' },
		{ uuid = 'harv-2', sub_type = 'Harvestable' },
	}
	self:assertEquals('harv-2', Records._internal.findHarvestableUuid(items))
end

function suite:testResolveRolesSelfIsRaw()
	local self_ = { name = 'Aslarite (Raw)', is_mineable = true, refined_version = { uuid = 'ref-1' } }
	local counterpart = { name = 'Aslarite' }
	local raw, refined = Records._internal.resolveRoles(self_, counterpart)
	self:assertEquals('Aslarite (Raw)', raw.name)
	self:assertEquals('Aslarite', refined.name)
end

function suite:testResolveRolesSelfIsRefined()
	local self_ = { name = 'Aslarite', raw_versions = { { uuid = 'raw-1' } } }
	local counterpart = { name = 'Aslarite (Raw)' }
	local raw, refined = Records._internal.resolveRoles(self_, counterpart)
	self:assertEquals('Aslarite (Raw)', raw.name)
	self:assertEquals('Aslarite', refined.name)
end

function suite:testResolveRolesRefinedOnlyNoCounterpart()
	local self_ = { name = 'GoldOnly', raw_versions = {} }
	local raw, refined = Records._internal.resolveRoles(self_, nil)
	self:assertEquals(nil, raw)
	self:assertEquals('GoldOnly', refined.name)
end

-- counterpartUuid (new direct coverage — previously only exercised via enrich)

function suite:testCounterpartUuidForwardViaRefinedVersion()
	self:assertEquals('ref-1', Records._internal.counterpartUuid({ refined_version = { uuid = 'ref-1' } }))
end

function suite:testCounterpartUuidBackViaRawVersions()
	self:assertEquals('raw-1', Records._internal.counterpartUuid({ raw_versions = { { uuid = 'raw-1' } } }))
end

function suite:testCounterpartUuidNilWhenOneSided()
	self:assertEquals(nil, Records._internal.counterpartUuid({}))
end

return suite
