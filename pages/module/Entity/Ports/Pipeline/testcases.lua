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

function suite:testNormalizeAttachedVehicleOverridesEquipped()
	-- A docking collar with a craft docked: show the docked vehicle
	-- (clean name, size_class, uuid for link resolution) instead of the
	-- placeholder docking-tube hardware, and drop the collar's internal
	-- child ports.
	local r = helpers.normalizePort({
		name = 'hardpoint_docking_module',
		type = 'DockingCollar',
		category_label = 'Docked Vehicles',
		compatible_types = { { type = 'DockingCollar' } },
		equipped_item = { name = '<= PLACEHOLDER =>', class_name = 'DRAK_Caterpillar_Command_Module_DockingTube' },
		attached_vehicle = { name = 'Command Module', uuid = 'bdeb88d1-c003-4dfa-942d-5043988e1c68', size_class = 2 },
		ports = {
			{
				name = 'itemport_vehicle_attach',
				type = 'NOITEM_Vehicle',
				compatible_types = { { type = 'NOITEM_Vehicle' } },
				equipped_item = { name = '<= PLACEHOLDER =>' },
			},
		},
	}, 1)
	self:assertEquals('Command Module', r.equippedItem.name)
	self:assertEquals('[[Command Module]]', r.equippedItem.pageLink)
	self:assertEquals(2, r.equippedItem.size)
	self:assertEquals('bdeb88d1-c003-4dfa-942d-5043988e1c68', r._equippedUuid)
	self:assertEquals(0, #r.children)
end

function suite:testNormalizeAttachedVehicleWithoutNameFallsBack()
	-- attached_vehicle present but empty (no craft docked) → normal
	-- equipped-item display, children retained.
	local r = helpers.normalizePort({
		name = 'p',
		type = 'DockingCollar',
		compatible_types = { { type = 'DockingCollar' } },
		equipped_item = { name = 'Docking Collar' },
		attached_vehicle = {},
	}, 1)
	self:assertEquals('Docking Collar', r.equippedItem.name)
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

function suite:testNarrowKeepsTractorBeamInTurret()
	-- A turret holding a tractor beam (e.g. Command Module's remote
	-- tractor turret): the TractorBeam child must survive narrowChildren,
	-- so "TractorBeam" is in the turret categories' expandIntoTypes.
	local turret = helpers.normalizePort({
		name = 'hardpoint_tractor_beam',
		type = 'Turret',
		category_label = 'Remote Turrets',
		compatible_types = { { type = 'Turret' } },
		equipped_item = { name = 'Tractor Beam' },
		ports = {
			{
				name = 'turret_weapon',
				type = 'TractorBeam',
				compatible_types = { { type = 'TractorBeam' } },
				equipped_item = { name = 'SureGrip S2 Tractor Beam' },
			},
		},
	}, 1)
	local narrowed = helpers.narrowChildren({ turret })
	self:assertEquals(1, #narrowed[1].children)
	self:assertEquals('SureGrip S2 Tractor Beam', narrowed[1].children[1].equippedItem.name)
end

function suite:testNarrowKeepsMiningLaserUnderMiningArm()
	-- Prospector: a ToolArm (Mining & Salvage) holds a WeaponMining laser.
	-- "WeaponMining" is in the category's expandIntoTypes, so the laser
	-- survives narrowChildren.
	local arm = helpers.normalizePort({
		name = 'hardpoint_mining_arm',
		type = 'ToolArm',
		category_label = 'Mining & Salvage',
		compatible_types = { { type = 'ToolArm' } },
		equipped_item = { name = 'Mining Arm' },
		ports = {
			{
				name = 'hardpoint_mining_laser',
				type = 'WeaponMining',
				compatible_types = { { type = 'WeaponMining' } },
				equipped_item = { name = 'Arbor MH1 Mining Laser' },
			},
		},
	}, 1)
	local narrowed = helpers.narrowChildren({ arm })
	self:assertEquals(1, #narrowed[1].children)
	self:assertEquals('Arbor MH1 Mining Laser', narrowed[1].children[1].equippedItem.name)
end

function suite:testNarrowKeepsSalvageChainTwoLevels()
	-- Vulture: ToolArm (Mining & Salvage) → SalvageHead → SalvageModifier
	-- modules. SalvageHead aliases to Mining & Salvage so it inherits the
	-- same allowlist (which includes SalvageModifier), letting the modules
	-- survive narrowing two levels deep.
	local arm = helpers.normalizePort({
		name = 'hardpoint_salvage_arm',
		type = 'ToolArm',
		category_label = 'Mining & Salvage',
		compatible_types = { { type = 'ToolArm' } },
		equipped_item = { name = 'Salvage Arm' },
		ports = {
			{
				name = 'hardpoint_salvage_laser',
				type = 'SalvageHead',
				compatible_types = { { type = 'SalvageHead' } },
				equipped_item = { name = 'Baler Salvage Head' },
				ports = {
					{
						name = 'subItem01',
						type = 'SalvageModifier',
						compatible_types = { { type = 'SalvageModifier' } },
						equipped_item = { name = 'Cinch Scraper Module' },
					},
					{
						name = 'subItem02',
						type = 'SalvageModifier',
						compatible_types = { { type = 'SalvageModifier' } },
						equipped_item = { name = 'Abrade Scraper Module' },
					},
				},
			},
		},
	}, 1)
	local narrowed = helpers.narrowChildren({ arm })
	self:assertEquals(1, #narrowed[1].children)
	local head = narrowed[1].children[1]
	self:assertEquals('Baler Salvage Head', head.equippedItem.name)
	self:assertEquals(2, #head.children)
	self:assertEquals('Cinch Scraper Module', head.children[1].equippedItem.name)
	self:assertEquals('Abrade Scraper Module', head.children[2].equippedItem.name)
end

function suite:testNarrowKeepsSalvageHeadUnderRemoteTurret()
	-- Reclaimer: a Remote Turret (Utility) holds a SalvageHead plus a Room
	-- (cockpit interior). "SalvageHead" is in the Remote Turrets allowlist,
	-- "Room" is not — so the head survives and the room is dropped.
	local turret = helpers.normalizePort({
		name = 'hardpoint_remote_turret_salvage',
		type = 'Turret',
		sub_type = 'Utility',
		category_label = 'Remote Turrets',
		compatible_types = { { type = 'Turret' } },
		equipped_item = { name = 'Remote Turret' },
		ports = {
			{
				name = 'hardpoint_weapon_salvage',
				type = 'SalvageHead',
				compatible_types = { { type = 'SalvageHead' } },
				equipped_item = { name = 'Baler Salvage Head' },
			},
			{
				name = 'hardpoint_interior',
				type = 'Room',
				compatible_types = { { type = 'Room' } },
				equipped_item = { name = 'Interior' },
			},
		},
	}, 1)
	local narrowed = helpers.narrowChildren({ turret })
	self:assertEquals(1, #narrowed[1].children)
	self:assertEquals('Baler Salvage Head', narrowed[1].children[1].equippedItem.name)
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

function suite:testAggregatePrecomputesExpandableTrueForWeapon()
	-- Weapons category has expandIntoTypes: ["WeaponGun"] (added so weapon-mount
	-- item pages show the inner gun slot as an L-tree child). expandable = true.
	local w = helpers.normalizePort({
		name = 'w',
		type = 'WeaponGun',
		category_label = 'Weapons',
		compatible_types = { { type = 'WeaponGun' } },
		equipped_item = { name = 'M9A' },
	}, 1)
	local agg = helpers.aggregateSiblings({ w })
	self:assertEquals(true, agg[1].expandable)
end

function suite:testAggregatePrecomputesExpandableFalseForLeafCategory()
	-- A category with no expandIntoTypes (Coolers) → expandable false.
	local c = helpers.normalizePort({
		name = 'c',
		type = 'Cooler',
		category_label = 'Coolers',
		compatible_types = { { type = 'Cooler' } },
		equipped_item = { name = 'Snowfall' },
	}, 1)
	local agg = helpers.aggregateSiblings({ c })
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
	-- Items don't run narrowChildren. Build a Turret top-level with a
	-- WeaponAttachment child + a WeaponGun child. The attachment maps to
	-- the primary "Weapon attachments" category, so filterPorts keeps it;
	-- its type is outside the Turret allowlist
	-- [Turret, WeaponGun, MissileLauncher], so narrow — and only narrow —
	-- drops it. (A collapsed-category child like a Display would be dropped
	-- by filterPorts on both paths, so it can't isolate narrow's effect.)
	local rawPorts = {
		{
			name = 'turret',
			type = 'Turret',
			category_label = 'Turrets',
			compatible_types = { { type = 'Turret' } },
			equipped_item = { name = 'Turret' },
			ports = {
				{
					name = 'attach',
					type = 'WeaponAttachment',
					compatible_types = { { type = 'WeaponAttachment', sub_types = { 'Barrel' } } },
					equipped_item = { name = 'Sawtooth Barrel' },
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
	-- Vehicle path: narrowChildren drops the WeaponAttachment (not in the allowlist).
	self:assertEquals(1, #vehicleGroups[1].rows[1].children)
	self:assertEquals('gun', vehicleGroups[1].rows[1].children[1].representative.name)

	local itemGroups = pipeline.process(rawPorts, { isVehicle = false })
	-- Item path: narrow is skipped, so the attachment survives alongside the gun.
	self:assertEquals(2, #itemGroups[1].rows[1].children)
end

function suite:testProcessExpandsSalvageChainTwoLevels()
	-- Full vehicle pipeline over a Vulture-style salvage arm: the arm
	-- expands its salvage head, and the head expands its modules. Both
	-- levels must report expandable=true so Render walks the L-tree down
	-- to the modules.
	local rawPorts = {
		{
			name = 'hardpoint_salvage_arm',
			type = 'ToolArm',
			category_label = 'Mining & Salvage',
			size = 2,
			compatible_types = { { type = 'ToolArm' } },
			equipped_item = { name = 'Salvage Arm', size = 2 },
			ports = {
				{
					name = 'hardpoint_salvage_laser',
					type = 'SalvageHead',
					compatible_types = { { type = 'SalvageHead' } },
					equipped_item = { name = 'Baler Salvage Head' },
					ports = {
						{
							name = 'subItem01',
							type = 'SalvageModifier',
							compatible_types = { { type = 'SalvageModifier' } },
							equipped_item = { name = 'Cinch Scraper Module' },
						},
						{
							name = 'subItem02',
							type = 'SalvageModifier',
							compatible_types = { { type = 'SalvageModifier' } },
							equipped_item = { name = 'Abrade Scraper Module' },
						},
					},
				},
			},
		},
	}
	local groups = pipeline.process(rawPorts, { isVehicle = true })
	self:assertEquals('Mining & Salvage', groups[1].label)
	local arm = groups[1].rows[1]
	self:assertEquals(true, arm.expandable)
	self:assertEquals(1, #arm.children)
	local head = arm.children[1]
	self:assertEquals('Baler Salvage Head', head.representative.equippedItem.name)
	self:assertEquals(true, head.expandable) -- head inherits Mining & Salvage allowlist
	self:assertEquals(2, #head.children) -- both modules survive
end

-- collectEquippedUuids / applyResolvedLinks

local function fakeGroups()
	return {
		{
			label = 'Weapons',
			rows = {
				{
					representative = {
						_equippedUuid = 'uuid-a',
						equippedItem = { name = 'M2C "Swarm"', pageLink = '[[M2C "Swarm"]]' },
					},
					children = {
						{
							representative = {
								_equippedUuid = 'uuid-b',
								equippedItem = { name = 'BEHR Gun', pageLink = '' },
							},
							children = {},
						},
						{
							representative = {
								_equippedUuid = 'uuid-a',
								equippedItem = { name = 'M2C "Swarm"', pageLink = '[[M2C "Swarm"]]' },
							},
							children = {},
						},
					},
				},
			},
		},
	}
end

function suite:testCollectEquippedUuidsDistinct()
	local uuids = pipeline.collectEquippedUuids(fakeGroups())
	table.sort(uuids)
	self:assertEquals(2, #uuids)
	self:assertEquals('uuid-a', uuids[1])
	self:assertEquals('uuid-b', uuids[2])
end

function suite:testApplyResolvedLinksRewritesWithNameLabel()
	local groups = fakeGroups()
	pipeline.applyResolvedLinks(groups, { ['uuid-a'] = { page = 'Mauler PDC Turret' } })
	self:assertEquals('[[Mauler PDC Turret|M2C "Swarm"]]', groups[1].rows[1].representative.equippedItem.pageLink)
end

function suite:testApplyResolvedLinksUnresolvedUntouched()
	local groups = fakeGroups()
	pipeline.applyResolvedLinks(groups, {})
	self:assertEquals('[[M2C "Swarm"]]', groups[1].rows[1].representative.equippedItem.pageLink)
end

function suite:testApplyResolvedLinksPlaceholderUsesPageLabel()
	local groups = fakeGroups()
	pipeline.applyResolvedLinks(groups, { ['uuid-b'] = { page = 'BEHR Repeater' } })
	self:assertEquals('[[BEHR Repeater]]', groups[1].rows[1].children[1].representative.equippedItem.pageLink)
end

return suite
