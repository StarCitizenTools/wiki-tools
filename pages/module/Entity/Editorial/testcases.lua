require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Editorial = require('Module:Entity/Editorial')

local suite = ScribuntoUnit:new()

local MANIFEST = {
	pledge_price = { arg = 'pledgecost', smw = 'Pledge Price', apiPath = 'msrp', transform = 'number' },
	scm_speed = { arg = 'scmspeed', smw = 'SCM Speed', apiPath = 'speed.scm', transform = 'number' },
	availability = { arg = 'pledgeavailability', smw = 'Pledge Availability' },
	series = { arg = 'series', smw = 'Series', transform = 'page' },
	added_in_version = { arg = 'addedinversion', smw = 'Added in version', transform = 'patchPage' },
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

-- A declared transform is the field's parser: input it cannot parse means the
-- editor value is ABSENT, not that the raw string stands in. parseNumber returns
-- nil for the placeholders editors actually type, so the API value must win and
-- keep its `api` provenance rather than being "overridden" by junk.
function suite:testUnparseableNumberLetsTheApiValueWin()
	local r = Editorial.resolve({ speed = { scm = 220 } }, { scmspeed = 'Unknown' }, MANIFEST)
	self:assertEquals('api', r.scm_speed.source)
	self:assertEquals(220, r.scm_speed.value)
end

--- Manifest shape of the Location count overrides: a transform and NO apiPath.
local COUNT_MANIFEST = { planets = { arg = 'planets', transform = 'number' } }

-- With no apiPath the entry is created unconditionally (source 'editorial'), so
-- an unparseable value there does not merely mislabel provenance — it displaces
-- the caller's own value. The field must not resolve at all, so View:value hands
-- back the fallback the caller passes (for Location, the starmap tally).
function suite:testUnparseableNumberWithoutApiPathDoesNotResolve()
	for _, junk in ipairs({ '?', 'TBD', 'Unknown', 'N/A', 'several' }) do
		local r = Editorial.resolve({}, { planets = junk }, COUNT_MANIFEST)
		self:assertEquals(nil, r.planets, 'junk value "' .. junk .. '" resolved to an entry')
		self:assertEquals(4, Editorial.view(r):value('planets', 4))
	end
end

-- The sharp edge of the rule, pinned because it is NOT Location-only. Vehicle's
-- editorial.json declares `transform` on 17 fields across 292 live pages, six of
-- them pure-editorial with no apiPath (warbondcost, originalpledgecost,
-- originalwarbondcost, retracted{length,width,height}). For those there is no API
-- value to defer to, so an unparseable entry does not fall back to anything — the
-- row simply disappears. That is the intended trade (a wrong number is worse than
-- a missing one), but it is the behaviour to check first when an editor reports a
-- row that "vanished". No live page currently supplies such a value: all 1068
-- transform-field values across the 292 pages parse.
function suite:testUnparseableNumberWithNoApiValueLeavesNothingToShow()
	local manifest = { warbond_price = { arg = 'warbondcost', smw = 'Warbond pledge price', transform = 'number' } }
	local resolved = Editorial.resolve({}, { warbondcost = 'TBA' }, manifest)
	self:assertEquals(nil, resolved.warbond_price)
	-- No entry and no caller fallback: the display value is nil, so the row is dropped.
	self:assertEquals(nil, Editorial.view(resolved):value('warbond_price'))
	-- A real figure on the same field still resolves, commas and all.
	self:assertEquals(275, Editorial.resolve({}, { warbondcost = '275' }, manifest).warbond_price.value)
end

-- Real editor input still parses through the same path: parseNumber handles
-- thousands separators and magnitude suffixes, so the guard costs nothing.
function suite:testParseableNumberWithoutApiPathStillResolves()
	self:assertEquals(24, Editorial.resolve({}, { planets = '24' }, COUNT_MANIFEST).planets.value)
	self:assertEquals(26245, Editorial.resolve({}, { planets = '26,245' }, COUNT_MANIFEST).planets.value)
end

-- The `page` transform never returns nil for non-empty input, so the guard does
-- not change it: a bare title and a piped link both still resolve.
function suite:testPageTransformUnaffectedByTheTransformGuard()
	self:assertEquals('Aurora', Editorial.resolve({}, { series = 'Aurora' }, MANIFEST).series.value)
	self:assertEquals('Aurora', Editorial.resolve({}, { series = '[[Aurora|Aurora MR]]' }, MANIFEST).series.value)
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

-- SMW values are queried, not rendered: the projection delinks wiki markup and
-- strips parser strip-markers (a ref in an editor arg is a UNIQ…QINU token by
-- the time Lua sees it), while the display path keeps the original value.
function suite:testToStructuredDataSanitizesStrings()
	local marker = '\127\'"`UNIQ--ref-0000001D-QINU`"\'\127'
	local r = Editorial.resolve({}, { pledgeavailability = '[[Time-limited|Limited]] sale' .. marker }, MANIFEST)
	self:assertEquals('[[Time-limited|Limited]] sale' .. marker, r.availability.value)
	local data = Editorial.toStructuredData(r, MANIFEST)
	self:assertEquals('Limited sale', data['Pledge Availability'])
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

function suite:testViewValueReturnsEntryValue()
	local r = Editorial.resolve({ msrp = 30 }, {}, MANIFEST)
	self:assertEquals(30, Editorial.view(r):value('pledge_price'))
end

function suite:testViewValueFallbackWhenAbsent()
	local ed = Editorial.view({})
	self:assertEquals('fb', ed:value('missing', 'fb'))
	self:assertEquals(nil, ed:value('missing'))
end

function suite:testViewNilResolvedIsSafe()
	local ed = Editorial.view(nil)
	self:assertEquals('fb', ed:value('x', 'fb'))
	self:assertEquals(nil, ed:source('x'))
end

function suite:testViewSourceApi()
	local r = Editorial.resolve({ msrp = 30 }, {}, MANIFEST)
	self:assertEquals('api', Editorial.view(r):source('pledge_price'))
end

function suite:testViewSourceOverride()
	local r = Editorial.resolve({ speed = { scm = 220 } }, { scmspeed = '210' }, MANIFEST)
	self:assertEquals('override', Editorial.view(r):source('scm_speed'))
end

function suite:testViewSourceWikiFromFill()
	local r = Editorial.resolve({}, { scmspeed = '210' }, MANIFEST)
	self:assertEquals('fill', r.scm_speed.source) -- internal vocabulary unchanged
	self:assertEquals('wiki', Editorial.view(r):source('scm_speed')) -- collapses to wiki
end

function suite:testViewSourceWikiFromEditorial()
	local r = Editorial.resolve({}, { pledgeavailability = 'Time-limited' }, MANIFEST)
	self:assertEquals('editorial', r.availability.source) -- internal vocabulary unchanged
	self:assertEquals('wiki', Editorial.view(r):source('availability')) -- collapses to wiki
end

function suite:testViewSourceNilWhenUnresolved()
	self:assertEquals(nil, Editorial.view({}):source('missing'))
end

function suite:testPatchPageBareVersion()
	local r = Editorial.resolve({}, { addedinversion = 'Alpha 4.8.0' }, MANIFEST)
	self:assertEquals('Update:Star Citizen Alpha 4.8.0', r.added_in_version.value)
end

function suite:testPatchPageBareRedirectTitle()
	local r = Editorial.resolve({}, { addedinversion = 'Star Citizen Alpha 3.2.0' }, MANIFEST)
	self:assertEquals('Update:Star Citizen Alpha 3.2.0', r.added_in_version.value)
end

function suite:testPatchPageAlreadyNamespaced()
	local r = Editorial.resolve({}, { addedinversion = 'Update:Star Citizen Patch V0.8.5' }, MANIFEST)
	self:assertEquals('Update:Star Citizen Patch V0.8.5', r.added_in_version.value)
end

function suite:testPatchPageExtractsLinkTarget()
	local r = Editorial.resolve({}, { addedinversion = '[[Update:Star Citizen Patch V0.8.5|Alpha 0.8.5]]' }, MANIFEST)
	self:assertEquals('Update:Star Citizen Patch V0.8.5', r.added_in_version.value)
end

return suite
