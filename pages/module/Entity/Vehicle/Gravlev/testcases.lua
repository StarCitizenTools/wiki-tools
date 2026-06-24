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
	-- DRAK resolves to short='Drake'; size is omitted for gravlevs.
	-- 'racing' not in ROLE_SUFFIXES → appends 'gravlev vehicle'.
	local apiData = { role = 'Racing' }
	local desc = Gravlev.getShortDescription(apiData, { manufacturer = 'DRAK' }, {}, nil, {})
	self:assertEquals('Drake racing gravlev vehicle', desc)
end

function suite:testShortDescriptionWithoutRole()
	-- No role → manufacturer + typeNoun only.
	local apiData = {}
	local desc = Gravlev.getShortDescription(apiData, { manufacturer = 'DRAK' }, {}, nil, {})
	self:assertEquals('Drake gravlev vehicle', desc)
end

function suite:testShortDescriptionWithoutManufacturer()
	-- No manufacturer; 'personal transport' not in ROLE_SUFFIXES → appends 'gravlev vehicle'.
	local apiData = { role = 'Personal transport' }
	local desc = Gravlev.getShortDescription(apiData, {}, {}, nil, {})
	self:assertEquals('Personal transport gravlev vehicle', desc)
end

return suite
