require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local commLink = require('Module:CommLink')

local bucketLib = require('mw.ext.bucket')

--- The recorded read: put() records a chain too.
local function readChain()
	for _, chain in ipairs(bucketLib._chains) do
		if chain.select[1] ~= nil then
			return chain
		end
	end
	return nil
end

local suite = ScribuntoUnit:new()

local FAR_FROM_HOME_URL =
	'https://robertsspaceindustries.com/comm-link/spectrum-dispatch/16835-Far-From-Home-Best-Laid-Plans'

function suite:testReadArgsTreatsBlankAsAbsent()
	local args = commLink.readArgs({ title = '  ', series = ' Galactic Guide ', type = '' })
	self:assertEquals(nil, args.title)
	self:assertEquals('Galactic Guide', args.series)
	self:assertEquals(nil, args.type)
	self:assertEquals(nil, args.publicationdate)
end

function suite:testNormaliseDate()
	self:assertEquals('2018-11-07', commLink.normaliseDate('2018-11-07'))
	self:assertEquals('2015-03-12', commLink.normaliseDate('2015-3-12'))
	self:assertEquals('2016-01-20', commLink.normaliseDate('2016-01-20 <br> republished 2020-05-01'))
	self:assertEquals(nil, commLink.normaliseDate('January 2015'))
	self:assertEquals(nil, commLink.normaliseDate(nil))
end

function suite:testRsiId()
	self:assertEquals(16835, commLink.rsiId(FAR_FROM_HOME_URL))
	self:assertEquals(15109, commLink.rsiId('comm-link//15109-Star-Citizen-Alpha-200'))
	self:assertEquals(nil, commLink.rsiId('https://robertsspaceindustries.com/comm-link'))
	self:assertEquals(nil, commLink.rsiId(nil))
end

function suite:testRow()
	self:assertDeepEquals(
		{
			title = 'Far From Home: Best Laid Plans',
			series = 'Far From Home',
			type = 'Spectrum Dispatch',
			published = '2018-11-07',
			rsi_id = 16835,
		},
		commLink.row(commLink.readArgs({
			title = 'Far From Home: Best Laid Plans',
			series = 'Far From Home',
			type = 'Spectrum Dispatch',
			publicationdate = '2018-11-07',
			url = FAR_FROM_HOME_URL,
			image = 'Comm-Link-FarFromHomeFI4.jpg',
		}))
	)
	self:assertDeepEquals({}, commLink.row(commLink.readArgs({})))
end

-- Reading order: date, then RSI number, then page name case-insensitively; a
-- missing date or number sorts after the rows that have one.
function suite:testOrderSeries()
	local ordered = commLink.orderSeries({
		{ page_name = 'Comm-Link:Undated', rsi_id = 100 },
		{ page_name = 'Comm-Link:Later', published = '2016-02-01', rsi_id = 14000 },
		{ page_name = 'Comm-Link:Same day, higher', published = '2015-06-01', rsi_id = 13002 },
		{ page_name = 'Comm-Link:Same day, lower', published = '2015-06-01', rsi_id = 13001 },
		{ page_name = 'Comm-Link:Same day, no number', published = '2015-06-01' },
		{ page_name = 'Comm-Link:b tie', published = '2014-01-01', rsi_id = 1 },
		{ page_name = 'Comm-Link:A tie', published = '2014-01-01', rsi_id = 1 },
	})
	local names = {}
	for i, row in ipairs(ordered) do
		names[i] = row.page_name
	end
	self:assertDeepEquals({
		'Comm-Link:A tie',
		'Comm-Link:b tie',
		'Comm-Link:Same day, lower',
		'Comm-Link:Same day, higher',
		'Comm-Link:Same day, no number',
		'Comm-Link:Later',
		'Comm-Link:Undated',
	}, names)
end

function suite:testOrderSeriesLeavesTheInputAlone()
	local rows = {
		{ page_name = 'Comm-Link:B', published = '2015-01-02' },
		{ page_name = 'Comm-Link:A', published = '2015-01-01' },
	}
	commLink.orderSeries(rows)
	self:assertEquals('Comm-Link:B', rows[1].page_name)
end

-- The page matches case-insensitively, as Bucket matches page names.
function suite:testNeighbours()
	local ordered =
		{ { page_name = 'Comm-Link:One' }, { page_name = 'Comm-Link:Two' }, { page_name = 'Comm-Link:Three' } }
	local before, after = commLink.neighbours(ordered, 'Comm-Link:One')
	self:assertEquals(nil, before)
	self:assertEquals('Comm-Link:Two', after.page_name)
	before, after = commLink.neighbours(ordered, 'comm-link:two')
	self:assertEquals('Comm-Link:One', before.page_name)
	self:assertEquals('Comm-Link:Three', after.page_name)
	before, after = commLink.neighbours(ordered, 'Comm-Link:Three')
	self:assertEquals('Comm-Link:Two', before.page_name)
	self:assertEquals(nil, after)
	before, after = commLink.neighbours({ { page_name = 'Comm-Link:Alone' } }, 'Comm-Link:Alone')
	self:assertEquals(nil, before)
	self:assertEquals(nil, after)
	before, after = commLink.neighbours(ordered, 'Comm-Link:Missing')
	self:assertEquals(nil, before)
	self:assertEquals(nil, after)
