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
	local names = Categories.deriveCategories({ name = 'Gun', category = 'Guns' }, nil, {}, {})
	self:assertEquals(true, hasValue(names, 'Guns'))
end

function suite:testTypeCategoryFallsBackToName()
	local names = Categories.deriveCategories({ name = 'Gun' }, nil, {}, {})
	self:assertEquals(true, hasValue(names, 'Gun'))
end

function suite:testManufacturerCategoryFromArg()
	local names = Categories.deriveCategories({ name = 'Gun', category = 'Guns' }, nil, {}, { manufacturer = 'HRST' })
	self:assertEquals(true, hasValue(names, 'Hurston Dynamics'))
end

function suite:testManufacturerCategoryFromApiFallback()
	local names = Categories.deriveCategories(
		{ name = 'Gun', category = 'Guns' },
		nil,
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
			nil,
			{ sub_type = 'PDCTurret', description_data = { { name = 'Item Type', value = 'Laser Repeater' } } },
			{}
		)
	)
end

function suite:testEmptyWhenNoTypeInfoOrManufacturer()
	self:assertEquals(0, #Categories.deriveCategories(nil, nil, {}, {}))
end

function suite:testExtraCategoriesAppendedAfterPrimary()
	local names = Categories.deriveCategories({ category = 'Metals', categories = { 'Commodities' } }, nil, {}, {})
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
	local names = Categories.deriveCategories({ name = 'Gun', category = 'Guns' }, nil, {}, {})
	self:assertEquals(true, hasValue(names, 'Guns'))
	self:assertEquals(false, hasValue(names, 'Commodities'))
end

function suite:testChainCategoriesEmittedWithoutATypeInfo()
	-- A record-less page resolves no type but still earns its chain's browse
	-- categories (a vehicle's career, its production state).
	local names = Categories.deriveCategories(nil, { 'Combat career', 'Flight ready' }, {}, {})
	self:assertEquals(true, hasValue(names, 'Combat career'))
	self:assertEquals(true, hasValue(names, 'Flight ready'))
end

function suite:testChainCategoriesFollowTheTypeInfoOnes()
	local names = Categories.deriveCategories(
		{ category = 'Metals', categories = { 'Commodities' } },
		{ 'Flight ready' },
		{},
		{}
	)
	self:assertEquals('Metals', names[1])
	self:assertEquals('Commodities', names[2])
	self:assertEquals('Flight ready', names[3])
end

function suite:testNoStructuralCategoryFromANamelessTypeInfo()
	self:assertEquals(0, #Categories.deriveCategories({ categories = {} }, nil, {}, {}))
end

-- build()

function suite:testBuildEmitsManualApiDataCategoryWhenTrue()
	local out = Categories.build({ name = 'Ship', category = 'Ships' }, nil, {}, {}, false, false, true)
	self:assertEquals(true, string.find(out, 'Category:Entities with manual API data', 1, true) ~= nil)
end

function suite:testBuildOmitsManualApiDataCategoryWhenFalse()
	local out = Categories.build({ name = 'Ship', category = 'Ships' }, nil, {}, {}, false, false, false)
	self:assertEquals(true, string.find(out, 'Category:Entities with manual API data', 1, true) == nil)
end

function suite:testBuildEmitsUnresolvedReferenceWhenTrue()
	local out = Categories.build({ name = 'Ship', category = 'Ships' }, nil, {}, {}, false, false, false, true)
	self:assertEquals(true, string.find(out, 'Pages with an unresolved entity reference', 1, true) ~= nil)
end

function suite:testBuildOmitsUnresolvedReferenceWhenFalse()
	local out = Categories.build({ name = 'Ship', category = 'Ships' }, nil, {}, {}, false, false, false, false)
	self:assertEquals(true, string.find(out, 'unresolved entity reference', 1, true) == nil)
end

function suite:testBuildOmitsUnresolvedReferenceWhenAbsent()
	-- 6-arg legacy callers must behave exactly as before.
	local out = Categories.build({ name = 'Ship', category = 'Ships' }, nil, {}, {}, false, false, false)
	self:assertEquals(true, string.find(out, 'unresolved entity reference', 1, true) == nil)
end

-- lacksManufacturer()

local MAKER_KIND = { name = 'Item', hasManufacturer = true }

function suite:testLacksManufacturerWhenAKindWithMakersHasNone()
	self:assertTrue(Categories.lacksManufacturer(MAKER_KIND, {}, {}))
end

function suite:testLacksManufacturerOnlyAsksAKindWithMakers()
	self:assertFalse(Categories.lacksManufacturer({ name = 'Location' }, {}, {}))
	self:assertFalse(Categories.lacksManufacturer(nil, {}, {}))
end

function suite:testLacksManufacturerSatisfiedByTheArg()
	self:assertFalse(Categories.lacksManufacturer(MAKER_KIND, {}, { manufacturer = 'AEGS' }))
end

function suite:testLacksManufacturerSatisfiedByTheRecord()
	self:assertFalse(Categories.lacksManufacturer(MAKER_KIND, { manufacturer = { code = 'AEGS' } }, {}))
	self:assertFalse(
		Categories.lacksManufacturer(MAKER_KIND, { manufacturer = { code = 'ZZZ_NOT_A_REAL_CODE', name = 'X' } }, {})
	)
end

function suite:testLacksManufacturerNotForANoMakerCode()
	-- Generic food and drink records carry GENF/GEND: they have no maker by design.
	self:assertFalse(Categories.lacksManufacturer(MAKER_KIND, { manufacturer = { code = 'GENF' } }, {}))
	self:assertFalse(Categories.lacksManufacturer(MAKER_KIND, { manufacturer = { code = 'GEND' } }, {}))
end

-- lacksType()

function suite:testLacksTypeWhenAClaimedPageResolvesNone()
	self:assertTrue(Categories.lacksType(MAKER_KIND, nil))
	self:assertTrue(Categories.lacksType(MAKER_KIND, { category = 'Guns' }))
end

function suite:testLacksTypeNotWhenTheTypeHasAName()
	self:assertFalse(Categories.lacksType(MAKER_KIND, { name = 'Gun', category = 'Guns' }))
end

function suite:testLacksTypeNotWhenNoKindClaimedThePage()
	self:assertFalse(Categories.lacksType(nil, nil))
end

-- build() missing-data categories

local function withNamespace(namespace, fn)
	local realGet = mw.title.getCurrentTitle
	mw.title.getCurrentTitle = function()
		return {
			namespace = namespace,
			inNamespace = function(_, ns)
				return ns == namespace
			end,
		}
	end
	local ok, err = pcall(fn)
	mw.title.getCurrentTitle = realGet
	if not ok then
		error(err, 0)
	end
end

local function buildFor(kind, typeInfo)
	return Categories.build(typeInfo, nil, {}, {}, false, false, false, false, false, kind)
end

function suite:testBuildEmitsMissingDataCategoriesOnArticles()
	withNamespace(0, function()
		local out = buildFor(MAKER_KIND, nil)
		self:assertTrue(out:find('Category:Entities needing a manufacturer', 1, true) ~= nil)
		self:assertTrue(out:find('Category:Entities needing a type', 1, true) ~= nil)
	end)
end

function suite:testBuildOmitsMissingDataCategoriesOutsideArticles()
	withNamespace(2, function()
		local out = buildFor(MAKER_KIND, nil)
		self:assertEquals(nil, out:find(' needing ', 1, true))
	end)
end

function suite:testBuildOmitsMissingDataCategoriesWithoutAKind()
	withNamespace(0, function()
		self:assertEquals(nil, buildFor(nil, nil):find(' needing ', 1, true))
	end)
end

function suite:testUnregisteredPropertyCategory()
	local withFlag = Categories.build(nil, nil, {}, {}, false, false, false, false, true)
	self:assertTrue(withFlag:find('Entities with unregistered structured-data properties', 1, true) ~= nil)
	local withoutFlag = Categories.build(nil, nil, {}, {}, false, false, false, false, false)
	self:assertEquals(nil, withoutFlag:find('Entities with unregistered structured-data properties', 1, true))
end

return suite
