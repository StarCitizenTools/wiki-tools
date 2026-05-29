require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Variants = require('Module:Entity/Commodity/Variants')

local suite = ScribuntoUnit:new()

function suite:testBuildRowsMassFromDensity()
	local rows = Variants._internal.buildRows({ 1, 2 }, 2.3)
	self:assertEquals(1, rows[1].scu)
	self:assertEquals(2300, rows[1].mass_kg)
	self:assertEquals(4600, rows[2].mass_kg)
end

function suite:testBuildRowsSortsAscending()
	local rows = Variants._internal.buildRows({ 8, 1, 4 }, 1)
	self:assertEquals(1, rows[1].scu)
	self:assertEquals(4, rows[2].scu)
	self:assertEquals(8, rows[3].scu)
end

function suite:testBuildRowsEmpty()
	self:assertEquals(0, #Variants._internal.buildRows(nil, 1))
end

return suite
