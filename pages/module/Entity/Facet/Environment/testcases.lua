require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Environment = require('Module:Entity/Facet/Environment')

local suite = ScribuntoUnit:new()

local function findItem(items, label)
	for _, it in ipairs(items or {}) do
		if it.label == label then
			return it
		end
	end
	return nil
end

-- A heavy armor torso: wide temperature band, real radiation protection, and a
-- g-force modifier.
local function armorData()
	return {
		temperature_resistance = { min = -75, max = 105, minimum = -75, maximum = 105 },
		radiation_resistance = { maximum_radiation_capacity = 26800, radiation_dissipation_rate = 145.8 },
		gforce_resistance = -0.5,
	}
end

-- A jacket: a modest temperature band, no radiation, no g-force.
local function jacketData()
	return {
		temperature_resistance = { min = 2, max = 30, minimum = 2, maximum = 30 },
		radiation_resistance = { maximum_radiation_capacity = 0, radiation_dissipation_rate = 0 },
		gforce_resistance = 0,
	}
end

function suite:testMatches()
	self:assertEquals(true, Environment.matches(armorData()))
	self:assertEquals(true, Environment.matches(jacketData()))
	self:assertEquals(false, Environment.matches({}))
	self:assertEquals(false, Environment.matches(nil))
end

function suite:testTemperatureBounds()
	-- Positive band.
	local min, max = Environment._internal.temperatureBounds({ min = 2, max = 30 })
	self:assertEquals(2, min)
	self:assertEquals(30, max)
	-- Negative band.
	min, max = Environment._internal.temperatureBounds({ min = -75, max = 105 })
	self:assertEquals(-75, min)
	self:assertEquals(105, max)
end

function suite:testTemperatureBoundsFallbackKeys()
	-- minimum/maximum are read when min/max are absent.
	local min, max = Environment._internal.temperatureBounds({ minimum = 2, maximum = 30 })
	self:assertEquals(2, min)
	self:assertEquals(30, max)
end

function suite:testTemperatureBoundsGated()
	-- A 0–0 band is a meaningless "no thermal rating" and collapses; so does a
	-- missing block.
	self:assertEquals(nil, Environment._internal.temperatureBounds({ min = 0, max = 0 }))
	self:assertEquals(nil, Environment._internal.temperatureBounds(nil))
	self:assertEquals(nil, Environment._internal.temperatureBounds({}))
end

function suite:testDegreeLabel()
	-- Band-edge labels: typographic minus (U+2212) on negatives; °C unit.
	self:assertEquals('−77 °C', Environment._internal.degreeLabel(-77))
	self:assertEquals('107 °C', Environment._internal.degreeLabel(107))
	self:assertEquals('0 °C', Environment._internal.degreeLabel(0))
end

function suite:testNumLabel()
	-- Tick label: bare value, no unit; typographic minus on negatives.
	self:assertEquals('−77', Environment._internal.numLabel(-77))
	self:assertEquals('107', Environment._internal.numLabel(107))
	self:assertEquals('0', Environment._internal.numLabel(0))
end

function suite:testArmorRows()
	local sections = Environment.getSections(armorData(), {})
	self:assertEquals(1, #sections)
	self:assertEquals('environment', sections[1].key)
	self:assertEquals('Environment', sections[1].label)
	-- Temperature is now the section content (a bar), not a label:value item.
	self:assertEquals('string', type(sections[1].content))
	self:assertEquals(nil, findItem(sections[1].items, 'Temperature'))
	self:assertEquals('26,800', findItem(sections[1].items, 'Radiation capacity').content)
	self:assertEquals('145.8', findItem(sections[1].items, 'Radiation dissipation').content)
	self:assertEquals('−0.5', findItem(sections[1].items, 'G-force resistance').content)
end

function suite:testClothingRowsGated()
	-- A jacket has zero radiation / g-force, so only the temperature bar shows.
	local sections = Environment.getSections(jacketData(), {})
	self:assertEquals('string', type(sections[1].content))
	self:assertEquals(0, #sections[1].items)
end

function suite:testStructuredDataArmor()
	local data = Environment.getStructuredData(armorData())
	self:assertEquals(-75, data.minimum_temperature)
	self:assertEquals(105, data.maximum_temperature)
	self:assertEquals(26800, data.radiation_capacity)
	self:assertEquals(145.8, data.radiation_dissipation)
	self:assertEquals(-0.5, data.g_force_resistance)
end

function suite:testStructuredDataClothing()
	-- Clothing stores only the temperature bounds; zero radiation / g-force omitted.
	local data = Environment.getStructuredData(jacketData())
	self:assertEquals(2, data.minimum_temperature)
	self:assertEquals(30, data.maximum_temperature)
	self:assertEquals(nil, data.radiation_capacity)
	self:assertEquals(nil, data.radiation_dissipation)
	self:assertEquals(nil, data.g_force_resistance)
end

function suite:testEmptyWhenNoBlock()
	self:assertEquals(false, Environment.matches({ size = 1 }))
	self:assertEquals(0, #Environment.getSections({}, {}))
end

return suite
