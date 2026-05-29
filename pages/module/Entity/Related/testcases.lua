require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Related = require('Module:Entity/Related')

local suite = ScribuntoUnit:new()

-- isCommodity()

function suite:testIsCommodityTrueWithBoxSizes()
	self:assertEquals(true, Related._internal.isCommodity({ box_sizes_scu = { 1, 2 } }))
end

function suite:testIsCommodityFalseForItem()
	self:assertEquals(false, Related._internal.isCommodity({ uuid = 'x', related_items = {} }))
end

function suite:testIsCommodityNilSafe()
	self:assertEquals(false, Related._internal.isCommodity(nil))
end

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

return suite
