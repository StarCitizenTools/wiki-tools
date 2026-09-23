require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local hatnote = require('Module:Hatnote')

local suite = ScribuntoUnit:new()

function suite:testHatnoteIsANoticeMbox()
	local html = hatnote._hatnote('For X, see Y.', { icon = 'WikimediaUI-Article-ltr.svg' })
	self:assertStringContains('t-mbox--notice', html, true)
	self:assertStringContains('role="note"', html, true)
	self:assertStringContains('t-mbox__icon', html, true)
	self:assertStringContains('For X, see Y.', html, true)
	self:assertNotStringContains('hatnote', html, true)
end

function suite:testExtraclassesAndSelfrefReachTheRoot()
	local html = hatnote._hatnote('Note', { extraclasses = 'extra', selfref = true })
	self:assertStringContains('extra selfref', html, true)
end

function suite:testInlineIsAPlainSpan()
	local html = hatnote._hatnote('Note', { inline = 1 })
	self:assertStringContains('<span', html, true)
	self:assertStringContains('navigation-not-searchable', html, true)
	self:assertNotStringContains('t-mbox', html, true)
end

function suite:testDefaultClasses()
	self:assertEquals('navigation-not-searchable', hatnote.defaultClasses())
	self:assertEquals('navigation-not-searchable', hatnote.defaultClasses(1))
end

function suite:testDisambiguateUnchanged()
	self:assertEquals('Example (disambiguation)', hatnote.disambiguate('Example'))
end

return suite
