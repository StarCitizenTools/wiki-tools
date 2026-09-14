require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local suite = ScribuntoUnit:new()
local Util = require('Module:AGGridColumns/Util')
local aggrid = require('mw.ext.aggrid')

function suite:testDecodeScalarPlain()
	self:assertEquals('Behring', Util.decodeScalar('Behring'))
end

function suite:testDecodeScalarEntities()
	self:assertEquals('180\194\160m/s', Util.decodeScalar('180&#160;m/s'))
end

function suite:testDecodeScalarNil()
	self:assertEquals(nil, Util.decodeScalar(nil))
end

function suite:testToTextArrayJoins()
	self:assertEquals('A, B', Util.toText({ 'A', 'B' }))
end

function suite:testToNumberParsesNumeralString()
	self:assertEquals(1234, Util.toNumber('1234'))
end

function suite:testToNumberPassesThroughRealNumber()
	self:assertEquals(180, Util.toNumber(180))
end

function suite:testToNumberNil()
	self:assertEquals(nil, Util.toNumber(nil))
end

function suite:testParseLinkTargetAndDisplay()
	local target, display = Util.parseLink('[[:Aegis Dynamics|Aegis]]')
	self:assertEquals('Aegis Dynamics', target)
	self:assertEquals('Aegis', display)
end

function suite:testParseLinkNotALink()
	self:assertEquals(nil, (Util.parseLink('Aegis Dynamics')))
end

function suite:testParseLinkTwoLinksNil()
	self:assertEquals(nil, (Util.parseLink('[[A]] and [[B]]')))
end

function suite:testCloneFormatCopies()
	local src = { style = 'number', suffix = ' m' }
	local copy = Util.cloneFormat(src)
	self:assertEquals(' m', copy.suffix)
	self:assertFalse(copy == src)
end

function suite:testCloneFormatNil()
	self:assertEquals(nil, Util.cloneFormat(nil))
end

function suite:testToTextScalar()
	self:assertEquals('Laser', Util.toText('Laser'))
end

function suite:testToTextNil()
	self:assertEquals(nil, Util.toText(nil))
end

-- Pre-existing, byte-identical behaviour: an all-empty multi-valued result joins to
-- '' (not nil). Pinned so a future change can't silently alter consumer output.
function suite:testToTextAllEmptyArrayIsEmptyString()
	self:assertEquals('', Util.toText({ '', '' }))
end

function suite:testToNumberNegative()
	self:assertEquals(-3, Util.toNumber('-3'))
end

function suite:testToNumberArrayUsesFirst()
	self:assertEquals(100, Util.toNumber({ 100, 200 }))
end

function suite:testParseLinkNoDisplay()
	local target, display = Util.parseLink('[[:Aegis Dynamics]]')
	self:assertEquals('Aegis Dynamics', target)
	self:assertEquals(nil, display)
end

function suite:testBuildValueListMultiPlain()
	self:assertDeepEquals(
		{ links = { { text = 'mining' }, { text = 'salvage' } } },
		Util.buildValueList({ 'mining', 'salvage' })
	)
end

function suite:testBuildValueListSingleScalar()
	self:assertDeepEquals({ links = { { text = 'mining' } } }, Util.buildValueList('mining'))
end

function suite:testBuildValueListLinksKeepTarget()
	self:assertDeepEquals(
		{ links = { { text = 'A', href = 'Aegis Dynamics' } } },
		Util.buildValueList({ '[[:Aegis Dynamics|A]]' })
	)
end

function suite:testBuildValueListPlainStaysPlain()
	self:assertDeepEquals({ links = { { text = 'plain' } } }, Util.buildValueList({ 'plain' }))
end

-- An item wrapping exactly one link (e.g. a loot-table quantity prefix) links as
-- a whole, the surrounding text kept as the cell's label.
function suite:testBuildValueListWrappedLinkLinksWholeItem()
	self:assertDeepEquals(
		{ links = { { text = '50x Council Scrip', href = 'Council Scrip' } } },
		Util.buildValueList({ '50x [[Council Scrip]]' })
	)
end

-- A [[:Target|Label]] wrapped in surrounding text strips the leading colon and
-- uses the label, same as a whole-link item.
function suite:testBuildValueListWrappedLinkWithLabelUsesLabel()
	self:assertDeepEquals(
		{ links = { { text = '50x Scrip', href = 'Council Scrip' } } },
		Util.buildValueList({ '50x [[:Council Scrip|Scrip]]' })
	)
end

-- A target containing quotes must not be truncated at the first one.
function suite:testBuildValueListWrappedLinkKeepsQuotesInTarget()
	self:assertDeepEquals(
		{ links = { { text = '1x Coda "Ascension" Pistol', href = 'Coda "Ascension" Pistol' } } },
		Util.buildValueList({ '1x [[Coda "Ascension" Pistol]]' })
	)
end

-- Two or more links in one item is ambiguous (which one is "the" link?), so it
-- stays plain text.
function suite:testBuildValueListTwoLinksStaysPlain()
	self:assertDeepEquals({ links = { { text = '[[A]] and [[B]]' } } }, Util.buildValueList({ '[[A]] and [[B]]' }))
end

function suite:testBuildValueListDropsEmpty()
	self:assertEquals(nil, Util.buildValueList(nil))
	self:assertEquals(nil, Util.buildValueList({ '', '' }))
end

--- buildThumb must never empty a whole grid over one bad filename: when
--- aggrid.thumb errors (an invalid title MediaWiki rejects), the cell drops
--- instead of the render erroring.
function suite:testBuildThumbSurvivesAggridThrow()
	local real = aggrid.thumb
	aggrid.thumb = function()
		error('boom')
	end
	local ok, err = pcall(function()
		self:assertEquals(nil, Util.buildThumb('[[File:X.png]]', 'Target'))
	end)
	aggrid.thumb = real
	if not ok then
		error(err, 0)
	end
end

return suite
