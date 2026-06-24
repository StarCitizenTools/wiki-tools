require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Editorial = require('Module:Entity/Editorial')

local suite = ScribuntoUnit:new()

local MANIFEST = {
	pledge_price = { arg = 'pledgecost', smw = 'Pledge Price', apiPath = 'msrp', transform = 'number' },
	scm_speed = { arg = 'scmspeed', smw = 'SCM Speed', apiPath = 'speed.scm', transform = 'number' },
	availability = { arg = 'pledgeavailability', smw = 'Pledge Availability' },
	series = { arg = 'series', smw = 'Series', transform = 'page' },
}

function suite:testApiOnlyWhenNoEditor()
	local r = Editorial.resolve({ msrp = 30 }, {}, MANIFEST)
	self:assertEquals('api', r.pledge_price.source)
	self:assertEquals(30, r.pledge_price.value)
end

function suite:testFieldOmittedWhenNeitherSource()
	local r = Editorial.resolve({}, {}, MANIFEST)
	self:assertEquals(nil, r.pledge_price)
end

function suite:testFillWhenApiEmpty()
	local r = Editorial.resolve({}, { scmspeed = '210' }, MANIFEST)
	self:assertEquals('fill', r.scm_speed.source)
	self:assertEquals(210, r.scm_speed.value)
end

function suite:testOverrideWhenDiffers()
	local r = Editorial.resolve({ speed = { scm = 220 } }, { scmspeed = '210' }, MANIFEST)
	self:assertEquals('override', r.scm_speed.source)
	self:assertEquals(210, r.scm_speed.value)
	self:assertEquals(220, r.scm_speed.apiValue)
end

function suite:testRedundantEditorialIsApiNotOverride()
	local r = Editorial.resolve({ msrp = 26245 }, { pledgecost = '26,245' }, MANIFEST)
	self:assertEquals('api', r.pledge_price.source)
end

function suite:testPureEditorialNeverAudited()
	local r = Editorial.resolve({}, { pledgeavailability = 'Time-limited' }, MANIFEST)
	self:assertEquals('editorial', r.availability.source)
	self:assertEquals(false, Editorial.hasManualApiData(r))
end

function suite:testNumberTransformStripsUnitsAndSuffix()
	local r = Editorial.resolve({}, { scmspeed = '900K µSCU' }, MANIFEST)
	self:assertEquals(900000, r.scm_speed.value)
end

function suite:testHasManualApiData()
	local r = Editorial.resolve({ speed = { scm = 220 } }, { scmspeed = '210' }, MANIFEST)
	self:assertEquals(true, Editorial.hasManualApiData(r))
end

function suite:testToStructuredDataProjectsAndFlagsManual()
	local r = Editorial.resolve(
		{ speed = { scm = 220 } },
		{ scmspeed = '210', pledgeavailability = 'Time-limited' },
		MANIFEST
	)
	local data = Editorial.toStructuredData(r, MANIFEST)
	self:assertEquals(210, data['SCM Speed'])
	self:assertEquals('Time-limited', data['Pledge Availability'])
	self:assertEquals(1, #data['Manual API field'])
	self:assertEquals('scm_speed', data['Manual API field'][1])
end

function suite:testPageTransform()
	local r = Editorial.resolve({}, { series = '[[Aurora]]' }, MANIFEST)
	self:assertEquals('Aurora', r.series.value)
end

function suite:testArgAliasFirstNonEmptyWins()
	-- A list-valued .arg tries each alias in order (mirrors legacy [ARG_Series, ARG_Model]).
	local M = { series = { arg = { 'series', 'model' }, smw = 'Series' } }
	self:assertEquals('Hull', Editorial.resolve({}, { series = 'Hull' }, M).series.value)
	self:assertEquals('Railen', Editorial.resolve({}, { model = 'Railen' }, M).series.value)
	-- First alias wins when both are set.
	self:assertEquals('A', Editorial.resolve({}, { series = 'A', model = 'B' }, M).series.value)
	-- Empty first alias falls through to the second.
	self:assertEquals('B', Editorial.resolve({}, { series = '', model = 'B' }, M).series.value)
end

return suite
