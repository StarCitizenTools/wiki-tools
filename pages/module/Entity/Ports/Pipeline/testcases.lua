require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local suite = ScribuntoUnit:new()
local pipeline = require('Module:Entity/Ports/Pipeline')
local helpers = pipeline._internal

-- equippedItemDisplay

function suite:testEquippedNormal()
	local r = helpers.equippedItemDisplay({ name = 'M9A Cannon' })
	self:assertEquals('M9A Cannon', r.name)
	self:assertEquals('[[M9A Cannon]]', r.pageLink)
end

function suite:testEquippedPlaceholderFallsBackToClass()
	local r = helpers.equippedItemDisplay({
		name = '<= PLACEHOLDER =>',
		class_name = 'AEGS_Javelin_Thruster_Main_01',
	})
	self:assertEquals('AEGS_Javelin_Thruster_Main_01', r.name)
	self:assertEquals('', r.pageLink)
end

function suite:testEquippedPlaceholderNoClassFallsBackToUnknown()
	local r = helpers.equippedItemDisplay({ name = '<= PLACEHOLDER =>' })
	self:assertEquals('Unknown item', r.name)
	self:assertEquals('', r.pageLink)
end

function suite:testEquippedNil()
	self:assertEquals(nil, helpers.equippedItemDisplay(nil))
end

-- normalizePort

function suite:testNormalizeSkipsBlankPort()
	-- No compatible_types, no equipped_item → skipped.
	local r = helpers.normalizePort({ name = 'interior_x' }, 1)
	self:assertEquals(nil, r)
end

