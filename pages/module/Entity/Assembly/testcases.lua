require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local suite = ScribuntoUnit:new()
local assembly = require('Module:Entity/Assembly')

-- mergeSections

function suite:testMergeSectionsEmptyList()
	local result = assembly.mergeSections({})
	self:assertEquals(0, #result)
end

function suite:testMergeSectionsSingleModule()
	local result = assembly.mergeSections({
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
	local result = assembly.mergeSections({
		{
			{ key = 'general', label = 'General', items = { { label = 'Name', content = 'Test' } } },
		},
		{
			{ key = 'general', items = { { label = 'Size', content = '3' } } },
		},
	})
	self:assertEquals(1, #result)
	self:assertEquals('General', result[1].label)
	self:assertEquals(2, #result[1].items)
	self:assertEquals('Name', result[1].items[1].label)
	self:assertEquals('Size', result[1].items[2].label)
end

function suite:testMergeSectionsFirstMetadataWins()
	local result = assembly.mergeSections({
		{
			{
				key = 'general',
				label = 'General',
				collapsible = true,
				items = { { label = 'Name', content = 'Test' } },
			},
		},
		{
			{
				key = 'general',
				label = 'Overridden',
				collapsible = false,
				items = { { label = 'Size', content = '3' } },
			},
		},
	})
	self:assertEquals('General', result[1].label)
	self:assertTrue(result[1].collapsible)
end

function suite:testMergeSectionsPreservesInsertionOrder()
	local result = assembly.mergeSections({
		{ { key = 'general', label = 'General', items = { { label = 'A', content = '1' } } } },
		{ { key = 'specs', label = 'Specs', items = { { label = 'B', content = '2' } } } },
		{ { key = 'damage', label = 'Damage', items = { { label = 'C', content = '3' } } } },
	})
	self:assertEquals(3, #result)
	self:assertEquals('General', result[1].label)
	self:assertEquals('Specs', result[2].label)
	self:assertEquals('Damage', result[3].label)
end

function suite:testMergeSectionsMultipleKeysPerModule()
	local result = assembly.mergeSections({
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
	local result = assembly.mergeSections({
		{
			{ key = 'general', label = 'General', content = 'Some HTML' },
		},
	})
	self:assertEquals(nil, result[1].items)
	self:assertEquals('Some HTML', result[1].content)
end

-- mergeStructuredData

function suite:testMergeStructuredDataEmpty()
	local result = assembly.mergeStructuredData({})
	self:assertEquals(nil, next(result))
end

function suite:testMergeStructuredDataCombinesKeys()
	local result = assembly.mergeStructuredData({
		{ uuid = '123', name = 'Test' },
		{ size = 3, mass = 100 },
	})
	self:assertEquals('123', result.uuid)
	self:assertEquals('Test', result.name)
	self:assertEquals(3, result.size)
	self:assertEquals(100, result.mass)
end

function suite:testMergeStructuredDataLaterOverrides()
	local result = assembly.mergeStructuredData({
		{ name = 'Original' },
		{ name = 'Override' },
	})
	self:assertEquals('Override', result.name)
end

-- buildChain

function suite:testBuildChainSingleModule()
	local base = { parent = nil }
	local chain = assembly.buildChain(base)
	self:assertEquals(1, #chain)
end

return suite
