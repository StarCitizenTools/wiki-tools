require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Acquisition = require('Module:Entity/Acquisition')

local suite = ScribuntoUnit:new()

function suite:testResolveFlagOverrideWins()
	self:assertEquals(true, Acquisition.resolveFlag('yes', false))
	self:assertEquals(false, Acquisition.resolveFlag('no', true))
end

function suite:testResolveFlagDerivedThenUnknown()
	self:assertEquals(true, Acquisition.resolveFlag(nil, true))
	self:assertEquals(nil, Acquisition.resolveFlag(nil, nil))
end

function suite:testPriceRangeSkipsZeros()
	local lo, hi = Acquisition.priceRange({ { price_buy = 0 }, { price_buy = 7 }, { price_buy = 12 } }, 'price_buy')
	self:assertEquals(7, lo)
	self:assertEquals(12, hi)
end

function suite:testInferCanAcquire()
	self:assertEquals(true, Acquisition.inferCanAcquire({ { price_buy = 5 } }, 'price_buy'))
	self:assertEquals(false, Acquisition.inferCanAcquire({ { price_buy = 0 } }, 'price_buy'))
	self:assertEquals(nil, Acquisition.inferCanAcquire({}, 'price_buy'))
	self:assertEquals(nil, Acquisition.inferCanAcquire(nil, 'price_buy'))
end

function suite:testHasEntityTag()
	self:assertEquals(
		true,
		Acquisition.hasEntityTag({ entity_tag_map = { { name = 'PromotionalItem' } } }, 'PromotionalItem')
	)
	self:assertEquals(false, Acquisition.hasEntityTag({ entity_tag_map = { { name = 'Other' } } }, 'PromotionalItem'))
	self:assertEquals(nil, Acquisition.hasEntityTag({}, 'PromotionalItem'))
end

function suite:testLocationCountLabel()
	self:assertEquals('1 location', Acquisition.locationCountLabel({ {} }))
	self:assertEquals('2 locations', Acquisition.locationCountLabel({ {}, {} }))
end

return suite
