require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local assembly = require('Module:Entity/Assembly')
local registry = require('Module:Entity/Registry')

local suite = ScribuntoUnit:new()

local function findItem(items, label)
	for _, it in ipairs(items or {}) do
		if it.label == label then
			return it
		end
	end
	return nil
end

-- Dispatch: every registered facet takes an EntityHookContext — a facet whose
-- hooks aren't written for ctx must fail here, not render wrong values
-- silently on the wiki. One case per Module:Entity/Registry facet, keyed by
-- the require path so it is matched to the module instance the registry
-- itself holds (require() caches modules, so the two are the same table).
-- Each fixture supplies exactly the one field its hook needs to produce a
-- value distinguishable from the hook's own nil-guarded default.
local FACET_DISPATCH_CASES = {
	{
		path = 'Entity/Facet/Consumable',
		hook = 'getStructuredData',
		ctx = { apiData = { food = { nutritional_density_rating = '80' } }, args = {} },
		expect = function(self, result)
			self:assertEquals(80, result.ndr)
		end,
	},
	{
		path = 'Entity/Facet/Seat',
		hook = 'getSections',
		ctx = { apiData = { seat = { yaw = { min = -20, max = 20 } } }, args = {} },
		expect = function(self, result)
			self:assertEquals('Seat', result[1].label)
			self:assertEquals('−20° — 20°', findItem(result[1].items, 'Yaw').content)
		end,
	},
	{
		path = 'Entity/Facet/Knife',
		hook = 'getSections',
		ctx = {
			apiData = { melee_weapon = { attack_modes = { { category = 'BladeSlash', damage = 30 } } } },
			args = {},
		},
		expect = function(self, result)
			self:assertEquals('Melee', result[1].label)
			self:assertEquals('30', findItem(result[1].items, 'Slash damage').content)
		end,
	},
	{
		path = 'Entity/Facet/Grenade',
		hook = 'getSections',
		ctx = { apiData = { grenade = { damage_type = 'Physical', damage = 20 } }, args = {} },
		expect = function(self, result)
			self:assertEquals('Physical', findItem(result[1].items, 'Damage type').content)
		end,
	},
	{
		path = 'Entity/Facet/Gadget',
		hook = 'getStructuredData',
		ctx = { apiData = { sub_type = 'Gadget', personal_weapon = { range = 5 } }, args = {} },
		expect = function(self, result)
			self:assertEquals(5, result.max_range)
		end,
	},
	{
		path = 'Entity/Facet/Salvage',
		hook = 'getStructuredData',
		ctx = {
			apiData = { personal_weapon = { modes = { { type = 'Salvage', material_efficiency = 0.8 } } } },
			args = {},
		},
		expect = function(self, result)
			self:assertEquals(80, result.material_efficiency)
		end,
	},
	{
		path = 'Entity/Facet/Heal',
		hook = 'getSections',
		ctx = {
			apiData = { personal_weapon = { modes = { { type = 'healingbeam', healing_per_second = 10 } } } },
			args = {},
		},
		expect = function(self, result)
			self:assertEquals('Healing', result[1].label)
			self:assertEquals('10/s', findItem(result[1].items, 'Healing rate').content)
		end,
	},
	{
		path = 'Entity/Facet/Medical',
		hook = 'getSections',
		ctx = { apiData = { medical = { nutrition = { blood_drug_level = 15 } } }, args = {} },
		expect = function(self, result)
			self:assertEquals('15', findItem(result[1].items, 'Blood drug level').content)
		end,
	},
	{
		path = 'Entity/Facet/Hacking',
		hook = 'getStructuredData',
		ctx = { apiData = { hacking_chip = { max_charges = 3 } }, args = {} },
		expect = function(self, result)
			self:assertEquals(3, result.charges)
		end,
	},
	{
		path = 'Entity/Facet/WeaponModifier',
		hook = 'getStructuredData',
		ctx = { apiData = { weapon_modifier = { aim = { zoom_scale = 8 } } }, args = {} },
		expect = function(self, result)
			self:assertEquals(8, result.magnification)
		end,
	},
	{
		path = 'Entity/Facet/IronSight',
		hook = 'getStructuredData',
		ctx = { apiData = { iron_sight = { max_range = 1000 } }, args = {} },
		expect = function(self, result)
			self:assertEquals(1000, result.max_range)
		end,
	},
	{
		path = 'Entity/Facet/Magazine',
		hook = 'getStructuredData',
		ctx = { apiData = { magazine = { max_ammo_count = 15 } }, args = {} },
		expect = function(self, result)
			self:assertEquals(15, result.ammo)
		end,
	},
	{
		path = 'Entity/Facet/LaserPointer',
		hook = 'getStructuredData',
		ctx = { apiData = { laser_pointer = { range = 20 } }, args = {} },
		expect = function(self, result)
			self:assertEquals(20, result.laser_range)
		end,
	},
	{
		path = 'Entity/Facet/Flashlight',
		hook = 'getSections',
		ctx = {
			apiData = {
				flashlight = {
					light_1 = { port_name = 'light_1', name = 'Narrow', light_type = 'Projector', light_radius = 35 },
				},
			},
			args = {},
		},
		expect = function(self, result)
			self:assertEquals('Narrow', result[1].items[1].label)
			self:assertEquals('Projector, 35 m', result[1].items[1].content)
		end,
	},
	{
		path = 'Entity/Facet/Mining',
		hook = 'getSections',
		ctx = { apiData = { mining_modifier = { type = 'Active', charges = 5 } }, args = {} },
		expect = function(self, result)
			self:assertEquals('Mining', result[1].label)
			self:assertEquals('5', findItem(result[1].items, 'Charges').content)
		end,
	},
	{
		path = 'Entity/Facet/Beam',
		hook = 'getStructuredData',
		ctx = { apiData = { type = 'TractorBeam', tractor_beam = { force = { max = 500000 } } }, args = {} },
		expect = function(self, result)
			self:assertEquals(500000, result.beam_force)
		end,
	},
	{
		path = 'Entity/Facet/Armor',
		hook = 'getStructuredData',
		ctx = {
			apiData = { sub_type = 'Heavy', suit_armor = { damage_resistance_map = { physical = 0.6 } } },
			args = {},
		},
		expect = function(self, result)
			self:assertEquals('Heavy', result.weight_class)
		end,
	},
	{
		path = 'Entity/Facet/Environment',
		hook = 'getStructuredData',
		ctx = { apiData = { temperature_resistance = { min = -75, max = 105 } }, args = {} },
		expect = function(self, result)
			self:assertEquals(-75, result.minimum_temperature)
		end,
	},
	{
		path = 'Entity/Facet/DamageFalloff',
		hook = 'getStructuredData',
		ctx = {
			apiData = {
				personal_weapon = {
					damage = { alpha_total = 100 },
					ammunition = {
						range = 500,
						damage_drop_min_distance = 50,
						damage_drop_per_meter = 1,
						damage_drop_min_damage = 50,
					},
				},
			},
			args = {},
		},
		expect = function(self, result)
			self:assertEquals(50, result.full_damage_range)
		end,
	},
	{
		path = 'Entity/Facet/Inventory',
		hook = 'getStructuredData',
		ctx = { apiData = { inventory = { scu_converted = 10500 } }, args = {} },
		expect = function(self, result)
			self:assertEquals(10500, result.storage_capacity)
		end,
	},
	{
		path = 'Entity/Facet/Component',
		hook = 'getStructuredData',
		ctx = { apiData = { durability = { health = 860 } }, args = {} },
		expect = function(self, result)
			self:assertEquals(860, result.health)
		end,
	},
	{
		path = 'Entity/Facet/Dimensions',
		hook = 'getSections',
		ctx = { apiData = { dimension = { cargo_dimension = { length = 1, width = 1, height = 1 } } }, args = {} },
		expect = function(self, result)
			self:assertEquals('Cargo dimensions', result[1].label)
		end,
	},
}

function suite:testEveryFacetDispatchesThroughContext()
	local byModule = {}
	for _, case in ipairs(FACET_DISPATCH_CASES) do
		byModule[require('Module:' .. case.path)] = case
	end

	local exercised = 0
	for _, facet in ipairs(registry.facets) do
		local case = byModule[facet]
		self:assertTrue(case ~= nil, 'no FACET_DISPATCH_CASES entry for a registered facet')
		local result = assembly.callHook(facet, case.hook, case.ctx)
		case.expect(self, result)
		exercised = exercised + 1
	end
	self:assertEquals(#FACET_DISPATCH_CASES, exercised)
end

return suite
