require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Ship = require('Module:Entity/Vehicle/Ship')

local suite = ScribuntoUnit:new()

function suite:testTypeInfoName()
	local ti = Ship.getTypeInfo({ is_spaceship = true }, {})
	self:assertEquals('Spaceship', ti.name)
end

function suite:testTypeInfoCategory()
	local ti = Ship.getTypeInfo({ is_spaceship = true }, {})
	self:assertEquals('Ships', ti.category)
end

function suite:testShortDescriptionWithRoleAndManufacturer()
	-- args.manufacturer resolves via Module:Manufacturers; RSI has short='RSI'
	local apiData = { role = 'Light fighter' }
	local desc = Ship.getShortDescription(apiData, { manufacturer = 'RSI' }, {}, nil, {})
	self:assertEquals('Light fighter spaceship by RSI', desc)
end

function suite:testShortDescriptionWithoutRole()
	local apiData = {}
	local desc = Ship.getShortDescription(apiData, { manufacturer = 'RSI' }, {}, nil, {})
	self:assertEquals('spaceship by RSI', desc)
end

function suite:testShortDescriptionWithoutManufacturer()
	local apiData = { role = 'Exploration' }
	local desc = Ship.getShortDescription(apiData, {}, {}, nil, {})
	self:assertEquals('Exploration spaceship', desc)
end

function suite:testShortDescriptionMultiRole()
	local apiData = { role = { 'Combat', 'Exploration' } }
	local desc = Ship.getShortDescription(apiData, { manufacturer = 'RSI' }, {}, nil, {})
	self:assertEquals('Combat/Exploration spaceship by RSI', desc)
end

return suite
