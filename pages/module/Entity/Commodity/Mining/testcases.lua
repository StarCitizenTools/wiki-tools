require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Mining = require('Module:Entity/Commodity/Mining')

local suite = ScribuntoUnit:new()

function suite:testAcquisitionLabelShipMining()
	self:assertEquals('Ship mining', Mining.acquisitionLabel({ methods = { 'Ship' } }, 'mineable'))
end

function suite:testAcquisitionLabelGroundVehicleMapsToVehicle()
	self:assertEquals('Vehicle mining', Mining.acquisitionLabel({ methods = { 'Ground Vehicle' } }, 'mineable'))
end

function suite:testAcquisitionLabelHarvestableDropsRedundantToken()
	self:assertEquals('Harvesting', Mining.acquisitionLabel({ methods = { 'Harvestable' } }, 'harvestable'))
end

function suite:testAcquisitionLabelJoinsMultipleMethods()
	self:assertEquals('Ship, FPS mining', Mining.acquisitionLabel({ methods = { 'Ship', 'FPS' } }, 'mineable'))
end

function suite:testAcquisitionLabelRemainsReturnsNil()
	self:assertEquals(nil, Mining.acquisitionLabel({ methods = { 'Ship' } }, 'remains'))
end

function suite:testIsLaserMiningShipTrue()
	self:assertEquals(true, Mining.isLaserMining({ methods = { 'Ship' } }))
end

function suite:testIsLaserMiningGroundVehicleTrue()
	self:assertEquals(true, Mining.isLaserMining({ methods = { 'Ground Vehicle' } }))
end

function suite:testIsLaserMiningFpsFalse()
	self:assertEquals(false, Mining.isLaserMining({ methods = { 'FPS' } }))
end

function suite:testQualityRangeSpansLocations()
	local raw = { locations = { { quality_min = 245, quality_max = 1000 }, { quality_min = 300, quality_max = 980 } } }
	self:assertEquals('245–1000', Mining.qualityRange(raw))
end

function suite:testQualityRangeNilWhenNoLocations()
	self:assertEquals(nil, Mining.qualityRange({ locations = {} }))
	self:assertEquals(nil, Mining.qualityRange(nil))
end

-- groupBySystem()

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
	local groups = Mining.groupBySystem(locs)
	self:assertEquals('Stanton System', groups[1].system)
	self:assertEquals(2, #groups[1].rows)
	self:assertEquals('ARC L3', groups[1].rows[1].body)
	self:assertEquals('245–1000', groups[1].rows[1].quality)
	self:assertEquals('Pyro System', groups[2].system)
end

function suite:testGroupBySystemEmpty()
	self:assertEquals(0, #Mining.groupBySystem(nil))
end

return suite
