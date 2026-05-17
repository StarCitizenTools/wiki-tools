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

function suite:testResolveSubtypeFoodReturnsFoodModule()
	local result = Item.resolveSubtype({ type = 'Food' })
	self:assertEquals(require('Module:Entity/Item/Food'), result)
end

function suite:testResolveSubtypeDrinkReturnsDrinkModule()
	local result = Item.resolveSubtype({ type = 'Drink' })
	self:assertEquals(require('Module:Entity/Item/Drink'), result)
end

function suite:testResolveSubtypeWeaponPersonalReturnsModule()
	local result = Item.resolveSubtype({ type = 'WeaponPersonal' })
	self:assertEquals(require('Module:Entity/Item/WeaponPersonal'), result)
end

function suite:testResolveSubtypeUnknownTypeReturnsNil()
	self:assertNil(Item.resolveSubtype({ type = 'BogusUnknownType' }))
end

function suite:testResolveSubtypeMissingTypeReturnsNil()
	self:assertNil(Item.resolveSubtype({}))
end

function suite:testResolveSubtypeNilApiDataReturnsNil()
	self:assertNil(Item.resolveSubtype(nil))
end

return suite
