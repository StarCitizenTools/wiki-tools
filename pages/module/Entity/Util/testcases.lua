require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local suite = ScribuntoUnit:new()
local util = require('Module:Entity/Util')

-- mergeSections

function suite:testMergeSectionsEmptyList()
	local result = util.mergeSections({})
	self:assertEquals(0, #result)
end

function suite:testMergeSectionsSingleModule()
	local result = util.mergeSections({
		{
			{
				key = 'general',
				label = 'General',
				items = {
					{ label = 'Name', content = 'Test' },
				},
			},
		},
	})
	self:assertEquals(1, #result)
	self:assertEquals('General', result[1].label)
	self:assertEquals(1, #result[1].items)
	self:assertEquals('Name', result[1].items[1].label)
end

function suite:testMergeSectionsAppendItems()
	local result = util.mergeSections({
		{
			{
				key = 'general',
				label = 'General',
				items = {
					{ label = 'Name', content = 'Test' },
				},
			},
		},
		{
			{
				key = 'general',
				items = {
					{ label = 'Size', content = '3' },
				},
			},
		},
	})
	self:assertEquals(1, #result)
	self:assertEquals('General', result[1].label)
	self:assertEquals(2, #result[1].items)
	self:assertEquals('Name', result[1].items[1].label)
	self:assertEquals('Size', result[1].items[2].label)
end

function suite:testMergeSectionsFirstMetadataWins()
	local result = util.mergeSections({
		{
			{
				key = 'general',
				label = 'General',
				collapsible = true,
				items = {
					{ label = 'Name', content = 'Test' },
				},
			},
		},
		{
			{
				key = 'general',
				label = 'Overridden',
				collapsible = false,
				items = {
					{ label = 'Size', content = '3' },
				},
			},
		},
	})
	self:assertEquals('General', result[1].label)
	self:assertTrue(result[1].collapsible)
end

function suite:testMergeSectionsPreservesInsertionOrder()
	local result = util.mergeSections({
		{
			{ key = 'general', label = 'General', items = { { label = 'A', content = '1' } } },
		},
		{
			{ key = 'specs', label = 'Specs', items = { { label = 'B', content = '2' } } },
		},
		{
			{ key = 'damage', label = 'Damage', items = { { label = 'C', content = '3' } } },
		},
	})
	self:assertEquals(3, #result)
	self:assertEquals('General', result[1].label)
	self:assertEquals('Specs', result[2].label)
	self:assertEquals('Damage', result[3].label)
end

function suite:testMergeSectionsMultipleKeysPerModule()
	local result = util.mergeSections({
		{
			{ key = 'general', label = 'General', items = { { label = 'Name', content = 'Test' } } },
			{ key = 'specs', label = 'Specs', items = { { label = 'Size', content = '3' } } },
		},
	})
	self:assertEquals(2, #result)
	self:assertEquals('General', result[1].label)
	self:assertEquals('Specs', result[2].label)
end

function suite:testMergeSectionsNilItemsOmitted()
	local result = util.mergeSections({
		{
			{
				key = 'general',
				label = 'General',
				content = 'Some HTML',
			},
		},
	})
	self:assertEquals(nil, result[1].items)
	self:assertEquals('Some HTML', result[1].content)
end

-- mergeStructuredData

function suite:testMergeStructuredDataEmpty()
	local result = util.mergeStructuredData({})
	self:assertEquals(nil, next(result))
end

function suite:testMergeStructuredDataCombinesKeys()
	local result = util.mergeStructuredData({
		{ uuid = '123', name = 'Test' },
		{ size = 3, mass = 100 },
	})
	self:assertEquals('123', result.uuid)
	self:assertEquals('Test', result.name)
	self:assertEquals(3, result.size)
	self:assertEquals(100, result.mass)
end

function suite:testMergeStructuredDataLaterOverrides()
	local result = util.mergeStructuredData({
		{ name = 'Original' },
		{ name = 'Override' },
	})
	self:assertEquals('Override', result.name)
end

-- buildChain

function suite:testBuildChainSingleModule()
	local base = { parent = nil }
	local chain = util.buildChain(base)
	self:assertEquals(1, #chain)
end

-- collectApiConfigs

function suite:testCollectApiConfigsNoConfigs()
	local base = {}
	local configs = util.collectApiConfigs({ base })
	self:assertEquals(0, #configs)
end

function suite:testCollectApiConfigsCombinesChain()
	local base = {}
	local item = {
		getApiConfigs = function()
			return { { name = 'API1', endpoint = 'v2/items/%s' } }
		end,
	}
	local configs = util.collectApiConfigs({ base, item })
	self:assertEquals(1, #configs)
	self:assertEquals('API1', configs[1].name)
end

-- joinAnd

function suite:testJoinAndEmpty()
	self:assertEquals(nil, util.joinAnd({}))
end

function suite:testJoinAndOne()
	self:assertEquals('Energizing', util.joinAnd({ 'Energizing' }))
end

function suite:testJoinAndTwo()
	self:assertEquals('Energizing and Hydrating', util.joinAnd({ 'Energizing', 'Hydrating' }))
end

function suite:testJoinAndThree()
	self:assertEquals('Energizing, Hydrating, and Healing', util.joinAnd({ 'Energizing', 'Hydrating', 'Healing' }))
end

function suite:testJoinAndFour()
	self:assertEquals('A, B, C, and D', util.joinAnd({ 'A', 'B', 'C', 'D' }))
end

-- buildHtmlList

function suite:testBuildHtmlListEmpty()
	self:assertEquals(nil, util.buildHtmlList({}))
end

function suite:testBuildHtmlListNil()
	self:assertEquals(nil, util.buildHtmlList(nil))
end

function suite:testBuildHtmlListSingle()
	self:assertEquals('Energizing', util.buildHtmlList({ 'Energizing' }))
end

function suite:testBuildHtmlListMultiple()
	self:assertEquals(
		'<ul><li>Energizing</li><li>Hydrating</li><li>Healing</li></ul>',
		util.buildHtmlList({ 'Energizing', 'Hydrating', 'Healing' })
	)
end

-- buildSiteLinks

function suite:testBuildSiteLinksFormatAndData()
	local siteDefs = {
		{ label = 'Example', format = 'https://example.com/%s', data = 'uuid' },
	}
	local lookup = { uuid = 'abc-123' }
	local result = util.buildSiteLinks(siteDefs, lookup)
	self:assertEquals('[https://example.com/abc-123 Example]', result)
end

function suite:testBuildSiteLinksArg()
	local siteDefs = {
		{ label = 'Galactapedia', arg = 'galactapedia_url' },
	}
	local lookup = { galactapedia_url = 'https://galactapedia.example.com/page' }
	local result = util.buildSiteLinks(siteDefs, lookup)
	self:assertEquals('[https://galactapedia.example.com/page Galactapedia]', result)
end

function suite:testBuildSiteLinksSkipsMissingData()
	local siteDefs = {
		{ label = 'Example', format = 'https://example.com/%s', data = 'uuid' },
		{ label = 'Other', format = 'https://other.com/%s', data = 'name' },
	}
	local lookup = { uuid = 'abc-123' }
	local result = util.buildSiteLinks(siteDefs, lookup)
	self:assertEquals('[https://example.com/abc-123 Example]', result)
end

function suite:testBuildSiteLinksSkipsMissingArg()
	local siteDefs = {
		{ label = 'Galactapedia', arg = 'galactapedia_url' },
	}
	local lookup = {}
	local result = util.buildSiteLinks(siteDefs, lookup)
	self:assertEquals(nil, result)
end

function suite:testBuildSiteLinksEmpty()
	local result = util.buildSiteLinks({}, {})
	self:assertEquals(nil, result)
end

function suite:testBuildSiteLinksEncodesSpacesInData()
	local siteDefs = {
		{ label = 'Example', format = 'https://example.com/search?q=%s', data = 'name' },
	}
	local lookup = { name = 'Foo Bar' }
	local result = util.buildSiteLinks(siteDefs, lookup)
	self:assertEquals('[https://example.com/search?q=Foo+Bar Example]', result)
end

function suite:testBuildSiteLinksJoinsMultiple()
	local siteDefs = {
		{ label = 'Finder', format = 'https://finder.example.com/%s', data = 'uuid' },
		{ label = 'Galactapedia', arg = 'galactapedia_url' },
	}
	local lookup = { uuid = 'abc-123', galactapedia_url = 'https://galactapedia.example.com/page' }
	local result = util.buildSiteLinks(siteDefs, lookup)
	self:assertEquals(
		'[https://finder.example.com/abc-123 Finder] · [https://galactapedia.example.com/page Galactapedia]',
		result
	)
end

-- formatNum

function suite:testFormatNumGroupsThousands()
	self:assertEquals('756,000', util.formatNum(756000))
end

function suite:testFormatNumSmallNumberUnchanged()
	self:assertEquals('86', util.formatNum(86))
end

function suite:testFormatNumDecimal()
	self:assertEquals('501.7', util.formatNum(501.7))
end

function suite:testFormatNumNilReturnsNil()
	self:assertEquals(nil, util.formatNum(nil))
end

function suite:testFormatNumNumericStringGrouped()
	self:assertEquals('1,480', util.formatNum('1480'))
end

function suite:testFormatNumNonNumericPassthrough()
	self:assertEquals('N/A', util.formatNum('N/A'))
end

-- getItemType

function suite:testGetItemTypeReturnsLabel()
	self:assertEquals(
		'Laser Repeater',
		util.getItemType({ description_data = { { name = 'Item Type', value = 'Laser Repeater' } } })
	)
end

function suite:testGetItemTypeFallsBackToTypeField()
	self:assertEquals(
		'Laser Repeater',
		util.getItemType({ description_data = { { name = 'Item Type', type = 'Laser Repeater' } } })
	)
end

function suite:testGetItemTypeFromTypeEntryName()
	-- Some items label it "Type" rather than "Item Type" (e.g. Exodus-10 Laser Beam).
	self:assertEquals(
		'Laser Beam',
		util.getItemType({ description_data = { { name = 'Type', value = 'Laser Beam' } } })
	)
end

function suite:testGetItemTypeNilWhenAbsent()
	self:assertEquals(nil, util.getItemType({}))
	self:assertEquals(nil, util.getItemType(nil))
end

return suite