end

function suite:testPutWritesOneRow()
	bucketLib._reset()
	commLink.put(commLink.readArgs({ title = 'Nyx', series = 'Galactic Guide', publicationdate = '2015-4-2' }))
	self:assertEquals(1, #bucketLib._puts)
	self:assertEquals('comm_link', bucketLib._puts[1].bucket)
	self:assertEquals('2015-04-02', bucketLib._puts[1].data.published)
	self:assertEquals('Galactic Guide', bucketLib._puts[1].data.series)
end

function suite:testNoticeTextWithoutACitation()
	self:assertEquals(
		'[https://robertsspaceindustries.com/comm-link Comm-Links] are official communications of '
			.. '[https://cloudimperiumgames.com/ Cloud Imperium Games Corporation] regarding [[Star Citizen]] & '
			.. '[[Squadron 42 (video game)|Squadron 42]]. The Comm-Link is reproduced here with minimal changes '
			.. '(format & wikilinking), as well as translations when available.',
		commLink.noticeText(nil)
	)
end

function suite:testNoticeTextWithACitation()
	self:assertEquals(
		'[https://robertsspaceindustries.com/comm-link Comm-Links] are official communications of '
			.. '[https://cloudimperiumgames.com/ Cloud Imperium Games Corporation] regarding [[Star Citizen]] & '
			.. '[[Squadron 42 (video game)|Squadron 42]]. The Comm-Link is reproduced here with minimal changes '
			.. '(format & wikilinking), as well as translations when available. The original source for this '
			.. 'specific Comm-Link can be found at &nbsp;[https://example.com/16835 cite]',
		commLink.noticeText('[https://example.com/16835 cite]')
	)
end

function suite:testInfoboxDataAllFields()
	local args = commLink.readArgs({
		title = 'Far From Home: Best Laid Plans',
		series = 'Far From Home',
		type = 'Spectrum Dispatch',
		publicationdate = '2018-11-07',
		url = FAR_FROM_HOME_URL,
		image = 'Comm-Link-FarFromHomeFI4.jpg',
	})
	local data = commLink.infoboxData(args, 'Far From Home: Best Laid Plans', '[https://example.com/16835 source]')
	self:assertEquals('Far From Home: Best Laid Plans', data.title)
	self:assertEquals('Comm-Link', data.subtitle)
	self:assertEquals('Comm-Link-FarFromHomeFI4.jpg', data.image)
	self:assertEquals(2, #data.sections)
	self:assertEquals(2, data.sections[1].columns)
	self:assertDeepEquals({
		{ label = 'Series', content = '[[:Category:Far From Home|Far From Home]]' },
		{ label = 'Type', content = '[[:Category:Spectrum Dispatch|Spectrum Dispatch]]' },
		{ label = 'ID', content = '16835' },
		{ label = 'Published', content = '2018-11-07' },
	}, data.sections[1].items)
	self:assertDeepEquals(
		{ { label = 'Source', content = '[https://example.com/16835 source]' } },
		data.sections[2].items
	)
end

function suite:testInfoboxDataWithoutAUrl()
	local args = commLink.readArgs({ title = 'T', series = 'S', type = 'Ty', publicationdate = '2020-01-01' })
	local data = commLink.infoboxData(args, 'T', nil)
	self:assertEquals(1, #data.sections)
	local labels = {}
	for _, item in ipairs(data.sections[1].items) do
		labels[#labels + 1] = item.label
	end
	self:assertDeepEquals({ 'Series', 'Type', 'Published' }, labels)
end

function suite:testInfoboxDataFallsBackToThePageName()
	local data = commLink.infoboxData(commLink.readArgs({}), 'Comm-Link:Untitled', nil)
	self:assertEquals('Comm-Link:Untitled', data.title)
	self:assertEquals(0, #data.sections)
end

function suite:testInfoboxDataWithoutAnImage()
	local data = commLink.infoboxData(commLink.readArgs({ title = 'T' }), 'T', nil)
	self:assertEquals(nil, data.image)
end

function suite:testCategoriesWithTypeAndSeries()
	self:assertEquals(
		'[[Category:Comm-Link]][[Category:Spectrum Dispatch]][[Category:Far From Home]]',
		commLink.categories(commLink.readArgs({ type = 'Spectrum Dispatch', series = 'Far From Home' }))
	)
end

function suite:testCategoriesWithNeitherTypeNorSeries()
	self:assertEquals('[[Category:Comm-Link]]', commLink.categories(commLink.readArgs({})))
end

function suite:testSeoArgs()
	local args = commLink.readArgs({ title = 'Far From Home: Best Laid Plans' })
	local seo = commLink.seoArgs(args, 'en', 'Far From Home: Best Laid Plans')
	self:assertEquals('', seo[1])
	self:assertEquals('Far From Home: Best Laid Plans - Comm-Link Archive - Star Citizen Wiki', seo.title)
	self:assertEquals('Star Citizen Wiki', seo.site_name)
	self:assertEquals('article', seo.type)
	self:assertEquals(
		'Far From Home: Best Laid Plans is part of the Comm-Link Archive on the Star Citizen Wiki.',
		seo.description
	)
	self:assertEquals('en', seo.locale)
	self:assertEquals('Placeholderv2.png', seo.image)
end

function suite:testSeoArgsImageFallsBackToThePlaceholder()
	local withImage = commLink.seoArgs(commLink.readArgs({ title = 'T', image = 'Foo.jpg' }), 'en', 'T')
	self:assertEquals('Foo.jpg', withImage.image)
	local withoutImage = commLink.seoArgs(commLink.readArgs({ title = 'T' }), 'en', 'T')
	self:assertEquals('Placeholderv2.png', withoutImage.image)
end

-- Without a `title`, the SEO title falls back to the page name rather than
-- concatenating a nil; the description keeps its own "This" fallback.
function suite:testSeoArgsTitleFallsBackToThePageNameWithoutATitle()
	local seo = commLink.seoArgs(commLink.readArgs({}), 'en', 'Galactic Guide - Nyx')
	self:assertEquals('Galactic Guide - Nyx - Comm-Link Archive - Star Citizen Wiki', seo.title)
	self:assertEquals('This is part of the Comm-Link Archive on the Star Citizen Wiki.', seo.description)
end

function suite:testSeriesRowsReadsTheSeriesOnce()
	bucketLib._reset()
	commLink.seriesRows(commLink.readArgs({ series = 'Galactic Guide' }), 'Comm-Link:Galactic Guide - Nyx (2015)')
	self:assertEquals(1, #bucketLib._chains)
	local chain = readChain()
	self:assertEquals('comm_link', chain.bucket)
	self:assertDeepEquals({ 'page_name', 'title', 'published', 'rsi_id' }, chain.select)
	self:assertDeepEquals({ 'series', 'Galactic Guide' }, chain.where)
	self:assertEquals(5000, chain.limit)
end

-- The page's own stored row is replaced by one built from its arguments, so an
-- edited date places it at once.
function suite:testSeriesRowsReplacesTheOwnRow()
	bucketLib._reset()
	bucketLib._setRows('comm_link', {
		{
			page_name = 'Comm-Link:Galactic Guide - Nyx (2015)',
			title = 'Old',
			published = '2010-01-01',
			rsi_id = '14000',
		},
		{ page_name = 'Comm-Link:Galactic Guide - Terra', title = 'Terra', published = '2014-05-01', rsi_id = '13800' },
	})
	local rows = commLink.seriesRows(
		commLink.readArgs({ title = 'Nyx', series = 'Galactic Guide', publicationdate = '2015-04-02' }),
		'comm-link:galactic guide - nyx (2015)'
	)
	self:assertEquals(2, #rows)
	self:assertEquals('Comm-Link:Galactic Guide - Terra', rows[1].page_name)
	self:assertEquals(13800, rows[1].rsi_id)
	self:assertEquals('Nyx', rows[2].title)
	self:assertEquals('2015-04-02', rows[2].published)
end

function suite:testSeriesRowsSurvivesAFailedRead()
	bucketLib._reset()
	bucketLib._failNext = true
	local rows = commLink.seriesRows(commLink.readArgs({ series = 'Galactic Guide' }), 'Comm-Link:X')
	self:assertEquals(1, #rows)
	self:assertEquals('Comm-Link:X', rows[1].page_name)
end

function suite:testPrevnextArgsShowsOnlyTheSidesThatExist()
	self:assertDeepEquals(
		{
			title = '[[:Category:Galactic Guide|Galactic Guide]]',
			next = 'Comm-Link:Two',
			nextTitle = 'Two',
			nextDesc = '2015-01-02',
		},
		commLink.prevnextArgs(
			nil,
			{ page_name = 'Comm-Link:Two', title = 'Two', published = '2015-01-02' },
			'Galactic Guide'
		)
	)
end

function suite:testPrevnextArgsFallsBackToThePageName()
	self:assertDeepEquals(
		{ title = '[[:Category:Tracker|Tracker]]', prev = 'Comm-Link:Untitled one', prevTitle = 'Untitled one' },
		commLink.prevnextArgs({ page_name = 'Comm-Link:Untitled one' }, nil, 'Tracker')
	)
end

return suite
