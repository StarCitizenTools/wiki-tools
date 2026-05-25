require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local WeaponGun = require('Module:Entity/Item/WeaponGun')
local Item = require('Module:Entity/Item')

local suite = ScribuntoUnit:new()

-- Attrition-3 Repeater shape (energy weapon, capacity 0, one mode).
local function fixture()
	return {
		type = 'Laser Repeater',
		rpm = 350,
		range = 1924,
		capacity = 0,
		damage = { burst = 501.7, alpha_total = 86 },
		ammunition = { speed = 1480 },
		modes = {
			{ mode = 'Single', rpm = 350, damage_per_second = 501.7, pellets_per_shot = 1, ammo_per_shot = 1 },
		},
	}
end

local function findSection(sections, key)
	for _, section in ipairs(sections) do
		if section.key == key then
			return section
		end
	end
	return nil
end

local function findItem(items, label)
	for _, item in ipairs(items or {}) do
		if item.label == label then
			return item
		end
	end
	return nil
end

-- getVehicleWeaponSections()

function suite:testNilReturnsEmpty()
	self:assertEquals(0, #WeaponGun.getVehicleWeaponSections(nil))
end

function suite:testEmptyTableReturnsEmpty()
	self:assertEquals(0, #WeaponGun.getVehicleWeaponSections({}))
end

function suite:testWeaponSectionPresent()
	local sections = WeaponGun.getVehicleWeaponSections(fixture())
	local weapon = findSection(sections, 'vehicle_weapon')
	self:assertNotEquals(nil, weapon)
	self:assertEquals('Weapon', weapon.label)
	self:assertEquals('Laser Repeater', findItem(weapon.items, 'Type').content)
	self:assertEquals('86', findItem(weapon.items, 'Damage').content)
	self:assertEquals('501.7', findItem(weapon.items, 'DPS').content)
	self:assertEquals('350 RPM', findItem(weapon.items, 'Fire rate').content)
	self:assertEquals('Single', findItem(weapon.items, 'Fire mode').content)
	self:assertEquals('1,924 m', findItem(weapon.items, 'Range').content)
	self:assertEquals('1,480 m/s', findItem(weapon.items, 'Speed').content)
end

function suite:testNoAmmoWhenCapacityZero()
	local sections = WeaponGun.getVehicleWeaponSections(fixture())
	local weapon = findSection(sections, 'vehicle_weapon')
	self:assertEquals(nil, findItem(weapon.items, 'Ammo'))
end

function suite:testAmmoShownWhenCapacityPositive()
	local vw = fixture()
	vw.capacity = 200
	local sections = WeaponGun.getVehicleWeaponSections(vw)
	local weapon = findSection(sections, 'vehicle_weapon')
	self:assertEquals('200', findItem(weapon.items, 'Ammo').content)
end

function suite:testPartialDataOmitsMissingRows()
	local sections = WeaponGun.getVehicleWeaponSections({
		type = 'Laser Cannon',
		damage = { alpha_total = 200 },
	})
	local weapon = findSection(sections, 'vehicle_weapon')
	self:assertEquals('Laser Cannon', findItem(weapon.items, 'Type').content)
	self:assertEquals('200', findItem(weapon.items, 'Damage').content)
	self:assertEquals(nil, findItem(weapon.items, 'Speed'))
end

function suite:testMultipleFireModesJoined()
	local vw = fixture()
	vw.modes = { { mode = 'Single' }, { mode = 'Burst' } }
	local sections = WeaponGun.getVehicleWeaponSections(vw)
	local weapon = findSection(sections, 'vehicle_weapon')
	self:assertEquals('Single, Burst', findItem(weapon.items, 'Fire mode').content)
end

function suite:testNoFireModeRowWhenAbsent()
	local vw = fixture()
	vw.modes = nil
	local sections = WeaponGun.getVehicleWeaponSections(vw)
	local weapon = findSection(sections, 'vehicle_weapon')
	self:assertEquals(nil, findItem(weapon.items, 'Fire mode'))
	-- Fire modes are a row in the Weapon section, not a separate section.
	self:assertEquals(nil, findSection(sections, 'modes'))
end

function suite:testFormatsLargeNumbersWithSeparator()
	local vw = fixture()
	vw.range = 12500
	local sections = WeaponGun.getVehicleWeaponSections(vw)
	local weapon = findSection(sections, 'vehicle_weapon')
	self:assertEquals('12,500 m', findItem(weapon.items, 'Range').content)
end

function suite:testGetSectionsForwardsToVehicleWeapon()
	local result = WeaponGun.getSections({ vehicle_weapon = fixture() }, {})
	self:assertNotEquals(nil, findSection(result, 'vehicle_weapon'))
end

-- getStructuredData()

function suite:testStructuredData()
	local result = WeaponGun.getStructuredData({ vehicle_weapon = fixture() })
	self:assertEquals(501.7, result.dps)
	self:assertEquals(86, result.alpha_damage)
	self:assertEquals(1924, result.max_range)
	self:assertEquals(1480, result.muzzle_velocity)
	self:assertEquals(350, result.fire_rate)
end

function suite:testStructuredDataNilSafe()
	self:assertEquals('table', type(WeaponGun.getStructuredData({})))
end

-- wiring

function suite:testResolveSubtypeReturnsWeaponGun()
	self:assertEquals(WeaponGun, Item.resolveSubtype({ type = 'WeaponGun' }))
end

return suite
