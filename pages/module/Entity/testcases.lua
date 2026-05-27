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

function suite:testNoStructuralCategoryWithoutTypeInfo()
	-- Regression guard: sub_type and the "Item Type" description row used to
	-- emit categories; they no longer do (the structural category comes only
	-- from the resolved typeInfo).
	self:assertEquals(
		0,
		#Entity.deriveCategories(
			nil,
			{ sub_type = 'PDCTurret', description_data = { { name = 'Item Type', value = 'Laser Repeater' } } },
			{}
		)
	)
end

function suite:testEmptyWhenNoTypeInfoOrManufacturer()
	self:assertEquals(0, #Entity.deriveCategories(nil, {}, {}))
end

return suite
