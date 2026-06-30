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

function suite:testApplySignatureModifierScalesRaw()
	self:assertEquals(600, Util.applySignatureModifier(1000, 0.6))
	self:assertEquals(1130, Util.applySignatureModifier(1000, 1.13))
end

function suite:testApplySignatureModifierMissingMultiplierIsNoChange()
	self:assertEquals(1000, Util.applySignatureModifier(1000, nil))
	self:assertEquals(1000, Util.applySignatureModifier(1000, 'not a number'))
end

function suite:testApplySignatureModifierNilRawStaysNil()
	self:assertEquals(nil, Util.applySignatureModifier(nil, 0.6))
end

function suite:testEffectiveIrEmission()
	self:assertEquals(600, Util.effectiveIrEmission({ emission = { ir = 1000 }, armor = { signal_infrared = 0.6 } }))
	-- No armor multiplier → raw passes through unchanged.
	self:assertEquals(1000, Util.effectiveIrEmission({ emission = { ir = 1000 } }))
	-- No emission → nil (the row/score component is omitted).
	self:assertEquals(nil, Util.effectiveIrEmission({ armor = { signal_infrared = 0.6 } }))
end

function suite:testEffectiveEmEmission()
	self:assertEquals(
		1000,
		Util.effectiveEmEmission({ emission = { em_max = 2000 }, armor = { signal_electromagnetic = 0.5 } })
	)
	self:assertEquals(nil, Util.effectiveEmEmission({ emission = {} }))
end

function suite:testEffectiveCrossSection()
	-- mean(100, 200, 300) = 200; × 0.6 = 120.
	self:assertEquals(
		120,
		Util.effectiveCrossSection({
			cross_section = { length = 100, width = 200, height = 300 },
			armor = { signal_cross_section = 0.6 },
		})
	)
	self:assertEquals(nil, Util.effectiveCrossSection({ armor = { signal_cross_section = 0.6 } }))
end

return suite
