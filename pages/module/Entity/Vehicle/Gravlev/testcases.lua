require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Gravlev = require('Module:Entity/Vehicle/Gravlev')

local suite = ScribuntoUnit:new()

function suite:testTypeInfoName()
	local ti = Gravlev.getTypeInfo({ is_gravlev = true }, {})
	self:assertEquals('Grav-lev vehicle', ti.name)
end

function suite:testTypeInfoCategory()
	local ti = Gravlev.getTypeInfo({ is_gravlev = true }, {})
	self:assertEquals('Grav-lev vehicles', ti.category)
end

function suite:testShortDescriptionWithRoleAndManufacturer()
	-- DRAK resolves to short='Drake'; size is omitted for gravlevs.
	-- 'racing' not in ROLE_SUFFIXES → appends 'grav-lev vehicle'.
	local apiData = { role = 'Racing' }
	local desc = Gravlev.getShortDescription(apiData, { manufacturer = 'DRAK' }, {}, nil, {})
	self:assertEquals('Drake racing grav-lev vehicle', desc)
end

function suite:testShortDescriptionWithoutRole()
	-- No role → manufacturer + typeNoun only.
	local apiData = {}
	local desc = Gravlev.getShortDescription(apiData, { manufacturer = 'DRAK' }, {}, nil, {})
	self:assertEquals('Drake grav-lev vehicle', desc)
end

function suite:testShortDescriptionWithoutManufacturer()
	-- No manufacturer; 'personal transport' not in ROLE_SUFFIXES → appends 'grav-lev vehicle'.
	local apiData = { role = 'Personal transport' }
	local desc = Gravlev.getShortDescription(apiData, {}, {}, nil, {})
	self:assertEquals('Personal transport grav-lev vehicle', desc)
end

function suite:testFamilyTag()
	self:assertEquals('gravlev', Gravlev.family)
end

return suite
