require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Availability = require('Module:Entity/Availability')

local suite = ScribuntoUnit:new()

-- renderCard() dispatches on card.type

function suite:testRenderCardHtmlPassthrough()
	self:assertEquals('<x>mine</x>', Availability._internal.renderCard({ type = 'html', html = '<x>mine</x>' }))
end

function suite:testRenderCardTerminalsReturnsString()
	-- CollapsibleCard is stubbed inert in the runner; verify renderCard completes
	-- without error and returns a string for a terminals card with no prices.
	local out = Availability._internal.renderCard({
		type = 'terminals',
		title = 'Shops',
		caption = 'Shop terminals',
		description = 'No shop data in UEX',
		prices = nil,
		priceColumns = { { id = 'buy', key = 'price_buy', label = 'Buy' } },
	})
	self:assertTrue(type(out) == 'string')
end

return suite
