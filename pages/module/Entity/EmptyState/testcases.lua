require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local emptyState = require('Module:Entity/EmptyState')

local suite = ScribuntoUnit:new()

function suite:testNoneIsAQuietPlaceholder()
	local html = emptyState.none('No ports.')
	self:assertStringContains('t-mbox--placeholder', html, true)
	self:assertStringContains('No ports.', html, true)
	self:assertNotStringContains('t-mbox__icon', html, true)
	self:assertNotStringContains('t-mbox--warning', html, true)
end

function suite:testFailedIsAWarningWithTheAlertIcon()
	local html = emptyState.failed("Couldn't load ports.")
	self:assertStringContains('t-mbox--warning', html, true)
	self:assertStringContains('t-mbox__icon', html, true)
	self:assertStringContains("Couldn't load ports.", html, true)
	self:assertNotStringContains('t-mbox--placeholder', html, true)
end

return suite
