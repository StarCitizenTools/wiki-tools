require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Locations = require('Module:Entity/Commodity/Locations')

local suite = ScribuntoUnit:new()

function suite:testGroupBySystemNormalizesAndOrders()
	local locs = {
		{
			system = 'Stanton System',
			display_name = 'ARC L3',
			type = 'Asteroid',
			relative_probability_percent = 28.5,
			quality_min = 245,
			quality_max = 1000,
		},
		{
			system = 'Pyro System',
			display_name = 'Pyro V',
			type = 'Planet',
			relative_probability_percent = 10,
			quality_min = 300,
			quality_max = 900,
		},
		{
			system = 'Stanton System',
			display_name = 'Yela',
			type = 'Moon',
			relative_probability_percent = 5,
			quality_min = 200,
			quality_max = 800,
		},
	}
	local groups = Locations._internal.groupBySystem(locs)
	self:assertEquals('Stanton System', groups[1].system)
	self:assertEquals(2, #groups[1].rows)
	self:assertEquals('ARC L3', groups[1].rows[1].body)
	self:assertEquals('245–1000', groups[1].rows[1].quality)
	self:assertEquals('Pyro System', groups[2].system)
end

function suite:testGroupBySystemEmpty()
	self:assertEquals(0, #Locations._internal.groupBySystem(nil))
end

return suite
