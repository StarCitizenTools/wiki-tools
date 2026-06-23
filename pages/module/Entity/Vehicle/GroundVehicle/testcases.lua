require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local GroundVehicle = require('Module:Entity/Vehicle/GroundVehicle')

local suite = ScribuntoUnit:new()

function suite:testTypeInfoName()
	local ti = GroundVehicle.getTypeInfo({ is_vehicle = true }, {})
	self:assertEquals('Ground vehicle', ti.name)
end

function suite:testTypeInfoCategory()
	local ti = GroundVehicle.getTypeInfo({ is_vehicle = true }, {})
	self:assertEquals('Ground vehicles', ti.category)
end

function suite:testShortDescriptionWithRoleAndManufacturer()
	-- TMBL has no 'short' in data.json so short falls back to name
	local apiData = { role = 'Combat' }
	local desc = GroundVehicle.getShortDescription(apiData, { manufacturer = 'TMBL' }, {}, nil, {})
	self:assertEquals('Combat ground vehicle by Tumbril Land Systems', desc)
end

function suite:testShortDescriptionWithoutRole()
	local apiData = {}
	local desc = GroundVehicle.getShortDescription(apiData, { manufacturer = 'TMBL' }, {}, nil, {})
	self:assertEquals('ground vehicle by Tumbril Land Systems', desc)
end

function suite:testShortDescriptionWithoutManufacturer()
	local apiData = { role = 'Exploration' }
	local desc = GroundVehicle.getShortDescription(apiData, {}, {}, nil, {})
	self:assertEquals('Exploration ground vehicle', desc)
end

return suite
