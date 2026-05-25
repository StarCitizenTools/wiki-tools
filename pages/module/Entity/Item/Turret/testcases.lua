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

-- humanizeRotation

function suite:testHumanizeRotationSplitsCamel()
	self:assertEquals('Single Axis', helpers.humanizeRotation('SingleAxis'))
end

function suite:testHumanizeRotationDualAxis()
	self:assertEquals('Dual Axis', helpers.humanizeRotation('DualAxis'))
end

function suite:testHumanizeRotationNoBoundary()
	self:assertEquals('Fixed', helpers.humanizeRotation('Fixed'))
end

function suite:testHumanizeRotationNilEmpty()
	self:assertEquals(nil, helpers.humanizeRotation(nil))
	self:assertEquals(nil, helpers.humanizeRotation(''))
end

-- buildTurretSection

function suite:testBuildTurretSectionPdc()
	-- M2C shape: rotation + mounts, axis speeds null.
	local section = helpers.buildTurretSection({
		rotation_style = 'SingleAxis',
		mounts = 1,
		yaw_axis = { speed = nil },
		pitch_axis = { speed = nil },
	})
	self:assertEquals('turret', section.key)
	self:assertEquals('Turret', section.label)
	self:assertEquals(true, section.collapsible)
	self:assertEquals(2, #section.items)
	self:assertEquals('Rotation', section.items[1].label)
	self:assertEquals('Single Axis', section.items[1].content)
	self:assertEquals('Mounts', section.items[2].label)
	self:assertEquals('1', section.items[2].content)
end

function suite:testBuildTurretSectionWithSpeeds()
	local section = helpers.buildTurretSection({
		rotation_style = 'DualAxis',
		mounts = 2,
		yaw_axis = { speed = 20 },
		pitch_axis = { speed = 15 },
	})
	self:assertEquals(4, #section.items)
	self:assertEquals('Yaw speed', section.items[3].label)
	self:assertEquals('20 °/s', section.items[3].content)
	self:assertEquals('Pitch speed', section.items[4].label)
	self:assertEquals('15 °/s', section.items[4].content)
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

return suite
