require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local patch = require('Module:Patch')

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

function suite:testReadArgsTreatsBlankAsAbsent()
	local args = patch.readArgs({ prev = '  ', next = ' Star Citizen Alpha 4.10.1 ', version = '' })
	self:assertEquals(nil, args.prev)
	self:assertEquals('Star Citizen Alpha 4.10.1', args.next)
	self:assertEquals(nil, args.version)
end

function suite:testReadArgsDefaultsTheProduct()
	self:assertEquals('Star Citizen', patch.readArgs({}).product)
	self:assertEquals('Spectrum', patch.readArgs({ product = 'Spectrum' }).product)
end

function suite:testReadArgsReadsUpcomingAsYesNo()
	self:assertEquals(true, patch.readArgs({ upcoming = 'yes' }).upcoming)
	self:assertEquals(false, patch.readArgs({ upcoming = 'no' }).upcoming)
	self:assertEquals(false, patch.readArgs({ upcoming = '' }).upcoming)
	self:assertEquals(false, patch.readArgs({}).upcoming)
end

function suite:testStatus()
	local label, modifier = patch.status(patch.readArgs({ upcoming = 'yes' }))
	self:assertEquals('Upcoming', label)
	self:assertEquals('upcoming', modifier)
	label, modifier = patch.status(patch.readArgs({ upcoming = 'yes', date = '2026-12-01' }))
	self:assertEquals('Upcoming', label)
	self:assertEquals('upcoming', modifier)
	label, modifier = patch.status(patch.readArgs({ date = '2026-08-26' }))
	self:assertEquals('Released', label)
	self:assertEquals('released', modifier)
	label, modifier = patch.status(patch.readArgs({}))
	self:assertEquals('Unknown', label)
	self:assertEquals(nil, modifier)
end

-- Only Star Citizen has a hub page to link back to.
function suite:testStatusTextLinksStarCitizenToTheHub()
	self:assertEquals('[[Patch notes|Released]]', patch.statusText(patch.readArgs({ date = '2026-08-26' })))
	self:assertEquals('[[Patch notes|Upcoming]]', patch.statusText(patch.readArgs({ upcoming = 'yes' })))
	self:assertEquals('Released', patch.statusText(patch.readArgs({ date = '2016-01-01', product = 'Spectrum' })))
end

-- {{Patch list}} sorts `Status desc` to put upcoming updates first.
function suite:testUpcomingStatusSortsLast()
	local upcoming = patch.status(patch.readArgs({ upcoming = 'yes' }))
	self:assertTrue(upcoming > patch.status(patch.readArgs({ date = '2026-08-26' })))
	self:assertTrue(upcoming > patch.status(patch.readArgs({})))
end

function suite:testDescription()
	self:assertEquals('', patch.description(patch.readArgs({}), 'x'))
	self:assertEquals(
		'2026-08-26 - 29 days ago',
		patch.description(patch.readArgs({ date = '2026-08-26' }), '29 days ago')
	)
	self:assertEquals(
		'est. 2026-12-01 - in 68 days',
		patch.description(patch.readArgs({ date = '2026-12-01', upcoming = 'yes' }), 'in 68 days')
	)
end

function suite:testShortDescription()
	self:assertEquals('Star Citizen build', patch.shortDescription(patch.readArgs({})))
	self:assertEquals(
		'Star Citizen build&nbsp;released on 2026-08-26',
		patch.shortDescription(patch.readArgs({ date = '2026-08-26' }))
	)
	self:assertEquals(
		'Star Citizen build&nbsp;scheduled for 2026-12-01',
		patch.shortDescription(patch.readArgs({ date = '2026-12-01', upcoming = 'yes' }))
	)
	self:assertEquals(
		'Spectrum build&nbsp;released on 2018-07-04',
		patch.shortDescription(patch.readArgs({ date = '2018-07-04', product = 'Spectrum' }))
	)
end

function suite:testCategoryForStarCitizen()
	self:assertEquals('Patch notes', patch.category(patch.readArgs({ date = '2026-08-26' })))
	self:assertEquals('Upcoming patches', patch.category(patch.readArgs({ upcoming = 'yes' })))
