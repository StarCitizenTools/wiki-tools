require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local RangeBar = require('Module:RangeBar')

local suite = ScribuntoUnit:new()

local STOPS = {
	{ at = 0, color = '#000000' },
	{ at = 50, color = '#888888' },
	{ at = 100, color = '#ffffff' },
}

-- clampPct()

function suite:testClampPctNormal()
	self:assertEquals(25, RangeBar._internal.clampPct(-125, -250, 250))
end

function suite:testClampPctMidpoint()
	self:assertEquals(50, RangeBar._internal.clampPct(0, -250, 250))
end

function suite:testClampPctBelowFloor()
	self:assertEquals(0, RangeBar._internal.clampPct(-300, -250, 250))
end

function suite:testClampPctAboveCeiling()
	self:assertEquals(100, RangeBar._internal.clampPct(300, -250, 250))
end

function suite:testClampPctEmptyDomain()
	self:assertEquals(0, RangeBar._internal.clampPct(10, 5, 5))
end

-- colorAt()

function suite:testColorAtExactStop()
	self:assertEquals('#888888', RangeBar._internal.colorAt(STOPS, 50))
end

function suite:testColorAtBelowFirst()
	self:assertEquals('#000000', RangeBar._internal.colorAt(STOPS, -10))
end

function suite:testColorAtAboveLast()
	self:assertEquals('#ffffff', RangeBar._internal.colorAt(STOPS, 200))
end

function suite:testColorAtInterpolatesFirstSegment()
	-- 25 is halfway between #000000 and #888888 -> #444444
	self:assertEquals('#444444', RangeBar._internal.colorAt(STOPS, 25))
end

function suite:testColorAtInterpolatesSecondSegment()
	-- 75 is halfway between #888888 and #ffffff -> #c4c4c4 (rounded)
	self:assertEquals('#c4c4c4', RangeBar._internal.colorAt(STOPS, 75))
end

-- gradientFor()

function suite:testGradientForSimpleRange()
	self:assertEquals('linear-gradient(90deg, #000000 0%, #888888 100%)', RangeBar._internal.gradientFor(STOPS, 0, 50))
end

function suite:testGradientForSpanningAStop()
	self:assertEquals(
		'linear-gradient(90deg, #000000 0%, #888888 50%, #ffffff 100%)',
		RangeBar._internal.gradientFor(STOPS, 0, 100)
	)
end

-- fmtNum()

function suite:testFmtNumStripsTrailingZeros()
	self:assertEquals('34.6', RangeBar._internal.fmtNum(34.6))
end

function suite:testFmtNumStripsToInteger()
	self:assertEquals('50', RangeBar._internal.fmtNum(50))
end

function suite:testFmtNumRoundsToTwoDecimals()
	self:assertEquals('41.85', RangeBar._internal.fmtNum(41.847))
end

function suite:testFmtNumZero()
	self:assertEquals('0', RangeBar._internal.fmtNum(0))
end

-- labelWidthPct() — width as a % of the nominal bar, by character count

function suite:testLabelWidthPctCountsCharsNotBytes()
	-- "−75 °C" is 6 characters (the minus and degree sign are multi-byte).
	self:assertEquals(6 * 8 / 300 * 100, RangeBar._internal.labelWidthPct('−75 °C'))
end

function suite:testLabelWidthPctShortLabel()
	self:assertEquals(1 * 8 / 300 * 100, RangeBar._internal.labelWidthPct('0'))
end

-- overlaps() — [left, right] percentage boxes

function suite:testOverlapsTrue()
	self:assertEquals(true, RangeBar._internal.overlaps({ 0, 10 }, { 5, 15 }))
end

function suite:testOverlapsFalse()
	self:assertEquals(false, RangeBar._internal.overlaps({ 0, 10 }, { 30, 40 }))
end

function suite:testOverlapsGapTreatedAsTouching()
	-- Boxes 0.2% apart are within the clearance gap, so they count as overlapping.
	self:assertEquals(true, RangeBar._internal.overlaps({ 0, 10 }, { 10.2, 20 }))
end

-- render() guards

function suite:testRenderNilOnMissingStops()
	self:assertEquals(nil, RangeBar.render({ min = -77, max = 107, domain = { min = -250, max = 250 } }))
end

function suite:testRenderNilOnMissingDomain()
	self:assertEquals(nil, RangeBar.render({ min = -77, max = 107, stops = STOPS }))
end

function suite:testRenderNilOnEmptyDomain()
	self:assertEquals(nil, RangeBar.render({ min = -77, max = 107, domain = { min = 5, max = 5 }, stops = STOPS }))
end

return suite
