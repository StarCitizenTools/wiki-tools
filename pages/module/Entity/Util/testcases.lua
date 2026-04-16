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

return suite
