require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Development = require('Module:Entity/Vehicle/Development')
local Editorial = require('Module:Entity/Editorial')

local suite = ScribuntoUnit:new()
local patchRow = Development._internal.patchRow

function suite:testPatchRowLinksUpdatePage()
	self:assertEquals('[[Update:Star Citizen Alpha 4.8.0|Alpha 4.8.0]]', patchRow('Update:Star Citizen Alpha 4.8.0'))
end

function suite:testPatchRowIrregularPage()
	self:assertEquals('[[Update:Star Citizen Patch V0.8.5|Patch V0.8.5]]', patchRow('Update:Star Citizen Patch V0.8.5'))
end

function suite:testPatchRowNilEmpty()
	self:assertEquals(nil, patchRow(nil))
	self:assertEquals(nil, patchRow(''))
end

function suite:testBuildNilWhenNoMilestones()
	self:assertEquals(nil, Development.build({}, {}, Editorial.view({})))
end

function suite:testBuildNonNilWithFlightReadyOnly()
	local ed =
		Editorial.view({ flight_ready_version = { value = 'Update:Star Citizen Alpha 4.8.0', source = 'editorial' } })
	self:assertEquals(false, Development.build({}, {}, ed) == nil)
end

return suite
