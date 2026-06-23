require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Vehicle = require('Module:Entity/Vehicle')
local Ship = require('Module:Entity/Vehicle/Ship')
local GroundVehicle = require('Module:Entity/Vehicle/GroundVehicle')
local Gravlev = require('Module:Entity/Vehicle/Gravlev')

local suite = ScribuntoUnit:new()

function suite:testMatchesNilReturnsFalse()
	self:assertEquals(false, Vehicle.matches(nil))
end

function suite:testMatchesEmptyTableReturnsFalse()
	self:assertEquals(false, Vehicle.matches({}))
end

function suite:testMatchesItemShapedDataReturnsFalse()
	self:assertEquals(false, Vehicle.matches({ uuid = 'abc-123', type = 'Food' }))
end

function suite:testMatchesUuidWithoutIsVehicleReturnsFalse()
	self:assertEquals(false, Vehicle.matches({ uuid = 'abc-123' }))
end

function suite:testMatchesGroundVehicleReturnsTrue()
	self:assertEquals(true, Vehicle.matches({ uuid = 'abc-123', is_vehicle = true }))
end

-- is_vehicle is a family discriminator (ground vehicle vs spaceship vs
-- gravlev), not a generic vehicle flag. Spaceships carry is_vehicle=false
-- but still belong to the vehicle kind — presence of the key is what
-- discriminates a vehicle response from an item response.
function suite:testMatchesSpaceshipReturnsTrue()
	self:assertEquals(true, Vehicle.matches({ uuid = 'abc-123', is_vehicle = false, is_spaceship = true }))
end

function suite:testResolveSubtypeSpaceship()
	self:assertEquals(Ship, Vehicle.resolveSubtype({ is_spaceship = true, is_vehicle = false }))
end

function suite:testResolveSubtypeGroundVehicle()
	self:assertEquals(GroundVehicle, Vehicle.resolveSubtype({ is_vehicle = true }))
end

function suite:testResolveSubtypeGravlevBeatsGroundVehicle()
	self:assertEquals(Gravlev, Vehicle.resolveSubtype({ is_gravlev = true, is_vehicle = true }))
end

function suite:testResolveSubtypeNilWhenNoFamily()
	self:assertEquals(nil, Vehicle.resolveSubtype({ uuid = 'x' }))
end

function suite:testResolveSubtypeNilWhenNotTable()
	self:assertEquals(nil, Vehicle.resolveSubtype(nil))
end

return suite
