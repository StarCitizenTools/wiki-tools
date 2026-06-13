require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Gadget = require('Module:Entity/Facet/Gadget')

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

-- Pyro RYT-like multi-tool: salvage + heal + tractor modes. Gadget renders ONLY
-- the overview; the Salvage and Heal facets own their respective mode sections.
local function multiTool()
	return {
		sub_type = 'Gadget',
		personal_weapon = {
			type = 'Utility',
			effective_range = 5,
			ammunition = { capacity = 100 },
			modes = {
				{ type = 'Salvage', material_efficiency = 0.8, max_health_repair_rate = 310 },
				{ type = 'healingbeam', healing_per_second = 8, max_distance = 1.5, max_sensor_distance = 20 },
				{ type = 'tractorbeam', toggle_mode = 'IsToggle' },
			},
		},
	}
end

function suite:testMatches()
	self:assertEquals(true, Gadget.matches({ sub_type = 'Gadget' }))
	self:assertEquals(false, Gadget.matches({ sub_type = 'Small' }))
	self:assertEquals(false, Gadget.matches(nil))
end

function suite:testOverviewOnly()
	local s = Gadget.getSections(multiTool(), {})
	-- Just the overview — no salvage / heal sections from this facet.
	self:assertEquals(1, #s)
	local overview = findSection(s, 'gadget')
	self:assertEquals('Utility', findItem(overview.items, 'Type').content)
	self:assertEquals('5 m', findItem(overview.items, 'Effective range').content)
	self:assertEquals('100', findItem(overview.items, 'Capacity').content)
end

-- MaxLift: type + range; tractor mode is stat-less -> still just the overview.
function suite:testTractorOnlyOverview()
	local s = Gadget.getSections({
		sub_type = 'Gadget',
		personal_weapon = {
			type = 'Tractor Beam',
			effective_range = 100,
			ammunition = { capacity = 50 },
			modes = { { type = 'tractorbeam', toggle_mode = 'IsToggle' } },
		},
	}, {})
	self:assertEquals(1, #s)
	self:assertEquals('gadget', s[1].key)
	self:assertEquals('Tractor Beam', findItem(s[1].items, 'Type').content)
end

-- XDL: all-null personal_weapon -> no gadget sections (zoom is WeaponModifier's job).
function suite:testEmptyWhenNoStats()
	self:assertEquals(0, #Gadget.getSections({ sub_type = 'Gadget', personal_weapon = { ammunition = {} } }, {}))
end

function suite:testStructuredData()
	self:assertEquals(5, Gadget.getStructuredData(multiTool(), {}).effective_range)
end

return suite
