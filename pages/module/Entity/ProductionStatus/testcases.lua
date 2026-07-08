require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local ProductionStatus = require('Module:Entity/ProductionStatus')

local suite = ScribuntoUnit:new()
local resolve = ProductionStatus._internal.resolve

function suite:testResolveApiHyphenated()
	self:assertEquals('Flight ready', resolve('flight-ready').label)
end

function suite:testResolveEditorialSpaced()
	self:assertEquals('Flight ready', resolve('Flight ready').label)
end

function suite:testResolveInConcept()
	self:assertEquals('In concept', resolve('In concept').label)
end

function suite:testResolveUnknown()
	self:assertEquals(nil, resolve('made up'))
end

function suite:testResolveNil()
	self:assertEquals(nil, resolve(nil))
end

function suite:testBadgeNilOnUnknown()
	self:assertEquals(nil, ProductionStatus.badge('made up'))
	self:assertEquals(nil, ProductionStatus.badge(nil))
end

function suite:testKeyNormalizesApiAndEditorialForms()
	self:assertEquals('flightready', ProductionStatus.key('flight-ready'))
	self:assertEquals('flightready', ProductionStatus.key('Flight ready'))
end

function suite:testKeyNilOnEmpty()
	self:assertEquals(nil, ProductionStatus.key(nil))
	self:assertEquals(nil, ProductionStatus.key(''))
end

function suite:testResolveAllStates()
	self:assertEquals('Active production', resolve('active-production').label)
	self:assertEquals('Active for Squadron 42', resolve('active-for-squadron-42').label)
	self:assertEquals('Long term production', resolve('long-term-production').label)
	self:assertEquals('In concept', resolve('in-concept').label)
	self:assertEquals('Lore-only', resolve('in-lore').label)
end

function suite:testLoreOnlyAliasAndLabel()
	-- Legacy "In lore" and canonical "Lore-only" resolve to the same tier/label
	-- and normalize to the same canonical key.
	self:assertEquals('Lore-only', resolve('In lore').label)
	self:assertEquals('Lore-only', resolve('Lore-only').label)
	self:assertEquals('loreonly', ProductionStatus.key('In lore'))
	self:assertEquals('loreonly', ProductionStatus.key('Lore-only'))
end

function suite:testDriveReadyIsNotAState()
	self:assertEquals(nil, resolve('drive-ready'))
end

function suite:testBadgeForNewState()
	self:assertEquals(true, type(ProductionStatus.badge('in-concept')) == 'string')
end

function suite:testLabelFlightReady()
	self:assertEquals('Flight ready', ProductionStatus.label('flight-ready'))
end

function suite:testLabelUnknown()
	self:assertEquals(nil, ProductionStatus.label('made up'))
end

function suite:testLabelNil()
	self:assertEquals(nil, ProductionStatus.label(nil))
end

return suite
