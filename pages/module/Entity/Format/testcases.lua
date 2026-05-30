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

-- buildSiteLinks

function suite:testBuildSiteLinksFormatAndData()
	local siteDefs = { { label = 'Example', format = 'https://example.com/%s', data = 'uuid' } }
	local result = format.buildSiteLinks(siteDefs, { uuid = 'abc-123' })
	self:assertEquals('[https://example.com/abc-123 Example]', result)
end

function suite:testBuildSiteLinksArg()
	local siteDefs = { { label = 'Galactapedia', arg = 'galactapedia_url' } }
	local result = format.buildSiteLinks(siteDefs, { galactapedia_url = 'https://galactapedia.example.com/page' })
	self:assertEquals('[https://galactapedia.example.com/page Galactapedia]', result)
end

function suite:testBuildSiteLinksSkipsMissingData()
	local siteDefs = {
		{ label = 'Example', format = 'https://example.com/%s', data = 'uuid' },
		{ label = 'Other', format = 'https://other.com/%s', data = 'name' },
	}
	local result = format.buildSiteLinks(siteDefs, { uuid = 'abc-123' })
	self:assertEquals('[https://example.com/abc-123 Example]', result)
end

function suite:testBuildSiteLinksSkipsMissingArg()
	local result = format.buildSiteLinks({ { label = 'Galactapedia', arg = 'galactapedia_url' } }, {})
	self:assertEquals(nil, result)
end

function suite:testBuildSiteLinksEmpty()
	self:assertEquals(nil, format.buildSiteLinks({}, {}))
end

function suite:testBuildSiteLinksEncodesSpacesInData()
	local siteDefs = { { label = 'Example', format = 'https://example.com/search?q=%s', data = 'name' } }
	local result = format.buildSiteLinks(siteDefs, { name = 'Foo Bar' })
	self:assertEquals('[https://example.com/search?q=Foo+Bar Example]', result)
end

function suite:testBuildSiteLinksJoinsMultiple()
	local siteDefs = {
		{ label = 'Finder', format = 'https://finder.example.com/%s', data = 'uuid' },
		{ label = 'Galactapedia', arg = 'galactapedia_url' },
	}
	local lookup = { uuid = 'abc-123', galactapedia_url = 'https://galactapedia.example.com/page' }
	local result = format.buildSiteLinks(siteDefs, lookup)
	self:assertEquals(
		'[https://finder.example.com/abc-123 Finder] · [https://galactapedia.example.com/page Galactapedia]',
		result
	)
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

return suite
