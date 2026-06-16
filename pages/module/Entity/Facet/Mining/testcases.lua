require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Mining = require('Module:Entity/Facet/Mining')

local suite = ScribuntoUnit:new()

local function findItem(items, label)
	for _, it in ipairs(items or {}) do
		if it.label == label then
			return it
		end
	end
	return nil
end

-- The Brandt: a vehicle active module — power +35%, resistance +15.5%, shatter -30%.
local function brandtData()
	return {
		size = 1,
		mining_modifier = {
			type = 'Active',
			charges = 5,
			duration = 60,
			power_modifier = 0.35,
			modifier_map = { resistance = 15.5, shatter_damage = -30 },
		},
	}
end

-- BoreMax: an FPS mining gadget — same block shape, passive, numeric modifiers.
local function boreMaxData()
	return {
		sub_type = 'Gadget',
		mining_modifier = {
			type = 'Passive',
			item_type = 'Gadget',
			charges = nil,
			duration = nil,
			power_modifier = nil,
			modifier_map = { resistance = 10, laser_instability = -70, cluster_factor = 30 },
		},
	}
end

function suite:testMatches()
	self:assertEquals(true, Mining.matches(brandtData()))
	self:assertEquals(true, Mining.matches(boreMaxData()))
	self:assertEquals(false, Mining.matches({}))
	self:assertEquals(false, Mining.matches(nil))
end

function suite:testActiveRows()
	local sections = Mining.getSections(brandtData(), {})
	self:assertEquals(1, #sections)
	self:assertEquals('mining', sections[1].key)
	self:assertEquals('Mining', sections[1].label)
	self:assertEquals('Active', findItem(sections[1].items, 'Type').content)
	-- 0.35 * 100 rounds cleanly to +35%; a positive power bonus is coloured green.
	local power = findItem(sections[1].items, 'Power').content
	self:assertStringContains('+35%', power, true)
	self:assertStringContains('--color-success', power, true)
	self:assertEquals('5', findItem(sections[1].items, 'Charges').content)
	self:assertEquals('60 s', findItem(sections[1].items, 'Duration').content)
	self:assertEquals('+15.5%', findItem(sections[1].items, 'Resistance').content)
	-- format.formatNum renders negatives with a typographic minus (U+2212).
	self:assertEquals('−30%', findItem(sections[1].items, 'Shatter damage').content)
end

-- FPS mining gadget: passive, no charges/duration/power; only modifier effects.
function suite:testGadgetPassive()
	local sections = Mining.getSections(boreMaxData(), {})
	self:assertEquals('Passive', findItem(sections[1].items, 'Type').content)
	self:assertEquals(nil, findItem(sections[1].items, 'Power'))
	self:assertEquals(nil, findItem(sections[1].items, 'Charges'))
	self:assertEquals('+10%', findItem(sections[1].items, 'Resistance').content)
	self:assertEquals('−70%', findItem(sections[1].items, 'Laser instability').content)
	self:assertEquals('+30%', findItem(sections[1].items, 'Cluster factor').content)
end

function suite:testEmptyWhenNoBlock()
	self:assertEquals(0, #Mining.getSections({}, {}))
end

function suite:testStructuredData()
	local data = Mining.getStructuredData(brandtData())
	self:assertEquals('Active', data.mining_type)
	self:assertEquals(35, data.power_modifier)
	self:assertEquals(5, data.charges)
	self:assertEquals(60, data.duration)
	-- Each modifier_map effect becomes a numeric "Modifier <effect>" facet.
	self:assertEquals(15.5, data.modifier_resistance)
	self:assertEquals(-30, data.modifier_shatter_damage)
end

-- The API sometimes hands a modifier value as a string with a percent sign
-- ("-80%") rather than a number; it must still render and store as -80.
function suite:testStringPercentValue()
	local apiData = {
		mining_modifier = {
			type = 'Active',
			power_modifier = -0.15,
			modifier_map = { overcharge_rate = '-80%' },
		},
	}
	local sections = Mining.getSections(apiData, {})
	self:assertEquals('−80%', findItem(sections[1].items, 'Overcharge rate').content)
	-- A negative power penalty is coloured red.
	local power = findItem(sections[1].items, 'Power').content
	self:assertStringContains('−15%', power, true)
	self:assertStringContains('--color-destructive', power, true)
	self:assertEquals(-80, Mining.getStructuredData(apiData).modifier_overcharge_rate)
end

-- Charges 0 / duration null are gated out of structured data.
function suite:testPassiveStructuredData()
	local data = Mining.getStructuredData({
		mining_modifier = {
			type = 'Passive',
			charges = 0,
			duration = nil,
			power_modifier = 0,
			modifier_map = { inert_materials = 5 },
		},
	})
	self:assertEquals('Passive', data.mining_type)
	self:assertEquals(0, data.power_modifier)
	self:assertEquals(nil, data.charges)
	self:assertEquals(nil, data.duration)
	self:assertEquals(5, data.modifier_inert_materials)
end

return suite
