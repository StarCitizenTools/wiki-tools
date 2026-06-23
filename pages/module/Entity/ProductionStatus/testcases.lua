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

return suite
