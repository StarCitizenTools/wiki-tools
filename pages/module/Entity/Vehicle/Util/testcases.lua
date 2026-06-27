require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Util = require('Module:Entity/Vehicle/Util')

local suite = ScribuntoUnit:new()

function suite:testResolveCareerArgWinsOverApi()
	self:assertEquals('Transport', Util.resolveCareer({ career = 'Transporter' }, { career = 'Transport' }))
end

function suite:testResolveCareerFallsBackToApi()
	self:assertEquals('Combat', Util.resolveCareer({ career = 'Combat' }, {}))
end

function suite:testResolveCareerNilWhenNeither()
	self:assertEquals(nil, Util.resolveCareer({}, {}))
	self:assertEquals(nil, Util.resolveCareer({ career = '' }, {}))
end

function suite:testMatrixSizeArgWinsOverApi()
	self:assertEquals('Large', Util.matrixSize({ size = 'medium' }, { size = 'Large' }))
end

function suite:testMatrixSizeFallsBackToApi()
	self:assertEquals('medium', Util.matrixSize({ size = 'medium' }, {}))
end

function suite:testMatrixSizeNilWhenNeither()
	self:assertEquals(nil, Util.matrixSize({}, {}))
end

function suite:testDamageTypesOrderAndKeys()
	self:assertEquals('damage_physical', Util.DAMAGE_TYPES[1].key)
	self:assertEquals('PHY', Util.DAMAGE_TYPES[1].abbr)
	self:assertEquals('damage_distortion', Util.DAMAGE_TYPES[3].key) -- distortion before thermal
	self:assertEquals(6, #Util.DAMAGE_TYPES)
end

function suite:testMeanDeflectionMeansPhysicalAndEnergy()
	self:assertEquals(10, Util.meanDeflection({ deflection = { physical = 11, energy = 9 } }))
end

function suite:testMeanDeflectionIgnoresOtherDamageTypes()
	self:assertEquals(500, Util.meanDeflection({ deflection = { physical = 600, energy = 400, thermal = 0 } }))
end

function suite:testMeanDeflectionNilWhenAbsent()
	self:assertEquals(nil, Util.meanDeflection(nil))
	self:assertEquals(nil, Util.meanDeflection({}))
	self:assertEquals(nil, Util.meanDeflection({ deflection = {} }))
end

return suite
