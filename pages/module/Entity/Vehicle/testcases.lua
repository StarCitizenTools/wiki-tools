require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Vehicle = require('Module:Entity/Vehicle')

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

function suite:testMatchesVehicleShapedDataReturnsTrue()
	self:assertEquals(true, Vehicle.matches({ uuid = 'abc-123', is_vehicle = true }))
end

function suite:testMatchesIsVehicleFalseReturnsFalse()
	self:assertEquals(false, Vehicle.matches({ uuid = 'abc-123', is_vehicle = false }))
end

return suite
