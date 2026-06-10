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

function suite:testParseArgsReferencePassthrough()
	local ref = { length = 1.25, width = 1.25, height = 1.25, label = '1 SCU box · 1.25 m' }
	local data = internal.parseArgs({ length = '2', width = '1', height = '1', reference = ref })
	self:assertEquals(ref, data.reference)
end

function suite:testParseArgsInvalidReferenceDropped()
	-- A reference missing a dimension is not a drawable box, so it is ignored.
	local data = internal.parseArgs({ length = '2', width = '1', height = '1', reference = { length = 1, width = 1 } })
	self:assertEquals(nil, data.reference)
end

function suite:testParseArgsMetricsPassthrough()
	local metrics = { { label = 'Mass', value = '2,000 kg' } }
	local data = internal.parseArgs({ length = '2', width = '1', height = '1', metrics = metrics })
	self:assertEquals(metrics, data.metrics)
end

-- isBox()

function suite:testIsBoxValid()
	self:assertEquals(true, internal.isBox({ length = 1.25, width = 1.25, height = 1.25 }))
end

function suite:testIsBoxZeroRejected()
	self:assertEquals(false, internal.isBox({ length = 0, width = 1, height = 1 }))
end

function suite:testIsBoxNilRejected()
	self:assertEquals(false, internal.isBox(nil))
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
	local html = Dimensions._main({ length = '18', width = '8', height = '4' })
	self:assertStringContains('data-length="18"', html, true)
	self:assertStringContains('data-width="8"', html, true)
	self:assertStringContains('data-height="4"', html, true)
end

function suite:testMainEmitsAltDataAttributes()
	local html = Dimensions._main({ length = '26', width = '4', height = '5', lengthAlt = '22' })
	self:assertStringContains('data-length-alt="22"', html, true)
	self:assertEquals(nil, string.find(html, 'data-width-alt', 1, true))
end

function suite:testMainRendersReference()
	local html = Dimensions._main({
		length = '2',
		width = '1',
		height = '1',
		reference = {
			length = 1.25,
			width = 1.25,
			height = 1.25,
			label = '1 SCU box · 1.25 m',
			color = '#c8742d',
		},
	})
	self:assertStringContains('t-dimensions--has-reference', html, true)
	self:assertStringContains('1 SCU box · 1.25 m', html, true)
	-- The caller's colour is applied inline.
	self:assertStringContains('#c8742d', html, true)
end

function suite:testMainRendersMetrics()
	local html = Dimensions._main({
		length = '2',
		width = '1',
		height = '1',
		metrics = { { label = 'Volume', value = '84,000 µSCU' } },
	})
	self:assertStringContains('t-dimensions-footer', html, true)
	self:assertStringContains('Volume', html, true)
	self:assertStringContains('84,000 µSCU', html, true)
end

function suite:testMainRendersMultipleMetrics()
	local html = Dimensions._main({
		length = '2',
		width = '1',
		height = '1',
		metrics = { { label = 'Mass', value = '2,000 kg' }, { label = 'Volume', value = '2 SCU' } },
	})
	self:assertStringContains('2,000 kg', html, true)
	self:assertStringContains('2 SCU', html, true)
end

function suite:testMainOmitsFooterWhenBare()
	local html = Dimensions._main({ length = '18', width = '8', height = '4' })
	self:assertEquals(nil, string.find(html, 't-dimensions-footer', 1, true))
	self:assertEquals(nil, string.find(html, 't-dimensions--has-reference', 1, true))
end

function suite:testMainInvalidReturnsNil()
	self:assertEquals(nil, Dimensions._main({ length = '18' }))
end

return suite
