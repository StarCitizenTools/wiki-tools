require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Description = require('Module:Entity/Description')

local suite = ScribuntoUnit:new()

function suite:testResolvesAPlainEnglishString()
	self:assertEquals(
		'A rugged exploration suit.',
		Description.resolveDescription({
			description = 'A rugged exploration suit.',
		})
	)
end

function suite:testResolvesTheLocaleMapFallback()
	self:assertEquals(
		'Ein Anzug.',
		Description.resolveDescription({
			description = { en_EN = 'Ein Anzug.' },
		})
	)
end

function suite:testAbsentOrEmptyDescriptionIsNil()
	self:assertEquals(nil, Description.resolveDescription({}))
	self:assertEquals(nil, Description.resolveDescription({ description = '' }))
	self:assertEquals(nil, Description.resolveDescription({ description = 42 }))
end

function suite:testUnresolvedPlaceholderIsTreatedAsAbsent()
	-- 184 of the 1,786 4.10 mission records carry only this shape; rendering it
	-- verbatim would print an internal token to the page.
	self:assertEquals(
		nil,
		Description.resolveDescription({
			description = '[Contractor|DestroyProbeDescription]',
		})
	)
	self:assertEquals(
		nil,
		Description.resolveDescription({
			description = '  [Contractor|BaseSweepDescription]  ',
		})
	)
end

function suite:testProseContainingAPlaceholderIsKept()
	-- The game substitutes these inline, so prose around one is a real description.
	local prose = 'Please head to [Location|Address] and eliminate the target.'
	self:assertEquals(prose, Description.resolveDescription({ description = prose }))
end

function suite:testTwoPlaceholdersAreProseNotAPlaceholder()
	local prose = '[Location|Address] to [Destination|Address]'
	self:assertEquals(prose, Description.resolveDescription({ description = prose }))
end

return suite
