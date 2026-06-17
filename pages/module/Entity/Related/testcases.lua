require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Related = require('Module:Entity/Related')

local suite = ScribuntoUnit:new()

-- buildCargoRows()

function suite:testBuildCargoRowsMassFromDensity()
	local rows = Related._internal.buildCargoRows({ 1, 2 }, 2.3)
	self:assertEquals(1, rows[1].scu)
	self:assertEquals(2300, rows[1].mass_kg)
	self:assertEquals(4600, rows[2].mass_kg)
end

function suite:testBuildCargoRowsSortsAscending()
	local rows = Related._internal.buildCargoRows({ 8, 1, 4 }, 1)
	self:assertEquals(1, rows[1].scu)
	self:assertEquals(4, rows[2].scu)
	self:assertEquals(8, rows[3].scu)
end

function suite:testBuildCargoRowsEmpty()
	self:assertEquals(0, #Related._internal.buildCargoRows(nil, 1))
end

-- boxDimensions()

function suite:testBoxDimensionsStandardSizes()
	local d1 = Related._internal.boxDimensions(1)
	self:assertEquals(1.25, d1[1])
	self:assertEquals(1.25, d1[2])
	self:assertEquals(1.25, d1[3])
	local d32 = Related._internal.boxDimensions(32)
	self:assertEquals(10, d32[1])
	self:assertEquals(2.5, d32[2])
	self:assertEquals(2.5, d32[3])
end

-- 0.125 SCU is the smallest *standard* container (1/8 SCU box, 0.5 m cube),
-- added to BOX_DIMENSIONS when CIG introduced the 1/8 box line.
function suite:testBoxDimensionsEighthScuIsStandard()
	local d = Related._internal.boxDimensions(0.125)
	self:assertEquals(0.5, d[1])
	self:assertEquals(0.5, d[2])
	self:assertEquals(0.5, d[3])
end

-- A genuinely non-standard size (not a CIG cargo container) returns nil.
function suite:testBoxDimensionsNonStandardSizeReturnsNil()
	self:assertEquals(nil, Related._internal.boxDimensions(3))
end

return suite
