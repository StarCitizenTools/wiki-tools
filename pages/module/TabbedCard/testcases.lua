require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local TabbedCard = require('Module:TabbedCard')

local suite = ScribuntoUnit:new()

function suite:testKeepsWellFormedTabsInOrder()
	local tabs = TabbedCard.resolveTabs({
		{ label = 'One', content = 'first' },
		{ label = 'Two', content = 'second' },
	})
	self:assertEquals(2, #tabs)
	self:assertEquals('One', tabs[1].label)
	self:assertEquals('second', tabs[2].content)
end

function suite:testDropsTabsMissingALabelOrContent()
	local tabs = TabbedCard.resolveTabs({
		{ label = 'Kept', content = 'body' },
		{ content = 'no label' },
		{ label = 'no content' },
		{ label = '', content = 'empty label' },
		{ label = 'empty content', content = '' },
	})
	self:assertEquals(1, #tabs)
	self:assertEquals('Kept', tabs[1].label)
end

function suite:testNoTabsResolvesToAnEmptyList()
	self:assertEquals(0, #TabbedCard.resolveTabs(nil))
	self:assertEquals(0, #TabbedCard.resolveTabs({}))
end

function suite:testContentIsStringifiedNotRequiredToBeAString()
	-- Callers hand over mw.html nodes; the tabber library needs strings.
	local tabs = TabbedCard.resolveTabs({ { label = 'N', content = 42 } })
	self:assertEquals('42', tabs[1].content)
end

return suite
