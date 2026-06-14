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

function suite:testTemperatureRange()
	-- Positive band: plain digits, em dash (U+2014) separator.
	self:assertEquals('2 °C — 30 °C', Environment._internal.formatTemperature({ min = 2, max = 30 }))
	-- Negative band: typographic minus (U+2212) on the lower bound.
	self:assertEquals('−75 °C — 105 °C', Environment._internal.formatTemperature({ min = -75, max = 105 }))
end

function suite:testTemperatureFallbackKeys()
	-- minimum/maximum are read when min/max are absent.
	self:assertEquals('2 °C — 30 °C', Environment._internal.formatTemperature({ minimum = 2, maximum = 30 }))
end

function suite:testTemperatureZeroZeroGated()
	-- A 0–0 band is a meaningless "no thermal rating" and collapses.
	self:assertEquals(nil, Environment._internal.formatTemperature({ min = 0, max = 0 }))
	self:assertEquals(nil, Environment._internal.formatTemperature(nil))
	self:assertEquals(nil, Environment._internal.formatTemperature({}))
end

function suite:testArmorRows()
	local sections = Environment.getSections(armorData(), {})
	self:assertEquals(1, #sections)
	self:assertEquals('environment', sections[1].key)
	self:assertEquals('Environment', sections[1].label)
	self:assertEquals('−75 °C — 105 °C', findItem(sections[1].items, 'Temperature').content)
	self:assertEquals('26,800', findItem(sections[1].items, 'Radiation capacity').content)
	self:assertEquals('145.8', findItem(sections[1].items, 'Radiation dissipation').content)
	self:assertEquals('−0.5', findItem(sections[1].items, 'G-force resistance').content)
end

function suite:testClothingRowsGated()
	-- A jacket has zero radiation / g-force, so only the temperature row shows.
	local sections = Environment.getSections(jacketData(), {})
	self:assertEquals('2 °C — 30 °C', findItem(sections[1].items, 'Temperature').content)
	self:assertEquals(nil, findItem(sections[1].items, 'Radiation capacity'))
	self:assertEquals(nil, findItem(sections[1].items, 'Radiation dissipation'))
	self:assertEquals(nil, findItem(sections[1].items, 'G-force resistance'))
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
