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

function suite:testResolvesTheVariantList()
	local variants = Description.resolveVariants({
		description = '[Contractor|GroupBountyDescription]',
		description_variants = { 'Local law bounced us a warrant.', 'Advocacy have been hunting a group.' },
	})
	self:assertEquals(2, #variants)
	self:assertEquals('Local law bounced us a warrant.', variants[1])
end

function suite:testNoVariantsResolvesToAnEmptyList()
	self:assertEquals(0, #Description.resolveVariants({}))
	self:assertEquals(0, #Description.resolveVariants({ description_variants = {} }))
	self:assertEquals(0, #Description.resolveVariants({ description_variants = 'nope' }))
end

function suite:testVariantsThatAreThemselvesPlaceholdersAreDropped()
	local variants = Description.resolveVariants({
		description_variants = { '[Contractor|BountyDescription]', 'Real prose.', '' },
	})
	self:assertEquals(1, #variants)
	self:assertEquals('Real prose.', variants[1])
end

function suite:testAVariantContainingAPlaceholderIsKept()
	-- Every real variant carries inline tokens the game substitutes.
	local prose = 'Take care of [Target1], [Target2], and [Target3].'
	local variants = Description.resolveVariants({ description_variants = { prose } })
	self:assertEquals(prose, variants[1])
end

return suite
