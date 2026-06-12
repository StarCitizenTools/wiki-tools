require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local PowerPlant = require('Module:Entity/Item/PowerPlant')
local Item = require('Module:Entity/Item')

local suite = ScribuntoUnit:new()

local function findItem(items, label)
	for _, it in ipairs(items or {}) do
		if it.label == label then
			return it
		end
	end
	return nil
end

function suite:testPowerGenerationRow()
	local sections = PowerPlant.getSections({ power_plant = { power_segment_generation = 20 } }, {})
	self:assertEquals(1, #sections)
	self:assertEquals('power_plant', sections[1].key)
	self:assertEquals('20', findItem(sections[1].items, 'Power').content)
	self:assertEquals(nil, findItem(sections[1].items, 'Power output'))
end

function suite:testPowerOutputShownWhenPresent()
	local sections = PowerPlant.getSections(
		{ power_plant = { power_output = 1500, power_segment_generation = 20 } },
		{}
	)
	self:assertEquals('1,500', findItem(sections[1].items, 'Power output').content)
end

function suite:testEmptyWhenNoBlock()
	self:assertEquals(0, #PowerPlant.getSections({}, {}))
end

function suite:testStructuredData()
	local data = PowerPlant.getStructuredData({ power_plant = { power_segment_generation = 20 } })
	self:assertEquals(20, data.power_generation)
end

function suite:testResolveSubtypeReturnsPowerPlant()
	self:assertEquals(PowerPlant, Item.resolveSubtype({ type = 'PowerPlant' }))
end

return suite
