require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local suite = ScribuntoUnit:new()
local Turret = require('Module:Entity/Item/Turret')
local helpers = Turret._internal

-- A vehicle_weapon block shaped like the PDC's embedded gun. Enough for
-- WeaponGun.getVehicleWeaponSections to yield a non-empty Weapon section.
local function gunVehicleWeapon()
	return {
		type = 'Laser Turret',
		capacity = 0,
		range = 1605,
		rpm = 1000,
		damage = { alpha_total = 10, burst = 166.7 },
		ammunition = { speed = 1500 },
		modes = { { mode = 'Single' } },
	}
end

-- buildTurretSection

function suite:testBuildTurretSectionPdc()
	-- M2C shape: rotation_style is present in the API but intentionally not
	-- surfaced (the SingleAxis value doesn't correspond to whether a turret
	-- has one or two functional axes). Only Mounts renders when speeds null.
	local section = helpers.buildTurretSection({
		rotation_style = 'SingleAxis',
		mounts = 1,
		yaw_axis = { speed = nil },
		pitch_axis = { speed = nil },
	})
	self:assertEquals('turret', section.key)
	self:assertEquals('Turret', section.label)
	self:assertEquals(true, section.collapsible)
	self:assertEquals(1, #section.items)
	self:assertEquals('Mounts', section.items[1].label)
	self:assertEquals('1', section.items[1].content)
end

function suite:testBuildTurretSectionWithSpeeds()
	local section = helpers.buildTurretSection({
		rotation_style = 'DualAxis',
		mounts = 2,
		yaw_axis = { speed = 20 },
		pitch_axis = { speed = 15 },
	})
	self:assertEquals(3, #section.items)
	self:assertEquals('Mounts', section.items[1].label)
	self:assertEquals('Yaw speed', section.items[2].label)
	self:assertEquals('20 °/s', section.items[2].content)
	self:assertEquals('Pitch speed', section.items[3].label)
	self:assertEquals('15 °/s', section.items[3].content)
end

function suite:testBuildTurretSectionEmpty()
	self:assertEquals(nil, helpers.buildTurretSection({}))
	self:assertEquals(nil, helpers.buildTurretSection(nil))
end

-- findLockedWeapon

function suite:testFindLockedWeaponPdc()
	local vw = gunVehicleWeapon()
	local found = helpers.findLockedWeapon({
		ports = {
			{ name = 'hardpoint_turret_weapon', editable = false, equipped_item = { vehicle_weapon = vw } },
		},
	})
	self:assertEquals(vw, found)
end

function suite:testFindLockedWeaponGimbalEmpty()
	self:assertEquals(
		nil,
		helpers.findLockedWeapon({
			ports = { { name = 'hardpoint_class_2', editable = true, equipped_item = nil } },
		})
	)
end

function suite:testFindLockedWeaponEditableGunNotLocked()
	self:assertEquals(
		nil,
		helpers.findLockedWeapon({
			ports = { { editable = true, equipped_item = { vehicle_weapon = gunVehicleWeapon() } } },
		})
	)
end

function suite:testFindLockedWeaponNoPorts()
	self:assertEquals(nil, helpers.findLockedWeapon({}))
end

function suite:testFindLockedWeaponNilEditableTreatedAsEditable()
	-- editable key absent → the API treats the port as editable, so not "locked".
	self:assertEquals(
		nil,
		helpers.findLockedWeapon({
			ports = { { equipped_item = { vehicle_weapon = gunVehicleWeapon() } } },
		})
	)
end

-- getSections

function suite:testGetSectionsPdcTurretAndWeapon()
	local sections = Turret.getSections({
		turret = { rotation_style = 'SingleAxis', mounts = 1 },
		ports = { { editable = false, equipped_item = { vehicle_weapon = gunVehicleWeapon() } } },
	}, {})
	self:assertEquals(2, #sections)
	self:assertEquals('Turret', sections[1].label)
	self:assertEquals('Weapon', sections[2].label)
end

function suite:testGetSectionsGimbalTurretOnly()
	local sections = Turret.getSections({
		turret = { rotation_style = 'SingleAxis', mounts = 1 },
		ports = { { editable = true, equipped_item = nil } },
	}, {})
	self:assertEquals(1, #sections)
	self:assertEquals('Turret', sections[1].label)
end

function suite:testGetSectionsNoTurretBlockReturnsEmpty()
	-- No turret block and no locked gun → the module contributes no sections.
	self:assertEquals(0, #Turret.getSections({}, {}))
end

-- getStructuredData

function suite:testGetStructuredDataWithBothSpeeds()
	-- Standalone gimbal mount (VariPuck) shape: outer turret block has the speeds.
	local data = Turret.getStructuredData({
		turret = { yaw_axis = { speed = 80 }, pitch_axis = { speed = 60 } },
	}, {})
	self:assertEquals(80, data.yaw_speed)
	self:assertEquals(60, data.pitch_speed)
end

function suite:testGetStructuredDataNullSpeedsAreNil()
	-- Housing turrets (TMSB-5, Anvil ball/nose, PDCs): outer speeds are null;
	-- we do NOT fall back to the inner equipped gimbal mount, per the
	-- "store only outer" policy. Partial coverage is honest.
	local data = Turret.getStructuredData({
		turret = { yaw_axis = { speed = nil }, pitch_axis = { speed = nil } },
	}, {})
	self:assertEquals(nil, data.yaw_speed)
	self:assertEquals(nil, data.pitch_speed)
end

function suite:testGetStructuredDataMissingTurretBlock()
	local data = Turret.getStructuredData({}, {})
	self:assertEquals(nil, data.yaw_speed)
	self:assertEquals(nil, data.pitch_speed)
end

function suite:testGetStructuredDataMissingOneAxis()
	-- Defensive: if the API ever ships only one axis populated, the other
	-- comes back nil without erroring.
	local data = Turret.getStructuredData({
		turret = { yaw_axis = { speed = 80 } },
	}, {})
	self:assertEquals(80, data.yaw_speed)
	self:assertEquals(nil, data.pitch_speed)
end

return suite
