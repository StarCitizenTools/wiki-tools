require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local TypeResolver = require('Module:Entity/TypeResolver')
local helpers = TypeResolver._internal

local suite = ScribuntoUnit:new()

-- resolveClassification

function suite:testResolveClassificationLeaf()
	self:assertEquals('PDCs', helpers.resolveClassification('Ship.Turret.PDCTurret').category)
	self:assertEquals('PDC', helpers.resolveClassification('Ship.Turret.PDCTurret').name)
end

function suite:testResolveClassificationRocketNotGun()
	self:assertEquals('Rocket pods', helpers.resolveClassification('Ship.Weapon.Rocket').category)
	self:assertEquals('Rocket pod', helpers.resolveClassification('Ship.Weapon.Rocket').name)
end

function suite:testResolveClassificationGunAndCooler()
	self:assertEquals('Guns', helpers.resolveClassification('Ship.Weapon.Gun').category)
	self:assertEquals('Coolers', helpers.resolveClassification('Ship.Cooler').category)
end

function suite:testResolveClassificationFallsToPrefix()
	self:assertEquals('Turrets', helpers.resolveClassification('Ship.Turret.SomethingNew').category)
end

function suite:testResolveClassificationNonShipOrNil()
	self:assertEquals(nil, helpers.resolveClassification('FPS.Weapon.Medium'))
	self:assertEquals(nil, helpers.resolveClassification(nil))
	self:assertEquals(nil, helpers.resolveClassification(''))
end

-- resolve (classification preferred for items; type-map fallback)

function suite:testResolvePrefersClassification()
	local typeInfo, displayType = TypeResolver.resolve('Turret', 'Ship.Turret.PDCTurret')
	self:assertEquals('PDCs', typeInfo.category)
	self:assertEquals('PDC', typeInfo.name)
	self:assertEquals('PDC', displayType)
end

function suite:testResolveFallsBackToTypeMap()
	-- Real FPS item: no Ship.* classification, so resolveClassification returns
	-- nil and resolve falls back to types.json[type].
	local typeInfo, displayType = TypeResolver.resolve('WeaponPersonal', 'FPS.Weapon.Medium')
	self:assertEquals('Personal weapons', typeInfo.category)
	self:assertEquals('Personal weapon', displayType)
end

return suite
