require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Item = require('Module:Entity/Item')
local assembly = require('Module:Entity/Assembly')

local suite = ScribuntoUnit:new()

--- Hook context for direct hook calls (Module:Entity/Types EntityHookContext).
local function ctx(apiData, args, resolved)
	return { apiData = apiData, args = args or {}, resolved = resolved }
end

-- matches()

function suite:testMatchesNilReturnsFalse()
	self:assertEquals(false, Item.matches(nil))
end

function suite:testMatchesEmptyTableReturnsFalse()
	self:assertEquals(false, Item.matches({}))
end

-- A uuid alone is not an item: Module:Entity/Data resolves a UUID through the
-- API's search endpoint and offers that one payload to every kind, so matches()
-- must identify items positively rather than acting as a catch-all.
function suite:testMatchesUuidAloneReturnsFalse()
	self:assertEquals(false, Item.matches({ uuid = 'abc-123' }))
end

function suite:testMatchesUuidWithClassNameReturnsTrue()
	self:assertEquals(true, Item.matches({ uuid = 'abc-123', class_name = 'Paint_100i' }))
end

function suite:testMatchesUuidWithItemTypeReturnsTrue()
	self:assertEquals(true, Item.matches({ uuid = 'abc-123', class_name = 'Food_Water', type = 'Food' }))
end

-- Vehicles carry class_name too, so the is_vehicle exclusion is what separates
-- them. This is the one cross-kind fact Item.matches encodes.
function suite:testMatchesVehicleShapedDataReturnsFalse()
	self:assertEquals(false, Item.matches({ uuid = 'abc-123', class_name = 'AEGS_Avenger', is_vehicle = false }))
end

-- Kinds that reach matches() only because the resolver answers for every kind.
-- None of them carry class_name.
function suite:testMatchesCommodityShapedDataReturnsFalse()
	self:assertEquals(false, Item.matches({ uuid = 'abc-123', box_sizes_scu = { 1, 2 } }))
end

function suite:testMatchesMissionShapedDataReturnsFalse()
	self:assertEquals(false, Item.matches({ uuid = 'abc-123', mission_type = 'Delivery' }))
end

-- Starmap locations carry uuid + type but no class_name; Entity doesn't model
-- them, so Item must not claim them.
function suite:testMatchesLocationShapedDataReturnsFalse()
	self:assertEquals(false, Item.matches({ uuid = 'abc-123', type = 'PLANET' }))
end

-- resolveSubtype()

-- Food / Drink are handled by the consumable facet, not a subtype leaf.
-- resolveSubtype must return nil for both so the facet path is taken.
function suite:testResolveSubtypeFoodReturnsNil()
	self:assertEquals(nil, Item.resolveSubtype({ type = 'Food' }))
end

function suite:testResolveSubtypeDrinkReturnsNil()
	self:assertEquals(nil, Item.resolveSubtype({ type = 'Drink' }))
end

function suite:testResolveSubtypeModuleReturnsModuleSubtype()
	local result = Item.resolveSubtype({ type = 'Module' })
	self:assertEquals(require('Module:Entity/Item/Module'), result)
end

function suite:testResolveSubtypeWeaponPersonalReturnsModule()
	local result = Item.resolveSubtype({ type = 'WeaponPersonal' })
	self:assertEquals(require('Module:Entity/Item/WeaponPersonal'), result)
end

function suite:testResolveSubtypeTurretReturnsTurretModule()
	local result = Item.resolveSubtype({ type = 'Turret' })
	self:assertEquals(require('Module:Entity/Item/Turret'), result)
end

function suite:testResolveSubtypeMiscReturnsMiscModule()
	local result = Item.resolveSubtype({ type = 'Misc' })
	self:assertEquals(require('Module:Entity/Item/Misc'), result)
end

function suite:testResolveSubtypeUnknownTypeReturnsNil()
	self:assertEquals(nil, Item.resolveSubtype({ type = 'BogusUnknownType' }))
end

function suite:testResolveSubtypeMissingTypeReturnsNil()
	self:assertEquals(nil, Item.resolveSubtype({}))
end

function suite:testResolveSubtypeNilApiDataReturnsNil()
	self:assertEquals(nil, Item.resolveSubtype(nil))
end

-- getStructuredData

function suite:testGetStructuredData()
	local result = Item.getStructuredData(ctx({
		size = 3,
		grade = 'A',
		rarity = 'Rare',
		description_data = { { name = 'Item Type', value = 'Laser Repeater' } },
	}, {}))
	self:assertEquals(3, result.size)
	self:assertEquals('A', result.grade)
	self:assertEquals('Laser Repeater', result.item_type)
	self:assertEquals('Rare', result.rarity)
