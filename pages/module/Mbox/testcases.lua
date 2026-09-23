require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local mbox = require('Module:Mbox')

local suite = ScribuntoUnit:new()

function suite:testTitleOnlyIsANote()
	local html = mbox.render({ title = 'Hello' })
	self:assertStringContains('class="t-mbox t-mbox--notice navigation-not-searchable noexcerpt"', html, true)
	self:assertStringContains('role="note"', html, true)
	self:assertStringContains('<span class="t-mbox__title">Hello</span>', html, true)
	self:assertNotStringContains('<details', html, true)
	self:assertNotStringContains('t-mbox__indicator', html, true)
end

function suite:testTypeSetsModifier()
	self:assertStringContains('t-mbox--warning', mbox.render({ title = 'T', type = 'warning' }), true)
	self:assertStringContains('t-mbox--error', mbox.render({ title = 'T', type = 'error' }), true)
end

function suite:testUnknownTypeFallsBackToNotice()
	local html = mbox.render({ title = 'T', type = 'shouty' })
	self:assertStringContains('t-mbox--notice', html, true)
	self:assertNotStringContains('t-mbox--shouty', html, true)
end

function suite:testPlaceholderHasNoRole()
	local html = mbox.render({ title = 'No ports.', placeholder = true })
	self:assertStringContains('t-mbox--placeholder', html, true)
	self:assertNotStringContains('role=', html, true)
end

function suite:testPlaceholderCarriesNoexcerpt()
	local html = mbox.render({ title = 'No ports.', placeholder = true })
	self:assertStringContains('noexcerpt', html, true)
end

function suite:testTextRendersAClosedDisclosure()
	local html = mbox.render({ title = 'Head', text = 'Body' })
	self:assertStringContains(
		'<details class="t-mbox t-mbox--notice navigation-not-searchable noexcerpt" open="no">',
		html,
		true
	)
	self:assertStringContains('<summary class="t-mbox__header">', html, true)
	self:assertStringContains('t-mbox__indicator', html, true)
	self:assertStringContains('class="t-mbox__text"', html, true)
	self:assertStringContains('Body', html, true)
	self:assertNotStringContains('role="note"', html, true)
end

function suite:testOpenStartsExpanded()
	self:assertStringContains('open="yes"', mbox.render({ title = 'H', text = 'B', open = true }), true)
end

function suite:testClassPassesThrough()
	self:assertStringContains('metadata plainlinks', mbox.render({ title = 'T', class = 'metadata plainlinks' }), true)
end

function suite:testIconIsAMaskByDefault()
	local html = mbox.render({ title = 'T', icon = 'WikimediaUI-Alert.svg' })
	self:assertStringContains('t-icon--mask', html, true)
	self:assertStringContains('t-mbox__icon', html, true)
end

function suite:testIconMaskFalseIsAThumbnail()
	local html = mbox.render({ title = 'T', icon = 'Relay icon.svg', iconMask = false })
	self:assertStringContains('[[File:Relay icon.svg|14px|', html, true)
	self:assertNotStringContains('t-icon--mask', html, true)
end

function suite:testNoIconWithoutAFile()
	self:assertNotStringContains('t-mbox__icon', mbox.render({ title = 'T' }), true)
end

function suite:testLegacyMboxMapsExtraclassesToType()
	local html = mbox._mbox('Head', 'Body', { extraclasses = 'mbox-med plainlinks' })
	self:assertStringContains('t-mbox--warning', html, true)
	self:assertStringContains('plainlinks', html, true)
	self:assertNotStringContains('mbox-med', html, true)
end

function suite:testLegacyMboxAcceptsNoText()
	local html = mbox._mbox('Head', nil, { icon = 'WikimediaUI-Code.svg' })
	self:assertStringContains('role="note"', html, true)
end

function suite:testSplitLegacyClasses()
	local boxType, classes = mbox._internal.splitLegacyClasses('mbox-high foo')
	self:assertEquals('error', boxType)
	self:assertEquals('foo', classes)
	boxType, classes = mbox._internal.splitLegacyClasses(nil)
	self:assertEquals(nil, boxType)
	self:assertEquals(nil, classes)
end

return suite
