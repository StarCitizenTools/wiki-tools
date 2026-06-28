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

function suite:testEstimatePriceSingleTerminal()
	self:assertEquals(1508220, Acquisition.estimatePrice({ { price_buy = 1508220 } }, 'price_buy'))
end

function suite:testEstimatePriceMedianOddCount()
	self:assertEquals(
		2000000,
		Acquisition.estimatePrice(
			{ { price_buy = 1000000 }, { price_buy = 3000000 }, { price_buy = 2000000 } },
			'price_buy'
		)
	)
end

function suite:testEstimatePriceMedianEvenCountRounds()
	-- (1,000,000 + 2,000,002) / 2 = 1,500,001
	self:assertEquals(
		1500001,
		Acquisition.estimatePrice({ { price_buy = 1000000 }, { price_buy = 2000002 } }, 'price_buy')
	)
end

function suite:testEstimatePriceSkipsZeros()
	self:assertEquals(2000000, Acquisition.estimatePrice({ { price_buy = 0 }, { price_buy = 2000000 } }, 'price_buy'))
end

function suite:testEstimatePriceLatestPatchOnly()
	-- median taken over the newest game_version only; older-patch terminal excluded
	local rows = {
		{ price_buy = 1000000, game_version = '4.8.2-LIVE.100' },
		{ price_buy = 2000000, game_version = '4.9.0-LIVE.200' },
		{ price_buy = 4000000, game_version = '4.9.0-LIVE.200' },
	}
	self:assertEquals(3000000, Acquisition.estimatePrice(rows, 'price_buy')) -- median of 2M, 4M
end

function suite:testEstimatePriceVersionCompareIsNumericNotLexicographic()
	-- 4.10 is newer than 4.8 despite a smaller build suffix
	local rows = {
		{ price_buy = 1000000, game_version = '4.8.2-LIVE.999' },
		{ price_buy = 5000000, game_version = '4.10.0-LIVE.100' },
	}
	self:assertEquals(5000000, Acquisition.estimatePrice(rows, 'price_buy'))
end

function suite:testEstimatePriceFallsBackWhenNewestLacksSide()
	-- newest patch only has a rental row (no buy) → fall back to the older patch's buy price
	local rows = {
		{ price_buy = 1000000, game_version = '4.8.2-LIVE.100' },
		{ price_rent = 5000, game_version = '4.9.0-LIVE.200' },
	}
	self:assertEquals(1000000, Acquisition.estimatePrice(rows, 'price_buy'))
end

function suite:testEstimatePriceNilWhenNoUsablePrice()
	self:assertEquals(nil, Acquisition.estimatePrice({}, 'price_buy'))
	self:assertEquals(nil, Acquisition.estimatePrice(nil, 'price_buy'))
	self:assertEquals(nil, Acquisition.estimatePrice({ { price_buy = 0 } }, 'price_buy'))
end

return suite
