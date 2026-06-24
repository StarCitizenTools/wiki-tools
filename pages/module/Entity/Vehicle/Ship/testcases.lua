require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Ship = require('Module:Entity/Vehicle/Ship')

local suite = ScribuntoUnit:new()

function suite:testTypeInfoName()
	local ti = Ship.getTypeInfo({ is_spacecraft = true }, {})
	self:assertEquals('Spacecraft', ti.name)
end

function suite:testTypeInfoCategory()
	local ti = Ship.getTypeInfo({ is_spacecraft = true }, {})
	self:assertEquals('Ships', ti.category)
end

function suite:testShortDescriptionWithRoleAndManufacturer()
	-- args.manufacturer resolves via Module:Manufacturers; RSI has short='RSI'.
	-- 'fighter' is in ROLE_SUFFIXES so 'ship' is not appended.
	local apiData = { role = 'Light fighter' }
	local desc = Ship.getShortDescription(apiData, { manufacturer = 'RSI' }, {}, nil, {})
	self:assertEquals('RSI light fighter', desc)
end

function suite:testShortDescriptionWithoutRole()
	-- No role, no size, no crew → manufacturer + typeNoun only.
	local apiData = {}
	local desc = Ship.getShortDescription(apiData, { manufacturer = 'RSI' }, {}, nil, {})
	self:assertEquals('RSI ship', desc)
end

function suite:testShortDescriptionWithoutManufacturer()
	-- No manufacturer; 'exploration' not in ROLE_SUFFIXES → appends 'ship'.
	local apiData = { role = 'Exploration' }
	local desc = Ship.getShortDescription(apiData, {}, {}, nil, {})
	self:assertEquals('Exploration ship', desc)
end

function suite:testShortDescriptionMultiRole()
	-- Array role: joined with ' / '; not a role suffix → appends 'ship'.
	local apiData = { role = { 'Combat', 'Exploration' } }
	local desc = Ship.getShortDescription(apiData, { manufacturer = 'RSI' }, {}, nil, {})
	self:assertEquals('RSI combat / exploration ship', desc)
end

return suite
