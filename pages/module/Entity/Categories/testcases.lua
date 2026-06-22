require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Categories = require('Module:Entity/Categories')

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
	local names = Categories.deriveCategories({ name = 'Gun', category = 'Guns' }, {}, {})
	self:assertEquals(true, hasValue(names, 'Guns'))
end

function suite:testTypeCategoryFallsBackToName()
	local names = Categories.deriveCategories({ name = 'Gun' }, {}, {})
	self:assertEquals(true, hasValue(names, 'Gun'))
end

function suite:testManufacturerCategoryFromArg()
	local names = Categories.deriveCategories({ name = 'Gun', category = 'Guns' }, {}, { manufacturer = 'HRST' })
	self:assertEquals(true, hasValue(names, 'Hurston Dynamics'))
end

function suite:testManufacturerCategoryFromApiFallback()
	local names = Categories.deriveCategories(
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
		#Categories.deriveCategories(
			nil,
			{ sub_type = 'PDCTurret', description_data = { { name = 'Item Type', value = 'Laser Repeater' } } },
			{}
		)
	)
end

function suite:testEmptyWhenNoTypeInfoOrManufacturer()
	self:assertEquals(0, #Categories.deriveCategories(nil, {}, {}))
end

function suite:testExtraCategoriesAppendedAfterPrimary()
	local names = Categories.deriveCategories({ category = 'Metals', categories = { 'Commodities' } }, {}, {})
	self:assertEquals(true, hasValue(names, 'Metals'))
	self:assertEquals(true, hasValue(names, 'Commodities'))
	-- primary group category comes before the extra
	local iMetals, iComm
	for i, v in ipairs(names) do
		if v == 'Metals' then
			iMetals = i
		end
		if v == 'Commodities' then
			iComm = i
		end
	end
	self:assertEquals(true, iMetals < iComm)
end

function suite:testNoExtraCategoriesWhenAbsent()
	-- typeInfo without a `categories` field must behave exactly as before.
	local names = Categories.deriveCategories({ name = 'Gun', category = 'Guns' }, {}, {})
	self:assertEquals(true, hasValue(names, 'Guns'))
	self:assertEquals(false, hasValue(names, 'Commodities'))
end

-- build()

function suite:testBuildEmitsManualApiDataCategoryWhenTrue()
	local out = Categories.build({ name = 'Ship', category = 'Ships' }, {}, {}, false, false, true)
	self:assertEquals(true, string.find(out, 'Category:Entities with manual API data', 1, true) ~= nil)
end

function suite:testBuildOmitsManualApiDataCategoryWhenFalse()
	local out = Categories.build({ name = 'Ship', category = 'Ships' }, {}, {}, false, false, false)
	self:assertEquals(true, string.find(out, 'Category:Entities with manual API data', 1, true) == nil)
end

return suite
