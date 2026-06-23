require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Gravlev = require('Module:Entity/Vehicle/Gravlev')

local suite = ScribuntoUnit:new()

function suite:testTypeInfoName()
	local ti = Gravlev.getTypeInfo({ is_gravlev = true }, {})
	self:assertEquals('Gravlev', ti.name)
end

function suite:testTypeInfoCategory()
	local ti = Gravlev.getTypeInfo({ is_gravlev = true }, {})
	self:assertEquals('Gravlevs', ti.category)
end

function suite:testShortDescriptionWithRoleAndManufacturer()
	-- DRAK has short='Drake' in data.json
	local apiData = { role = 'Racing' }
	local desc = Gravlev.getShortDescription(apiData, { manufacturer = 'DRAK' }, {}, nil, {})
	self:assertEquals('Racing gravlev by Drake', desc)
end

function suite:testShortDescriptionWithoutRole()
	local apiData = {}
	local desc = Gravlev.getShortDescription(apiData, { manufacturer = 'DRAK' }, {}, nil, {})
	self:assertEquals('gravlev by Drake', desc)
end

function suite:testShortDescriptionWithoutManufacturer()
	local apiData = { role = 'Personal transport' }
	local desc = Gravlev.getShortDescription(apiData, {}, {}, nil, {})
	self:assertEquals('Personal transport gravlev', desc)
end

return suite