end

function suite:testCategoryForAnotherProduct()
	-- Another product has one category whether or not it is released.
	self:assertEquals('Spectrum patch notes', patch.category(patch.readArgs({ product = 'Spectrum' })))
	self:assertEquals(
		'Spectrum patch notes',
		patch.category(patch.readArgs({ product = 'Spectrum', upcoming = 'yes' }))
	)
end

function suite:testRow()
	self:assertDeepEquals({
		version = '4.10.0',
		build = '4.10.0-LIVE.12519617',
		release_date = '2026-08-26',
		upcoming = false,
		status = 'Released',
		product = 'Star Citizen',
	}, patch.row(patch.readArgs({ version = '4.10.0', build = '4.10.0-LIVE.12519617', date = '2026-08-26' })))
	local upcoming = patch.row(patch.readArgs({ upcoming = 'yes' }))
	self:assertEquals(nil, upcoming.release_date)
	self:assertEquals('Upcoming', upcoming.status)
end

function suite:testNeighbourTitle()
	self:assertEquals('Update:Star Citizen Alpha 4.9.0', patch.neighbourTitle('Star Citizen Alpha 4.9.0'))
	self:assertEquals(nil, patch.neighbourTitle(nil))
end

function suite:testStorePutsOneRow()
	bucketLib._reset()
	patch.store(patch.readArgs({ version = '4.10.0', date = '2026-08-26' }))
	self:assertEquals(1, #bucketLib._puts)
	self:assertEquals('patch', bucketLib._puts[1].bucket)
	self:assertEquals('2026-08-26', bucketLib._puts[1].data.release_date)
	self:assertEquals('Star Citizen', bucketLib._puts[1].data.product)
end

function suite:testNeighbourDatesReadsOnceForBothTitles()
	bucketLib._reset()
	patch.neighbourDates({ 'Update:Star Citizen Alpha 4.9.0', 'Update:Star Citizen Alpha 4.10.1' })
	local chain = readChain()
	self:assertEquals('patch', chain.bucket)
	self:assertDeepEquals({ 'page_name', 'release_date' }, chain.select)
	self:assertEquals('or', chain.where[1].op)
	self:assertDeepEquals({ 'page_name', 'Update:Star Citizen Alpha 4.9.0' }, chain.where[1][1])
	self:assertDeepEquals({ 'page_name', 'Update:Star Citizen Alpha 4.10.1' }, chain.where[1][2])
end

function suite:testNeighbourDatesKeysCaseInsensitively()
	bucketLib._reset()
	bucketLib._setRows('patch', {
		{ page_name = 'Update:Star Citizen Alpha 4.9.0', release_date = '2026-07-15' },
		{ page_name = 'Update:Star Citizen Alpha 4.10.2' },
	})
	local dates = patch.neighbourDates({ 'Update:star citizen alpha 4.9.0', 'Update:Star Citizen Alpha 4.10.2' })
	self:assertEquals('2026-07-15', patch.dateFor(dates, 'Update:star citizen alpha 4.9.0'))
	-- A row without a date reads as unknown, like a missing row.
	self:assertEquals(nil, patch.dateFor(dates, 'Update:Star Citizen Alpha 4.10.2'))
	self:assertEquals(nil, patch.dateFor(dates, nil))
end

function suite:testNeighbourDatesSkipsTheReadWithoutTitles()
	bucketLib._reset()
	self:assertDeepEquals({}, patch.neighbourDates({}))
	self:assertEquals(nil, readChain())
end

function suite:testNeighbourDatesSurvivesAFailedRead()
	bucketLib._reset()
	bucketLib._failNext = true
	self:assertDeepEquals({}, patch.neighbourDates({ 'Update:Star Citizen Alpha 4.9.0' }))
end

function suite:testStoreWithoutADateStoresNoReleaseDate()
	bucketLib._reset()
	patch.store(patch.readArgs({ upcoming = 'yes' }))
	self:assertEquals(nil, bucketLib._puts[1].data.release_date)
	self:assertEquals(true, bucketLib._puts[1].data.upcoming)
end

return suite
