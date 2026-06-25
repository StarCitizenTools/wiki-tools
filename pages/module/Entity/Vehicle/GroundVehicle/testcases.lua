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
	-- TMBL resolves to short='Tumbril'; size is omitted for ground vehicles.
	-- 'combat' not in ROLE_SUFFIXES → appends 'ground vehicle'.
	local apiData = { role = 'Combat' }
	local desc = GroundVehicle.getShortDescription(apiData, { manufacturer = 'TMBL' }, {}, nil, {})
	self:assertEquals('Tumbril combat ground vehicle', desc)
end

function suite:testShortDescriptionWithoutRole()
	-- No role → manufacturer + typeNoun only.
	local apiData = {}
	local desc = GroundVehicle.getShortDescription(apiData, { manufacturer = 'TMBL' }, {}, nil, {})
	self:assertEquals('Tumbril ground vehicle', desc)
end

function suite:testShortDescriptionWithoutManufacturer()
	-- No manufacturer; 'exploration' not in ROLE_SUFFIXES → appends 'ground vehicle'.
	local apiData = { role = 'Exploration' }
	local desc = GroundVehicle.getShortDescription(apiData, {}, {}, nil, {})
	self:assertEquals('Exploration ground vehicle', desc)
end

function suite:testFamilyTag()
	self:assertEquals('ground', GroundVehicle.family)
end

return suite
