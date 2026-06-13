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

return suite