end

-- classContent / gradeContent (graded-component rows)

function suite:testClassContentPresent()
	self:assertEquals('Military', Item._internal.classContent({ class = 'Military' }))
end

function suite:testClassContentAbsentOrEmpty()
	self:assertEquals(nil, Item._internal.classContent({}))
	self:assertEquals(nil, Item._internal.classContent({ class = '' }))
end

function suite:testGradeContentComponent()
	self:assertEquals('B', Item._internal.gradeContent({ class = 'Military', grade = 'B' }))
end

function suite:testGradeContentWeaponNoClassReturnsNil()
	-- Vehicle gun: constant grade 'A' but no class -> no grade row.
	self:assertEquals(nil, Item._internal.gradeContent({ grade = 'A' }))
end

function suite:testGradeContentComponentNoGradeReturnsNil()
	self:assertEquals(nil, Item._internal.gradeContent({ class = 'Military' }))
end

function suite:testGradeContentFpsReturnsNil()
	self:assertEquals(nil, Item._internal.gradeContent({}))
end

-- formatGradedShortDescription (graded vehicle components)

function suite:testGradedShortDescription()
	local desc = Item.formatGradedShortDescription(
		{ name = 'Power plant' },
		{ size = 3, grade = 'A', class = 'Military' },
		{ manufacturer = 'Amon & Reese Co.' }
	)
	self:assertEquals('S3 Gr. A military power plant by A&R', desc)
end

function suite:testGradedShortDescriptionNoClassReturnsNil()
	-- No class (vehicle weapon / FPS item) -> nil, so the generic descriptor is used.
	self:assertEquals(nil, Item.formatGradedShortDescription({ name = 'Gun' }, { size = 1, grade = 'A' }, {}))
end

function suite:testGradedShortDescriptionNoGradeReturnsNil()
	self:assertEquals(
		nil,
		Item.formatGradedShortDescription({ name = 'Power plant' }, { size = 2, class = 'Military' }, {})
	)
end

-- getItemType (relocated from Util)

function suite:testGetItemTypeReturnsLabel()
	self:assertEquals(
		'Laser Repeater',
		Item._internal.getItemType({ description_data = { { name = 'Item Type', value = 'Laser Repeater' } } })
	)
end

function suite:testGetItemTypeFallsBackToTypeField()
	self:assertEquals(
		'Laser Repeater',
		Item._internal.getItemType({ description_data = { { name = 'Item Type', type = 'Laser Repeater' } } })
	)
end

function suite:testGetItemTypeFromTypeEntryName()
	self:assertEquals(
		'Laser Beam',
		Item._internal.getItemType({ description_data = { { name = 'Type', value = 'Laser Beam' } } })
	)
end

function suite:testGetItemTypeNilWhenAbsent()
	self:assertEquals(nil, Item._internal.getItemType({}))
	self:assertEquals(nil, Item._internal.getItemType(nil))
end

-- getVolume (relocated from Util)

function suite:testGetVolumeMicroScuPassthrough()
	self:assertEquals(
		756000,
		Item._internal.getVolume({ dimension = { volume_converted = 756000, volume_converted_unit = 'µSCU' } })
	)
end

function suite:testGetVolumeScuConvertsToMicroScu()
	self:assertEquals(
		500000,
		Item._internal.getVolume({ dimension = { volume_converted = 0.5, volume_converted_unit = 'SCU' } })
	)
end

function suite:testGetVolumeTinyItemPreservesPrecision()
	self:assertEquals(
		1,
		Item._internal.getVolume({ dimension = { volume_converted = 1, volume_converted_unit = 'µSCU' } })
	)
end

function suite:testGetVolumeNilWhenAbsent()
	self:assertEquals(nil, Item._internal.getVolume(nil))
	self:assertEquals(nil, Item._internal.getVolume({}))
	self:assertEquals(nil, Item._internal.getVolume({ dimension = {} }))
	self:assertEquals(nil, Item._internal.getVolume({ dimension = { volume_converted_unit = 'µSCU' } }))
end

function suite:testGetVolumeUnknownUnitReturnsNil()
	self:assertEquals(
		nil,
		Item._internal.getVolume({ dimension = { volume_converted = 5, volume_converted_unit = 'mSCU' } })
	)
end

function suite:testGetVolumeMissingUnitTreatedAsScu()
	self:assertEquals(1000000, Item._internal.getVolume({ dimension = { volume_converted = 1 } }))
end

