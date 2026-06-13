require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local suite = ScribuntoUnit:new()
local Util = require('Module:DataGrid/Util')

-- decodeScalar

function suite:testDecodeScalarPlain()
	self:assertEquals('Behring', Util.decodeScalar('Behring'))
end

-- The SMW formatter emits the literal entity "&#160;" for nbsp; it must decode so
-- the "160" does not leak into the text. U+00A0 is "\194\160" in UTF-8.
function suite:testDecodeScalarEntities()
	self:assertEquals('180\194\160m/s', Util.decodeScalar('180&#160;m/s'))
end

function suite:testDecodeScalarTable()
	self:assertEquals('Foo', Util.decodeScalar({ fulltext = 'Foo' }))
end

function suite:testDecodeScalarNil()
	self:assertEquals(nil, Util.decodeScalar(nil))
end

-- toText

function suite:testToTextScalar()
	self:assertEquals('Laser', Util.toText('Laser'))
end

function suite:testToTextArrayJoins()
	self:assertEquals('A, B', Util.toText({ 'A', 'B' }))
end

function suite:testToTextNil()
	self:assertEquals(nil, Util.toText(nil))
end

-- parseLink

function suite:testParseLinkTargetAndDisplay()
	local target, display = Util.parseLink('[[:Aegis Dynamics|Aegis]]')
	self:assertEquals('Aegis Dynamics', target)
	self:assertEquals('Aegis', display)
end

function suite:testParseLinkNoDisplay()
	local target, display = Util.parseLink('[[:Aegis Dynamics]]')
	self:assertEquals('Aegis Dynamics', target)
	self:assertEquals(nil, display)
end

function suite:testParseLinkNotALink()
	self:assertEquals(nil, (Util.parseLink('Aegis Dynamics')))
end

-- classifyColumn

function suite:testClassifyColumnAllLinks()
	self:assertEquals('link', Util.classifyColumn({ '[[:A|A]]', '[[:B|B]]' }))
end

function suite:testClassifyColumnMixedIsPlain()
	self:assertEquals('plain', Util.classifyColumn({ '[[:A|A]]', 'text' }))
end

function suite:testClassifyColumnAllTextIsPlain()
	self:assertEquals('plain', Util.classifyColumn({ '180 m/s', '90 m/s' }))
end

function suite:testClassifyColumnFileIsPlain()
	self:assertEquals('plain', Util.classifyColumn({ '[[File:X.png|frameless]]' }))
end

function suite:testClassifyColumnEmptyIsPlain()
	self:assertEquals('plain', Util.classifyColumn({}))
end

return suite
