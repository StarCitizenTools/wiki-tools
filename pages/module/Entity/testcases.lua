require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Entity = require('Module:Entity')

local suite = ScribuntoUnit:new()

local isIdentifiable = Entity._internal.isIdentifiable
local setShortDescription = Entity._internal.setShortDescription

--- Only the two fields the identity guard reads out of a Data.get result.
--- @param fields nil|{ apiData: table|nil, matchedKind: table|nil }
--- @return table
local function result(fields)
	fields = fields or {}
	return { apiData = fields.apiData or {}, matchedKind = fields.matchedKind }
end

function suite:testIdentifiableByUuid()
	self:assertTrue(isIdentifiable({ uuid = 'c9c137cf-c520-47ee-9e6d-5d653dfbe201' }, result()))
end

function suite:testIdentifiableByCuratedName()
	self:assertTrue(isIdentifiable({ name = 'Stanton system' }, result()))
end

function suite:testIdentifiableByApiRecordName()
	self:assertTrue(isIdentifiable({}, result({ apiData = { name = 'Stanton System' } })))
end

--- A bare `{{Location}}` on a lore system: the facade injects |kind=Location,
--- the editorial fork resolves it, and the page's identity is its title. Before
--- this guard learned about kinds it rejected the invocation outright, so a live
--- `{{Location}}` on Nexus system rendered the red error even though the starmap
--- record resolves and the infobox would have been correct.
function suite:testIdentifiableByDeclaredKindAlone()
	self:assertTrue(isIdentifiable({ kind = 'Location' }, result({ matchedKind = { name = 'Location' } })))
end

--- The kind must have actually CLAIMED the page. A misspelled |kind= resolves to
--- no kind, so it stays an error rather than silently rendering a title-only
--- shell — this is why the guard tests result.matchedKind, not raw args.kind.
function suite:testUnresolvedKindIsStillAnError()
	self:assertFalse(isIdentifiable({ kind = 'Lcoation' }, result()))
end

function suite:testNothingAtAllIsAnError()
	self:assertFalse(isIdentifiable({}, result()))
end

function suite:testBaseStructuredDataCarriesTheClassName()
	local Base = require('Module:Entity/Base')
	-- The stable game-data key, stored for matching a page against the game files
	-- or another site's dataset.
	local data = Base.getStructuredData({
		apiData = { name = 'Gladius', class_name = 'AEGS_Gladius' },
		args = { uuid = 'u' },
	})
	self:assertEquals('AEGS_Gladius', data.class_name)
end

function suite:testBaseStructuredDataOmitsAnAbsentClassName()
	local Base = require('Module:Entity/Base')
	-- Missions carry no class name; the column is simply absent on those rows.
	local data = Base.getStructuredData({ apiData = { name = 'X' }, args = { uuid = 'u' } })
	self:assertEquals(nil, data.class_name)
end

function suite:testBaseStructuredDataCarriesImage()
	local Base = require('Module:Entity/Base')
	local data = Base.getStructuredData({ apiData = { name = 'X' }, args = { uuid = 'u', image = 'File:X.png' } })
	self:assertEquals('X.png', data.image)
	self:assertEquals(nil, Base.getStructuredData({ apiData = { name = 'X' }, args = {} }).image)
end

--- A percent-encoded filename such as `Valkyrie_%27Liberator%27_...png` (a live
--- |image= value) is a title the wikitext parser tolerates but MediaWiki's
--- Title class rejects; storing it verbatim once raised inside aggrid.thumb and
--- blanked a whole grid (task-12-report.md). The off-wiki runner's mw.title.new
--- shim never rejects a title (mwenv.lua's titleStub echoes back whatever text
--- it is given), so this overrides it for the duration of the test to simulate
--- the wiki's real Title validation; on the wiki no override is needed.
function suite:testBaseStructuredDataDropsInvalidImageTitle()
	local Base = require('Module:Entity/Base')
	local BAD = 'File:Valkyrie_%27Liberator%27_flying_fast_-_Above.png'
	local realNew = mw.title.new
	mw.title.new = function(text)
		if text == BAD then
			return nil
		end
		return realNew(text)
	end
	local ok, err = pcall(function()
		local data = Base.getStructuredData({
			apiData = { name = 'X' },
			args = { image = 'Valkyrie_%27Liberator%27_flying_fast_-_Above.png' },
		})
		self:assertEquals(nil, data.image)
	end)
	mw.title.new = realNew
	if not ok then
		error(err, 0)
	end
end

-- ── setShortDescription ────────────────────────────────────────────────────

--- @return table frame, table captured
local function capturingFrame()
	local captured = {}
	local frame = {
		callParserFunction = function(_, name, value)
			captured[#captured + 1] = { name = name, value = value }
			return ''
		end,
	}
	return frame, captured
end

--- A record-less page whose type never resolved has nothing to describe.
--- #shortdesc rejects a nil value with a Lua error that aborts the whole render
--- (Sabre Raven EX: a uuid the API 404s, no |family= so the Vehicle kind stayed
--- the leaf and contributed no getShortDescription, and a typeInfo carrying only
--- categories), so the hook must stay silent rather than call out with nothing.
function suite:testShortDescriptionSkippedWhenNothingResolves()
	local frame, captured = capturingFrame()
	setShortDescription(frame, { {} }, {}, { typeInfo = { category = 'Ships' } })
	self:assertEquals(0, #captured)
end

function suite:testShortDescriptionSkippedWhenEmpty()
	local frame, captured = capturingFrame()
	setShortDescription(frame, { {
		getShortDescription = function()
			return ''
		end,
	} }, {}, { typeInfo = {} })
	self:assertEquals(0, #captured)
end

function suite:testShortDescriptionSetFromTheChain()
	local frame, captured = capturingFrame()
	setShortDescription(
		frame,
		{ {
			getShortDescription = function()
				return 'Light fighter'
			end,
		} },
		{},
		{ typeInfo = {} }
	)
	self:assertEquals(1, #captured)
	self:assertEquals('SHORTDESC', captured[1].name)
	self:assertEquals('Light fighter', captured[1].value)
end

function suite:testShortDescriptionFallsBackToTheTypeName()
	local frame, captured = capturingFrame()
	setShortDescription(frame, { {} }, {}, { typeInfo = { name = 'Spacecraft' } })
	self:assertEquals('Spacecraft', captured[1].value)
end

function suite:testNamesNoMakerCoversTheFourSentinels()
	local Base = require('Module:Entity/Base')
	for _, code in ipairs({ 'GENF', 'GEND', 'NONE', 'TBD' }) do
		self:assertEquals(true, Base.namesNoMaker(code), code)
	end
	-- UNKN is a real record with its own catalogue page.
	self:assertEquals(false, Base.namesNoMaker('UNKN'))
	self:assertEquals(false, Base.namesNoMaker('AEGS'))
	self:assertEquals(false, Base.namesNoMaker(''))
	self:assertEquals(false, Base.namesNoMaker(nil))
end

function suite:testResolveManufacturerDropsAnApiSentinel()
	local Base = require('Module:Entity/Base')
	self:assertEquals(nil, Base.resolveManufacturer({ manufacturer = { code = 'NONE', name = 'None' } }, {}))
end

function suite:testResolveManufacturerKeepsAnEditorialSentinel()
	-- NONE is recorded as the page's classification; only link targets drop it.
	local Base = require('Module:Entity/Base')
	self:assertEquals('NONE', Base.resolveManufacturer({}, { manufacturer = 'NONE' }).code)
end

return suite