function suite:testGetAcquisitionItem()
	local a = Item.getAcquisition(ctx({ uex_prices = { purchase = { { price_buy = 500 } } }, is_lootable = true }, {}))
	local byLabel = {}
	for _, r in ipairs(a.summary) do
		byLabel[r.label] = r.value
	end
	self:assertEquals(true, byLabel['Buy'])
	self:assertEquals(true, byLabel['Loot'])
	self:assertEquals(nil, byLabel['Rent']) -- no canRent → Rent row absent
	self:assertEquals('terminals', a.cards[1].type)
	self:assertEquals('Shop terminals', a.cards[1].caption)
end

-- Dispatch: every Item subtype leaf takes an EntityHookContext (Task 1 review
-- requirement — a leaf whose contextHooks flag is set but whose hooks weren't
-- rewritten must fail here, not render wrong values silently on the wiki).

--- One dispatch case per subtype leaf Item.resolveSubtype can reach (every target
--- in Module:Entity/Item's itemSubtypeMapping, de-duplicated). Each fixture supplies
--- exactly the one field its hook needs to produce a value distinguishable from the
--- hook's own nil-guarded default — a leaf still reading its old positional
--- (apiData, args, ...) parameters sees the whole ctx table where it expects the
--- domain apiData, finds none of these fields at that top level, and so returns the
--- empty/default result the `expect` assertion below rejects (or, for the two
--- getShortDescription-only leaves, errors outright on a nil typeInfo).
local LEAF_DISPATCH_CASES = {
	{
		path = 'Entity/Item/Beam',
		hook = 'getShortDescription',
		ctx = { apiData = { size = 1 }, args = {}, typeInfo = { name = 'Test type' } },
		expect = function(self, result)
			self:assertEquals('S1 test type', result)
		end,
	},
	{
		path = 'Entity/Item/Bomb',
		hook = 'getSections',
		ctx = { apiData = { bomb = { damage_total = 100 } }, args = {} },
		expect = function(self, result)
			self:assertEquals('Damage', result[1].items[1].label)
			self:assertEquals('100', result[1].items[1].content)
		end,
	},
	{
		path = 'Entity/Item/Cooler',
		hook = 'getSections',
		ctx = { apiData = { cooler = { coolant_segment_generation = 46 } }, args = {} },
		expect = function(self, result)
			self:assertEquals('46', result[1].items[1].content)
		end,
	},
	{
		path = 'Entity/Item/EMP',
		hook = 'getSections',
		ctx = { apiData = { emp = { emp_radius = 1100 } }, args = {} },
		expect = function(self, result)
			self:assertEquals('1,100 m', result[1].items[1].content)
		end,
	},
	{
		path = 'Entity/Item/FPSConsumable',
		hook = 'getTypeInfo',
		ctx = { apiData = { sub_type = 'Medical' }, args = {} },
		expect = function(self, result)
			self:assertEquals('Medical consumable', result.name)
			self:assertEquals('Medical consumables', result.category)
		end,
	},
	{
		path = 'Entity/Item/FlightController',
		hook = 'getSections',
		ctx = { apiData = { flight_controller = { scm_speed = 200 } }, args = {} },
		expect = function(self, result)
			self:assertEquals('200 m/s', result[1].items[1].content)
		end,
	},
	{
		path = 'Entity/Item/JumpModule',
		hook = 'getSections',
		ctx = { apiData = { jump_drive = { alignment_rate = 0.2 } }, args = {} },
		expect = function(self, result)
			self:assertEquals('0.2', result[1].items[1].content)
		end,
	},
	{
		path = 'Entity/Item/MiningModule',
		hook = 'getShortDescription',
		ctx = { apiData = { size = 1 }, args = {}, typeInfo = { name = 'Test type' } },
		expect = function(self, result)
			self:assertEquals('S1 test type', result)
		end,
	},
	{
		path = 'Entity/Item/Misc',
		hook = 'getTypeInfo',
		ctx = { apiData = { sub_type = 'Flair_Wall_Picture' }, args = {} },
		expect = function(self, result)
			self:assertEquals('Wall flair', result.name)
			self:assertEquals('Wall flair', result.category)
		end,
	},
	{
		path = 'Entity/Item/Missile',
		hook = 'getSections',
		ctx = { apiData = { missile = { signal_type = 'Infrared' } }, args = {} },
		expect = function(self, result)
			self:assertEquals('Signal type', result[1].items[1].label)
			self:assertEquals('Infrared', result[1].items[1].content)
		end,
	},
	{
		path = 'Entity/Item/Module',
		hook = 'getTypeInfo',
		ctx = { apiData = { vehicles = { { name = 'Test Vehicle' } } }, args = {} },
		expect = function(self, result)
			self:assertEquals('Test Vehicle', result.category)
		end,
	},
	{
		path = 'Entity/Item/PowerPlant',
		hook = 'getSections',
		ctx = { apiData = { power_plant = { power_segment_generation = 20 } }, args = {} },
		expect = function(self, result)
			self:assertEquals('Power', result[1].items[1].label)
			self:assertEquals('20', result[1].items[1].content)
		end,
	},
	{
		path = 'Entity/Item/QuantumDrive',
		hook = 'getSections',
		ctx = { apiData = { quantum_drive = { standard_jump = { spool_up_time = 4 } } }, args = {} },
		expect = function(self, result)
			self:assertEquals('Spool time', result[1].items[1].label)
			self:assertEquals('4 s', result[1].items[1].content)
		end,
	},
	{
		path = 'Entity/Item/QuantumInterdictionGenerator',
		hook = 'getSections',
		ctx = { apiData = { quantum_interdiction_generator = { pulse = { charge_time = 90 } } }, args = {} },
		expect = function(self, result)
			self:assertEquals('Charge time', result[1].items[1].label)
			self:assertEquals('90 s', result[1].items[1].content)
		end,
	},
	{
		path = 'Entity/Item/Rack',
		hook = 'getSections',
		ctx = { apiData = { missile_rack = { missile_count = 4 } }, args = {} },
		expect = function(self, result)
			self:assertEquals('Capacity', result[1].items[1].label)
			self:assertEquals('4', result[1].items[1].content)
		end,
	},
	{
		path = 'Entity/Item/Radar',
		hook = 'getSections',
		ctx = { apiData = { radar = { cooldown = 2.5 } }, args = {} },
		expect = function(self, result)
			self:assertEquals('Cooldown', result[1].items[1].label)
			self:assertEquals('2.5 s', result[1].items[1].content)
		end,
	},
	{
		path = 'Entity/Item/SalvageHead',
		hook = 'getSections',
		ctx = { apiData = { vehicle_weapon = { range = 150 } }, args = {} },
		expect = function(self, result)
			self:assertEquals('Range', result[1].items[1].label)
			self:assertEquals('150 m', result[1].items[1].content)
		end,
	},
	{
		path = 'Entity/Item/Scraper',
		hook = 'getSections',
		ctx = { apiData = { salvage_modifier = { extraction_efficiency = 0.9 } }, args = {} },
		expect = function(self, result)
			self:assertEquals('Extraction efficiency', result[1].items[1].label)
			self:assertEquals('90%', result[1].items[1].content)
		end,
	},
	{
		path = 'Entity/Item/Shield',
		hook = 'getSections',
		ctx = { apiData = { shield = { max_health = 3168 } }, args = {} },
		expect = function(self, result)
			self:assertEquals('Shield HP', result[1].items[1].label)
			self:assertEquals('3,168', result[1].items[1].content)
		end,
	},
	{
		path = 'Entity/Item/Turret',
		hook = 'getSections',
		ctx = { apiData = { turret = { mounts = 1 } }, args = {} },
		expect = function(self, result)
			self:assertEquals('Mounts', result[1].items[1].label)
			self:assertEquals('1', result[1].items[1].content)
		end,
	},
	{
		path = 'Entity/Item/WeaponAttachment',
		hook = 'getTypeInfo',
		ctx = { apiData = { sub_type = 'Magazine' }, args = {} },
		expect = function(self, result)
			self:assertEquals('Magazine', result.name)
			self:assertEquals('Magazines', result.category)
		end,
	},
	{
		path = 'Entity/Item/WeaponGun',
		hook = 'getSections',
		ctx = { apiData = { vehicle_weapon = { type = 'Laser Repeater' } }, args = {} },
		expect = function(self, result)
			self:assertEquals('Type', result[1].items[1].label)
			self:assertEquals('Laser Repeater', result[1].items[1].content)
		end,
	},
	{
		path = 'Entity/Item/WeaponMining',
		hook = 'getSections',
		ctx = { apiData = { mining_laser = { module_slots = 1 } }, args = {} },
		expect = function(self, result)
			self:assertEquals('Module slots', result[1].items[1].label)
			self:assertEquals('1', result[1].items[1].content)
		end,
	},
	{
		path = 'Entity/Item/WeaponPersonal',
		hook = 'getTypeInfo',
		ctx = { apiData = { sub_type = 'Knife' }, args = {} },
		expect = function(self, result)
			self:assertEquals('Knife', result.name)
			self:assertEquals('Knives', result.category)
		end,
	},
}

function suite:testEveryItemSubtypeLeafDispatchesThroughContext()
	for _, case in ipairs(LEAF_DISPATCH_CASES) do
		local mod = require('Module:' .. case.path)
		self:assertEquals(true, mod.contextHooks)
		local result = assembly.callHook(mod, case.hook, case.ctx)
		case.expect(self, result)
	end
end

return suite
