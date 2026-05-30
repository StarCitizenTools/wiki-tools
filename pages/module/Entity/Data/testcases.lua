require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Data = require('Module:Entity/Data')
local helpers = Data._internal

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

-- resolveType (classification preferred for items; type-map fallback)

function suite:testResolveTypePrefersClassification()
	local typeInfo, displayType = helpers.resolveType('Turret', 'Ship.Turret.PDCTurret')
	self:assertEquals('PDCs', typeInfo.category)
	self:assertEquals('PDC', typeInfo.name)
	self:assertEquals('PDC', displayType)
end

function suite:testResolveTypeFallsBackToTypeMap()
	-- Real FPS item: no Ship.* classification, so resolveClassification returns
	-- nil and resolveType falls back to types.json[type].
	local typeInfo, displayType = helpers.resolveType('WeaponPersonal', 'FPS.Weapon.Medium')
	self:assertEquals('Personal weapons', typeInfo.category)
	self:assertEquals('Personal weapon', displayType)
end

-- detectFacets (facet registry detection)

function suite:testDetectFacetsConsumable()
	local facets = helpers.detectFacets({ food = {} })
	self:assertEquals(1, #facets)
	self:assertTrue(facets[1].matches({ food = {} }))
end

function suite:testDetectFacetsNoneWhenNoFood()
	self:assertEquals(0, #helpers.detectFacets({}))
end

function suite:testDetectFacetsNilSafe()
	self:assertEquals(0, #helpers.detectFacets(nil))
end

return suite
