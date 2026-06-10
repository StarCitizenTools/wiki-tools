require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local suite = ScribuntoUnit:new()
local Dimensions = require('Module:Dimensions')
local internal = Dimensions._internal

-- parseArgs()

function suite:testParseArgsValid()
	local data = internal.parseArgs({ length = '18', width = '8', height = '4' })
	self:assertEquals(18, data.length)
	self:assertEquals(8, data.width)
	self:assertEquals(4, data.height)
end

function suite:testParseArgsMissingRequired()
	self:assertEquals(nil, internal.parseArgs({ length = '18', width = '8' }))
end

function suite:testParseArgsZeroRejected()
	self:assertEquals(nil, internal.parseArgs({ length = '0', width = '8', height = '4' }))
end

function suite:testParseArgsNegativeRejected()
	self:assertEquals(nil, internal.parseArgs({ length = '-3', width = '8', height = '4' }))
end

function suite:testParseArgsNonNumericRejected()
	self:assertEquals(nil, internal.parseArgs({ length = 'tall', width = '8', height = '4' }))
end

function suite:testParseArgsAltEqualDropped()
	local data = internal.parseArgs({ length = '18', width = '8', height = '4', lengthAlt = '18', widthAlt = '8' })
	self:assertEquals(nil, data.lengthAlt)
	self:assertEquals(nil, data.widthAlt)
end

function suite:testParseArgsAltKept()
	local data = internal.parseArgs({ length = '26', width = '4', height = '5', lengthAlt = '22' })
	self:assertEquals(22, data.lengthAlt)
end

function suite:testParseArgsKnownReference()
	local data = internal.parseArgs({ length = '18', width = '8', height = '4', referenceType = 'human' })
	self:assertEquals('human', data.referenceType)
	self:assertEquals(1.8, data.reference.height)
end

function suite:testParseArgsUnknownReferenceIgnored()
	local data = internal.parseArgs({ length = '18', width = '8', height = '4', referenceType = 'dragon' })
	self:assertEquals(nil, data.reference)
end

-- formatValue()

function suite:testFormatValuePlain()
	self:assertEquals('18 m', internal.formatValue(18, 'm'))
end

function suite:testFormatValueWithAlt()
	self:assertEquals('26 m <span class="t-dimensions-value-subtle">(22 m)</span>', internal.formatValue(26, 'm', 22))
end

function suite:testFormatValueThousands()
	self:assertEquals('25,172 kg', internal.formatValue(25172, 'kg'))
end

-- _main()

function suite:testMainEmitsDataAttributes()
	local html = Dimensions._main({ length = '18', width = '8', height = '4', mass = '25172', referenceType = 'human' })
	self:assertStringContains('data-length="18"', html, true)
	self:assertStringContains('data-width="8"', html, true)
	self:assertStringContains('data-height="4"', html, true)
	self:assertStringContains('data-mass="25172"', html, true)
	self:assertStringContains('data-reference="human"', html, true)
end

function suite:testMainEmitsAltDataAttributes()
	local html = Dimensions._main({ length = '26', width = '4', height = '5', lengthAlt = '22' })
	self:assertStringContains('data-length-alt="22"', html, true)
	self:assertEquals(nil, string.find(html, 'data-width-alt', 1, true))
end

function suite:testMainOmitsAbsentDataAttributes()
	local html = Dimensions._main({ length = '18', width = '8', height = '4' })
	self:assertEquals(nil, string.find(html, 'data-mass', 1, true))
	self:assertEquals(nil, string.find(html, 'data-reference', 1, true))
	self:assertEquals(nil, string.find(html, 't-dimensions-footer', 1, true))
end

function suite:testMainInvalidReturnsNil()
	self:assertEquals(nil, Dimensions._main({ length = '18' }))
end

return suite
