require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Heal = require('Module:Entity/Facet/Heal')

local suite = ScribuntoUnit:new()

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

-- ParaMed Medical Device: twin Heal / SelfHeal modes, identical stats.
local function paraMed()
	return {
		sub_type = 'Small',
		personal_weapon = {
			type = 'Medical Device',
			modes = {
				{
					mode = 'Heal',
					type = 'healingbeam',
					healing_per_second = 10,
					max_distance = 1.5,
					max_sensor_distance = 20,
				},
				{
					mode = 'SelfHeal',
					type = 'healingbeam',
					healing_per_second = 10,
					max_distance = 1.5,
					max_sensor_distance = 20,
				},
			},
		},
	}
end

-- A multi-tool that heals among other modes.
local function healGadget()
	return {
		sub_type = 'Gadget',
		personal_weapon = {
			modes = {
				{ type = 'Salvage', material_efficiency = 0.8 },
				{ type = 'healingbeam', healing_per_second = 8, max_distance = 1.5, max_sensor_distance = 20 },
			},
		},
	}
end

function suite:testMatches()
	self:assertEquals(true, Heal.matches(paraMed()))
	self:assertEquals(true, Heal.matches(healGadget()))
	-- A vehicle medical beam matches off vehicle_weapon.modes too.
	self:assertEquals(
		true,
		Heal.matches({ vehicle_weapon = { modes = { { type = 'healingbeam', healing_per_second = 50 } } } })
	)
	self:assertEquals(false, Heal.matches({ personal_weapon = { modes = { { type = 'Salvage' } } } }))
	self:assertEquals(false, Heal.matches({}))
	self:assertEquals(false, Heal.matches(nil))
end

function suite:testParaMedSection()
	local sec = findSection(Heal.getSections(paraMed(), {}), 'heal')
	self:assertEquals('Healing', sec.label)
	self:assertEquals('10/s', findItem(sec.items, 'Healing rate').content)
	self:assertEquals('1.5 m', findItem(sec.items, 'Range').content)
	self:assertEquals('20 m', findItem(sec.items, 'Sensor range').content)
end

function suite:testGadgetHealSection()
	local sec = findSection(Heal.getSections(healGadget(), {}), 'heal')
	self:assertEquals('8/s', findItem(sec.items, 'Healing rate').content)
end

function suite:testNoHealMode()
	self:assertEquals(0, #Heal.getSections({ personal_weapon = { modes = { { type = 'Salvage' } } } }, {}))
end

-- A healing-beam mode with no stats renders nothing.
function suite:testStatlessHeal()
	self:assertEquals(0, #Heal.getSections({ personal_weapon = { modes = { { type = 'healingbeam' } } } }, {}))
end

return suite
