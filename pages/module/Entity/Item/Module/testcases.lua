require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local suite = ScribuntoUnit:new()
local Module = require('Module:Entity/Item/Module')
local item = require('Module:Entity/Item')
local helpers = Module._internal

-- An item shaped like the Aurora Mk II DM Module: empty vehicles array, owning
-- vehicle resolved from related_items.set_name (the fallback path).
local function moduleWithSet()
	return {
		name = 'Aurora Mk II DM Module',
		type = 'Module',
		vehicles = {},
		related_items = { set_name = 'Aurora Mk II' },
	}
end

-- An item shaped like an Apollo module: populated vehicles relation listing
-- both variants (and a cruder set_name that must NOT win).
local function moduleWithVehicles()
	return {
		name = 'Apollo Tier 1 Module Left',
		type = 'Module',
		vehicles = { { name = 'Apollo Medivac' }, { name = 'Apollo Triage' } },
		related_items = { set_name = 'Apollo Tier' },
	}
end

-- resolveVehicles

function suite:testResolveVehiclesFromVehiclesRelation()
	local v = helpers.resolveVehicles(moduleWithVehicles())
	self:assertEquals(2, #v)
	self:assertEquals('Apollo Medivac', v[1])
	self:assertEquals('Apollo Triage', v[2])
end

function suite:testResolveVehiclesPrefersVehiclesOverSetName()
	-- set_name 'Apollo Tier' must be ignored when vehicles is populated.
	local v = helpers.resolveVehicles(moduleWithVehicles())
	self:assertEquals('Apollo Medivac', v[1])
end

function suite:testResolveVehiclesFallsBackToSetName()
	local v = helpers.resolveVehicles(moduleWithSet())
	self:assertEquals(1, #v)
	self:assertEquals('Aurora Mk II', v[1])
end

function suite:testResolveVehiclesDedupesAndSkipsEmpty()
	local v = helpers.resolveVehicles({
		vehicles = { { name = 'Shiv' }, { name = '' }, { name = 'Shiv' }, { foo = 1 } },
	})
	self:assertEquals(1, #v)
	self:assertEquals('Shiv', v[1])
end

function suite:testResolveVehiclesNoneResolvable()
	self:assertEquals(0, #helpers.resolveVehicles({ name = 'X' }))
	self:assertEquals(0, #helpers.resolveVehicles({ vehicles = {}, related_items = {} }))
	self:assertEquals(0, #helpers.resolveVehicles({ vehicles = 'nope' }))
	self:assertEquals(0, #helpers.resolveVehicles(nil))
end

-- getTypeInfo

function suite:testGetTypeInfoSingleVehicle()
	local info = Module.getTypeInfo(moduleWithSet(), {})
	self:assertEquals('Vehicle module', info.name)
	self:assertEquals('Aurora Mk II', info.category)
	self:assertEquals(1, #info.categories)
	self:assertEquals('Vehicle modules', info.categories[1])
end

function suite:testGetTypeInfoMultipleVehicles()
	local info = Module.getTypeInfo(moduleWithVehicles(), {})
	self:assertEquals('Apollo Medivac', info.category)
	-- Second vehicle rides along as an extra, then the shared bucket.
	self:assertEquals(2, #info.categories)
	self:assertEquals('Apollo Triage', info.categories[1])
	self:assertEquals('Vehicle modules', info.categories[2])
end

function suite:testGetTypeInfoNoVehicle()
	local info = Module.getTypeInfo({ type = 'Module' }, {})
	self:assertEquals('Vehicle module', info.name)
	self:assertEquals('Vehicle modules', info.category)
end

-- getSections

function suite:testGetSectionsSingleVehicle()
	local sections = Module.getSections(moduleWithSet(), {})
	self:assertEquals(1, #sections)
	self:assertEquals('general', sections[1].key)
	self:assertEquals('Vehicle', sections[1].items[1].label)
	self:assertEquals('[[Aurora Mk II]]', sections[1].items[1].content)
end

function suite:testGetSectionsMultipleVehicles()
	local sections = Module.getSections(moduleWithVehicles(), {})
	self:assertEquals('Vehicles', sections[1].items[1].label)
	self:assertEquals('[[Apollo Medivac]], [[Apollo Triage]]', sections[1].items[1].content)
end

function suite:testGetSectionsNoVehicle()
	self:assertEquals(0, #Module.getSections({ type = 'Module' }, {}))
end

-- getShortDescription

function suite:testGetShortDescriptionSingleVehicle()
	local apiData = moduleWithSet()
	local typeInfo = Module.getTypeInfo(apiData, {})
	self:assertEquals('Vehicle module for the Aurora Mk II', Module.getShortDescription(apiData, {}, typeInfo, nil))
end

function suite:testGetShortDescriptionMultipleVehicles()
	local apiData = moduleWithVehicles()
	local typeInfo = Module.getTypeInfo(apiData, {})
	self:assertEquals(
		'Vehicle module for the Apollo Medivac and Apollo Triage',
		Module.getShortDescription(apiData, {}, typeInfo, nil)
	)
end

function suite:testGetShortDescriptionNoVehicleDelegatesToItem()
	-- No vehicle → defer to Item's "<type> by <manufacturer>" composer; assert
	-- it matches Item's own output for the same inputs (delegation).
	local apiData = { type = 'Module' }
	local typeInfo = Module.getTypeInfo(apiData, {})
	local expected = item.getShortDescription(apiData, {}, typeInfo, nil)
	self:assertEquals(expected, Module.getShortDescription(apiData, {}, typeInfo, nil))
end

-- getStructuredData

function suite:testGetStructuredDataSingleVehicleScalar()
	self:assertEquals('Aurora Mk II', Module.getStructuredData(moduleWithSet(), {}).vehicle)
end

function suite:testGetStructuredDataMultipleVehiclesList()
	local v = Module.getStructuredData(moduleWithVehicles(), {}).vehicle
	self:assertEquals(2, #v)
	self:assertEquals('Apollo Medivac', v[1])
	self:assertEquals('Apollo Triage', v[2])
end

function suite:testGetStructuredDataNoVehicle()
	self:assertEquals(nil, Module.getStructuredData({ type = 'Module' }, {}).vehicle)
end

return suite
