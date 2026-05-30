require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Item = require('Module:Entity/Item')

local suite = ScribuntoUnit:new()

-- matches()

function suite:testMatchesNilReturnsFalse()
	self:assertEquals(false, Item.matches(nil))
end

function suite:testMatchesEmptyTableReturnsFalse()
	self:assertEquals(false, Item.matches({}))
end

function suite:testMatchesUuidPresentReturnsTrue()
	self:assertEquals(true, Item.matches({ uuid = 'abc-123' }))
end

function suite:testMatchesUuidWithItemTypeReturnsTrue()
	self:assertEquals(true, Item.matches({ uuid = 'abc-123', type = 'Food' }))
end

-- Documents current permissive behavior: Item.matches doesn't check
-- `is_vehicle`. The items endpoint never returns is_vehicle in practice
-- (Apiunto doesn't follow the items→vehicles redirect), so this is
-- safe. If Apiunto ever changes to follow the redirect, tighten matches
-- to also check `not apiData.is_vehicle` and flip this assertion.
function suite:testMatchesVehicleShapedDataCurrentlyReturnsTrue()
	self:assertEquals(true, Item.matches({ uuid = 'abc-123', is_vehicle = true }))
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

function suite:testResolveSubtypeWeaponPersonalReturnsModule()
	local result = Item.resolveSubtype({ type = 'WeaponPersonal' })
	self:assertEquals(require('Module:Entity/Item/WeaponPersonal'), result)
end

function suite:testResolveSubtypeTurretReturnsTurretModule()
	local result = Item.resolveSubtype({ type = 'Turret' })
	self:assertEquals(require('Module:Entity/Item/Turret'), result)
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

-- getSections (number formatting)

function suite:testGetSectionsFormatsVolumeAndMass()
	local sections = Item.getSections({
		mass = 150,
		dimension = { volume_converted = 756000, volume_converted_unit = 'µSCU' },
	}, {})

	local function findItem(items, label)
		for _, item in ipairs(items or {}) do
			if item.label == label then
				return item
			end
		end
		return nil
	end

	local general = sections[1].items
	self:assertEquals('756,000 µSCU', findItem(general, 'Volume').content)
	self:assertEquals('150 kg', findItem(general, 'Mass').content)
end

-- getStructuredData

function suite:testGetStructuredData()
	local result = Item.getStructuredData({
		size = 3,
		grade = 'A',
		description_data = { { name = 'Item Type', value = 'Laser Repeater' } },
	}, {})
	self:assertEquals(3, result.size)
	self:assertEquals('A', result.grade)
	self:assertEquals('Laser Repeater', result.item_type)
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

return suite