function suite:testNormalizeKeepsPortWithCompatTypes()
	local r = helpers.normalizePort({
		name = 'BAR1',
		display_name = '@LOC_EMPTY',
		size = 2,
		sizes = { min = 2, max = 2 },
		type = 'WeaponAttachment',
		compatible_types = { { type = 'WeaponAttachment', sub_types = { 'Barrel' } } },
		editable = false,
	}, 1)
	self:assertEquals('BAR1', r.name)
	self:assertEquals('BAR1', r.displayName)
	self:assertEquals(2, r.sizeMin)
	self:assertEquals(2, r.sizeMax)
	self:assertEquals('WeaponAttachment', r.type)
	self:assertEquals(false, r.editable)
	self:assertEquals(1, #r.compatibleTypes)
	self:assertEquals('WeaponAttachment.Barrel', r.compatibleTypes[1])
	self:assertEquals(nil, r.equippedItem)
	self:assertEquals(0, #r.children)
	-- typeAlias resolves WeaponAttachment → "Weapon attachments" (primary card).
	self:assertEquals('Weapon attachments', r.category.label)
	self:assertEquals(false, r.category.collapsed)
end

function suite:testNormalizeKeepsEquippedWithoutCompatTypes()
	-- Equipped item present, compat types absent → kept (the rule is AND, not OR).
	local r = helpers.normalizePort({
		name = 'p',
		equipped_item = { name = 'M9A Cannon' },
	}, 1)
	self:assertNotEquals(nil, r)
	self:assertEquals('p', r.name)
	self:assertEquals('M9A Cannon', r.equippedItem.name)
end

function suite:testNormalizePassesThroughEquippedUuid()
	local r = helpers.normalizePort({
		name = 'p',
		type = 'WeaponGun',
		compatible_types = { { type = 'WeaponGun' } },
		equipped_item_uuid = 'bf958f42-4f50-46ce-af92-64b08e7f7c19',
		equipped_item = { name = 'M9A Cannon' },
	}, 1)
	self:assertEquals('bf958f42-4f50-46ce-af92-64b08e7f7c19', r._equippedUuid)
end

function suite:testNormalizeOmitsMissingEquippedUuid()
	local r = helpers.normalizePort({
		name = 'p',
		type = 'WeaponGun',
		compatible_types = { { type = 'WeaponGun' } },
		equipped_item = { name = 'M9A Cannon' },
	}, 1)
	self:assertEquals(nil, r._equippedUuid)
end

function suite:testNormalizeUsesSizeFallback()
	local r = helpers.normalizePort({
		name = 'p',
		size = 5,
		type = 'Cooler',
		compatible_types = { { type = 'Cooler' } },
	}, 1)
	self:assertEquals(5, r.sizeMin)
	self:assertEquals(5, r.sizeMax)
end

function suite:testNormalizeEditableDefaultsTrue()
	local r = helpers.normalizePort({
		name = 'p',
		type = 'Cooler',
		compatible_types = { { type = 'Cooler' } },
	}, 1)
	self:assertEquals(true, r.editable)
end

function suite:testNormalizeAdoptsApiCategoryLabel()
	local r = helpers.normalizePort({
		name = 'hardpoint_left_turret',
		type = 'TurretBase',
		category_label = 'Manned Turrets',
		compatible_types = { { type = 'TurretBase' } },
		equipped_item = { name = 'Manned Turret' },
	}, 1)
	self:assertEquals('Manned Turrets', r.category.label)
	self:assertEquals(false, r.category.collapsed)
end

function suite:testNormalizeCollapsedFromApiCategoryLabel()
	local r = helpers.normalizePort({
		name = 'hardpoint_screen',
		type = 'Display',
		category_label = 'Systems',
		compatible_types = { { type = 'Display' } },
	}, 1)
	self:assertEquals('Systems', r.category.label)
	self:assertEquals(true, r.category.collapsed)
end

function suite:testNormalizeRecursesIntoChildren()
	local r = helpers.normalizePort({
		name = 'turret',
		type = 'Turret',
		category_label = 'Turrets',
		compatible_types = { { type = 'Turret' } },
		equipped_item = { name = 'Remote Turret' },
		ports = {
			{
				name = 'gun_left',
				type = 'WeaponGun',
				category_label = 'Weapons',
				compatible_types = { { type = 'WeaponGun', sub_types = { 'Gun' } } },
				equipped_item = { name = 'M9A Cannon' },
			},
		},
	}, 1)
	self:assertEquals(1, #r.children)
	self:assertEquals('gun_left', r.children[1].name)
	self:assertEquals('M9A Cannon', r.children[1].equippedItem.name)
end

function suite:testNormalizeFallsBackToEquippedItemPorts()
	-- Older / item-endpoint shape: children nested under equipped_item.ports.
	local r = helpers.normalizePort({
		name = 'turret',
		type = 'Turret',
		category_label = 'Turrets',
		compatible_types = { { type = 'Turret' } },
		equipped_item = {
			name = 'Remote Turret',
			ports = {
				{
					name = 'gun_left',
					type = 'WeaponGun',
					compatible_types = { { type = 'WeaponGun' } },
					equipped_item = { name = 'M9A Cannon' },
				},
			},
		},
	}, 1)
	self:assertEquals(1, #r.children)
	self:assertEquals('gun_left', r.children[1].name)
end

function suite:testNormalizeRespectsDepthCap()
	local function nestedPort(depth)
		local n = {
			name = 'p' .. depth,
			type = 'X',
			compatible_types = { { type = 'X' } },
			equipped_item = { name = 'e' .. depth },
		}
		if depth < 5 then
			n.ports = { nestedPort(depth + 1) }
		end
		return n
	end
	local r = helpers.normalizePort(nestedPort(1), 1)
	local n2 = r.children[1]
	local n3 = n2.children[1]
	local n4 = n3.children[1]
	self:assertEquals('p4', n4.name)
	self:assertEquals(0, #n4.children) -- depth 4 must not recurse further
end

-- isCollapsedCategory / filterPorts

function suite:testIsCollapsedCategoryBareNode()
	self:assertEquals(true, helpers.isCollapsedCategory({}))
end

function suite:testIsCollapsedCategoryItemPrimary()
	local node = helpers.normalizePort({
		name = 'BAR1',
		compatible_types = { { type = 'WeaponAttachment', sub_types = { 'Barrel' } } },
	}, 1)
	self:assertEquals(false, helpers.isCollapsedCategory(node))
end

function suite:testFilterDropsCollapsedCategory()
	local nodes = {
		helpers.normalizePort({
			name = 'screen',
			type = 'Display',
			category_label = 'Systems',
			compatible_types = { { type = 'Display' } },
		}, 1),
	}
	local filtered = helpers.filterPorts(nodes)
	self:assertEquals(0, #filtered)
end

function suite:testFilterKeepsPrimaryCategory()
	local nodes = {
		helpers.normalizePort({
			name = 'gun',
			type = 'WeaponGun',
			category_label = 'Weapons',
			compatible_types = { { type = 'WeaponGun' } },
			equipped_item = { name = 'M9A Cannon' },
		}, 1),
	}
	local filtered = helpers.filterPorts(nodes)
	self:assertEquals(1, #filtered)
	self:assertEquals('gun', filtered[1].name)
end

function suite:testFilterKeepsUnknownLabelByDefault()
	local nodes = {
		helpers.normalizePort({
			name = 'novel',
			type = 'SomethingNew',
			category_label = 'SomeNewCategory',
			compatible_types = { { type = 'SomethingNew' } },
		}, 1),
	}
	local filtered = helpers.filterPorts(nodes)
	self:assertEquals(1, #filtered)
end

-- narrowChildren — vehicle-only allowlist filter against parent's
-- expandIntoTypes. The end-to-end test exercises the keep path
-- implicitly; these test the drop path explicitly.

function suite:testNarrowDropsChildTypeNotInAllowlist()
	-- A Turret parent (allowlist [Turret, WeaponGun, MissileLauncher])
	-- with a Display child + a WeaponGun child. After narrowing the
	-- Display is gone, the WeaponGun stays.
	local turret = helpers.normalizePort({
		name = 'manned_turret',
		type = 'TurretBase',
		category_label = 'Manned Turrets',
		compatible_types = { { type = 'TurretBase' } },
		equipped_item = { name = 'Manned Turret' },
		ports = {
			{
				name = 'screen',
				type = 'Display',
				compatible_types = { { type = 'Display' } },
				equipped_item = { name = 'Status Screen' },
			},
			{
				name = 'gun',
				type = 'WeaponGun',
				compatible_types = { { type = 'WeaponGun' } },
				equipped_item = { name = 'CF-227' },
			},
		},
	}, 1)
	local narrowed = helpers.narrowChildren({ turret })
	self:assertEquals(1, #narrowed[1].children)
	self:assertEquals('gun', narrowed[1].children[1].name)
end

function suite:testNarrowPassesThroughChildrenWhenNoAllowlist()
	-- A category without expandIntoTypes (e.g. Power Plants) leaves
	-- its children untouched — narrow is a narrowing pass, not a gate.
	local pp = helpers.normalizePort({
		name = 'power',
		type = 'PowerPlant',
		category_label = 'Power Plants',
		compatible_types = { { type = 'PowerPlant' } },
		equipped_item = { name = 'PowerBolt' },
		ports = {
			{
				name = 'sub',
				type = 'AnythingGoes',
				compatible_types = { { type = 'AnythingGoes' } },
				equipped_item = { name = 'Sub' },
			},
		},
	}, 1)
	local narrowed = helpers.narrowChildren({ pp })
	self:assertEquals(1, #narrowed[1].children)
	self:assertEquals('sub', narrowed[1].children[1].name)
end

function suite:testFilterRecursesIntoChildren()
	local input = helpers.normalizePort({
		name = 'turret',
		type = 'Turret',
		category_label = 'Turrets',
		compatible_types = { { type = 'Turret' } },
		equipped_item = { name = 'Manned Turret' },
		ports = {
			{
				name = 'screen',
				type = 'Display',
				category_label = 'Systems',
				compatible_types = { { type = 'Display' } },
			},
			{
				name = 'gun_mount',
				type = 'Turret',
				category_label = 'Turrets',
				compatible_types = { { type = 'Turret' } },
				equipped_item = { name = 'Gimbal Mount' },
			},
		},
	}, 1)
	local filtered = helpers.filterPorts({ input })
	self:assertEquals(1, #filtered)
	self:assertEquals(1, #filtered[1].children)
	self:assertEquals('gun_mount', filtered[1].children[1].name)
end

-- signatureFor / aggregateSiblings

local function makeTurret(name, gunName)
	local raw = {
		name = name,
		type = 'Turret',
		category_label = 'Turrets',
		compatible_types = { { type = 'Turret' } },
		equipped_item = { name = 'Manned Turret' },
	}
	if gunName then
		raw.ports = {
			{
				name = 'gun',
				type = 'WeaponGun',
				category_label = 'Weapons',
				compatible_types = { { type = 'WeaponGun' } },
				equipped_item = { name = gunName },
			},
		}
	end
	return helpers.normalizePort(raw, 1)
end

function suite:testSignatureStableAcrossInstances()
	local a = makeTurret('t1')
	local b = makeTurret('t2')
	self:assertEquals(helpers.signatureFor(a), helpers.signatureFor(b))
end

function suite:testSignatureDistinguishesEquipped()
	local a = helpers.normalizePort({
		name = 't1',
		type = 'Turret',
		category_label = 'Turrets',
		compatible_types = { { type = 'Turret' } },
		equipped_item = { name = 'Manned Turret' },
	}, 1)
	local b = helpers.normalizePort({
		name = 't2',
		type = 'Turret',
		category_label = 'Turrets',
		compatible_types = { { type = 'Turret' } },
		equipped_item = { name = 'Remote Turret' },
	}, 1)
	self:assertNotEquals(helpers.signatureFor(a), helpers.signatureFor(b))
end

function suite:testSignatureDistinguishesCompatibleTypes()
	-- M4A Cannon-style case: both ports have type="" / equipped=nil,
	-- but accept different attachment sub_types. They must NOT aggregate.
	local barrel = helpers.normalizePort({
		name = 'BAR1',
		compatible_types = { { type = 'WeaponAttachment', sub_types = { 'Barrel' } } },
	}, 1)
	local power = helpers.normalizePort({
		name = 'POW',
		compatible_types = { { type = 'WeaponAttachment', sub_types = { 'PowerArray' } } },
	}, 1)
	self:assertNotEquals(helpers.signatureFor(barrel), helpers.signatureFor(power))
end

function suite:testSignatureDistinguishesEditable()
	local a = helpers.normalizePort({
		name = 't1',
		type = 'Cooler',
		category_label = 'Coolers',
		compatible_types = { { type = 'Cooler' } },
		editable = true,
	}, 1)
	local b = helpers.normalizePort({
		name = 't2',
		type = 'Cooler',
		category_label = 'Coolers',
		compatible_types = { { type = 'Cooler' } },
		editable = false,
	}, 1)
	self:assertNotEquals(helpers.signatureFor(a), helpers.signatureFor(b))
end

function suite:testAggregateMergesIdenticalSiblings()
	local agg = helpers.aggregateSiblings({ makeTurret('t1'), makeTurret('t2') })
	self:assertEquals(1, #agg)
	self:assertEquals(2, agg[1].count)
end

function suite:testAggregateSeparatesByInnerGun()
	local agg = helpers.aggregateSiblings({ makeTurret('t1', 'M9A'), makeTurret('t2', 'CF-557') })
	self:assertEquals(2, #agg)
end

function suite:testAggregateRecursesIntoChildren()
	local agg = helpers.aggregateSiblings({ makeTurret('t1', 'M9A'), makeTurret('t2', 'M9A') })
	self:assertEquals(1, #agg)
	self:assertEquals(2, agg[1].count)
	self:assertEquals(1, #agg[1].children)
	self:assertEquals(1, agg[1].children[1].count)
end

function suite:testAggregatePreservesFirstOccurrenceOrder()
	local a = helpers.normalizePort({
		name = 'a',
		type = 'Cooler',
		category_label = 'Coolers',
		compatible_types = { { type = 'Cooler' } },
	}, 1)
	local b = helpers.normalizePort({
		name = 'b',
		type = 'PowerPlant',
		category_label = 'Power Plants',
		compatible_types = { { type = 'PowerPlant' } },
	}, 1)
	local agg = helpers.aggregateSiblings({ b, a, b }) -- B occurs first
	self:assertEquals(2, #agg)
	self:assertEquals('PowerPlant', agg[1].representative.type)
	self:assertEquals(2, agg[1].count)
	self:assertEquals('Cooler', agg[2].representative.type)
end

function suite:testAggregatePrecomputesExpandableTrueForTurret()
	-- Turret category has expandIntoTypes → expandable should be true.
	local t = helpers.normalizePort({
		name = 't',
		type = 'Turret',
		category_label = 'Turrets',
		compatible_types = { { type = 'Turret' } },
		equipped_item = { name = 'Manned Turret' },
	}, 1)
	local agg = helpers.aggregateSiblings({ t })
	self:assertEquals(true, agg[1].expandable)
end

function suite:testAggregatePrecomputesExpandableFalseForWeapon()
	-- Weapons category has no expandIntoTypes → expandable should be false.
	local w = helpers.normalizePort({
		name = 'w',
		type = 'WeaponGun',
		category_label = 'Weapons',
		compatible_types = { { type = 'WeaponGun' } },
		equipped_item = { name = 'M9A' },
	}, 1)
	local agg = helpers.aggregateSiblings({ w })
	self:assertEquals(false, agg[1].expandable)
end

function suite:testAggregateStripsSignatureKey()
	-- signatureKey is an internal implementation detail; not part of the contract.
	local t = makeTurret('t1')
	local agg = helpers.aggregateSiblings({ t })
	self:assertEquals(nil, agg[1].signatureKey)
end

-- groupByCategory

function suite:testGroupSeparatesByLabel()
	local n1 = helpers.normalizePort({
		name = 'remote',
		type = 'Turret',
		category_label = 'Remote Turrets',
		compatible_types = { { type = 'Turret' } },
		equipped_item = { name = 'Remote' },
	}, 1)
	local n2 = helpers.normalizePort({
		name = 'manned',
		type = 'TurretBase',
		category_label = 'Manned Turrets',
		compatible_types = { { type = 'TurretBase' } },
		equipped_item = { name = 'Manned' },
	}, 1)
	local agg = helpers.aggregateSiblings({ n1, n2 })
	local groups = helpers.groupByCategory(agg)
	self:assertEquals(2, #groups)
end

function suite:testGroupSortsByOrder()
	-- Primary cards sort by `order`: Weapons (5) before Shields (30).
	local n1 = helpers.normalizePort({
		name = 'shield',
		category_label = 'Shields',
		compatible_types = { { type = 'Shield' } },
		equipped_item = { name = 'Holdstrong' },
	}, 1)
	local n2 = helpers.normalizePort({
		name = 'gun',
		category_label = 'Weapons',
		compatible_types = { { type = 'WeaponGun' } },
		equipped_item = { name = 'M9A' },
	}, 1)
	local agg = helpers.aggregateSiblings({ n1, n2 })
	local groups = helpers.groupByCategory(agg)
	self:assertEquals('Weapons', groups[1].label)
	self:assertEquals('Shields', groups[2].label)
end

function suite:testGroupMergesCollapsedIntoOtherWithSubGroups()
	local primary = helpers.normalizePort({
		name = 'gun',
		category_label = 'Weapons',
		compatible_types = { { type = 'WeaponGun' } },
		equipped_item = { name = 'M9A' },
	}, 1)
	local controller = helpers.normalizePort({
		name = 'ctrl',
		type = 'WeaponController',
		category_label = 'Controllers',
		compatible_types = { { type = 'WeaponController' } },
	}, 1)
	local door = helpers.normalizePort({
		name = 'door',
		type = 'Door',
		category_label = 'Doors & Hatches',
		compatible_types = { { type = 'Door' } },
	}, 1)
	local agg = helpers.aggregateSiblings({ primary, controller, door })
	local groups = helpers.groupByCategory(agg)
	self:assertEquals(2, #groups)
	self:assertEquals('Weapons', groups[1].label)
	self:assertEquals('Other', groups[2].label)
	self:assertEquals(true, groups[2].collapsed)
	self:assertEquals(2, #groups[2].rows)
	-- subGroups sectionizes the Other body by original category label.
	self:assertEquals(2, #groups[2].subGroups)
	self:assertEquals('Controllers', groups[2].subGroups[1].label)
	self:assertEquals(1, #groups[2].subGroups[1].rows)
	self:assertEquals('Doors & Hatches', groups[2].subGroups[2].label)
	self:assertEquals(1, #groups[2].subGroups[2].rows)
end

function suite:testGroupSendsUnmappedToOwnPrimaryCard()
	local n = helpers.normalizePort({
		name = 'unknown',
		category_label = 'SomeNewCategoryCIGAdded',
		compatible_types = { { type = 'X' } },
	}, 1)
	local agg = helpers.aggregateSiblings({ n })
	local groups = helpers.groupByCategory(agg)
	self:assertEquals(1, #groups)
	self:assertEquals('SomeNewCategoryCIGAdded', groups[1].label)
	self:assertNotEquals(true, groups[1].collapsed)
end

-- pipeline.process — end-to-end contract test

function suite:testProcessEndToEndAuroraShape()
	-- A hand-built rawPorts fixture loosely modelled on Aurora Mk II:
	-- 4 gimbal-mount turrets (each with a CF-227 gun child), 1 missile rack
	-- with 2 missile children, 1 quantum drive with a jump drive child,
	-- 1 power plant, and 1 collapsed-category Door. Tests the full pipeline:
	-- normalize → clean → narrow (vehicle path) → aggregate → group.
	local rawPorts = {}
	for i = 1, 4 do
		table.insert(rawPorts, {
			name = 'turret_' .. i,
			type = 'Turret',
			category_label = 'Turrets',
			size = 2,
			sizes = { min = 2, max = 2 },
			compatible_types = { { type = 'Turret' } },
			equipped_item = { name = 'VariPuck S2 Gimbal Mount', size = 2 },
			ports = {
				{
					name = 'gun',
					type = 'WeaponGun',
					compatible_types = { { type = 'WeaponGun' } },
					equipped_item = { name = 'CF-227 Badger Repeater', size = 2 },
				},
			},
		})
	end
	table.insert(rawPorts, {
		name = 'rack',
		type = 'MissileLauncher',
		category_label = 'Missile & Bomb Racks',
		size = 2,
		compatible_types = { { type = 'MissileLauncher' } },
		equipped_item = { name = 'MSD-221 Missile Rack', size = 2 },
		ports = {
			{
				name = 'm1',
				type = 'Missile',
				compatible_types = { { type = 'Missile' } },
				equipped_item = { name = 'Stalker V Missile' },
			},
			{
				name = 'm2',
				type = 'Missile',
				compatible_types = { { type = 'Missile' } },
				equipped_item = { name = 'Stalker V Missile' },
			},
		},
	})
	table.insert(rawPorts, {
		name = 'quantum',
		type = 'QuantumDrive',
		category_label = 'Quantum Drives',
		size = 1,
		compatible_types = { { type = 'QuantumDrive' } },
		equipped_item = { name = 'Eos', size = 1 },
		ports = {
			{
				name = 'jd',
				type = 'JumpDrive',
				compatible_types = { { type = 'JumpDrive' } },
				equipped_item = { name = 'Explorer' },
			},
		},
	})
	table.insert(rawPorts, {
		name = 'power',
		type = 'PowerPlant',
		category_label = 'Power Plants',
		size = 1,
		compatible_types = { { type = 'PowerPlant' } },
		equipped_item = { name = 'PowerBolt' },
	})
	table.insert(rawPorts, {
		name = 'airlock',
		type = 'Door',
		category_label = 'Doors & Hatches',
		size = 1,
		compatible_types = { { type = 'Door' } },
		equipped_item = { name = 'Door' },
	})

	local groups = pipeline.process(rawPorts, { isVehicle = true })

	-- Primary cards sorted by order: Weapons (5) – none – Turrets (13),
	-- Missile & Bomb Racks (14), Power Plants (33), Quantum Drives (50),
	-- then Other (1000).
	self:assertEquals('Turrets', groups[1].label)
	self:assertEquals(1, #groups[1].rows)
	self:assertEquals(4, groups[1].rows[1].count) -- 4× aggregated
	self:assertEquals(true, groups[1].rows[1].expandable)
	self:assertEquals(1, #groups[1].rows[1].children) -- aggregated CF-227

	self:assertEquals('Missile & Bomb Racks', groups[2].label)
	self:assertEquals(1, #groups[2].rows)
	self:assertEquals(true, groups[2].rows[1].expandable)
	self:assertEquals(1, #groups[2].rows[1].children) -- aggregated Stalker
	self:assertEquals(2, groups[2].rows[1].children[1].count) -- 2× missiles

	self:assertEquals('Power Plants', groups[3].label)
	self:assertEquals(false, groups[3].rows[1].expandable) -- no expandIntoTypes

	self:assertEquals('Quantum Drives', groups[4].label)
	self:assertEquals(true, groups[4].rows[1].expandable)
	self:assertEquals(1, #groups[4].rows[1].children) -- the Explorer jump drive

	self:assertEquals('Other', groups[5].label)
	self:assertEquals(true, groups[5].collapsed)
	self:assertNotEquals(nil, groups[5].subGroups)
	self:assertEquals(1, #groups[5].subGroups)
	self:assertEquals('Doors & Hatches', groups[5].subGroups[1].label)
end

function suite:testProcessItemPathSkipsNarrow()
	-- Items don't run narrowChildren. Build a Turret-like top-level
	-- with a Display child + a WeaponGun child; with isVehicle=false
	-- both children survive (the Display is type-noise, not category-
	-- noise — narrow is the only thing that drops it).
	local rawPorts = {
		{
			name = 'turret',
			type = 'Turret',
			category_label = 'Turrets',
			compatible_types = { { type = 'Turret' } },
			equipped_item = { name = 'Turret' },
			ports = {
				{
					name = 'screen',
					type = 'Display',
					compatible_types = { { type = 'Display' } },
					equipped_item = { name = 'Status Screen' },
				},
				{
					name = 'gun',
					type = 'WeaponGun',
					compatible_types = { { type = 'WeaponGun' } },
					equipped_item = { name = 'CF-227' },
				},
			},
		},
	}

	local vehicleGroups = pipeline.process(rawPorts, { isVehicle = true })
	-- Vehicle path: narrowChildren drops the Display.
	self:assertEquals(1, #vehicleGroups[1].rows[1].children)
	self:assertEquals('gun', vehicleGroups[1].rows[1].children[1].representative.name)

	local itemGroups = pipeline.process(rawPorts, { isVehicle = false })
	-- Item path: narrow is skipped, so the Display survives alongside the gun.
	self:assertEquals(2, #itemGroups[1].rows[1].children)
end

return suite
