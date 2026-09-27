require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Registry = require('Module:Entity/Registry')
local Contract = require('Module:Entity/Contract')

local suite = ScribuntoUnit:new()

--- The loaded modules behind a list of registry entries.
--- @param entries table[]
--- @return table[]
local function loadAll(entries)
	local modules = {}
	for i, entry in ipairs(entries) do
		modules[i] = entry.load()
	end
	return modules
end

function suite:testRegistryNonEmpty()
	self:assertTrue(#Registry.kinds > 0)
	self:assertTrue(#Registry.facets > 0)
end

-- A kind entry is looked up by `name` without loading its module, so the name
-- must be the one the module itself declares.
function suite:testKindEntriesNameTheModuleTheyLoad()
	for i, entry in ipairs(Registry.kinds) do
		self:assertEquals('string', type(entry.name), 'kind entry #' .. i .. ' has no string name')
		self:assertEquals('function', type(entry.load), 'kind entry #' .. i .. ' has no load function')
		self:assertEquals(entry.name, entry.load().name, 'kind entry #' .. i .. ' names a different module')
	end
end

-- The probe fetches a kind's identity endpoint from its entry before loading
-- the kind, so the entry's copy must be the config the kind itself declares:
-- a different endpoint or params would fetch, and cache, a different URL.
function suite:testKindEntriesCarryTheKindsIdentityEndpoint()
	for i, entry in ipairs(Registry.kinds) do
		self:assertEquals('table', type(entry.api), 'kind entry #' .. i .. ' has no api config')
		self:assertDeepEquals(entry.load().getApiConfigs()[1], entry.api, 'kind entry #' .. i .. ' api differs')
	end
end

-- The probe skips loading a kind whose endpoint answered nothing or an empty
-- record, which is only sound while no kind claims either.
function suite:testKindsRejectAnEmptyRecord()
	for i, entry in ipairs(Registry.kinds) do
		local kind = entry.load()
		self:assertFalse(kind.matches(nil), 'kind entry #' .. i .. ' claims nil')
		self:assertFalse(kind.matches({}), 'kind entry #' .. i .. ' claims an empty record')
	end
end

function suite:testFacetEntriesDeclareGateKeys()
	for i, entry in ipairs(Registry.facets) do
		self:assertEquals('function', type(entry.load), 'facet entry #' .. i .. ' has no load function')
		self:assertEquals('table', type(entry.keys), 'facet entry #' .. i .. ' has no keys')
		self:assertTrue(entry.keys[1] ~= nil, 'facet entry #' .. i .. ' has an empty keys list')
		for _, key in ipairs(entry.keys) do
			self:assertEquals('string', type(key), 'facet entry #' .. i .. ' has a non-string key')
		end
	end
end

-- Records each facet's matches() accepts, keyed by require path. A facet that
-- reads more than one top-level field has one record per field, so a gate that
-- omits any of them fails below.
local FACET_MATCH_FIXTURES = {
	['Entity/Facet/Consumable'] = { { food = {} } },
	['Entity/Facet/Seat'] = { { seat = {} } },
	['Entity/Facet/Knife'] = { { knife = {} }, { melee_weapon = {} } },
	['Entity/Facet/Grenade'] = { { grenade = {} } },
	['Entity/Facet/Gadget'] = { { sub_type = 'Gadget' } },
	['Entity/Facet/Salvage'] = {
		{ vehicle_weapon = { modes = { { type = 'Salvage' } } } },
		{ personal_weapon = { modes = { { type = 'Salvage' } } } },
	},
	['Entity/Facet/Heal'] = {
		{ personal_weapon = { modes = { { type = 'healingbeam' } } } },
		{ vehicle_weapon = { modes = { { type = 'healingbeam' } } } },
	},
	['Entity/Facet/Medical'] = { { medical = {} } },
	['Entity/Facet/Hacking'] = { { hacking_chip = {} } },
	['Entity/Facet/WeaponModifier'] = { { weapon_modifier = {} } },
	['Entity/Facet/IronSight'] = { { iron_sight = {} } },
	['Entity/Facet/Magazine'] = { { magazine = {} } },
	['Entity/Facet/LaserPointer'] = { { laser_pointer = {} } },
	['Entity/Facet/Flashlight'] = { { flashlight = {} } },
	['Entity/Facet/Mining'] = { { mining_modifier = {} } },
	['Entity/Facet/Beam'] = { { tractor_beam = {} } },
	['Entity/Facet/Armor'] = { { suit_armor = {} } },
	['Entity/Facet/Environment'] = { { temperature_resistance = {} } },
	['Entity/Facet/DamageFalloff'] = {
		{
			personal_weapon = {
				damage = { alpha_total = 100 },
				ammunition = {
					range = 1000,
					damage_drop_min_distance = 50,
					damage_drop_per_meter = 0.5,
					damage_drop_min_damage = 20,
				},
			},
		},
		{
			vehicle_weapon = {
				damage = { alpha_total = 100 },
				ammunition = {
					range = 1000,
					damage_drop_min_distance = 50,
					damage_drop_per_meter = 0.5,
					damage_drop_min_damage = 20,
				},
			},
		},
	},
	['Entity/Facet/Inventory'] = { { inventory = { scu_converted = 1 } } },
	['Entity/Facet/Component'] = { { durability = {} } },
	['Entity/Facet/Dimensions'] = {
		{ dimension = { dimensions = { length = 1, width = 1, height = 1 } } },
		{ dimension = { cargo_dimension = { length = 1, width = 1, height = 1 } } },
	},
}

--- `record` without the given top-level keys.
--- @param record table
--- @param keys string[]
--- @return table
local function without(record, keys)
	local copy = {}
	for k, v in pairs(record) do
		copy[k] = v
	end
	for _, key in ipairs(keys) do
		copy[key] = nil
	end
	return copy
end

-- Data loads a facet only when one of its gate keys is present, so a record the
-- facet matches must stop matching once every gate key is removed. Otherwise
-- the gate would hide a facet that should render.
function suite:testFacetGateKeysAreNecessaryForAMatch()
	local fixturesByModule = {}
	for path, fixtures in pairs(FACET_MATCH_FIXTURES) do
		fixturesByModule[require('Module:' .. path)] = { path = path, fixtures = fixtures }
	end
	for i, entry in ipairs(Registry.facets) do
		local facet = entry.load()
		local case = fixturesByModule[facet]
		self:assertTrue(case ~= nil, 'facet entry #' .. i .. ' has no FACET_MATCH_FIXTURES entry')
		for n, record in ipairs(case.fixtures) do
			local label = case.path .. ' fixture #' .. n
			self:assertTrue(facet.matches(record), label .. ' does not match')
			self:assertFalse(facet.matches(without(record, entry.keys)), label .. ' matches without its gate keys')
		end
	end
end

function suite:testAllKindsConform()
	for i, kind in ipairs(loadAll(Registry.kinds)) do
		local ok, errors = Contract.validate(kind, Contract.KIND, { strict = true })
		self:assertTrue(ok, 'kind #' .. i .. ' failed: ' .. table.concat(errors, '; '))
	end
end

-- Every kind must declare a non-empty, unique string `name` — the canonical kind
-- name exposed as Data.get(args).kind.
-- Authoritative `name` check (non-empty + uniqueness, which KIND_FIELDS cannot
-- express); keep it distinct from testAllKindsConformFields below.
function suite:testAllKindsDeclareName()
	local seen = {}
	for i, kind in ipairs(loadAll(Registry.kinds)) do
		self:assertEquals('string', type(kind.name), 'kind #' .. i .. ' has no string name')
		self:assertTrue(#kind.name > 0, 'kind #' .. i .. ' has an empty name')
		self:assertEquals(nil, seen[kind.name], 'duplicate kind name: ' .. tostring(kind.name))
		seen[kind.name] = true
	end
end

function suite:testAllFacetsConform()
	for i, facet in ipairs(loadAll(Registry.facets)) do
		local ok, errors = Contract.validate(facet, Contract.FACET, { strict = true })
		self:assertTrue(ok, 'facet #' .. i .. ' failed: ' .. table.concat(errors, '; '))
	end
end

-- Generic typed-field gate: every kind's non-function fields (name, editorialMode)
-- conform to KIND_FIELDS. Complements testAllKindsDeclareName (which additionally
-- guarantees name is non-empty + unique) — do not dedupe the two.
function suite:testAllKindsConformFields()
	for i, kind in ipairs(loadAll(Registry.kinds)) do
		local ok, errors = Contract.validateFields(kind, Contract.KIND_FIELDS)
		self:assertTrue(ok, 'kind #' .. i .. ' field check failed: ' .. table.concat(errors, '; '))
	end
end

-- Base is the root of every chain: a contributor, not a kind or facet, so
-- the kind/facet sweeps above never validate it.
function suite:testBaseConformsToContributorContract()
	local ok, errors = Contract.validate(require('Module:Entity/Base'), Contract.CONTRIBUTOR, { strict = true })
	self:assertTrue(ok, table.concat(errors or {}, '; '))
end

return suite
