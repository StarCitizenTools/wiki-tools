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

function suite:testNumLabel()
	-- Temperature value parts: bare value, no unit; typographic minus on negatives.
	self:assertEquals('−77', Environment._internal.numLabel(-77))
	self:assertEquals('107', Environment._internal.numLabel(107))
	self:assertEquals('0', Environment._internal.numLabel(0))
end

function suite:testGforceLabel()
	-- Positive (a bonus): explicit + sign, coloured success.
	local pos = Environment._internal.gforceLabel(1)
	self:assertEquals(true, mw.ustring.find(pos, '+1', 1, true) ~= nil)
	self:assertEquals(true, mw.ustring.find(pos, 'color-success', 1, true) ~= nil)
	-- Negative (a high-g penalty): typographic minus, coloured destructive.
	local neg = Environment._internal.gforceLabel(-0.5)
	self:assertEquals(true, mw.ustring.find(neg, '−0.5', 1, true) ~= nil)
	self:assertEquals(true, mw.ustring.find(neg, 'color-destructive', 1, true) ~= nil)
end

function suite:testArmorRows()
	local sections = Environment.getSections(armorData(), {})
	self:assertEquals(1, #sections)
	self:assertEquals('environment', sections[1].key)
	self:assertEquals('Environment', sections[1].label)
	local its = sections[1].items
	-- Temperature + radiation capacity + radiation dissipation + g-force = 4 items,
	-- each bar its own item.
	self:assertEquals(4, #its)
	-- The first three are full-width, label-less graph items (bars).
	self:assertEquals('t-infobox-item--block', its[1].class)
	self:assertEquals('string', type(its[1].content))
	self:assertEquals('t-infobox-item--block', its[2].class)
	self:assertEquals('t-infobox-item--block', its[3].class)
	-- G resistance is a plain labelled row (signed, value coloured when negative).
	self:assertEquals('string', type(findItem(its, 'G resistance').content))
end

function suite:testClothingRowsGated()
	-- A jacket has zero radiation / g-force, so only the temperature bar item shows.
	local sections = Environment.getSections(jacketData(), {})
	self:assertEquals(1, #sections[1].items)
	self:assertEquals('t-infobox-item--block', sections[1].items[1].class)
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
