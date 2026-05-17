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
