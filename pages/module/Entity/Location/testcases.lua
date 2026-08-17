require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Location = require('Module:Entity/Location')

local suite = ScribuntoUnit:new()

--- Stanton-shaped location payload (trimmed from the live API response).
local function solarSystemFixture()
	return {
		uuid = 'c9c137cf-c520-47ee-9e6d-5d653dfbe201',
		name = 'Stanton System',
		respawn_location_type = 'None',
		type = { name = 'SolarSystem', classification = 'Solar System' },
		jurisdiction = { name = 'UEE' },
	}
end

--- Starmap record as enrich() attaches it (trimmed).
local function starsystemFixture()
	return {
		code = 'STANTON',
		type = 'SINGLE_STAR',
		status = 'P',
		aggregated = { size = 4.85, population = 10, economy = 10 },
		affiliation = { { code = 'uee', name = 'UEE' } },
		celestial_objects = {
			{ type = 'STAR', sub_type = { name = 'Main Sequence-Dwarf-G' } },
			{ type = 'PLANET' },
			{ type = 'PLANET' },
			{ type = 'SATELLITE' },
			{ type = 'ASTEROID_BELT' },
			{ type = 'MANMADE' },
			{ type = 'JUMPPOINT' },
		},
	}
end

function suite:testMatchesSolarSystem()
	self:assertTrue(Location.matches(solarSystemFixture()))
end

function suite:testMatchesRejectsOtherLocationClassifications()
	local planet = solarSystemFixture()
	planet.type = { name = 'Planet', classification = 'Planet' }
	self:assertFalse(Location.matches(planet))
end

function suite:testMatchesRejectsNonLocationPayloads()
	self:assertFalse(Location.matches(nil))
	self:assertFalse(Location.matches({}))
	-- Item-shaped: class_name, string type.
	self:assertFalse(Location.matches({ class_name = 'behr_lmg_ballistic_01', type = 'WeaponPersonal' }))
	-- Vehicle-shaped.
	self:assertFalse(Location.matches({ class_name = 'AEGS_Gladius', is_vehicle = true }))
	-- Commodity-shaped.
	self:assertFalse(Location.matches({ box_sizes_scu = { 1, 2, 4 } }))
	-- Mission-shaped.
	self:assertFalse(Location.matches({ mission_type = 'Delivery' }))
end

function suite:testEditorialModeOptIn()
	self:assertEquals(true, Location.editorialMode)
end

function suite:testShouldFetchStarsystem()
	local f = Location._internal.shouldFetchStarsystem
	self:assertTrue(f(solarSystemFixture(), nil)) -- uuid path, SolarSystem record
	self:assertTrue(f({}, { kind = 'Location' })) -- editorial fork, kind-declared
	self:assertFalse(f({ type = { name = 'Planet' } }, nil)) -- other location, undeclared
	self:assertFalse(f({}, {})) -- nothing at all
end

function suite:testResolveLookupNamePrecedence()
	local f = Location._internal.resolveLookupName
	self:assertEquals('Rihlah', f({ name = 'Ignored System' }, { starmapname = 'Rihlah', name = 'Also ignored' }))
	self:assertEquals('Stanton System', f({ name = 'Stanton System' }, { name = 'Ignored' }))
	self:assertEquals('Terra system', f({}, { name = 'Terra system' }))
end

function suite:testPlainKey()
	local f = Location._internal.plainKey
	self:assertEquals('stanton', f('Stanton System'))
	self:assertEquals('terra', f('Terra system'))
	self:assertEquals("kyuk'ya", f("Kyuk'ya"))
	self:assertEquals(nil, f(nil))
	self:assertEquals(nil, f(''))
	self:assertEquals(nil, f(' System'))
end

function suite:testPickStarsystemExactBeatsAliasBeatsFirst()
	local f = Location._internal.pickStarsystem
	local rows = {
		{ name = 'Vega Prime' },
		{ name = 'Vega' },
	}
	self:assertEquals('Vega', f(rows, 'vega').name)
	local aliasRows = {
		{ name = 'Something Else' },
		{ name = "K.ap'a'ri (Khabari)" },
	}
	self:assertEquals("K.ap'a'ri (Khabari)", f(aliasRows, 'khabari').name)
	self:assertEquals('Something Else', f(aliasRows, 'nomatch').name)
end

function suite:testSubtypeMapTargetsStarSystem()
	self:assertEquals('Entity/Location/StarSystem', Location._internal.LOCATION_SUBTYPE_MAP.SolarSystem)
end

