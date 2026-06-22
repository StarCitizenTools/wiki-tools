require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local suite = ScribuntoUnit:new()
local Util = require('Module:AGGridColumns/Util')

function suite:testDecodeScalarPlain()
	self:assertEquals('Behring', Util.decodeScalar('Behring'))
end

function suite:testDecodeScalarEntities()
	self:assertEquals('180\194\160m/s', Util.decodeScalar('180&#160;m/s'))
end

function suite:testDecodeScalarTable()
	self:assertEquals('Foo', Util.decodeScalar({ fulltext = 'Foo' }))
end

function suite:testDecodeScalarNil()
	self:assertEquals(nil, Util.decodeScalar(nil))
end

function suite:testToTextArrayJoins()
	self:assertEquals('A, B', Util.toText({ 'A', 'B' }))
end

function suite:testToNumberStripsUnits()
	self:assertEquals(1234, Util.toNumber('1,234 m/s'))
end

function suite:testToNumberNbsp()
	self:assertEquals(180, Util.toNumber('180&#160;m'))
end

function suite:testToNumberNil()
	self:assertEquals(nil, Util.toNumber(nil))
end

function suite:testParseLinkTargetAndDisplay()
	local target, display = Util.parseLink('[[:Aegis Dynamics|Aegis]]')
	self:assertEquals('Aegis Dynamics', target)
	self:assertEquals('Aegis', display)
end

function suite:testParseLinkNotALink()
	self:assertEquals(nil, (Util.parseLink('Aegis Dynamics')))
end

function suite:testClassifyColumnAllLinks()
	self:assertEquals('link', Util.classifyColumn({ '[[:A|A]]', '[[:B|B]]' }))
end

function suite:testClassifyColumnMixedIsPlain()
	self:assertEquals('plain', Util.classifyColumn({ '[[:A|A]]', 'text' }))
end

function suite:testClassifyColumnFileIsPlain()
	self:assertEquals('plain', Util.classifyColumn({ '[[File:X.png|frameless]]' }))
end

function suite:testClassifyColumnEmptyIsPlain()
	self:assertEquals('plain', Util.classifyColumn({}))
end

function suite:testCloneFormatCopies()
	local src = { style = 'number', suffix = ' m' }
	local copy = Util.cloneFormat(src)
	self:assertEquals(' m', copy.suffix)
	self:assertFalse(copy == src)
end

function suite:testCloneFormatNil()
	self:assertEquals(nil, Util.cloneFormat(nil))
end

function suite:testToTextScalar()
	self:assertEquals('Laser', Util.toText('Laser'))
end

function suite:testToTextNil()
	self:assertEquals(nil, Util.toText(nil))
end

-- Pre-existing, byte-identical behaviour: an all-empty multi-valued result joins to
-- '' (not nil). Pinned so a future change can't silently alter consumer output.
function suite:testToTextAllEmptyArrayIsEmptyString()
	self:assertEquals('', Util.toText({ '', '' }))
end

function suite:testToNumberNegative()
	self:assertEquals(-3, Util.toNumber('-3 m/s'))
end

function suite:testToNumberArrayUsesFirst()
	self:assertEquals(100, Util.toNumber({ '100 m/s', '200 m/s' }))
end

function suite:testParseLinkNoDisplay()
	local target, display = Util.parseLink('[[:Aegis Dynamics]]')
	self:assertEquals('Aegis Dynamics', target)
	self:assertEquals(nil, display)
end

function suite:testClassifyColumnAllTextIsPlain()
	self:assertEquals('plain', Util.classifyColumn({ '180 m/s', '90 m/s' }))
end

-- A multi-valued cell (a sequence) classifies the whole column as a value list.
function suite:testClassifyColumnMultiValueIsList()
	self:assertEquals('list', Util.classifyColumn({ { 'mining', 'salvage' } }))
end

-- The list check is a full first pass: a single plain value before a multi-valued one
-- still yields 'list' (order-independent), not 'plain'.
function suite:testClassifyColumnMixedSingleThenMultiIsList()
	self:assertEquals('list', Util.classifyColumn({ 'trade', { 'mining', 'salvage' } }))
end

-- A keyed-object scalar ({ fulltext = … }) is not a sequence, so it is not a list.
function suite:testClassifyColumnKeyedObjectIsNotList()
	self:assertEquals('link', Util.classifyColumn({ '[[:A|A]]', '[[:B|B]]' }))
	self:assertEquals('plain', Util.classifyColumn({ { fulltext = 'Foo' } }))
end

function suite:testBuildValueListMultiPlain()
	self:assertDeepEquals(
		{ links = { { text = 'mining' }, { text = 'salvage' } } },
		Util.buildValueList({ 'mining', 'salvage' })
	)
end

function suite:testBuildValueListSingleScalar()
	self:assertDeepEquals({ links = { { text = 'mining' } } }, Util.buildValueList('mining'))
end

function suite:testBuildValueListLinksKeepTarget()
	self:assertDeepEquals(
		{ links = { { text = 'A', href = 'Aegis Dynamics' } } },
		Util.buildValueList({ '[[:Aegis Dynamics|A]]' })
	)
end

function suite:testBuildValueListDropsEmpty()
	self:assertEquals(nil, Util.buildValueList(nil))
	self:assertEquals(nil, Util.buildValueList({ '', '' }))
end

return suite
