require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local MiningModule = require('Module:Entity/Item/MiningModule')
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

-- The Brandt: an active module, power +35%, resistance +15.5%, shatter -30%.
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

function suite:testActiveRows()
	local sections = MiningModule.getSections(brandtData(), {})
	self:assertEquals(1, #sections)
	self:assertEquals('mining_modifier', sections[1].key)
	self:assertEquals('Mining module', sections[1].label)
	self:assertEquals('Active', findItem(sections[1].items, 'Type').content)
	-- 0.35 * 100 rounds cleanly to +35%, not +34.9999%.
	self:assertEquals('+35%', findItem(sections[1].items, 'Power').content)
	self:assertEquals('5', findItem(sections[1].items, 'Charges').content)
	self:assertEquals('60 s', findItem(sections[1].items, 'Duration').content)
	self:assertEquals('+15.5%', findItem(sections[1].items, 'Resistance').content)
	self:assertEquals('-30%', findItem(sections[1].items, 'Shatter damage').content)
end

-- A passive module: no charges/duration; modifier_map keys auto-title.
function suite:testPassiveAndAutoTitle()
	local sections = MiningModule.getSections({
		mining_modifier = {
			type = 'Passive',
			power_modifier = 0.1,
			modifier_map = { optimal_charge_window_rate = 25 },
		},
	}, {})
	self:assertEquals('Passive', findItem(sections[1].items, 'Type').content)
	self:assertEquals('+10%', findItem(sections[1].items, 'Power').content)
	self:assertEquals(nil, findItem(sections[1].items, 'Charges'))
	self:assertEquals(nil, findItem(sections[1].items, 'Duration'))
	self:assertEquals('+25%', findItem(sections[1].items, 'Optimal charge window rate').content)
end

function suite:testEmptyWhenNoBlock()
	self:assertEquals(0, #MiningModule.getSections({}, {}))
end

function suite:testShortDescription()
	local desc = MiningModule.getShortDescription(
		brandtData(),
		{ manufacturer = 'Musashi Industrial and Starflight Concern' },
		{ name = 'Mining module' }
	)
	self:assertEquals('S1 mining module by Musashi Industrial and Starflight Concern', desc)
end

function suite:testStructuredData()
	local data = MiningModule.getStructuredData(brandtData())
	self:assertEquals('Active', data.mining_type)
	self:assertEquals(35, data.power_modifier)
	self:assertEquals(5, data.charges)
	self:assertEquals(60, data.duration)
end

function suite:testResolveSubtype()
	self:assertEquals(MiningModule, Item.resolveSubtype({ type = 'MiningModifier' }))
end

return suite