function suite:testGetCategoriesFullRecord()
	local apiData = solarSystemFixture()
	apiData.starsystem = starsystemFixture()
	local categories = Location.getCategories(apiData)
	self:assertEquals('Single Star systems', categories[1])
	self:assertEquals('United Empire of Earth systems', categories[2])
end

function suite:testGetCategoriesWithoutStarsystem()
	local categories = Location.getCategories(solarSystemFixture())
	self:assertEquals(0, #categories)
end

function suite:testGetCategoriesUnclaimed()
	local apiData = solarSystemFixture()
	local starsystem = starsystemFixture()
	starsystem.affiliation = { { code = 'UNC', name = 'UNC' } }
	apiData.starsystem = starsystem
	local categories = Location.getCategories(apiData)
	self:assertEquals('Unclaimed systems', categories[2])
end

function suite:testEditorialManifestShape()
	local manifest = Location.getEditorialManifest()
	self:assertEquals('discoveredin', manifest.discoveredin.arg)
	self:assertEquals('Discovered in', manifest.discoveredin.smw)
	self:assertEquals('starsystem.aggregated.size', manifest.size.apiPath)
	self:assertEquals('number', manifest.size.transform)
	self:assertEquals('startypes', manifest.startypes.arg)
	self:assertEquals(nil, manifest.startypes.apiPath)
end

function suite:testPrimaryConfigShape()
	local config = Location.getApiConfigs()[1]
	self:assertEquals('locations/%s', config.endpoint)
	self:assertEquals('data', config.responseDataPath)
	self:assertEquals('en_EN', config.params.locale)
end

-- ── StarSystem leaf ────────────────────────────────────────────────────────

local StarSystem = require('Module:Entity/Location/StarSystem')
local Registry = require('Module:Entity/Registry')

function suite:testResolveSubtypeReturnsStarSystem()
	local leaf = Location.resolveSubtype(solarSystemFixture(), {})
	self:assertEquals(StarSystem, leaf)
	self:assertEquals('Entity/Location', leaf.parent)
end

function suite:testResolveSubtypeUnknownClassification()
	local planet = solarSystemFixture()
	planet.type = { name = 'Planet' }
	self:assertEquals(nil, Location.resolveSubtype(planet, {}))
end

function suite:testResolveSubtypeKindDeclaredDefaultsToStarSystem()
	local leaf = Location.resolveSubtype({}, { kind = 'Location' })
	self:assertEquals('Entity/Location', leaf.parent)
end

function suite:testResolveSubtypeUndeclaredWithoutRecordIsNil()
	self:assertEquals(nil, Location.resolveSubtype({}, {}))
end

--- The search resolver offers one payload to every kind: only Location may
--- claim a location record.
function suite:testOnlyLocationClaimsLocationPayloads()
	local fixture = solarSystemFixture()
	for _, kind in ipairs(Registry.kinds) do
		if kind.name == 'Location' then
			self:assertTrue(kind.matches(fixture))
		else
			self:assertFalse(kind.matches(fixture), kind.name .. ' falsely claims a location payload')
		end
	end
end

function suite:testGetTypeInfo()
	local apiData = solarSystemFixture()
	apiData.starsystem = starsystemFixture()
	local info = StarSystem.getTypeInfo(apiData)
	self:assertEquals('Single star system', info.name)
	self:assertEquals('Systems', info.category)
end

function suite:testGetTypeInfoFallback()
	local info = StarSystem.getTypeInfo(solarSystemFixture())
	self:assertEquals('Star system', info.name)
end

function suite:testFormatSensor()
	local f = StarSystem._internal.formatSensor
	self:assertEquals('10/10', f(10))
	self:assertEquals('8.1/10', f(8.13))
	self:assertEquals('3/10', f(3.02))
	self:assertEquals(nil, f(0))
	self:assertEquals(nil, f(nil))
	self:assertEquals(nil, f('n/a'))
end

function suite:testBuildObjectTiles()
	local tiles = StarSystem._internal.buildObjectTiles(starsystemFixture())
	self:assertEquals(6, #tiles)
	self:assertEquals(1, tiles[1].value)
	self:assertEquals('Star', tiles[1].label) -- count-1 → singular
	self:assertEquals('Planets', tiles[2].label)
	self:assertEquals(2, tiles[2].value)
	self:assertEquals('Belt', tiles[4].label) -- fixture has ONE belt → singular
	self:assertEquals('Asteroid belts', tiles[4].title)
end

function suite:testBuildObjectTilesEmpty()
	self:assertEquals(0, #StarSystem._internal.buildObjectTiles(nil))
	self:assertEquals(0, #StarSystem._internal.buildObjectTiles({ celestial_objects = {} }))
end

-- Editorial hand counts beat the starmap tallies (Stanton: 24 stations
-- counting rest stops vs the starmap's 6 MANMADE objects).
function suite:testBuildObjectTilesEditorialOverride()
	local Editorial = require('Module:Entity/Editorial')
	local ed = Editorial.view({ stations = { value = 24, source = 'editorial' } })
	local tiles = StarSystem._internal.buildObjectTiles(starsystemFixture(), ed)
	local station
	for _, tile in ipairs(tiles) do
		if tile.label == 'Stations' then
			station = tile
		end
	end
	self:assertEquals(24, station.value)
end

function suite:testStructuredDataCountOverride()
	local apiData = solarSystemFixture()
	apiData.starsystem = starsystemFixture()
	local resolved = { stations = { value = 24, source = 'editorial' } }
	local data = StarSystem.getStructuredData(apiData, {}, resolved)
	self:assertEquals(24, data.station_count)
	self:assertEquals(2, data.planet_count) -- un-overridden counts keep the API tally
end

function suite:testShortDescriptionPlanetOverride()
	local apiData = solarSystemFixture()
	apiData.starsystem = starsystemFixture()
	local resolved = { planets = { value = 4, source = 'editorial' } }
	local typeInfo = StarSystem.getTypeInfo(apiData)
	self:assertEquals(
		'UEE single star system with 4 planets',
		StarSystem.getShortDescription(apiData, {}, typeInfo, nil, resolved)
	)
end

function suite:testStarTypeList()
	self:assertEquals('G-type main sequence', StarSystem._internal.starTypeList(starsystemFixture()))
	self:assertEquals(nil, StarSystem._internal.starTypeList(nil))
end

function suite:testStatusLabels()
	self:assertEquals('Published', StarSystem._internal.STATUS_LABELS.P)
	self:assertEquals('Probe data incomplete', StarSystem._internal.STATUS_LABELS.N)
end

function suite:testGetFooterButtons()
	local apiData = solarSystemFixture()
	apiData.starsystem = starsystemFixture()
	local buttons = StarSystem.getFooterButtons(apiData, {})
	self:assertEquals(1, #buttons)
	self:assertEquals('Starmap', buttons[1].label)
	self:assertEquals('https://robertsspaceindustries.com/starmap?location=STANTON', buttons[1].url)
	self:assertEquals('Sc-icon-galactapedia.svg', buttons[1].icon)
end

function suite:testGetFooterButtonsWithoutRecord()
	self:assertEquals(0, #StarSystem.getFooterButtons(solarSystemFixture(), {}))
end

function suite:testGetMetadataItems()
	local apiData = solarSystemFixture()
	apiData.starsystem = starsystemFixture()
	local items = StarSystem.getMetadataItems(apiData, {})
	self:assertEquals(1, #items)
	self:assertEquals('Starmap code', items[1].label)
	self:assertEquals('STANTON', items[1].content)
end

function suite:testGetMetadataItemsWithoutRecord()
	self:assertEquals(0, #StarSystem.getMetadataItems(solarSystemFixture(), {}))
end

-- Legacy planet-count formula + affiliation prefix, no trailing period.
function suite:testShortDescriptionUee()
	local apiData = solarSystemFixture()
	apiData.starsystem = starsystemFixture() -- 2 planets in the fixture
	local typeInfo = StarSystem.getTypeInfo(apiData)
	self:assertEquals('UEE single star system with 2 planets', StarSystem.getShortDescription(apiData, {}, typeInfo))
end

function suite:testShortDescriptionUnclaimed()
	local apiData = solarSystemFixture()
	local starsystem = starsystemFixture()
	starsystem.affiliation = { { code = 'UNC' } }
	apiData.starsystem = starsystem
	local typeInfo = StarSystem.getTypeInfo(apiData)
	self:assertEquals(
		'Unclaimed single star system with 2 planets',
		StarSystem.getShortDescription(apiData, {}, typeInfo)
	)
end

function suite:testShortDescriptionSingularPlanet()
	local apiData = solarSystemFixture()
	local starsystem = starsystemFixture()
	starsystem.celestial_objects = { { type = 'STAR' }, { type = 'PLANET' } }
	apiData.starsystem = starsystem
	local typeInfo = StarSystem.getTypeInfo(apiData)
	self:assertEquals('UEE single star system with 1 planet', StarSystem.getShortDescription(apiData, {}, typeInfo))
end

function suite:testShortDescriptionNoPlanetsNoAffiliation()
	local apiData = solarSystemFixture()
	local starsystem = starsystemFixture()
	starsystem.celestial_objects = { { type = 'STAR' } }
	starsystem.affiliation = nil
	apiData.starsystem = starsystem
	local typeInfo = StarSystem.getTypeInfo(apiData)
	self:assertEquals('Single star system', StarSystem.getShortDescription(apiData, {}, typeInfo))
end

function suite:testShortDescriptionNoRecordFallsBackToLegacyCatchAll()
	local apiData = solarSystemFixture()
	local typeInfo = StarSystem.getTypeInfo(apiData)
	self:assertEquals('A star system in Star Citizen', StarSystem.getShortDescription(apiData, {}, typeInfo))
end

local function findSection(sections, key)
	for _, s in ipairs(sections) do
		if s.key == key then
			return s
		end
	end
end

local function findItem(section, label)
	for _, item in ipairs(section.items) do
		if item.label == label then
			return item.content
		end
	end
end

function suite:testGetSectionsGeneralRows()
	local apiData = solarSystemFixture()
	apiData.starsystem = starsystemFixture()
	local general = findSection(StarSystem.getSections(apiData, {}, nil), 'general')
	self:assertEquals('[[United Empire of Earth]]', findItem(general, 'Affiliation'))
	self:assertEquals('[[UEE]]', findItem(general, 'Jurisdiction'))
	self:assertEquals('4.85 AU', findItem(general, 'Size'))
	self:assertEquals('G-type main sequence', findItem(general, 'Star type'))
	-- Demoted from a header badge: RSI workflow state renders as a plain,
	-- explicitly-labelled row so it cannot read as in-game availability.
	self:assertEquals('Published', findItem(general, 'Starmap status'))
end

function suite:testGetSectionsRowsCollapse()
	-- Pyro-shaped: no jurisdiction, no starsystem record → General carries no
	-- Affiliation/Jurisdiction/Size rows; sensor and objects sections drop.
	local apiData = solarSystemFixture()
	apiData.name = 'Pyro System'
	apiData.jurisdiction = nil
	local sections = StarSystem.getSections(apiData, {}, nil)
	local general = findSection(sections, 'general')
	if general then
		self:assertEquals(nil, findItem(general, 'Jurisdiction'))
		self:assertEquals(nil, findItem(general, 'Affiliation'))
	end
	self:assertEquals(nil, findSection(sections, 'sensor'))
	self:assertEquals(nil, findSection(sections, 'objects'))
end

function suite:testStructuredData()
	local apiData = solarSystemFixture()
	apiData.starsystem = starsystemFixture()
	local data = StarSystem.getStructuredData(apiData, {}, nil)
	-- Raw code + compact affiliation: the vocabulary pre-Entity pages store.
	self:assertEquals('SINGLE_STAR', data.system_type)
	self:assertEquals('UEE', data.affiliation)
	self:assertEquals(1, data.star_count)
	self:assertEquals(2, data.planet_count)
	self:assertEquals(1, data.moon_count)
	self:assertEquals(1, data.station_count)
	self:assertEquals(1, data.jump_point_count)
end

function suite:testStructuredDataWithoutStarsystem()
	local data = StarSystem.getStructuredData(solarSystemFixture(), {}, nil)
	self:assertEquals(nil, next(data))
end

--- An unpublished system with no catalogued bodies: the ARK's stub block, which
--- the twelve Vanduul systems share byte-for-byte. `size` varies (0, 1, 7)
--- across them and is noise in every case.
--- @param status string
--- @param size number
local function withheldStubFixture(status, size)
	local record = starsystemFixture()
	record.status = status
	record.aggregated = { size = size, population = 1.08, economy = 0.12 }
	record.celestial_objects = { { type = 'STAR', sub_type = { name = 'Main Sequence-Dwarf-G' } } }
	return record
end

-- A zero size is never a measurement, whatever the status.
function suite:testNormalizeAggregatesDropsZeroSize()
	local f = Location._internal.normalizeAggregates
	local record = starsystemFixture()
	record.aggregated.size = 0
	self:assertEquals(nil, f(record).aggregated.size)
end

function suite:testNormalizeAggregatesDropsNonPositiveOrUnparsableSize()
	local f = Location._internal.normalizeAggregates
	for _, bad in ipairs({ -1, '0', 'Unknown' }) do
		local record = starsystemFixture()
		record.aggregated.size = bad
		self:assertEquals(nil, f(record).aggregated.size)
	end
end

function suite:testNormalizeAggregatesKeepsRealSize()
	local f = Location._internal.normalizeAggregates
	self:assertEquals(4.85, f(starsystemFixture()).aggregated.size)
	-- Numeric strings are a legitimate measurement and survive untouched.
	local stringy = starsystemFixture()
	stringy.aggregated.size = '9.83'
	self:assertEquals('9.83', f(stringy).aggregated.size)
end

function suite:testNormalizeAggregatesToleratesMissingShapes()
	local f = Location._internal.normalizeAggregates
	self:assertEquals(nil, f(nil))
	self:assertEquals(nil, next(f({})))
	local noAggregate = { code = 'STANTON' }
	self:assertEquals('STANTON', f(noAggregate).code)
end

-- A zero-size record must leave the Size row out entirely rather than assert
-- "0 AU"; the other rows keep rendering.
function suite:testSectionsOmitSizeRowForZeroSizeSystem()
	local record = starsystemFixture()
	record.aggregated.size = 0
	local apiData = solarSystemFixture()
	apiData.starsystem = Location._internal.normalizeAggregates(record)
	local general = findSection(StarSystem.getSections(apiData, {}, nil), 'general')
	self:assertEquals(nil, findItem(general, 'Size'))
	self:assertEquals('Published', findItem(general, 'Starmap status'))
end

-- The stub block is dropped whole — a nonzero size in it is still noise, and the
-- population/economy sensors are the same template default.
function suite:testNormalizeAggregatesDropsWholeWithheldStub()
	local f = Location._internal.normalizeAggregates
	-- 0/1/7 AU are the three sizes the twelve Vanduul stubs actually report.
	for _, size in ipairs({ 0, 1, 7 }) do
		local aggregated = f(withheldStubFixture('M', size)).aggregated
		self:assertEquals(nil, aggregated.size)
		self:assertEquals(nil, aggregated.population)
		self:assertEquals(nil, aggregated.economy)
	end
	-- Status N (probe data incomplete) reports the same stub as straight zeros.
	self:assertEquals(nil, f(withheldStubFixture('N', 0)).aggregated.size)
end

-- Published beats every other signal: Gurzil has no catalogued bodies and a real
-- 4.2 AU extent, so a bodies-only rule would wrongly strip it.
function suite:testNormalizeAggregatesKeepsPublishedSystemWithNoBodies()
	local record = withheldStubFixture('P', 4.2)
	record.aggregated.economy = 0.93
	record.aggregated.population = 0
	local aggregated = Location._internal.normalizeAggregates(record).aggregated
	self:assertEquals(4.2, aggregated.size)
	self:assertEquals(0.93, aggregated.economy)
end

-- Unpublished but properly catalogued systems keep their real aggregates, so a
-- status-only rule would wrongly strip them (Caliban / Orion / Virgil / Oretani).
function suite:testNormalizeAggregatesKeepsCataloguedUnpublishedSystem()
	local record = withheldStubFixture('M', 5.89)
	record.aggregated.planets = 5
	record.aggregated.moons = 9
	record.aggregated.population = 7.21
	local aggregated = Location._internal.normalizeAggregates(record).aggregated
	self:assertEquals(5.89, aggregated.size)
	self:assertEquals(7.21, aggregated.population)
end

-- Stars must not count as bodies: the stub claims one, so counting it would
-- disable the rule on every page it exists for.
function suite:testNormalizeAggregatesIgnoresStarsInBodyCount()
	local record = withheldStubFixture('M', 7)
	record.aggregated.stars = 1
	self:assertEquals(nil, Location._internal.normalizeAggregates(record).aggregated.size)
end

-- End to end: a withheld stub renders neither a Size row nor a sensor section.
function suite:testSectionsDropSizeAndSensorsForWithheldStub()
	local apiData = solarSystemFixture()
	apiData.starsystem = Location._internal.normalizeAggregates(withheldStubFixture('M', 7))
	local sections = StarSystem.getSections(apiData, {}, nil)
	self:assertEquals(nil, findItem(findSection(sections, 'general'), 'Size'))
	self:assertEquals(nil, findSection(sections, 'sensor'))
end

-- An editorial |size= override still wins over an absent starmap size.
function suite:testSizeOverrideSurvivesDroppedStarmapSize()
	local apiData = solarSystemFixture()
	apiData.starsystem = starsystemFixture()
	apiData.starsystem.aggregated.size = nil
	local resolved = { size = { value = 12, source = 'override' } }
	local general = findSection(StarSystem.getSections(apiData, {}, resolved), 'general')
	self:assertEquals('12 AU', findItem(general, 'Size'))
end

return suite
