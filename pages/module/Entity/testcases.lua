require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Entity = require('Module:Entity')

local suite = ScribuntoUnit:new()

local function hasValue(list, value)
	for _, v in ipairs(list) do
		if v == value then
			return true
		end
	end
	return false
end

-- deriveCategories()

function suite:testTypeCategoryUsesTypeInfoCategory()
	local names = Entity.deriveCategories({ name = 'Gun', category = 'Guns' }, {}, {})
	self:assertEquals(true, hasValue(names, 'Guns'))
end

function suite:testTypeCategoryFallsBackToName()
	local names = Entity.deriveCategories({ name = 'Gun' }, {}, {})
	self:assertEquals(true, hasValue(names, 'Gun'))
end

function suite:testManufacturerCategoryFromArg()
	local names = Entity.deriveCategories({ name = 'Gun', category = 'Guns' }, {}, { manufacturer = 'HRST' })
	self:assertEquals(true, hasValue(names, 'Hurston Dynamics'))
end

function suite:testManufacturerCategoryFromApiFallback()
	local names = Entity.deriveCategories(
		{ name = 'Gun', category = 'Guns' },
		{ manufacturer = { code = 'ZZZ_NOT_A_REAL_CODE', name = 'Test Manufacturer' } },
		{}
	)
	self:assertEquals(true, hasValue(names, 'Test Manufacturer'))
end

function suite:testItemTypeCategoryEmittedWhenMapped()
	local names = Entity.deriveCategories(
		{ name = 'Gun', category = 'Guns' },
		{ description_data = { { name = 'Item Type', value = 'Laser Repeater' } } },
		{}
	)
	self:assertEquals(true, hasValue(names, 'Laser repeaters'))
end

function suite:testItemTypeCategoryOmittedWhenUnmapped()
	local names = Entity.deriveCategories(
		{ name = 'Gun', category = 'Guns' },
		{ description_data = { { name = 'Item Type', value = 'Totally Bogus Type' } } },
		{}
	)
	self:assertEquals(false, hasValue(names, 'Totally Bogus Type'))
	self:assertEquals(true, hasValue(names, 'Guns'))
end

function suite:testItemTypeCategoryFromTagFallback()
	-- No explicit Item Type label (e.g. 'WARLORD' Cannon): derive from the
	-- CamelCase weapon-type tag.
	local names = Entity.deriveCategories(
		{ name = 'Gun', category = 'Guns' },
		{ tags = { 'VNCL', 'PlasmaCannon', 'flightReady' } },
		{}
	)
	self:assertEquals(true, hasValue(names, 'Plasma cannons'))
end

function suite:testTagFallbackSkippedWhenLabelPresent()
	-- A present-but-unmapped label (PDC guns' "Laser Turret") must NOT fall
	-- back to tags, so PDC guns stay uncategorized until the Turret work.
	local names = Entity.deriveCategories(
		{ name = 'Gun', category = 'Guns' },
		{ description_data = { { name = 'Item Type', value = 'Laser Turret' } }, tags = { 'LaserRepeater' } },
		{}
	)
	self:assertEquals(false, hasValue(names, 'Laser repeaters'))
end

function suite:testEmptyWhenNoTypeInfoOrManufacturer()
	self:assertEquals(0, #Entity.deriveCategories(nil, {}, {}))
end

return suite
