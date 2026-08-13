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
	local result = Item.getStructuredData({
		size = 3,
		grade = 'A',
		rarity = 'Rare',
		description_data = { { name = 'Item Type', value = 'Laser Repeater' } },
	}, {})
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
	local a = Item.getAcquisition({ uex_prices = { purchase = { { price_buy = 500 } } }, is_lootable = true }, {})
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

return suite
