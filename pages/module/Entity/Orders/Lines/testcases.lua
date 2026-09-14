require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Lines = require('Module:Entity/Orders/Lines')

local suite = ScribuntoUnit:new()

function suite:testFormatQuantityMinScu()
	local quantity, units, scu = Lines.formatQuantity({ min_scu = 5 })
	self:assertEquals('5 SCU', quantity)
	self:assertEquals(0, units)
	self:assertEquals(5, scu)
end

function suite:testFormatQuantityMinAmount()
	local quantity, units, scu = Lines.formatQuantity({ min_amount = 2 })
	self:assertEquals('2x', quantity)
	self:assertEquals(2, units)
	self:assertEquals(0, scu)
end

function suite:testFormatQuantityUnknown()
	local quantity, units, scu = Lines.formatQuantity({})
	self:assertEquals('?', quantity)
	self:assertEquals(0, units)
	self:assertEquals(0, scu)
end

function suite:testCargoLabelTagMatchWithContainerSize()
	self:assertEquals('Cargo', Lines.cargoLabel({ kind = 'TagMatch', max_container_size = 4 }))
end

function suite:testCargoLabelTagMatchWithoutContainerSize()
	self:assertEquals('Package', Lines.cargoLabel({ kind = 'TagMatch' }))
end

function suite:testCargoLabelLinksTheItemNameForAnyOtherKind()
	self:assertEquals('[[Agricium]]', Lines.cargoLabel({ kind = 'Item', name = 'Agricium' }))
end

function suite:testOrderLines()
	local haulingOrders = {
		{ kind = 'Item', name = 'Agricium', min_scu = 5 },
		{ kind = 'TagMatch', max_container_size = 4, min_amount = 2 },
		{ kind = 'TagMatch', min_amount = 1 },
	}
	self:assertDeepEquals({ '5 SCU [[Agricium]]', '2x Cargo', '1x Package' }, Lines.orderLines(haulingOrders))
end

function suite:testOrderLinesNilIsEmpty()
	self:assertDeepEquals({}, Lines.orderLines(nil))
end

return suite
