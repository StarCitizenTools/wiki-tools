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

local function labels(items)
	local out = {}
	for _, it in ipairs(items or {}) do
		out[#out + 1] = it.label
	end
	return table.concat(out, ', ')
end

-- The Brandt: a vehicle active module — mining power +35%, resistance +15.5%,
-- shatter -30%. description_data carries the card's absolute "135%".
local function brandtData()
	return {
		size = 1,
		description_data = { { name = 'Mining Laser Power', value = '135%' } },
		weapon_modifier = { damage_multiplier = 1.35 },
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
	-- The card's "135%" becomes a +35% delta, under the beam it actually names.
	local power = findItem(sections[1].items, 'Mining laser power').content
	self:assertStringContains('+35%', power, true)
	self:assertStringContains('--color-success', power, true)
	self:assertEquals(nil, findItem(sections[1].items, 'Power'))
	self:assertEquals('5', findItem(sections[1].items, 'Charges').content)
	self:assertEquals('60 s', findItem(sections[1].items, 'Duration').content)
	-- Resistance is a penalty, so positive is red; shatter damage likewise, so its
	-- negative is green. format.formatNum renders negatives with U+2212.
	local resistance = findItem(sections[1].items, 'Resistance').content
	self:assertStringContains('+15.5%', resistance, true)
	self:assertStringContains('--color-destructive', resistance, true)
	local shatter = findItem(sections[1].items, 'Shatter damage').content
	self:assertStringContains('−30%', shatter, true)
	self:assertStringContains('--color-success', shatter, true)
end

-- MODIFIER_EFFECTS order, not alphabetical.
function suite:testEffectOrder()
	local sections = Mining.getSections(boreMaxData(), {})
	self:assertEquals('Type, Instability, Resistance, Cluster factor', labels(sections[1].items))
end

-- The FLTR shape: one game value arriving twice collapses to a single negated row,
-- reproducing the item card's "Inert Material Level: -20%" from the API's +20.
function suite:testFilterCollapsesToOneNegatedRow()
	local sections = Mining.getSections({
		mining_modifier = {
			type = 'Passive',
			modifier_map = { all_charge_rates = 20, inert_materials = 20 },
		},
	}, {})
	self:assertEquals('Type, Inert material level', labels(sections[1].items))
	local inert = findItem(sections[1].items, 'Inert material level').content
	self:assertStringContains('−20%', inert, true)
	self:assertStringContains('--color-success', inert, true)
	-- Neither API key becomes a row of its own.
	self:assertEquals(nil, findItem(sections[1].items, 'Inert materials'))
	self:assertEquals(nil, findItem(sections[1].items, 'All charge rates'))
end

-- An effect the API adds later still renders, auto-titled and uncoloured.
function suite:testUnknownEffectStillRenders()
	local sections = Mining.getSections({
		mining_modifier = {
			type = 'Passive',
			modifier_map = { warp_factor = -12.5, resistance = 10 },
		},
	}, {})
	self:assertEquals('Type, Resistance, Warp factor', labels(sections[1].items))
	self:assertEquals('−12.5%', findItem(sections[1].items, 'Warp factor').content)
end

-- FPS mining gadget: passive, no charges/duration/power; only modifier effects.
function suite:testGadgetPassive()
	local sections = Mining.getSections(boreMaxData(), {})
	self:assertEquals('Passive', findItem(sections[1].items, 'Type').content)
	self:assertEquals(nil, findItem(sections[1].items, 'Power'))
	self:assertEquals(nil, findItem(sections[1].items, 'Charges'))
	local resistance = findItem(sections[1].items, 'Resistance').content
	self:assertStringContains('+10%', resistance, true)
	self:assertStringContains('--color-destructive', resistance, true)
	-- laser_instability renders under the game's label, "Instability".
	self:assertEquals(nil, findItem(sections[1].items, 'Laser instability'))
	local instability = findItem(sections[1].items, 'Instability').content
	self:assertStringContains('−70%', instability, true)
	self:assertStringContains('--color-success', instability, true)
	local cluster = findItem(sections[1].items, 'Cluster factor').content
	self:assertStringContains('+30%', cluster, true)
	self:assertStringContains('--color-success', cluster, true)
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
	local overcharge = findItem(sections[1].items, 'Overcharge rate').content
	self:assertStringContains('−80%', overcharge, true)
	self:assertStringContains('--color-success', overcharge, true)
	self:assertEquals(-80, Mining.getStructuredData(apiData).modifier_overcharge_rate)
end

-- Stampede: the card names both beams, and the API's single power_modifier (+0.35)
-- can only carry one. Both rows render.
function suite:testBothPowerBeams()
	local sections = Mining.getSections({
		description_data = {
			{ name = 'Mining Laser Power', value = '135%' },
			{ name = 'Extraction Laser Power', value = '85%' },
		},
		weapon_modifier = { damage_multiplier = 1.35 },
		mining_modifier = { type = 'Active', power_modifier = 0.35, modifier_map = {} },
	}, {})
	local mining = findItem(sections[1].items, 'Mining laser power').content
	self:assertStringContains('+35%', mining, true)
	self:assertStringContains('--color-success', mining, true)
	local extraction = findItem(sections[1].items, 'Extraction laser power').content
	self:assertStringContains('−15%', extraction, true)
	self:assertStringContains('--color-destructive', extraction, true)
end

-- Deluge / Clearcut / Overrun get an empty description_data, and a null
-- power_modifier. damage_multiplier is always the fracture beam, so it fills in the
-- mining figure that would otherwise be lost.
function suite:testPowerFallsBackToDamageMultiplier()
	local sections = Mining.getSections({
		description_data = {},
		weapon_modifier = { damage_multiplier = 1.15 },
		mining_modifier = { type = 'Passive', power_modifier = nil, modifier_map = { resistance = -15.5 } },
	}, {})
	local mining = findItem(sections[1].items, 'Mining laser power').content
	self:assertStringContains('+15%', mining, true)
	self:assertEquals(nil, findItem(sections[1].items, 'Extraction laser power'))
end

-- A no-op multiplier is not a stat; the ROC Module's old "+0%" row goes away.
function suite:testNoPowerRowWhenNeutral()
	local sections = Mining.getSections({
		description_data = {},
		weapon_modifier = { damage_multiplier = 1 },
		mining_modifier = { type = 'Passive', power_modifier = 0, modifier_map = { resistance = 5 } },
	}, {})
	self:assertEquals(nil, findItem(sections[1].items, 'Mining laser power'))
	self:assertEquals(nil, findItem(sections[1].items, 'Power'))
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
