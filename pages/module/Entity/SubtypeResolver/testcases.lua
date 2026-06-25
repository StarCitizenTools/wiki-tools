require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local SubtypeResolver = require('Module:Entity/SubtypeResolver')

local suite = ScribuntoUnit:new()

-- A map whose values are real, requirable modules keeps the test offline-safe.
local MAP = { ship = 'Entity/Vehicle/Ship', ground = 'Entity/Vehicle/GroundVehicle' }

function suite:testResolvesMappedToken()
	self:assertEquals(require('Module:Entity/Vehicle/Ship'), SubtypeResolver.resolve('ship', MAP))
end

function suite:testNilWhenUnmapped()
	self:assertEquals(nil, SubtypeResolver.resolve('nope', MAP))
end

function suite:testNilWhenTokenNilOrEmpty()
	self:assertEquals(nil, SubtypeResolver.resolve(nil, MAP))
	self:assertEquals(nil, SubtypeResolver.resolve('', MAP))
end

return suite
