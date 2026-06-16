require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local SalvageHead = require('Module:Entity/Item/SalvageHead')
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

-- The Baler Salvage Head: range 150 m; Beam/Salvage mode + a TractorBeam mode.
local function balerData()
	return {
		size = 2,
		vehicle_weapon = {
			range = 150,
			modes = {
				{
					mode = 'Beam',
					type = 'Salvage',
					material_efficiency = 1,
					max_health_repair_rate = 10,
					max_damage_map_repair_rate = 10,
					health_to_ammo_ratio = 0.5,
					ramp_up_time = 1,
					ramp_down_time = 2,
					max_vehicle_damage_ratio = 0.9,
					repaired_material_ratio = 1,
				},
				{ mode = 'TractorBeam', type = 'tractorbeam' },
			},
		},
	}
end

-- SalvageHead.getSections contributes only the Range row. The Salvage-mode stat
-- set (material efficiency, repair rates, ramp times, etc.) is delegated to the
-- Module:Entity/Facet/Salvage data-driven facet, which renders below via the
-- section-merge chain. Both share the 'salvage' section key.
function suite:testRows()
	local sections = SalvageHead.getSections(balerData(), {})
	self:assertEquals(1, #sections)
	self:assertEquals('salvage', sections[1].key)
	self:assertEquals('Salvage', sections[1].label)
	self:assertEquals('150 m', findItem(sections[1].items, 'Range').content)
	-- Mode-stat rows (material efficiency, repair rates, etc.) are NOT emitted by
	-- this subtype; they come from the Salvage facet.
	self:assertEquals(nil, findItem(sections[1].items, 'Material efficiency'))
end

-- The FPS salvage tool shares the mode shape under personal_weapon; the head
-- only reads vehicle_weapon, so a record with no vehicle_weapon yields nothing.
function suite:testEmptyWhenNoWeapon()
	self:assertEquals(0, #SalvageHead.getSections({}, {}))
end

-- A head whose modes lack a Salvage mode still shows range, no mode rows.
function suite:testRangeOnly()
	local sections = SalvageHead.getSections({
		vehicle_weapon = { range = 120, modes = { { mode = 'TractorBeam', type = 'tractorbeam' } } },
	}, {})
	self:assertEquals('120 m', findItem(sections[1].items, 'Range').content)
	self:assertEquals(nil, findItem(sections[1].items, 'Material efficiency'))
end

function suite:testShortDescription()
	local desc = SalvageHead.getShortDescription(
		balerData(),
		{ manufacturer = 'Greycat Industrial' },
		{ name = 'Salvage head' }
	)
	self:assertEquals('S2 salvage head by Greycat', desc)
end

-- getStructuredData emits only beam_range from the subtype; the Salvage facet
-- stores material_efficiency, repair rates, and ramp times.
function suite:testStructuredData()
	local data = SalvageHead.getStructuredData(balerData())
	self:assertEquals(150, data.beam_range)
	-- Facet-owned fields are not present on the subtype's structured data.
	self:assertEquals(nil, data.material_efficiency)
	self:assertEquals(nil, data.health_repair_rate)
	self:assertEquals(nil, data.ramp_up_time)
end

function suite:testResolveSubtype()
	self:assertEquals(SalvageHead, Item.resolveSubtype({ type = 'SalvageHead' }))
end

return suite
