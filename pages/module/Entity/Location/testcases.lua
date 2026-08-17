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

function suite:testDeriveFilterKey()
	local derive = Location._internal.deriveFilterKey
	self:assertEquals('stanton', derive('Stanton System'))
	self:assertEquals('pyro', derive('Pyro System'))
	self:assertEquals('nyx', derive('Nyx System'))
	-- Encoding details (apostrophe → %27 or as-is) vary by shim; the invariants
	-- are lowercase and no raw spaces.
	local ailka = derive("Ail'ka System")
	self:assertEquals(ailka, ailka:lower())
	self:assertEquals(nil, ailka:match('%s'))
	self:assertEquals(nil, derive(nil))
	self:assertEquals(nil, derive(''))
	self:assertEquals(nil, derive(' System'))
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
	self:assertEquals('https://robertsspaceindustries.com/starmap?system=STANTON', buttons[1].url)
	self:assertEquals('Sc-icon-galactapedia.svg', buttons[1].icon)
end

function suite:testGetFooterButtonsWithoutRecord()
	self:assertEquals(0, #StarSystem.getFooterButtons(solarSystemFixture(), {}))
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

return suite
