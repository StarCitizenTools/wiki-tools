require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Trade = require('Module:Entity/Commodity/Trade')

local suite = ScribuntoUnit:new()

function suite:testFlattenPrices()
	local rows = Trade._internal.flattenPrices({
		purchase = { { location = 'Area18', price = 12 } },
		sale = { { location = 'Lorville', price = 15 } },
	})
	self:assertEquals(2, #rows)
	self:assertEquals('buy', rows[1].action)
	self:assertEquals('Area18', rows[1].location)
	self:assertEquals('sell', rows[2].action)
end

function suite:testFlattenPricesEmpty()
	self:assertEquals(0, #Trade._internal.flattenPrices({ purchase = {} }))
end

function suite:testFlattenPricesNil()
	self:assertEquals(0, #Trade._internal.flattenPrices(nil))
end

return suite
