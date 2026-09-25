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

function suite:testStoreReadsTheTemplateArguments()
	bucketLib._reset()
	local frame = {
		getParent = function()
			return { args = { series = 'Tracker', title = 'T' } }
		end,
	}
	self:assertEquals('', commLink.store(frame))
	self:assertEquals('Tracker', bucketLib._puts[1].data.series)
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

function suite:testSeriesIsEmptyWithoutASeries()
	local frame = {
		getParent = function()
			return { args = { title = 'T' } }
		end,
	}
	self:assertEquals('', commLink.series(frame))
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
