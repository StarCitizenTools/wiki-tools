require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Salvage = require('Module:Entity/Facet/Salvage')

local suite = ScribuntoUnit:new()

local salvageItems = Salvage._internal.salvageItems
local findSalvageMode = Salvage._internal.findSalvageMode

local function findSection(sections, key)
	for _, s in ipairs(sections or {}) do
		if s.key == key then
			return s
		end
	end
	return nil
end

local function findItem(items, label)
	for _, it in ipairs(items or {}) do
		if it.label == label then
			return it
		end
	end
	return nil
end

-- A Pyro RYT / salvage-head Salvage mode.
local function salvageMode()
	return {
		type = 'Salvage',
		material_efficiency = 0.8,
		max_health_repair_rate = 310,
		max_damage_map_repair_rate = 10,
		health_to_ammo_ratio = 2,
		ramp_up_time = 4,
		ramp_down_time = 0.25,
		max_vehicle_damage_ratio = 1,
		repaired_material_ratio = 1,
	}
end

-- A vehicle salvage head: Salvage mode lives in vehicle_weapon.modes.
local function salvageHead()
	return { vehicle_weapon = { range = 20, modes = { { type = 'Beam' }, salvageMode() } } }
end

-- An FPS salvage tool: Salvage mode lives in personal_weapon.modes.
local function salvageGadget()
	return { sub_type = 'Gadget', personal_weapon = { modes = { salvageMode() } } }
end

function suite:testMatches()
	self:assertEquals(true, Salvage.matches(salvageHead()))
	self:assertEquals(true, Salvage.matches(salvageGadget()))
	self:assertEquals(false, Salvage.matches({ vehicle_weapon = { modes = { { type = 'Beam' } } } }))
	self:assertEquals(false, Salvage.matches({}))
	self:assertEquals(false, Salvage.matches(nil))
end

function suite:testFindSalvageMode()
	local modes = { { type = 'Heal' }, { type = 'Salvage', material_efficiency = 0.5 } }
	self:assertEquals('Salvage', findSalvageMode(modes).type)
	self:assertEquals(nil, findSalvageMode({ { type = 'Heal' } }))
	self:assertEquals(nil, findSalvageMode(nil))
end

function suite:testSalvageItems()
	local items = salvageItems(salvageMode())
	self:assertEquals('80%', findItem(items, 'Material efficiency').content)
	self:assertEquals('310', findItem(items, 'Health repair rate').content)
	self:assertEquals('10', findItem(items, 'Damage repair rate').content)
	self:assertEquals('2', findItem(items, 'Health-to-ammo ratio').content)
	self:assertEquals('4 s / 0.25 s', findItem(items, 'Ramp up / down').content)
	self:assertEquals('100%', findItem(items, 'Max vehicle damage').content)
	self:assertEquals('100%', findItem(items, 'Repaired material').content)
end

function suite:testSalvageItemsEmpty()
	self:assertEquals(0, #salvageItems(nil))
	self:assertEquals(0, #salvageItems({}))
end

-- The facet renders the stat rows under the 'salvage' key for BOTH populations;
-- it never emits Range (that is the SalvageHead subtype's row).
function suite:testGetSectionsHead()
	local sections = Salvage.getSections(salvageHead(), {})
	local sec = findSection(sections, 'salvage')
	self:assertEquals('Salvage', sec.label)
	self:assertEquals('80%', findItem(sec.items, 'Material efficiency').content)
	self:assertEquals(nil, findItem(sec.items, 'Range'))
end

function suite:testGetSectionsGadget()
	local sec = findSection(Salvage.getSections(salvageGadget(), {}), 'salvage')
	self:assertEquals('80%', findItem(sec.items, 'Material efficiency').content)
end

function suite:testGetSectionsEmpty()
	self:assertEquals(0, #Salvage.getSections({ personal_weapon = { modes = {} } }, {}))
end

function suite:testStructuredData()
	local d = Salvage.getStructuredData(salvageHead(), {})
	self:assertEquals(80, d.material_efficiency)
	self:assertEquals(310, d.health_repair_rate)
	self:assertEquals(10, d.damage_repair_rate)
	self:assertEquals(4, d.ramp_up_time)
	self:assertEquals(0.25, d.ramp_down_time)
	-- Reads identically off the gadget's personal_weapon block.
	self:assertEquals(80, Salvage.getStructuredData(salvageGadget(), {}).material_efficiency)
end

return suite
