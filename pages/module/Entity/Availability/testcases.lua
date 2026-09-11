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

-- acquisitionFor(): leaf-first over the chain, nothing for an unclaimed page

local function stubResult(chain, matchedKind, args)
	return { chain = chain, matchedKind = matchedKind, apiData = {}, ctx = { apiData = {}, args = args or {} } }
end

function suite:testAcquisitionForNilWhenNoKindClaimedThePage()
	local item = {
		getAcquisition = function()
			return { summary = {}, cards = {} }
		end,
	}
	self:assertEquals(nil, Availability._internal.acquisitionFor(stubResult({ item }, nil)))
end

function suite:testAcquisitionForKindHook()
	local kind = {
		getAcquisition = function(apiData, args)
			return { summary = { args.tag }, cards = {} }
		end,
	}
	local a = Availability._internal.acquisitionFor(stubResult({ {}, kind }, kind, { tag = 'kind' }))
	self:assertEquals('kind', a.summary[1])
end

function suite:testAcquisitionForLeafOverridesKind()
	local kind = {
		getAcquisition = function()
			return { summary = { 'kind' }, cards = {} }
		end,
	}
	local leaf = {
		getAcquisition = function()
			return { summary = { 'leaf' }, cards = {} }
		end,
	}
	local a = Availability._internal.acquisitionFor(stubResult({ {}, kind, leaf }, kind))
	self:assertEquals('leaf', a.summary[1])
end

return suite
