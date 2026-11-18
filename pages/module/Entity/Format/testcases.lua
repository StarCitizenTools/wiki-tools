require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local suite = ScribuntoUnit:new()
local format = require('Module:Entity/Format')

-- joinAnd

function suite:testJoinAndEmpty()
	self:assertEquals(nil, format.joinAnd({}))
end

function suite:testJoinAndOne()
	self:assertEquals('Energizing', format.joinAnd({ 'Energizing' }))
end

function suite:testJoinAndTwo()
	self:assertEquals('Energizing and Hydrating', format.joinAnd({ 'Energizing', 'Hydrating' }))
end

function suite:testJoinAndThree()
	self:assertEquals('Energizing, Hydrating, and Healing', format.joinAnd({ 'Energizing', 'Hydrating', 'Healing' }))
end

function suite:testJoinAndFour()
	self:assertEquals('A, B, C, and D', format.joinAnd({ 'A', 'B', 'C', 'D' }))
end

-- colorBySign

function suite:testColorBySignPositive()
	local out = format.colorBySign('+1', 1)
	self:assertEquals(true, mw.ustring.find(out, '+1', 1, true) ~= nil)
	self:assertEquals(true, mw.ustring.find(out, 'color-success', 1, true) ~= nil)
end

function suite:testColorBySignNegative()
	local out = format.colorBySign('−0.5', -0.5)
	self:assertEquals(true, mw.ustring.find(out, '−0.5', 1, true) ~= nil)
	self:assertEquals(true, mw.ustring.find(out, 'color-destructive', 1, true) ~= nil)
end

function suite:testColorBySignZeroUnchanged()
	self:assertEquals('0', format.colorBySign('0', 0))
end

-- colorByDirection

function suite:testColorByDirectionHigherBetter()
	-- baseline 1 (multiplier), higher is better: ×1.2 good (green), ×0.8 bad (red).
	self:assertStringContains('color-success', format.colorByDirection('×1.2', 1.2, 1, 'higher'), true)
	self:assertStringContains('color-destructive', format.colorByDirection('×0.8', 0.8, 1, 'higher'), true)
end

function suite:testColorByDirectionLowerBetter()
	-- baseline 1, lower is better (recoil): ×0.8 good (green), ×1.2 bad (red).
	self:assertStringContains('color-success', format.colorByDirection('×0.8', 0.8, 1, 'lower'), true)
	self:assertStringContains('color-destructive', format.colorByDirection('×1.2', 1.2, 1, 'lower'), true)
end

function suite:testColorByDirectionBaselineUnchanged()
	-- At the baseline (no modification) and for non-numeric input, return text plain.
	self:assertEquals('×1', format.colorByDirection('×1', 1, 1, 'higher'))
	self:assertEquals('×1', format.colorByDirection('×1', 1, 1, 'lower'))
	self:assertEquals('—', format.colorByDirection('—', 'n/a', 1, 'higher'))
end

function suite:testColorBySignDelegates()
	-- colorBySign is colorByDirection(value, 0, 'higher').
	self:assertEquals(format.colorByDirection('+1', 1, 0, 'higher'), format.colorBySign('+1', 1))
end

-- buildHtmlList

function suite:testBuildHtmlListEmpty()
	self:assertEquals(nil, format.buildHtmlList({}))
end

function suite:testBuildHtmlListNil()
	self:assertEquals(nil, format.buildHtmlList(nil))
end

function suite:testBuildHtmlListSingle()
	self:assertEquals('Energizing', format.buildHtmlList({ 'Energizing' }))
end

function suite:testBuildHtmlListMultiple()
	self:assertEquals(
		'<ul><li>Energizing</li><li>Hydrating</li><li>Healing</li></ul>',
		format.buildHtmlList({ 'Energizing', 'Hydrating', 'Healing' })
	)
end

-- splitSemi

function suite:testSplitSemiEmpty()
	self:assertEquals(0, #format.splitSemi(''))
	self:assertEquals(0, #format.splitSemi(nil))
end

function suite:testSplitSemiSingle()
	local r = format.splitSemi('https://a')
	self:assertEquals(1, #r)
	self:assertEquals('https://a', r[1])
end

function suite:testSplitSemiMultipleTrimmed()
	local r = format.splitSemi('https://a; https://b ;https://c')
	self:assertEquals(3, #r)
	self:assertEquals('https://a', r[1])
	self:assertEquals('https://b', r[2])
	self:assertEquals('https://c', r[3])
end

function suite:testSplitSemiDropsBlanks()
	-- empty segments (e.g. a trailing ';') are skipped
	local r = format.splitSemi('https://a;;')
	self:assertEquals(1, #r)
	self:assertEquals('https://a', r[1])
end

-- formatNum

function suite:testFormatNumGroupsThousands()
	self:assertEquals('756,000', format.formatNum(756000))
end

function suite:testFormatNumSmallNumberUnchanged()
	self:assertEquals('86', format.formatNum(86))
end

function suite:testFormatNumDecimal()
	self:assertEquals('501.7', format.formatNum(501.7))
end

function suite:testFormatNumNilReturnsNil()
	self:assertEquals(nil, format.formatNum(nil))
end

function suite:testFormatNumNumericStringGrouped()
	self:assertEquals('1,480', format.formatNum('1480'))
end

function suite:testFormatNumNonNumericPassthrough()
	self:assertEquals('N/A', format.formatNum('N/A'))
end

-- gradedShortDescription

function suite:testGradedShortDescriptionFull()
	self:assertEquals(
		'S3 Gr. A military power plant by A&R',
		format.gradedShortDescription('Power plant', 3, 'Military', 'A', 'A&R')
	)
end

function suite:testGradedShortDescriptionNoManufacturer()
	self:assertEquals(
		'S3 Gr. A military power plant',
		format.gradedShortDescription('Power plant', 3, 'Military', 'A', nil)
	)
end

function suite:testGradedShortDescriptionNilWhenMissing()
	self:assertEquals(nil, format.gradedShortDescription('Power plant', 3, nil, 'A', 'A&R'))
	self:assertEquals(nil, format.gradedShortDescription('Power plant', nil, 'Military', 'A', 'A&R'))
	self:assertEquals(nil, format.gradedShortDescription('Power plant', 3, 'Military', nil, 'A&R'))
end

function suite:testGameVersionReadsTheBuildKey()
	self:assertEquals('4.10.0-LIVE.12519617', format.gameVersion({ version = '4.10.0-LIVE.12519617' }))
end

function suite:testGameVersionIsNilWhenAbsentOrUnusable()
	self:assertEquals(nil, format.gameVersion({}))
	self:assertEquals(nil, format.gameVersion(nil))
	self:assertEquals(nil, format.gameVersion({ version = '' }))
	self:assertEquals(nil, format.gameVersion({ version = 410 }))
end

return suite
