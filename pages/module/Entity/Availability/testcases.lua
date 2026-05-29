require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Availability = require('Module:Entity/Availability')

local suite = ScribuntoUnit:new()

-- isCommodity()

function suite:testIsCommodityTrueWithBoxSizes()
	self:assertEquals(true, Availability._internal.isCommodity({ box_sizes_scu = { 1, 2 } }))
end

function suite:testIsCommodityFalseForItem()
	self:assertEquals(false, Availability._internal.isCommodity({ uuid = 'x' }))
end

function suite:testIsCommodityFalseForVehicle()
	self:assertEquals(false, Availability._internal.isCommodity({ is_vehicle = true }))
end

function suite:testIsCommodityNilSafe()
	self:assertEquals(false, Availability._internal.isCommodity(nil))
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
	local groups = Availability._internal.groupBySystem(locs)
	self:assertEquals('Stanton System', groups[1].system)
	self:assertEquals(2, #groups[1].rows)
	self:assertEquals('ARC L3', groups[1].rows[1].body)
	self:assertEquals('245–1000', groups[1].rows[1].quality)
	self:assertEquals('Pyro System', groups[2].system)
end

function suite:testGroupBySystemEmpty()
	self:assertEquals(0, #Availability._internal.groupBySystem(nil))
end

-- buildCommoditySummaryRows()

function suite:testCommoditySummaryMineableHarvestable()
	local apiData = {
		box_sizes_scu = { 1, 2 },
		_rawRecord = { is_mineable = true, has_harvestables = false },
	}
	local rows = Availability._internal.buildCommoditySummaryRows({}, apiData)
	local function value(label)
		for _, r in ipairs(rows) do
			if r.label == label then
				return r.value
			end
		end
	end
	self:assertEquals(true, value('Mine'))
	self:assertEquals(false, value('Harvest'))
	-- No UEX purchase data → Buy is unknown (nil).
	self:assertEquals(nil, value('Buy'))
end

return suite
