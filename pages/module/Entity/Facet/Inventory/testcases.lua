require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Inventory = require('Module:Entity/Facet/Inventory')

local suite = ScribuntoUnit:new()

-- A torso armor with a 10,500 µSCU pocket.
local function torsoData()
	return {
		inventory = { scu = 0.0105, scu_converted = 10500, unit = 'µSCU' },
	}
end

function suite:testMatches()
	self:assertEquals(true, Inventory.matches(torsoData()))
	self:assertEquals(false, Inventory.matches({}))
	self:assertEquals(false, Inventory.matches(nil))
	-- An inventory block with no usable capacity does not fire.
	self:assertEquals(false, Inventory.matches({ inventory = { scu_converted = 0 } }))
end

function suite:testRow()
	local sections = Inventory.getSections(torsoData(), {})
	self:assertEquals(1, #sections)
	self:assertEquals('inventory', sections[1].key)
	self:assertEquals('Storage', sections[1].label)
	self:assertEquals('10,500 µSCU', sections[1].items[1].content)
	self:assertEquals('Storage capacity', sections[1].items[1].label)
end

function suite:testEmptyWhenNoCapacity()
	self:assertEquals(0, #Inventory.getSections({ inventory = { scu_converted = 0 } }, {}))
	self:assertEquals(0, #Inventory.getSections({}, {}))
end

function suite:testStructuredData()
	self:assertEquals(10500, Inventory.getStructuredData(torsoData()).storage_capacity)
	self:assertEquals(nil, Inventory.getStructuredData({}).storage_capacity)
end

return suite
