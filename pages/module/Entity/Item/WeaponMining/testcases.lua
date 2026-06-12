require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local WeaponMining = require('Module:Entity/Item/WeaponMining')
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

-- The Arbor MH1: laser power 94.5-1890, 1 module slot, 60/180 m range,
-- extraction 1850, with built-in effects.
local function arborData()
	return {
		size = 1,
		mining_laser = {
			laser_power = { min = 94.5, max = 1890 },
			module_slots = 1,
			optimal_range = 60,
			maximum_range = 180,
			extraction_throughput = 1850,
			modifier_map = {
				resistance = 25,
				laser_instability = -35,
				optimal_charge_window_size = 40,
			},
		},
	}
end

function suite:testRows()
	local sections = WeaponMining.getSections(arborData(), {})
	self:assertEquals(1, #sections)
	self:assertEquals('mining_laser', sections[1].key)
	self:assertEquals('Mining laser', sections[1].label)
	self:assertEquals('94.5 – 1,890', findItem(sections[1].items, 'Mining power').content)
	self:assertEquals('1', findItem(sections[1].items, 'Module slots').content)
	self:assertEquals('60 m', findItem(sections[1].items, 'Optimal range').content)
	self:assertEquals('180 m', findItem(sections[1].items, 'Maximum range').content)
	self:assertEquals('1,850', findItem(sections[1].items, 'Extraction rate').content)
	-- Built-in effects render like the modules (signed %, typographic minus).
	self:assertEquals('+25%', findItem(sections[1].items, 'Resistance').content)
	self:assertEquals('−35%', findItem(sections[1].items, 'Laser instability').content)
	self:assertEquals('+40%', findItem(sections[1].items, 'Optimal charge window size').content)
end

function suite:testEmptyWhenNoBlock()
	self:assertEquals(0, #WeaponMining.getSections({}, {}))
end

function suite:testShortDescription()
	local desc = WeaponMining.getShortDescription(
		arborData(),
		{ manufacturer = 'Greycat Industrial' },
		{ name = 'Mining laser head' }
	)
	-- formatShortDescription uses the manufacturer's short form (Greycat for GRIN).
	self:assertEquals('S1 mining laser head by Greycat', desc)
end

function suite:testStructuredData()
	local data = WeaponMining.getStructuredData(arborData())
	self:assertEquals(94.5, data.mining_power_min)
	self:assertEquals(1890, data.mining_power_max)
	self:assertEquals(1, data.module_slots)
	self:assertEquals(60, data.optimal_range)
	self:assertEquals(180, data.maximum_range)
	self:assertEquals(1850, data.extraction_throughput)
	self:assertEquals(25, data.modifier_resistance)
	self:assertEquals(-35, data.modifier_laser_instability)
end

function suite:testResolveSubtype()
	self:assertEquals(WeaponMining, Item.resolveSubtype({ type = 'WeaponMining' }))
end

return suite
