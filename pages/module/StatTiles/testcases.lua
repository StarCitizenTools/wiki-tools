require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local StatTiles = require('Module:StatTiles')

local suite = ScribuntoUnit:new()

-- presentItems()

function suite:testPresentItemsNilValueIsDropped()
	local result = StatTiles._internal.presentItems({
		{ value = nil, label = 'Empty' },
		{ value = 5, label = 'Real' },
	})
	self:assertEquals(1, #result)
	self:assertEquals(5, result[1].value)
end

function suite:testPresentItemsEmptyStringValueIsDropped()
	local result = StatTiles._internal.presentItems({
		{ value = '', label = 'Empty' },
		{ value = 42, label = 'Real' },
	})
	self:assertEquals(1, #result)
	self:assertEquals(42, result[1].value)
end

function suite:testPresentItemsZeroValueIsKept()
	local result = StatTiles._internal.presentItems({
		{ value = 0, label = 'Zero' },
		{ value = 5, label = 'Five' },
	})
	self:assertEquals(2, #result)
	self:assertEquals(0, result[1].value)
	self:assertEquals(5, result[2].value)
end

function suite:testPresentItemsMissingLabelIsDropped()
	local result = StatTiles._internal.presentItems({
		{ value = 10 },
		{ value = 20, label = 'Valid' },
	})
	self:assertEquals(1, #result)
	self:assertEquals(20, result[1].value)
end

function suite:testPresentItemsNilListReturnsEmpty()
	local result = StatTiles._internal.presentItems(nil)
	self:assertEquals(0, #result)
end

function suite:testPresentItemsPreservesOrder()
	local result = StatTiles._internal.presentItems({
		{ value = 1, label = 'First' },
		{ value = 2, label = 'Second' },
		{ value = 3, label = 'Third' },
	})
	self:assertEquals(3, #result)
	self:assertEquals(1, result[1].value)
	self:assertEquals(2, result[2].value)
	self:assertEquals(3, result[3].value)
end

function suite:testPresentItemsAllEmptyReturnsEmpty()
	local result = StatTiles._internal.presentItems({
		{ value = nil, label = 'A' },
		{ value = '', label = 'B' },
		{ value = 5 },
	})
	self:assertEquals(0, #result)
end

return suite
