require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Cooler = require('Module:Entity/Item/Cooler')
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

function suite:testCoolingRow()
	local sections = Cooler.getSections({ cooler = { coolant_segment_generation = 46 } }, {})
	self:assertEquals(1, #sections)
	self:assertEquals('cooler', sections[1].key)
	self:assertEquals('46', findItem(sections[1].items, 'Cooling').content)
	self:assertEquals(nil, findItem(sections[1].items, 'Cooling rate'))
end

function suite:testCoolingRateShownWhenPresent()
	local sections = Cooler.getSections({ cooler = { cooling_rate = 1500, coolant_segment_generation = 46 } }, {})
	self:assertEquals('1,500', findItem(sections[1].items, 'Cooling rate').content)
end

function suite:testEmptyWhenNoBlock()
	self:assertEquals(0, #Cooler.getSections({}, {}))
end

function suite:testStructuredData()
	local data = Cooler.getStructuredData({ cooler = { coolant_segment_generation = 46 } })
	self:assertEquals(46, data.coolant_generation)
end

function suite:testResolveSubtypeReturnsCooler()
	self:assertEquals(Cooler, Item.resolveSubtype({ type = 'Cooler' }))
end

return suite
