require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Editorial = require('Module:Entity/Editorial')
local Location = require('Module:Entity/Location')
local Util = require('Module:Entity/Location/Util')
local assembly = require('Module:Entity/Assembly')
local StarSystem = require('Module:Entity/Location/StarSystem')
local JumpPoint = require('Module:Entity/Location/JumpPoint')
local Star = require('Module:Entity/Location/Star')
local Body = require('Module:Entity/Location/Body')

--- Hook context for direct hook calls (Module:Entity/Types EntityHookContext).
local function ctx(apiData, args, resolved)
	return { apiData = apiData, args = args or {}, resolved = resolved }
end

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

--- Pyro - Nyx gate location payload (trimmed from the live API response): the
--- record shape the probe fetches for a jump-point uuid. Typed 'Anomaly' —
--- the token the locations API gives jump points AND non-jump-point
--- anomalies; only the exact name suffix separates a gate.
local function jumpPointFixture()
	return {
		uuid = '80bac534-3e84-4a2d-97c2-3edefa2d5bef',
		name = 'Pyro - Nyx Jump Point',
		respawn_location_type = 'Other',
		type = { name = 'Anomaly', classification = 'Anomaly' },
		jurisdiction = { name = 'UEE' },
		system = 'Pyro System', -- plain string: the live field shape (not an embedded record)
		hide_in_starmap = true, -- true on all four live gates
		quantum_travel = {
			arrival_radius_formatted = '18 km',
			adoption_radius_formatted = '500 km',
			obstruction_radius_formatted = '11 km',
		},
	}
end

--- Starmap celestial-object record as enrichCelestialObject() attaches it
--- (trimmed from the live API response).
local function celestialObjectFixture()
	return {
		code = 'PYRO.JUMPPOINTS.NYX',
		designation = 'Pyro - Nyx',
		type = 'JUMPPOINT',
		distance = 13,
		jumppoints = { size = 'M', direction = 'B' },
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

-- Outpost stands in for "a location type no leaf models yet"; it is the most
-- numerous one (902 records). Planet and Moon were this test's example until
-- the Body leaf claimed them.
function suite:testMatchesRejectsOtherLocationClassifications()
	local outpost = solarSystemFixture()
	outpost.type = { name = 'Outpost', classification = 'Outpost' }
	self:assertFalse(Location.matches(outpost))
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

-- matches() claims exactly the records a leaf renders: SolarSystem records
-- and jump-point gates in every form the API emits.
function suite:testMatchesJumpPointRecords()
	self:assertTrue(Location.matches(jumpPointFixture()))
	local castra = jumpPointFixture()
	castra.name = 'Jump Point Pyro Castra'
	self:assertTrue(Location.matches(castra))
	local typed = jumpPointFixture()
	typed.type = { name = 'JumpPoint' }
	typed.name = 'Stanton - Magnus Jump Point'
	self:assertTrue(Location.matches(typed))
end

function suite:testMatchesRejectsWreckSite()
	local wreck = jumpPointFixture()
	wreck.name = 'Stanton-Pyro Jump Point Wreck Site'
	self:assertFalse(Location.matches(wreck))
end

function suite:testLeafFamilyTagsMatchDispatch()
	self:assertEquals('starsystem', StarSystem.family)
	self:assertEquals('jumppoint', JumpPoint.family)
	self:assertEquals(StarSystem, Location.resolveSubtype({}, { kind = 'Location', family = StarSystem.family }))
	self:assertEquals(JumpPoint, Location.resolveSubtype({}, { kind = 'Location', family = JumpPoint.family }))
	self:assertEquals('starsystem', Location.defaultFamily)
end

function suite:testEditorialModeOptIn()
	self:assertEquals(true, Location.editorialMode)
end

-- The predicate recordFamily uses to distinguish a jump-point record from
-- every other Anomaly-typed one, exercised directly: the Anomaly type alone
-- is NOT a jump point, and the name check is a real suffix match — the
-- wreck site (suffix mid-name) and the misnamed inactive gate (prefix) must
-- both stay out.
function suite:testIsJumpPointRecord()
	local f = Location._internal.isJumpPointRecord
	self:assertTrue(f(jumpPointFixture()))
	self:assertFalse(f({ type = { name = 'Anomaly' }, name = 'Stanton-Pyro Jump Point Wreck Site' }))
	-- The one upstream misnaming: exact "Jump Point " PREFIX also admits (a
	-- real Pyro gate); "Jump PointX" (no space) does not.
	self:assertTrue(f({ type = { name = 'Anomaly' }, name = 'Jump Point Pyro Castra' }))
	self:assertFalse(f({ type = { name = 'Anomaly' }, name = 'Jump Pointer Pyro' }))
	-- The unambiguous 'JumpPoint' type token admits regardless of name — the
	-- repurposed Stanton-side gates carry STALE names (the record called
	-- 'Stanton - Magnus Jump Point' is the in-game Stanton - Nyx gate).
	self:assertTrue(f({ type = { name = 'JumpPoint' }, name = 'Stanton - Magnus Jump Point' }))
	self:assertTrue(f({ type = { name = 'JumpPoint' } })) -- even nameless
	-- The type half: the suffix alone does not admit other classifications.
	self:assertFalse(f({ type = { name = 'SolarSystem' }, name = 'Odd Jump Point' }))
	self:assertFalse(f({ name = 'Pyro - Nyx Jump Point' })) -- untyped record
	self:assertFalse(f({ type = { name = 'Anomaly' } })) -- nameless record
	self:assertFalse(f(nil))
	self:assertFalse(f({}))
end

-- Every subtype leaf in the map conforms to the contributor contract, strict
-- mode included: a misspelled hook (getMetadateItems) no-ops silently at
-- render time. Kinds and facets get this from Registry/testcases; the leaves
-- get it here.
function suite:testSubtypeLeavesConformToChainLinkContract()
	local Contract = require('Module:Entity/Contract')
	for token, path in pairs(Location._internal.LOCATION_SUBTYPE_MAP) do
		local leaf = require('Module:' .. path)
		local ok, errors = Contract.validate(leaf, Contract.CHAIN_LINK, { strict = true })
		self:assertTrue(ok, token .. ' leaf fails the chain contract: ' .. table.concat(errors or {}, '; '))
		self:assertEquals('Entity/Location', leaf.parent, token .. ' leaf parent')
	end
end

function suite:testSubtypeMapTargetsStarSystem()
	self:assertEquals('Entity/Location/StarSystem', Location._internal.LOCATION_SUBTYPE_MAP.starsystem)
end

-- Pins the leaf PATH Task 3's module must occupy (Module: prefix added by the
-- SubtypeResolver); the identity assertion lives in
-- testResolveSubtypeJumpPointRecord.
function suite:testSubtypeMapTargetsJumpPoint()
	self:assertEquals('Entity/Location/JumpPoint', Location._internal.LOCATION_SUBTYPE_MAP.jumppoint)
end

function suite:testGetCategoriesFullRecord()
	local apiData = solarSystemFixture()
	apiData.starsystem = starsystemFixture()
	local categories = StarSystem.getCategories(ctx(apiData, {}, nil))
	self:assertEquals('Single Star systems', categories[1])
	self:assertEquals('United Empire of Earth systems', categories[2])
end

function suite:testGetCategoriesWithoutStarsystem()
	local categories = StarSystem.getCategories(ctx(solarSystemFixture(), {}, nil))
	self:assertEquals(0, #categories)
end

function suite:testGetCategoriesUnclaimed()
	local apiData = solarSystemFixture()
	local starsystem = starsystemFixture()
	starsystem.affiliation = { { code = 'UNC', name = 'UNC' } }
	apiData.starsystem = starsystem
	local categories = StarSystem.getCategories(ctx(apiData, {}, nil))
	self:assertEquals('Unclaimed systems', categories[2])
end

function suite:testEditorialManifestShape()
	local manifest = assembly.mergeEditorialManifests(assembly.buildChain(StarSystem))
	self:assertEquals('discoveredin', manifest.discoveredin.arg)
	self:assertEquals('Discovered in', manifest.discoveredin.property)
	self:assertEquals('starsystem.aggregated.size', manifest.size.apiPath)
	self:assertEquals('number', manifest.size.transform)
	self:assertEquals('startypes', manifest.startypes.arg)
	self:assertEquals(nil, manifest.startypes.apiPath)
	-- Each link declares only the fields its rows read.
	local kindOnly = Location.getEditorialManifest()
	self:assertEquals('discoveredin', kindOnly.discoveredin.arg)
	self:assertEquals(nil, kindOnly.size)
	self:assertEquals(nil, kindOnly.starmapcode)
	local jump = JumpPoint.getEditorialManifest()
	self:assertEquals('starmapcode', jump.starmapcode.arg[1])
	self:assertEquals(nil, jump.size)
	self:assertEquals(nil, StarSystem.getEditorialManifest().starmapcode)
end

function suite:testPrimaryConfigShape()
	local config = Location.getApiConfigs()[1]
	self:assertEquals('locations/%s', config.endpoint)
	self:assertEquals('data', config.responseDataPath)
	self:assertEquals('en_EN', config.params.locale)
end

-- ── StarSystem leaf ────────────────────────────────────────────────────────

local Registry = require('Module:Entity/Registry')

function suite:testResolveSubtypeReturnsStarSystem()
	local leaf = Location.resolveSubtype(solarSystemFixture(), {})
	self:assertEquals(StarSystem, leaf)
	self:assertEquals('Entity/Location', leaf.parent)
end

function suite:testResolveSubtypeUnknownClassification()
	local outpost = solarSystemFixture()
	outpost.type = { name = 'Outpost' }
	self:assertEquals(nil, Location.resolveSubtype(outpost, {}))
end

function suite:testResolveSubtypeKindDeclaredDefaultsToStarSystem()
	local leaf = Location.resolveSubtype({}, { kind = 'Location' })
	self:assertEquals(StarSystem, leaf)
	self:assertEquals('Entity/Location', leaf.parent)
end

-- |family=jumppoint fills the no-record void with the JumpPoint leaf (the
-- starmap-only tunnels have nothing else to dispatch on); a genuine record
-- always wins over the arg, and no family keeps the StarSystem default.
function suite:testResolveSubtypeFamilyJumpPoint()
	local jp = require('Module:Entity/Location/JumpPoint')
	self:assertEquals(jp, Location.resolveSubtype({}, { kind = 'Location', family = 'jumppoint' }))
	self:assertEquals(jp, Location.resolveSubtype({}, { kind = 'Location', family = ' JumpPoint ' }))
	local star = require('Module:Entity/Location/StarSystem')
	self:assertEquals(star, Location.resolveSubtype({}, { kind = 'Location' }))
	self:assertEquals(star, Location.resolveSubtype(solarSystemFixture(), { kind = 'Location', family = 'jumppoint' }))
end

function suite:testResolveSubtypeUnknownFamilyKeepsDefault()
	local star = require('Module:Entity/Location/StarSystem')
	self:assertEquals(star, Location.resolveSubtype({}, { kind = 'Location', family = 'planet' }))
	self:assertEquals(nil, Location.resolveSubtype({}, { family = 'planet' }))
end

function suite:testResolveSubtypeUndeclaredWithoutRecordIsNil()
	self:assertEquals(nil, Location.resolveSubtype({}, {}))
end

-- A jump-point record dispatches to its leaf on the record alone.
function suite:testResolveSubtypeJumpPointRecord()
	local leaf = Location.resolveSubtype(jumpPointFixture(), {})
	self:assertEquals(require('Module:Entity/Location/JumpPoint'), leaf)
	self:assertEquals('Entity/Location', leaf.parent)
end

-- The wreck site shares the Anomaly token: it must stay unresolved — and a
-- declared kind must not rescue it into the StarSystem default either (the
-- default is for pages with NO typed record).
function suite:testResolveSubtypeAnomalyWreckSiteIsNil()
	local wreck = { type = { name = 'Anomaly' }, name = 'Stanton-Pyro Jump Point Wreck Site' }
	self:assertEquals(nil, Location.resolveSubtype(wreck, {}))
	self:assertEquals(nil, Location.resolveSubtype(wreck, { kind = 'Location' }))
end

-- "Jump Point " as an exact PREFIX (the one upstream misnaming, a real Pyro
-- gate) resolves the leaf just like the suffix form.
function suite:testResolveSubtypeJumpPointPrefixNameResolves()
	local castra = { type = { name = 'Anomaly' }, name = 'Jump Point Pyro Castra' }
	self:assertEquals(require('Module:Entity/Location/JumpPoint'), Location.resolveSubtype(castra, {}))
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
	local info = StarSystem.getTypeInfo(ctx(apiData))
	self:assertEquals('Single star system', info.name)
	self:assertEquals('Systems', info.category)
end

function suite:testGetTypeInfoFallback()
	local info = StarSystem.getTypeInfo(ctx(solarSystemFixture()))
	self:assertEquals('Star system', info.name)
end

function suite:testFormatSensor()
	local f = Util.formatSensor
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
	local data = StarSystem.getStructuredData(ctx(apiData, {}, resolved))
	self:assertEquals(24, data.station_count)
	self:assertEquals(2, data.planet_count) -- un-overridden counts keep the API tally
end

function suite:testShortDescriptionPlanetOverride()
	local apiData = solarSystemFixture()
	apiData.starsystem = starsystemFixture()
	local resolved = { planets = { value = 4, source = 'editorial' } }
	local typeInfo = StarSystem.getTypeInfo(ctx(apiData))
	self:assertEquals(
		'UEE single star system with 4 planets',
		StarSystem.getShortDescription({
			apiData = apiData,
			args = {},
			typeInfo = typeInfo,
			prefix = nil,
			resolved = resolved,
		})
	)
end

function suite:testStarTypeList()
	self:assertEquals(
		'[[G-type main-sequence star|G-type main-sequence]]',
		StarSystem._internal.starTypeList(starsystemFixture())
	)
	self:assertEquals(nil, StarSystem._internal.starTypeList(nil))
end

function suite:testStatusLabels()
	self:assertEquals('Published', StarSystem._internal.STATUS_LABELS.P)
	self:assertEquals('Probe data incomplete', StarSystem._internal.STATUS_LABELS.N)
end

function suite:testGetFooterButtons()
	local apiData = solarSystemFixture()
	apiData.starsystem = starsystemFixture()
	local buttons = StarSystem.getFooterButtons(ctx(apiData, {}))
	self:assertEquals(1, #buttons)
	self:assertEquals('Starmap', buttons[1].label)
	self:assertEquals('https://robertsspaceindustries.com/starmap?location=STANTON', buttons[1].url)
	self:assertEquals('Sc-icon-galactapedia.svg', buttons[1].icon)
end

function suite:testGetFooterButtonsWithoutRecord()
	self:assertEquals(0, #StarSystem.getFooterButtons(ctx(solarSystemFixture(), {})))
end

function suite:testGetMetadataItems()
	local apiData = solarSystemFixture()
	apiData.starsystem = starsystemFixture()
	local items = StarSystem.getMetadataItems(ctx(apiData, {}))
	self:assertEquals(1, #items)
	self:assertEquals('Starmap code', items[1].label)
	self:assertEquals('STANTON', items[1].content)
end

function suite:testGetMetadataItemsWithoutRecord()
	self:assertEquals(0, #StarSystem.getMetadataItems(ctx(solarSystemFixture(), {})))
end

-- Both consumers read the code through one accessor, so they cannot disagree
-- about what counts as one. An empty string does not: it would emit a bare
-- "?location=" Starmap button and a blank "Starmap code" metadata row.
function suite:testStarmapCode()
	local f = StarSystem._internal.starmapCode
	local apiData = solarSystemFixture()
	apiData.starsystem = starsystemFixture()
	self:assertEquals('STANTON', f(apiData))
	for _, bad in ipairs({ '', 0, {} }) do
		apiData.starsystem.code = bad
		self:assertEquals(nil, f(apiData))
	end
	apiData.starsystem.code = nil
	self:assertEquals(nil, f(apiData))
	self:assertEquals(nil, f(solarSystemFixture()))
end

function suite:testEmptyStarmapCodeYieldsNeitherButtonNorRow()
	local apiData = solarSystemFixture()
	apiData.starsystem = starsystemFixture()
	apiData.starsystem.code = ''
	self:assertEquals(0, #StarSystem.getFooterButtons(ctx(apiData, {})))
	self:assertEquals(0, #StarSystem.getMetadataItems(ctx(apiData, {})))
end

-- Legacy planet-count formula + affiliation prefix, no trailing period.
function suite:testShortDescriptionUee()
	local apiData = solarSystemFixture()
	apiData.starsystem = starsystemFixture() -- 2 planets in the fixture
	local typeInfo = StarSystem.getTypeInfo(ctx(apiData))
	self:assertEquals(
		'UEE single star system with 2 planets',
		StarSystem.getShortDescription({ apiData = apiData, args = {}, typeInfo = typeInfo })
	)
end

function suite:testShortDescriptionUnclaimed()
	local apiData = solarSystemFixture()
	local starsystem = starsystemFixture()
	starsystem.affiliation = { { code = 'UNC' } }
	apiData.starsystem = starsystem
	local typeInfo = StarSystem.getTypeInfo(ctx(apiData))
	self:assertEquals(
		'Unclaimed single star system with 2 planets',
		StarSystem.getShortDescription({ apiData = apiData, args = {}, typeInfo = typeInfo })
	)
end

function suite:testShortDescriptionSingularPlanet()
	local apiData = solarSystemFixture()
	local starsystem = starsystemFixture()
	starsystem.celestial_objects = { { type = 'STAR' }, { type = 'PLANET' } }
	apiData.starsystem = starsystem
	local typeInfo = StarSystem.getTypeInfo(ctx(apiData))
	self:assertEquals(
		'UEE single star system with 1 planet',
		StarSystem.getShortDescription({ apiData = apiData, args = {}, typeInfo = typeInfo })
	)
end

function suite:testShortDescriptionNoPlanetsNoAffiliation()
	local apiData = solarSystemFixture()
	local starsystem = starsystemFixture()
	starsystem.celestial_objects = { { type = 'STAR' } }
	starsystem.affiliation = nil
	apiData.starsystem = starsystem
	local typeInfo = StarSystem.getTypeInfo(ctx(apiData))
	self:assertEquals(
		'Single star system',
		StarSystem.getShortDescription({ apiData = apiData, args = {}, typeInfo = typeInfo })
	)
end

function suite:testShortDescriptionNoRecordFallsBackToLegacyCatchAll()
	local apiData = solarSystemFixture()
	local typeInfo = StarSystem.getTypeInfo(ctx(apiData))
	self:assertEquals(
		'A star system in Star Citizen',
		StarSystem.getShortDescription({ apiData = apiData, args = {}, typeInfo = typeInfo })
	)
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

-- End to end through the real Editorial.resolve: an unparseable count override
-- must not DELETE the starmap tally. The count fields carry no apiPath, so a
-- resolved entry is unconditionally authoritative; a junk `| planets = Unknown`
-- that survived the transform would blank the tile, the stored planet_count and
-- the short-description clause in one go (this is why El'sin shipped "Size: ?").
function suite:testUnparseableCountOverrideKeepsTheStarmapTally()
	local apiData = solarSystemFixture()
	apiData.starsystem = starsystemFixture() -- 2 PLANET objects
	local resolved = Editorial.resolve(
		apiData,
		{ planets = 'Unknown' },
		assembly.mergeEditorialManifests(assembly.buildChain(StarSystem))
	)
	self:assertEquals(nil, resolved.planets)

	local planetTile
	for _, tile in ipairs(StarSystem._internal.buildObjectTiles(apiData.starsystem, Editorial.view(resolved))) do
		if tile.label == 'Planets' then
			planetTile = tile
		end
	end
	self:assertEquals(2, planetTile and planetTile.value)
	self:assertEquals(2, StarSystem.getStructuredData(ctx(apiData, {}, resolved)).planet_count)
	self:assertEquals(
		'UEE single star system with 2 planets',
		StarSystem.getShortDescription({
			apiData = apiData,
			args = {},
			typeInfo = StarSystem.getTypeInfo(ctx(apiData)),
			prefix = nil,
			resolved = resolved,
		})
	)
end

-- The same guard on the one overlap field: a junk `| size =` must not displace
-- the starmap's aggregated size (the live "Size: ? AU" regression).
function suite:testUnparseableSizeOverrideKeepsTheStarmapSize()
	local apiData = solarSystemFixture()
	apiData.starsystem = starsystemFixture()
	local resolved =
		Editorial.resolve(apiData, { size = '?' }, assembly.mergeEditorialManifests(assembly.buildChain(StarSystem)))
	self:assertEquals(4.85, resolved.size.value)
	self:assertEquals('api', resolved.size.source)
	self:assertEquals(
		'4.85 AU',
		findItem(findSection(StarSystem.getSections(ctx(apiData, {}, resolved)), 'general'), 'Size')
	)
end

function suite:testGetSectionsGeneralRows()
	local apiData = solarSystemFixture()
	apiData.starsystem = starsystemFixture()
	local general = findSection(StarSystem.getSections(ctx(apiData, {}, nil)), 'general')
	self:assertEquals('[[United Empire of Earth]]', findItem(general, 'Affiliation'))
	self:assertEquals('[[UEE]]', findItem(general, 'Jurisdiction'))
	self:assertEquals('4.85 AU', findItem(general, 'Size'))
	self:assertEquals('[[G-type main-sequence star|G-type main-sequence]]', findItem(general, 'Star type'))
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
	local sections = StarSystem.getSections(ctx(apiData, {}, nil))
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
	local data = StarSystem.getStructuredData(ctx(apiData, {}, nil))
	-- Display label + compact affiliation: store equals display. (The raw-code
	-- vocabulary retired with legacy Module:System — this leaf is the only
	-- writer now.)
	self:assertEquals('Single star system', data.system_type)
	self:assertEquals('UEE', data.affiliation)
	self:assertEquals(1, data.star_count)
	self:assertEquals(2, data.planet_count)
	self:assertEquals(1, data.moon_count)
	self:assertEquals(1, data.station_count)
	self:assertEquals(1, data.jump_point_count)
end

function suite:testStructuredDataWithoutStarsystem()
	local data = StarSystem.getStructuredData(ctx(solarSystemFixture(), {}, nil))
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

-- A zero-size record must leave the Size row out entirely rather than assert
-- "0 AU"; the other rows keep rendering.
function suite:testSectionsOmitSizeRowForZeroSizeSystem()
	local record = starsystemFixture()
	record.aggregated.size = 0
	local apiData = solarSystemFixture()
	apiData.starsystem = Util._internal.normalizeAggregates(record)
	local general = findSection(StarSystem.getSections(ctx(apiData, {}, nil)), 'general')
	self:assertEquals(nil, findItem(general, 'Size'))
	self:assertEquals('Published', findItem(general, 'Starmap status'))
end

-- End to end: a withheld stub renders neither a Size row nor a sensor section.
function suite:testSectionsDropSizeAndSensorsForWithheldStub()
	local apiData = solarSystemFixture()
	apiData.starsystem = Util._internal.normalizeAggregates(withheldStubFixture('M', 7))
	local sections = StarSystem.getSections(ctx(apiData, {}, nil))
	self:assertEquals(nil, findItem(findSection(sections, 'general'), 'Size'))
	self:assertEquals(nil, findSection(sections, 'sensor'))
end

-- An editorial |size= override still wins over an absent starmap size.
function suite:testSizeOverrideSurvivesDroppedStarmapSize()
	local apiData = solarSystemFixture()
	apiData.starsystem = starsystemFixture()
	apiData.starsystem.aggregated.size = nil
	local resolved = { size = { value = 12, source = 'override' } }
	local general = findSection(StarSystem.getSections(ctx(apiData, {}, resolved)), 'general')
	self:assertEquals('12 AU', findItem(general, 'Size'))
end

-- ── enrich (the starmap fetch seam) ────────────────────────────────────────
--
-- enrich() takes no injection point, but Location holds the Module:Entity/Api
-- module TABLE from the require cache and calls `api.fetchApi` through it, so
-- swapping that field is the seam. Without this, everything between the fetch
-- and the attachment — the URL encoding of the lookup key and the
-- normalizeAggregates call — could be deleted with the suite still green.

--- Run `fn(captured)` with Module:Entity/Api.fetchApi replaced by a stub that
--- records its arguments and answers with `rows`. Always restores the real
--- function, so one failing test cannot poison the rest of the suite.
--- @param rows table|nil the decoded `data` payload the stubbed fetch returns
---   (a result LIST for the starsystems endpoint, a single record for
---   celestial-objects, nil for a failed fetch)
--- @param fn fun(captured: { config: table|nil, key: string|nil })
local function withStubbedFetch(rows, fn)
	local api = require('Module:Entity/Api')
	local realFetch = api.fetchApi
	local captured = {}
	api.fetchApi = function(config, key)
		captured.config, captured.key = config, key
		return rows
	end
	local ok, err = pcall(fn, captured)
	api.fetchApi = realFetch
	if not ok then
		error(err, 0)
	end
end

-- The plain key is URL-encoded where it enters the endpoint, not before: names
-- with an apostrophe (the Xi'an systems) would otherwise emit a raw `'` into the
-- filter[name] query value.
function suite:testEnrichUrlEncodesTheLookupKey()
	withStubbedFetch({ starsystemFixture() }, function(captured)
		StarSystem.enrich(ctx({}, { kind = 'Location', starmapname = "Kyuk'ya" }))
		self:assertEquals('kyuk%27ya', captured.key)
		self:assertEquals(
			'starsystems?filter[name]=kyuk%27ya&include=celestialObjects&locale=en_EN',
			string.format(captured.config.endpoint, captured.key)
		)
	end)
end

-- enrich must normalize the record it attaches, not just attach it: a withheld
-- survey stub reaching apiData.starsystem raw would put a fabricated 7 AU extent
-- and a 0.1/10 economy on twelve Vanduul pages.
function suite:testEnrichNormalizesTheAttachedRecord()
	withStubbedFetch({ withheldStubFixture('M', 7) }, function()
		local apiData = StarSystem.enrich(ctx(solarSystemFixture(), nil))
		self:assertEquals(nil, apiData.starsystem.aggregated.size)
		self:assertEquals(nil, apiData.starsystem.aggregated.population)
		self:assertEquals(nil, apiData.starsystem.aggregated.economy)
	end)
end

-- enrich picks the same row pickStarsystem would: the exact name beats a longer
-- substring match returned by the filter[name] query.
function suite:testEnrichAttachesThePickedRow()
	withStubbedFetch({ { name = 'Vega Prime' }, { name = 'Vega', code = 'VEGA' } }, function()
		local apiData = StarSystem.enrich(ctx({ name = 'Vega System', type = { name = 'SolarSystem' } }, nil))
		self:assertEquals('VEGA', apiData.starsystem.code)
	end)
end

-- Soft-fail: an empty result list leaves the record absent rather than
-- attaching an empty table the section builders would have to nil-guard.
function suite:testEnrichSoftFailsOnEmptyResult()
	withStubbedFetch({}, function()
		self:assertEquals(nil, StarSystem.enrich(ctx(solarSystemFixture(), nil)).starsystem)
	end)
end

-- ── enrich: the celestial-object branch (jump-point records) ───────────────

function suite:testEnrichJumpPointFetchesCelestialObject()
	withStubbedFetch(celestialObjectFixture(), function(captured)
		local apiData =
			JumpPoint.enrich(ctx(jumpPointFixture(), { kind = 'Location', starmapcode = 'PYRO.JUMPPOINTS.NYX' }))
		self:assertEquals('PYRO.JUMPPOINTS.NYX', captured.key)
		self:assertEquals('celestial-objects/%s?include=starsystem&locale=en_EN', captured.config.endpoint)
		-- locale rides the endpoint, not params: the include gives the endpoint
		-- a query string of its own, and Apiunto appends params as a second
		-- `?query` that would corrupt it.
		self:assertEquals(nil, captured.config.params)
		self:assertEquals('data', captured.config.responseDataPath)
		self:assertEquals('Pyro - Nyx', apiData.celestialobject.designation)
		-- Mutually exclusive with the starsystems bridge by construction.
		self:assertEquals(nil, apiData.starsystem)
	end)
end

-- The legacy |code= alias fetches too, and |starmapcode= wins when both are
-- present — the same order the starmapcode manifest entry declares.
function suite:testEnrichCelestialCodeAliasAndPrecedence()
	withStubbedFetch(celestialObjectFixture(), function(captured)
		JumpPoint.enrich(ctx(jumpPointFixture(), { code = 'NYX.JUMPPOINTS.PYRO' }))
		self:assertEquals('NYX.JUMPPOINTS.PYRO', captured.key)
		JumpPoint.enrich(ctx(jumpPointFixture(), { starmapcode = 'PYRO.JUMPPOINTS.NYX', code = 'NYX.JUMPPOINTS.PYRO' }))
		self:assertEquals('PYRO.JUMPPOINTS.NYX', captured.key)
	end)
end

-- No code arg → no fetch of ANY kind.
function suite:testEnrichJumpPointWithoutCodeFetchesNothing()
	withStubbedFetch(celestialObjectFixture(), function(captured)
		local apiData = JumpPoint.enrich(ctx(jumpPointFixture(), { kind = 'Location' }))
		self:assertEquals(nil, captured.key)
		self:assertEquals(nil, apiData.celestialobject)
		self:assertEquals(nil, apiData.starsystem)
	end)
end

-- Soft-fail exactly like the starsystem fetch: a failed fetch (nil) and an
-- empty payload both leave apiData unchanged.
function suite:testEnrichCelestialSoftFailsOnErrorOrEmptyPayload()
	for _, payload in ipairs({ 'error', 'empty' }) do
		withStubbedFetch(payload == 'empty' and {} or nil, function()
			local apiData = JumpPoint.enrich(ctx(jumpPointFixture(), { starmapcode = 'PYRO.JUMPPOINTS.NYX' }))
			self:assertEquals(nil, apiData.celestialobject, payload .. ' payload must not attach')
		end)
	end
end

-- A record no leaf models resolves no leaf, so no link on its chain fetches
-- anything.
function suite:testUnclaimedPayloadResolvesNoLeaf()
	self:assertEquals(nil, Location.resolveSubtype({ type = { name = 'Outpost' } }, nil))
	self:assertEquals(nil, Location.enrich)
end

-- The two bridges belong to different leaves, so a SolarSystem record can
-- never reach the celestial fetch however the args look, and vice versa.
function suite:testBridgesAreLeafExclusive()
	withStubbedFetch({ starsystemFixture() }, function(captured)
		local apiData = StarSystem.enrich(ctx(solarSystemFixture(), { starmapcode = 'STANTON' }))
		self:assertEquals('starsystems?filter[name]=%s&include=celestialObjects&locale=en_EN', captured.config.endpoint)
		self:assertEquals('STANTON', apiData.starsystem.code)
		self:assertEquals(nil, apiData.celestialobject)
	end)
	self:assertEquals(
		nil,
		Location.resolveSubtype(
			{ type = { name = 'Anomaly' }, name = 'Stanton-Pyro Jump Point Wreck Site' },
			{ kind = 'Location', starmapcode = 'STANTON.JUMPPOINTS.PYRO' }
		)
	)
end

-- ── Editorial identity (the no-record lore systems) ────────────────────────
-- Seven systems exist only in lore: the starmap has no record, so affiliation
-- and system type arrive as editor args, exactly as the legacy {{System}}
-- template took them.

function suite:testGetTypeInfoFromEditorialArgs()
	-- Type info runs before editorial resolution, so it reads the raw args;
	-- the legacy `type` arg name works as the alias.
	self:assertEquals('Trinary star system', StarSystem.getTypeInfo(ctx({}, { type = 'Trinary' })).name)
	self:assertEquals('Single star system', StarSystem.getTypeInfo(ctx({}, { systemtype = 'SINGLE_STAR' })).name)
	self:assertEquals('Star system', StarSystem.getTypeInfo(ctx({}, {})).name)
	self:assertEquals('Star system', StarSystem.getTypeInfo(ctx({})).name)
end

--- Drive the REAL manifest through Editorial.resolve: the integration seam a
--- hand-built `resolved` table would bypass (arg aliasing included).
--- @param args table
--- @return table resolved
local function resolveEditorially(args)
	return Editorial.resolve({}, args, assembly.mergeEditorialManifests(assembly.buildChain(StarSystem)))
end

function suite:testNoRecordPageResolvesIdentityThroughManifest()
	local resolved = resolveEditorially({ type = 'TRINARY', affiliation = 'Unknown' })
	self:assertEquals('TRINARY', (Util.resolveSystemType(nil, resolved)))
	self:assertEquals('Unknown', Util.resolveAffiliation(nil, resolved).label)
end

function suite:testGetCategoriesFromEditorialIdentity()
	local resolved = resolveEditorially({ type = 'Trinary', affiliation = "[[Kr'Thak]]" })
	local categories = StarSystem.getCategories(ctx({}, {}, resolved))
	self:assertEquals('Trinary Star systems', categories[1])
	self:assertEquals("Kr'Thak systems", categories[2])
end

function suite:testSectionsAffiliationRowFromEditorial()
	-- Free text renders exactly as written; canonical text renders linked.
	local general =
		findSection(StarSystem.getSections(ctx({}, {}, resolveEditorially({ affiliation = "[[Kr'Thak]]" }))), 'general')
	self:assertEquals("[[Kr'Thak]]", findItem(general, 'Affiliation'))
	general = findSection(StarSystem.getSections(ctx({}, {}, resolveEditorially({ affiliation = "Xi'An" }))), 'general')
	self:assertEquals("[[Xi'an Empire]]", findItem(general, 'Affiliation'))
end

function suite:testStructuredDataFromEditorialIdentityWithoutRecord()
	-- The early return without a record is gone: identity and counts store
	-- exactly like a record-backed page, with the free-text affiliation
	-- delinked for the store.
	local resolved = resolveEditorially({ type = 'Trinary', affiliation = "[[Kr'Thak]]", planets = '9' })
	local data = StarSystem.getStructuredData(ctx({}, {}, resolved))
	self:assertEquals('Trinary star system', data.system_type)
	self:assertEquals("Kr'Thak", data.affiliation)
	self:assertEquals(9, data.planet_count)
	self:assertEquals(nil, data.star_count)
end

-- The unmapped-code fallback at the storage level: a future ARK type stores
-- its raw code (visible, queryable) rather than vanishing, and self-heals
-- into the label once SYSTEM_TYPES learns it.
function suite:testStructuredDataStoresRawCodeForUnmappedType()
	local apiData = solarSystemFixture()
	apiData.starsystem = starsystemFixture()
	apiData.starsystem.type = 'BLACK_HOLE'
	self:assertEquals('BLACK_HOLE', StarSystem.getStructuredData(ctx(apiData, {}, nil)).system_type)
end

function suite:testStructuredDataStillEmptyWithNothingAtAll()
	self:assertEquals(nil, next(StarSystem.getStructuredData(ctx({}, {}, resolveEditorially({})))))
end

function suite:testShortDescriptionFromEditorialIdentity()
	-- Ophos shape: canonical affiliation + editorial type + 1 planet.
	local args = { type = 'SINGLE_STAR', affiliation = 'Banu Protectorate', planets = '1' }
	local resolved = resolveEditorially(args)
	local typeInfo = StarSystem.getTypeInfo(ctx({}, args))
	self:assertEquals(
		'Banu Protectorate single star system with 1 planet',
		StarSystem.getShortDescription({
			apiData = {},
			args = args,
			typeInfo = typeInfo,
			prefix = nil,
			resolved = resolved,
		})
	)
end

function suite:testShortDescriptionSkipsFreeTextAffiliationPrefix()
	-- UDS shape: 'Unknown trinary star system' would say the wrong thing, so
	-- a free-text affiliation stays out of the prefix.
	local args = { type = 'Trinary', affiliation = 'Unknown' }
	self:assertEquals(
		'Trinary star system',
		StarSystem.getShortDescription({
			apiData = {},
			args = args,
			typeInfo = StarSystem.getTypeInfo(ctx({}, args)),
			prefix = nil,
			resolved = resolveEditorially(args),
		})
	)
end

-- ── JumpPoint leaf ─────────────────────────────────────────────────────────

--- The merged payload the leaf renders on the happy path: the location record
--- plus the celestial object this leaf's enrich attaches.
local function jumpPointApiData()
	local apiData = jumpPointFixture()
	apiData.celestialobject = celestialObjectFixture()
	return apiData
end

function suite:testJumpPointTypeInfo()
	local info = JumpPoint.getTypeInfo(ctx(jumpPointApiData(), {}))
	self:assertEquals('Jump point', info.name)
	self:assertEquals('Jump points', info.category)
end

-- Shared in Util: both leaves' system-name handling routes through it
-- (StarSystem's short description, JumpPoint's title parsing), and Util's own
-- gateEntrySystem/entrySystem call it internally.
function suite:testJumpPointSystemShortName()
	local f = Util.systemShortName
	self:assertEquals('Pyro', f('Pyro System'))
	self:assertEquals('Terra', f('Terra system'))
	self:assertEquals('Nyx', f('Nyx'))
	self:assertEquals(nil, f(''))
	self:assertEquals(nil, f(' System'))
	self:assertEquals(nil, f(nil))
end

-- The canonical page name beats the designation outright — the only fix that
-- also repairs the bare-legacy-name case ("Th.us'ūng (Pallas) - Hadur", where
-- Hadur is now Yā'mon and no amount of decoration-stripping helps).
function suite:testJumpPointSystemsComeFromTheCanonicalName()
	local apiData = jumpPointApiData()
	apiData.system = nil
	apiData.celestialobject.designation = "Th.us'ūng (Pallas) - Hadur"
	local args = { name = "Th.us'ūng - Yā'mon jump point" }
	local general = findSection(JumpPoint.getSections(ctx(apiData, args, nil)), 'general')
	self:assertEquals("[[Th.us'ūng system]]", findItem(general, 'System'))
	self:assertEquals("[[Yā'mon system]]", findItem(general, 'Destination'))
	local data = JumpPoint.getStructuredData(ctx(apiData, args, nil))
	self:assertEquals("Th.us'ūng system", data.system)
	self:assertEquals("Yā'mon system", data.destination_system)
end

-- A page whose name is not gate-shaped falls through to the record/designation
-- chain, so the sandbox and any oddly-titled page keep working.
function suite:testJumpPointFallsBackWhenNameIsNotGateShaped()
	local apiData = jumpPointApiData()
	local general = findSection(JumpPoint.getSections(ctx(apiData, { name = 'Some Sandbox Page' }, nil)), 'general')
	self:assertEquals('[[Pyro system]]', findItem(general, 'System'))
	self:assertEquals('[[Nyx system]]', findItem(general, 'Destination'))
end

function suite:testJumpPointGeneralRows()
	local apiData = jumpPointApiData()
	-- A parent whose (star) page exists NOWHERE: the plain-text branch then
	-- holds under the offline runner (title shim can't answer `exists`) AND
	-- under live Scribunto (the page genuinely doesn't exist), so this test
	-- is environment-stable — the on-wiki suite runs these same cases, and a
	-- real-page fixture ('Pyro') turned red there when live resolved the
	-- link. Candidate selection is pinned separately; live linking is
	-- browser-verified.
	apiData.parent = { name = 'Zzyzx Test Star', type_name = 'Star' }
	local general = findSection(JumpPoint.getSections(ctx(apiData, {}, nil)), 'general')
	self:assertEquals('[[Pyro system]]', findItem(general, 'System'))
	self:assertEquals('[[Nyx system]]', findItem(general, 'Destination'))
	self:assertEquals('Zzyzx Test Star', findItem(general, 'Parent'))
	self:assertEquals('Medium', findItem(general, 'Size'))
	self:assertEquals('[[UEE]]', findItem(general, 'Jurisdiction'))
	-- Distance from star was dropped by design review: not a row.
	self:assertEquals(nil, findItem(general, 'Distance from star'))
end

-- The link-candidate rule: a Star parent targets its (star) page; anything
-- else targets the system-disambiguated title — two stations share the name
-- "Pyro Gateway" (one per side), so the bare title is a disambiguation page
-- and is never a candidate. No entry system -> no candidate, name only.
function suite:testJumpPointParentLinkCandidate()
	local f = JumpPoint._internal.parentLinkCandidate
	local star = jumpPointApiData()
	star.parent = { name = 'Pyro', type_name = 'Star' }
	local name, candidate = f(star)
	self:assertEquals('Pyro', name)
	self:assertEquals('Pyro (star)', candidate)
	local station = jumpPointApiData()
	station.parent = { name = 'Pyro Gateway', type_name = 'Manmade' }
	station.system = 'Stanton System'
	name, candidate = f(station)
	self:assertEquals('Pyro Gateway', name)
	self:assertEquals('Pyro Gateway (Stanton)', candidate)
	local orphan = jumpPointApiData()
	orphan.parent = { name = 'Pyro Gateway', type_name = 'Manmade' }
	orphan.system = nil
	orphan.celestialobject = nil -- no designation to fall back to either
	name, candidate = f(orphan)
	self:assertEquals('Pyro Gateway', name)
	self:assertEquals(nil, candidate)
	self:assertEquals(nil, (f(jumpPointApiData()))) -- no parent field at all
end

-- The destination is whichever designation side is NOT the entry system —
-- never a fixed side. Both directions pinned: entry-as-side-A catches an
-- always-take-side-A parse, entry-as-side-B an always-take-side-B one.
-- The table-with-name entry shape is the defensive branch (the live field is
-- a plain string), covered here so both shapes resolve.
function suite:testJumpPointDestinationOrderIndependence()
	local f = JumpPoint._internal.destinationSystem
	local nyxGate = jumpPointApiData()
	nyxGate.system = { name = 'Nyx System' }
	nyxGate.celestialobject.designation = 'Nyx - Pyro'
	self:assertEquals('Pyro', f(nyxGate))
	local reversed = jumpPointApiData() -- entry stays Pyro System
	reversed.celestialobject.designation = 'Nyx - Pyro'
	self:assertEquals('Nyx', f(reversed))
end

-- No guessing where a RECORD disagrees: an absent celestial record, an
-- unparsable designation, or a record system naming neither designation side
-- all yield no destination (a guessed side could name the gate's own
-- system). A record-LESS page differs: entry falls back to the designation's
-- first side (the starmap's entry-first convention), so the destination
-- resolves — that is what lets |family=jumppoint pages render.
function suite:testJumpPointDestinationUnresolvable()
	local f = JumpPoint._internal.destinationSystem
	self:assertEquals(nil, f(jumpPointFixture())) -- no celestial record
	local strangers = jumpPointApiData()
	strangers.celestialobject.designation = 'Stanton - Terra'
	self:assertEquals(nil, f(strangers))
	local noEntry = jumpPointApiData()
	noEntry.system = nil
	self:assertEquals('Nyx', f(noEntry)) -- fallback: side A is the entry
	local noDesignation = jumpPointApiData()
	noDesignation.celestialobject.designation = nil
	self:assertEquals(nil, f(noDesignation))
	local unparsable = jumpPointApiData()
	unparsable.celestialobject.designation = 'PyroNyx'
	self:assertEquals(nil, f(unparsable))
end

function suite:testJumpPointSizeMap()
	local f = JumpPoint._internal.sizeLabel
	self:assertEquals('Small', f({ jumppoints = { size = 'S' } }))
	self:assertEquals('Medium', f({ jumppoints = { size = 'M' } }))
	self:assertEquals('Large', f({ jumppoints = { size = 'L' } }))
	self:assertEquals(nil, f({ jumppoints = { size = 'X' } })) -- unknown letter
	self:assertEquals(nil, f({ jumppoints = {} }))
	self:assertEquals(nil, f({}))
	self:assertEquals(nil, f(nil))
end

-- An unknown size letter drops the Size row rather than leaking a raw code.
function suite:testJumpPointUnknownSizeOmitsRow()
	local apiData = jumpPointApiData()
	apiData.celestialobject.jumppoints.size = 'X'
	local general = findSection(JumpPoint.getSections(ctx(apiData, {}, nil)), 'general')
	self:assertEquals(nil, findItem(general, 'Size'))
end

-- Distance from star was removed from the infobox by design review (not
-- important for a gate); the celestial record still carries it, unused.
function suite:testJumpPointDistanceNotRendered()
	local general = findSection(JumpPoint.getSections(ctx(jumpPointApiData(), {}, nil)), 'general')
	self:assertEquals(nil, findItem(general, 'Distance from star'))
end

function suite:testJumpPointTravelRows()
	local travel = findSection(JumpPoint.getSections(ctx(jumpPointApiData(), {}, nil)), 'travel')
	self:assertEquals('Travel', travel.label)
	self:assertEquals(true, travel.collapsible)
	self:assertEquals(nil, travel.collapsed) -- open by default, like StarSystem's Lore
	self:assertEquals('18 km', findItem(travel, 'Arrival radius'))
	-- Adoption radius was dropped by design review.
	self:assertEquals(nil, findItem(travel, 'Adoption radius'))
	self:assertEquals('11 km', findItem(travel, 'Obstruction radius'))
	-- Boolean icon, negated polarity: the fixture's gate is HIDDEN, so the
	-- icon answers "on the starmap?" with no.
	self:assertStringContains('data%-state="no"', findItem(travel, 'Starmap'))
end

-- The standard tri-state boolean icon with NEGATED polarity (the icon answers
-- "is it on the starmap?"): hidden -> no, shown -> yes, absent -> no row
-- (never the Unknown icon for a field the record does not carry).
function suite:testJumpPointStarmapVisibility()
	local f = JumpPoint._internal.starmapVisibility
	self:assertStringContains('data%-state="no"', f({ hide_in_starmap = true }))
	self:assertStringContains('data%-state="yes"', f({ hide_in_starmap = false }))
	self:assertEquals(nil, f({}))
	self:assertEquals(nil, f({ hide_in_starmap = 'true' })) -- non-boolean shape
end

-- The Travel section drops only when radii AND the visibility flag are all
-- absent; radii-less records still show the Starmap row.
function suite:testJumpPointTravelSectionDropsWithoutData()
	local apiData = jumpPointApiData()
	apiData.quantum_travel = nil
	local travel = findSection(JumpPoint.getSections(ctx(apiData, {}, nil)), 'travel')
	self:assertStringContains('data%-state="no"', findItem(travel, 'Starmap'))
	self:assertEquals(nil, findItem(travel, 'Arrival radius'))
	apiData.hide_in_starmap = nil
	self:assertEquals(nil, findSection(JumpPoint.getSections(ctx(apiData, {}, nil)), 'travel'))
end

-- One accessor feeds the Starmap button and the Metadata row: the fetched
-- record's code wins, the raw |starmapcode=/|code= arg (read through the
-- manifest entry enrich fetches with) covers a soft-failed fetch, and an
-- empty record code falls through rather than blanking both.
function suite:testJumpPointStarmapCodeAccessor()
	local f = JumpPoint._internal.starmapCode
	self:assertEquals('PYRO.JUMPPOINTS.NYX', f(jumpPointApiData(), { starmapcode = 'OTHER.CODE' }))
	self:assertEquals('PYRO.JUMPPOINTS.NYX', f(jumpPointFixture(), { starmapcode = 'PYRO.JUMPPOINTS.NYX' }))
	self:assertEquals('NYX.JUMPPOINTS.PYRO', f(jumpPointFixture(), { code = 'NYX.JUMPPOINTS.PYRO' }))
	local blankCode = jumpPointApiData()
	blankCode.celestialobject.code = ''
	self:assertEquals('FALLBACK.CODE', f(blankCode, { starmapcode = 'FALLBACK.CODE' }))
	self:assertEquals(nil, f(jumpPointFixture(), {}))
	self:assertEquals(nil, f(jumpPointFixture(), nil))
end

function suite:testJumpPointManifestStarmapCode()
	local manifest = assembly.mergeEditorialManifests(assembly.buildChain(JumpPoint))
	self:assertEquals('starmapcode', manifest.starmapcode.arg[1])
	self:assertEquals('code', manifest.starmapcode.arg[2])
	self:assertEquals(nil, manifest.starmapcode.property)
	self:assertEquals(nil, manifest.starmapcode.transform)
	self:assertEquals('discoveredin', manifest.discoveredin.arg) -- inherited from the kind
end

function suite:testJumpPointFooterButton()
	local buttons = JumpPoint.getFooterButtons(ctx(jumpPointApiData(), {}))
	self:assertEquals(1, #buttons)
	self:assertEquals('Starmap', buttons[1].label)
	self:assertEquals('https://robertsspaceindustries.com/starmap?location=PYRO.JUMPPOINTS.NYX', buttons[1].url)
	self:assertEquals('Sc-icon-galactapedia.svg', buttons[1].icon)
	self:assertEquals('t-button--branded t-button--starmap', buttons[1].class)
end

function suite:testJumpPointMetadataItems()
	local items = JumpPoint.getMetadataItems(ctx(jumpPointApiData(), {}))
	self:assertEquals(1, #items)
	self:assertEquals('Starmap code', items[1].label)
	-- <wbr> after each dot: the row breaks at a segment, not mid-name.
	self:assertEquals('PYRO.<wbr>JUMPPOINTS.<wbr>NYX', items[1].content)
	-- The arg fallback feeds the row too (soft-failed fetch).
	local fromArg = JumpPoint.getMetadataItems(ctx(jumpPointFixture(), { code = 'NYX.JUMPPOINTS.PYRO' }))
	self:assertEquals('NYX.<wbr>JUMPPOINTS.<wbr>PYRO', fromArg[1].content)
end

-- No usable code from record or args → neither button nor metadata row.
function suite:testJumpPointAbsentCodeYieldsNeitherButtonNorRow()
	self:assertEquals(0, #JumpPoint.getFooterButtons(ctx(jumpPointFixture(), {})))
	self:assertEquals(0, #JumpPoint.getMetadataItems(ctx(jumpPointFixture(), {})))
	local blankCode = jumpPointApiData()
	blankCode.celestialobject.code = ''
	self:assertEquals(0, #JumpPoint.getFooterButtons(ctx(blankCode, {})))
	self:assertEquals(0, #JumpPoint.getMetadataItems(ctx(blankCode, {})))
end

function suite:testJumpPointStructuredData()
	local data = JumpPoint.getStructuredData(ctx(jumpPointApiData(), {}, nil))
	self:assertEquals('Medium', data.jump_point_size)
	-- Page-name forms ('Pyro system'), so [[System::…]] resolves wiki pages.
	self:assertEquals('Pyro system', data.system)
	self:assertEquals('Nyx system', data.destination_system)
end

function suite:testJumpPointStructuredDataDegradesWithoutCelestialRecord()
	local data = JumpPoint.getStructuredData(ctx(jumpPointFixture(), {}, nil))
	self:assertEquals(nil, data.jump_point_size)
	-- The location record alone still carries the entry system.
	self:assertEquals('Pyro system', data.system)
	self:assertEquals(nil, data.destination_system)
end

function suite:testJumpPointLoreRowsThroughManifest()
	local resolved = resolveEditorially({ discoveredin = '[[2469]]', discoveredby = '[[Nick Croshaw]]' })
	local lore = findSection(JumpPoint.getSections(ctx(jumpPointApiData(), {}, resolved)), 'lore')
	self:assertEquals('[[2469]]', findItem(lore, 'Discovered in'))
	self:assertEquals('[[Nick Croshaw]]', findItem(lore, 'Discovered by'))
end

-- Gate-directional, no trailing period; no size → unsized head; no resolvable
-- route → the catch-all (size or not: "Medium jump point" alone names no
-- route).
function suite:testJumpPointShortDescription()
	local typeInfo = JumpPoint.getTypeInfo(ctx())
	self:assertEquals(
		'Medium jump point from Pyro to Nyx',
		JumpPoint.getShortDescription({ apiData = jumpPointApiData(), args = {}, typeInfo = typeInfo })
	)
	local unsized = jumpPointApiData()
	unsized.celestialobject.jumppoints = nil
	self:assertEquals(
		'Jump point from Pyro to Nyx',
		JumpPoint.getShortDescription({ apiData = unsized, args = {}, typeInfo = typeInfo })
	)
	self:assertEquals(
		'A jump point in Star Citizen',
		JumpPoint.getShortDescription({ apiData = jumpPointFixture(), args = {}, typeInfo = typeInfo })
	)
end

-- A gate files under its ENTRY system's category — functional membership:
-- {{System navplate}} builds its "Jump points" row from the per-system
-- category ∩ Jump points, so this is what keeps that row populated. The
-- star-system trees stay out, and the legacy flat 'Astronomical objects' /
-- 'Locations' memberships are deliberately not carried (the classification
-- bucket covers that taxonomy).
function suite:testJumpPointKindCategoriesEntrySystem()
	local categories = JumpPoint.getCategories(ctx(jumpPointApiData(), {}, nil))
	self:assertEquals('Pyro system', categories[1])
	self:assertEquals(1, #categories)
end

function suite:testJumpPointKindCategoriesEmptyWithoutEntry()
	local record = jumpPointApiData()
	record.system = nil
	record.celestialobject = nil -- no designation fallback either
	self:assertEquals(0, #JumpPoint.getCategories(ctx(record, {}, nil)))
end

-- The record-less family page still files under its entry system: the
-- designation's first side carries it (the entry-first convention).
function suite:testJumpPointCategoriesFromDesignationFallback()
	local apiData = { celestialobject = { designation = 'Stanton - Nyx', jumppoints = { size = 'L' } } }
	local categories = JumpPoint.getCategories(ctx(apiData, {}, nil))
	self:assertEquals('Stanton system', categories[1])
	self:assertEquals(1, #categories)
end

function suite:testShortDescriptionNoTypeKeepsLegacyShape()
	-- Krell shape: affiliation but no type — the legacy "System with N
	-- planets" branch, unprefixed.
	local args = { affiliation = "[[Kr'Thak]]", planets = '9' }
	self:assertEquals(
		'System with 9 planets',
		StarSystem.getShortDescription({
			apiData = {},
			args = args,
			typeInfo = StarSystem.getTypeInfo(ctx({}, args)),
			prefix = nil,
			resolved = resolveEditorially(args),
		})
	)
end

-- ── Star leaf ──────────────────────────────────────────────────────────────

--- Stanton's star location record (trimmed): one of the three stars the game
--- actually serves.
local function starFixture()
	return {
		uuid = '34ff378f-faee-47bb-b5fe-f505e665c5ca',
		name = 'Stanton',
		respawn_location_type = 'None',
		type = { name = 'Star', classification = 'Star' },
		jurisdiction = { name = 'UEE' },
		system = 'Stanton System',
		size = 696000000, -- metres, and never read: see radiusKm
	}
end

--- Starmap celestial-object record for a star, as attachCelestialObject leaves
--- it. `starsystem` is the include the bridge asks for and the only reliable
--- name for the star's system.
local function starCelestialFixture()
	return {
		code = 'GOSS.STARS.GOSSA',
		designation = 'Goss A',
		type = 'STAR',
		size = 536151,
		sub_type = { name = 'Main Sequence-Dwarf-K', type = 'STAR' },
		starsystem = { id = 306, code = 'GOSS', name = 'Goss' },
	}
end

--- Star payload with both halves merged, the shape every hook below sees.
local function starApiData()
	local apiData = starFixture()
	apiData.celestialobject = starCelestialFixture()
	return apiData
end

--- Drive the REAL manifest through Editorial.resolve, as the Star leaf's own
--- chain assembles it.
local function starResolved(args)
	return Editorial.resolve({}, args, assembly.mergeEditorialManifests(assembly.buildChain(Star)))
end

function suite:testResolveSubtypeStarRecord()
	local apiData = starFixture()
	self:assertTrue(Location.matches(apiData))
	self:assertEquals('star', Location._internal.recordFamily(apiData))
	local leaf = Location.resolveSubtype(apiData, {})
	self:assertEquals(Star, leaf)
	self:assertEquals('Entity/Location', leaf.parent)
end

-- Every star page but three is record-less, so |family=star IS the entry path.
function suite:testFamilyArgResolvesStarLeaf()
	self:assertEquals(Star, Location.resolveSubtype({}, { kind = 'Location', family = 'star' }))
	self:assertEquals('Entity/Location/Star', Location._internal.LOCATION_SUBTYPE_MAP.star)
end

-- The starmap serves star sizes in km, and the surveyed values are sound.
function suite:testRadiusReadsTheStarmapSize()
	self:assertEquals(536151, Star._internal.radiusKm(starApiData(), nil))
end

-- The nineteen placeholders: eighteen unsurveyed stars carry a bare `1` and
-- Stanton a `1.2`, neither of them a radius in any unit. Banshee's 13.91 km
-- neutron radius is on the other side of the cut and must survive it.
function suite:testRadiusDropsPlaceholdersButKeepsANeutronStar()
	local placeholder = starApiData()
	placeholder.celestialobject.size = 1
	self:assertEquals(nil, Star._internal.radiusKm(placeholder, nil))
	placeholder.celestialobject.size = 1.2
	self:assertEquals(nil, Star._internal.radiusKm(placeholder, nil))
	local neutron = starApiData()
	neutron.celestialobject.size = 13.91
	self:assertEquals(13.91, Star._internal.radiusKm(neutron, nil))
end

-- The location record's own size is a placeholder too (Pyro and Nyx share one
-- byte-identical value), so a record with no starmap half yields no radius
-- rather than a 696,000,000 km star.
function suite:testRadiusIgnoresTheLocationRecordSize()
	self:assertEquals(nil, Star._internal.radiusKm(starFixture(), nil))
end

-- The only route to a radius for the placeholder stars.
function suite:testEditorialRadiusWins()
	local apiData = starApiData()
	self:assertEquals(696340, Star._internal.radiusKm(apiData, starResolved({ radius = '696340' })))
end

function suite:testRadiusDisplay()
	local f = Star._internal.radiusDisplay
	self:assertEquals('536,151 km (0.77 R☉)', f(536151))
	-- Sub-100 km keeps its decimals, and 0.00002 R☉ would print as a
	-- meaningless 0.00, so the comparison is dropped rather than rounded.
	self:assertEquals('13.91 km', f(13.91))
	-- A white dwarf is still legible at two decimals.
	self:assertEquals('6,260 km (0.01 R☉)', f(6259.5))
	self:assertEquals(nil, f(nil))
end

function suite:testClassificationFromTheStarmapSubType()
	self:assertEquals('K-type main-sequence star', Star._internal.classification(starApiData(), {}))
	self:assertEquals('K-type main-sequence star', Star.getTypeInfo(ctx(starApiData(), {})).name)
	self:assertEquals('Stars', Star.getTypeInfo(ctx(starApiData(), {})).category)
end

-- Pyro is a flare star by lore, a fact the starmap does not carry.
function suite:testEditorialClassificationWins()
	local args = { classification = 'K-type main sequence flare star' }
	self:assertEquals('K-type main sequence flare star', Star._internal.classification(starApiData(), args))
	self:assertEquals('K-type main sequence flare star', Star.getTypeInfo(ctx(starApiData(), args)).name)
end

-- A black hole with no mapped sub_type still says what it is; a star with
-- nothing to go on stays the generic 'Star' rather than inventing a class.
function suite:testClassificationFallbacks()
	local blackHole = starApiData()
	blackHole.celestialobject.type = 'BLACKHOLE'
	blackHole.celestialobject.sub_type = nil
	self:assertEquals('Black hole', Star._internal.classification(blackHole, {}))
	blackHole.celestialobject.sub_type = { name = 'Stellar', type = 'BLACKHOLE' }
	self:assertEquals('Stellar black hole', Star._internal.classification(blackHole, {}))
	self:assertEquals(nil, Star._internal.classification(starFixture(), {}))
	self:assertEquals('Star', Star.getTypeInfo(ctx(starFixture(), {})).name)
end

function suite:testGetCategoriesUsesTheRecordClassFirst()
	self:assertEquals('K-type main-sequence stars', Star.getCategories(ctx(starApiData(), {}))[1])
	-- Pyro's elaborated display text must not cost it the API's own class.
	local elaborated = ctx(starApiData(), { classification = 'K-type main-sequence flare star' })
	self:assertEquals('K-type main-sequence stars', Star.getCategories(elaborated)[1])
end

-- FUNCTIONAL, not taxonomy: {{Navplate system}} builds its Stars row from the
-- per-system category intersected with Stars, so a star that stops filing
-- under its system empties that row on the system page.
function suite:testGetCategoriesFilesUnderTheSystem()
	self:assertEquals('Stanton system', Star.getCategories(ctx(starApiData(), {}))[2])
	local recordless = ctx({ celestialobject = starCelestialFixture() }, {})
	self:assertEquals('Goss system', Star.getCategories(recordless)[2])
	-- Nothing to name the system with: the facet stands alone rather than a
	-- category called ' system'.
	self:assertEquals(1, #Star.getCategories(ctx({}, {})))
end

-- A record-less page's only route to a spectral-type category.
function suite:testGetCategoriesFromEditorialClassification()
	self:assertEquals(
		'G-type main-sequence stars',
		Star.getCategories(ctx({}, { classification = 'G-type main-sequence star' }))[1]
	)
	self:assertEquals('Unknown spectral type stars', Star.getCategories(ctx({}, {}))[1])
end

-- The system comes from the record or the include, NEVER the page title:
-- "Terra Nova" is the star of Terra and "Goss A" is one of two suns, so a
-- title-derived name is wrong for exactly the pages it would exist to rescue.
function suite:testSystemName()
	self:assertEquals('Stanton', Star._internal.systemName(starApiData()))
	local recordless = { celestialobject = starCelestialFixture() }
	self:assertEquals('Goss', Star._internal.systemName(recordless))
	self:assertEquals(nil, Star._internal.systemName({}))
end

-- The starmap lists no 78 Leonis, so the editorial arg is the only thing that
-- can name its system. It is LAST: a record or the include always wins.
function suite:testSystemNameFallsBackToTheEditorialArg()
	self:assertEquals('78 Leonis', Star._internal.systemName({}, { system = '78 Leonis system' }))
	self:assertEquals('Stanton', Star._internal.systemName(starApiData(), { system = 'Wrong' }))
	local recordless = { celestialobject = starCelestialFixture() }
	self:assertEquals('Goss', Star._internal.systemName(recordless, { system = 'Wrong' }))
end

-- The subtitle links; getTypeInfo.name must NOT, because it is stored as
-- `Subject type` and is the short-description fallback.
function suite:testSubtitleLinksButTypeInfoStaysPlain()
	local c = ctx(starApiData(), {})
	self:assertEquals('[[K-type main-sequence star]]', Star.getSubtitle(c))
	self:assertEquals('K-type main-sequence star', Star.getTypeInfo(c).name)
end

-- An editor's wording is kept as the display and the target still comes from
-- the record's class, so Pyro points at the K-type index.
function suite:testSubtitleKeepsEditorialWording()
	local c = ctx(starApiData(), { classification = 'K-type main-sequence flare star' })
	self:assertEquals('[[K-type main-sequence star|K-type main-sequence flare star]]', Star.getSubtitle(c))
end

-- A LINKED editorial classification must not reach the subtitle, the stored
-- `Subject type` or the short description: the subtitle would nest one link
-- inside another and render literal brackets, and the other two are stored or
-- read as plain text. Delinking happens once, in classification().
function suite:testLinkedEditorialClassificationIsDelinked()
	local args = { classification = '[[Main sequence star|K-type main-sequence]] flare star' }
	local c = ctx(starApiData(), args, starResolved(args))
	self:assertEquals('K-type main-sequence flare star', Star.getTypeInfo(c).name)
	self:assertEquals('[[K-type main-sequence star|K-type main-sequence flare star]]', Star.getSubtitle(c))
	self:assertEquals('K-type main-sequence flare star in the Stanton system', Star.getShortDescription(c))
	self:assertEquals('K-type main-sequence flare star', Star.getStructuredData(c).classification)
end

function suite:testSubtitleFallbacks()
	local blackHole = starApiData()
	blackHole.celestialobject.sub_type = { name = 'Stellar', type = 'BLACKHOLE' }
	self:assertEquals('[[Black hole|Stellar black hole]]', Star.getSubtitle(ctx(blackHole, {})))
	-- Unclassed, and a black hole the ARK gave no sub_type: the generic pages.
	self:assertEquals('[[Star]]', Star.getSubtitle(ctx({}, {})))
	blackHole.celestialobject.sub_type = nil
	blackHole.celestialobject.type = 'BLACKHOLE'
	self:assertEquals('[[Black hole]]', Star.getSubtitle(ctx(blackHole, {})))
	-- The subtitle and the category must name the same class: a sub_type-less
	-- black hole files under Black holes, not Unknown spectral type stars.
	self:assertEquals('Black holes', Star.getCategories(ctx(blackHole, {}))[1])
	-- An unmapped class names no page, so the subtitle stays plain.
	local unknown = starApiData()
	unknown.celestialobject.sub_type = { name = 'Main Sequence-Dwarf-Q' }
	self:assertEquals(
		'Main Sequence-Dwarf-Q',
		Star.getSubtitle(ctx(unknown, { classification = 'Main Sequence-Dwarf-Q' }))
	)
end

-- Tanga's white dwarf carries 58,460,000 km, byte-identical to La'uo's M
-- giant. Only the classes with a declared ceiling are policed.
function suite:testRadiusCeilingRejectsAnImpossibleClassSize()
	local tanga = starApiData()
	tanga.celestialobject.sub_type = { name = 'White Dwarf-Degenerate-A', type = 'STAR' }
	tanga.celestialobject.size = 58460000
	self:assertEquals(nil, Star._internal.radiusKm(tanga, nil))
	tanga.celestialobject.size = 14834
	self:assertEquals(14834, Star._internal.radiusKm(tanga, nil))
	local giant = starApiData()
	giant.celestialobject.sub_type = { name = 'Giants-Giant-M', type = 'STAR' }
	giant.celestialobject.size = 58460000
	self:assertEquals(58460000, Star._internal.radiusKm(giant, nil))
end

function suite:testStarSections()
	local sections = Star.getSections(ctx(starApiData(), {}, starResolved({ satellites = '4' })))
	local general = findSection(sections, 'general')
	self:assertEquals('[[Stanton system]]', findItem(general, 'System'))
	self:assertEquals('536,151 km (0.77 R☉)', findItem(general, 'Radius'))
	-- A STRING, not the number the 'number' transform produced: InfoboxLua's
	-- item schema requires string content and drops anything else without a
	-- word, so asserting the section table alone passes while the live row
	-- disappears.
	self:assertEquals('4', findItem(general, 'Satellites'))
	self:assertEquals('[[UEE]]', findItem(general, 'Jurisdiction'))
end

-- A star's satellites are its planets, so they store as Planet count rather
-- than inventing a second column for the same fact.
function suite:testStarStructuredData()
	local data = Star.getStructuredData(ctx(starApiData(), {}, starResolved({ satellites = '4' })))
	self:assertEquals('Stanton system', data.system)
	self:assertEquals('K-type main-sequence star', data.classification)
	self:assertEquals(536151, data.radius)
	self:assertEquals(4, data.planet_count)
end

-- An editor's markup is delinked before it is stored, the same rule the
-- affiliation vocabulary follows.
function suite:testStarStructuredDataDelinksClassification()
	local args = { classification = '[[Main sequence star|K-type main-sequence]] flare star' }
	local data = Star.getStructuredData(ctx(starApiData(), args, starResolved(args)))
	self:assertEquals('K-type main-sequence flare star', data.classification)
end

function suite:testStarShortDescription()
	self:assertEquals(
		'K-type main-sequence star in the Stanton system',
		Star.getShortDescription(ctx(starApiData(), {}))
	)
	self:assertEquals('Star in the Stanton system', Star.getShortDescription(ctx(starFixture(), {})))
	self:assertEquals('A star in Star Citizen', Star.getShortDescription(ctx({}, {})))
end

function suite:testStarStarmapButtonAndMetadata()
	local buttons = Star.getFooterButtons(ctx(starApiData(), {}))
	self:assertEquals(1, #buttons)
	self:assertEquals('https://robertsspaceindustries.com/starmap?location=GOSS.STARS.GOSSA', buttons[1].url)
	-- The button keeps the bare code; only the row gains the break points.
	self:assertEquals('GOSS.<wbr>STARS.<wbr>GOSSA', Star.getMetadataItems(ctx(starApiData(), {}))[1].content)
	-- A soft-failed fetch still renders both from the arg that would have
	-- keyed it, under either alias.
	self:assertEquals('SOL.<wbr>STARS.<wbr>SOL', Star.getMetadataItems(ctx({}, { code = 'SOL.STARS.SOL' }))[1].content)
	self:assertEquals(0, #Star.getFooterButtons(ctx({}, {})))
	self:assertEquals(0, #Star.getMetadataItems(ctx({}, {})))
end

function suite:testStarEnrichFetchesByCode()
	withStubbedFetch(starCelestialFixture(), function(captured)
		local apiData = Star.enrich(ctx({}, { kind = 'Location', family = 'star', code = 'GOSS.STARS.GOSSA' }))
		self:assertEquals('GOSS.STARS.GOSSA', captured.key)
		self:assertEquals('Goss A', apiData.celestialobject.designation)
	end)
end

-- ── Body leaf ──────────────────────────────────────────────────────────────

--- Cellin's location record (trimmed): a moon with a real game record.
local function moonFixture()
	return {
		uuid = 'aaaa1111-0000-0000-0000-000000000001',
		name = 'Cellin',
		respawn_location_type = 'None',
		type = { name = 'Moon', classification = 'Moon' },
		system = 'Stanton System',
		size = 260333, -- metres; the record's size IS the radius
		parent = { name = 'Crusader', type_name = 'Planet' },
	}
end

--- A Stanton-shaped starsystem payload holding the objects the Body leaf
--- resolves against, in the ARK's real shape: a body carries its plain `name`
--- while its code embeds the designation and the owning corporation, and a star
--- carries no `name` at all, only a designation that IS the system's.
local function bodyStarsystemFixture()
	return {
		code = 'STANTON',
		name = 'Stanton',
		affiliation = { { code = 'uee', name = 'UEE' } },
		celestial_objects = {
			{ id = 1691, code = 'STANTON.STARS.STANTON', type = 'STAR', designation = 'Stanton' },
			{
				id = 1693,
				code = 'STANTON.PLANETS.STANTONIHURSTONDYNAMICS',
				type = 'PLANET',
				name = 'Hurston',
				designation = 'Stanton I',
				parent_id = 1691,
				sub_type = { name = 'Super-Earth', type = 'PLANET' },
				sensor = { population = 6, economy = 6, danger = 4 },
			},
			{
				id = 1695,
				code = 'STANTON.PLANETS.STANTONIICRUSADER',
				type = 'PLANET',
				name = 'Crusader',
				designation = 'Stanton II',
				parent_id = 1691,
				sub_type = { name = 'Gas Giant', type = 'PLANET' },
			},
			{
				id = 2737,
				code = 'STANTON.MOONS.CELLIN',
				type = 'SATELLITE',
				name = 'Cellin',
				designation = 'Stanton 2a',
				parent_id = 1695,
				sub_type = { name = 'Planetary Moon', type = 'SATELLITE' },
			},
		},
	}
end

local function bodyApiData()
	local apiData = moonFixture()
	apiData.starsystem = bodyStarsystemFixture()
	return apiData
end

local function bodyResolved(args)
	return Editorial.resolve({}, args, assembly.mergeEditorialManifests(assembly.buildChain(Body)))
end

function suite:testResolveSubtypePlanetAndMoonRecords()
	local moon = moonFixture()
	self:assertTrue(Location.matches(moon))
	self:assertEquals('body', Location._internal.recordFamily(moon))
	self:assertEquals(Body, Location.resolveSubtype(moon, {}))
	local planet = moonFixture()
	planet.type = { name = 'Planet', classification = 'Planet' }
	self:assertEquals('body', Location._internal.recordFamily(planet))
	self:assertEquals(Body, Location.resolveSubtype(planet, {}))
	self:assertEquals(Body, Location.resolveSubtype({}, { kind = 'Location', family = 'body' }))
end

-- The record decides, because the two sources disagree on Delamar: the game
-- calls it a Moon, the starmap a PLANET.
function suite:testIsMoonPrefersTheRecord()
	local apiData = bodyApiData()
	self:assertTrue(Body._internal.isMoon(apiData, { code = 'STANTON.MOONS.CELLIN' }))
	-- Flipping the type needs the parent flipped too, since a planet parent
	-- settles it first.
	apiData.type = { name = 'Planet' }
	apiData.parent = { name = 'Stanton', type_name = 'Star' }
	self:assertFalse(Body._internal.isMoon(apiData, { code = 'STANTON.MOONS.CELLIN' }))
	-- No record: the starmap's SATELLITE token answers instead.
	local recordless = { starsystem = bodyStarsystemFixture() }
	self:assertTrue(Body._internal.isMoon(recordless, { code = 'STANTON.MOONS.CELLIN' }))
	self:assertFalse(Body._internal.isMoon(recordless, { code = 'STANTON.PLANETS.STANTONIHURSTONDYNAMICS' }))
end

-- Neither starmap signal is reliable alone: the ARK types Pyro IV a PLANET but
-- parents it to a planet, and types Gainey a SATELLITE but parents it to the
-- star. Both pages say Moon, so |type= outranks the token.
function suite:testIsMoonHonoursTheStatedType()
	local recordless = { starsystem = bodyStarsystemFixture() }
	local asMoon = { code = 'STANTON.PLANETS.STANTONIHURSTONDYNAMICS', type = 'Moon' }
	self:assertTrue(Body._internal.isMoon(recordless, asMoon))
	self:assertEquals('Moons', Body.getTypeInfo(ctx(recordless, asMoon)).category)
	local asPlanet = { code = 'STANTON.MOONS.CELLIN', type = 'Planet' }
	self:assertFalse(Body._internal.isMoon(recordless, asPlanet))
	-- The legacy corpus spells one of them plural.
	self:assertTrue(Body._internal.isMoon(recordless, { type = 'Moons' }))
	-- The record still outranks the page: the game calls Delamar a Moon while
	-- the starmap files it as a PLANET.
	local record = { type = { name = 'Moon' }, starsystem = bodyStarsystemFixture() }
	self:assertTrue(Body._internal.isMoon(record, { type = 'Planet' }))
end

-- Pyro IV's own record is type Planet with parent Pyro V, itself a planet.
function suite:testIsMoonPrefersTheRecordParentOverItsOwnType()
	local pyroIV = { type = { name = 'Planet' }, parent = { name = 'Pyro V', type_name = 'Planet' } }
	self:assertTrue(Body._internal.isMoon(pyroIV, {}))
	self:assertEquals('Moons', Body.getTypeInfo(ctx(pyroIV, {})).category)
	-- One direction only: a star parent does not unmake a moon, which is how
	-- Delamar's record reads.
	local delamar = { type = { name = 'Moon' }, parent = { name = 'Nyx', type_name = 'Star' } }
	self:assertTrue(Body._internal.isMoon(delamar, {}))
	local planet = { type = { name = 'Planet' }, parent = { name = 'Stanton', type_name = 'Star' } }
	self:assertFalse(Body._internal.isMoon(planet, {}))
end

-- The record's size is METRES and is the radius. The starmap size is never
-- read for a body: it carries at least three different units there.
function suite:testBodyRadiusComesFromTheRecordInMetres()
	self:assertEquals(260.333, Body._internal.radiusKm(moonFixture()))
	self:assertEquals('260 km', Body._internal.radiusDisplay(moonFixture()))
	local big = moonFixture()
	big.size = 7450000
	self:assertEquals('7,450 km', Body._internal.radiusDisplay(big))
	self:assertEquals(nil, Body._internal.radiusKm({}))
	-- No record: an editor's kilometres stand in, which is the only radius the
	-- starmap-only bodies can have.
	local args = { radius = '1740' }
	self:assertEquals(1740, Body._internal.radiusKm({}, bodyResolved(args)))
	self:assertEquals('1,740 km', Body._internal.radiusDisplay({}, bodyResolved(args)))
	-- The record still wins where there is one.
	self:assertEquals(260.333, Body._internal.radiusKm(moonFixture(), bodyResolved(args)))
end

function suite:testBodyClassification()
	local hurston = { starsystem = bodyStarsystemFixture() }
	self:assertEquals(
		'Super-Earth',
		Body._internal.classification(hurston, { code = 'STANTON.PLANETS.STANTONIHURSTONDYNAMICS' })
	)
	-- A moon's uniform sub_type maps to nothing, so the subtitle stays 'Moon'.
	self:assertEquals(nil, Body._internal.classification(bodyApiData(), { code = 'STANTON.MOONS.CELLIN' }))
	self:assertEquals('Moon', Body.getTypeInfo(ctx(bodyApiData(), { code = 'STANTON.MOONS.CELLIN' })).name)
	self:assertEquals('Moons', Body.getTypeInfo(ctx(bodyApiData(), { code = 'STANTON.MOONS.CELLIN' })).category)
	-- An editor's linked wording is delinked before it can reach the store.
	self:assertEquals('Super-Earth', Body._internal.classification(hurston, { classification = '[[Super-Earth]]' }))
end

-- The 33 in-game body pages carry no `code`, so the name match is the only
-- thing that resolves them. Without it they lose their classification, their
-- starmap parent and their Starmap button.
function suite:testBodyResolvesByNameWithoutACode()
	local hurston = { name = 'Hurston', starsystem = bodyStarsystemFixture() }
	self:assertEquals('Super-Earth', Body._internal.classification(hurston, {}))
	self:assertEquals('STANTON.PLANETS.STANTONIHURSTONDYNAMICS', Body._internal.resolvedStarmapCode(hurston, {}))
	-- Only the display name is asserted: the target depends on which title
	-- exists, which the runner's mw.title shim cannot answer, so it is verified
	-- on the live wiki like tier()'s own linking.
	self:assertEquals('Stanton', (Body._internal.parentAnchor(hurston, {})))
	-- A code the editor supplied still wins, so an ARK name collision stays
	-- correctable from the page.
	self:assertEquals(
		'Gas giant',
		Body._internal.classification(hurston, { code = 'STANTON.PLANETS.STANTONIICRUSADER' })
	)
end

-- The designation rides in the header title, so it is suppressed where it
-- would only repeat it: every body the ARK names by designation alone.
function suite:testBodyTitleAnnotationIsTheDesignation()
	local hurston = { name = 'Hurston', starsystem = bodyStarsystemFixture() }
	self:assertEquals('Stanton I', Body.getTitleAnnotation(ctx(hurston, {})))
	-- The editor's arg wins over the ARK's.
	local args = { designation = 'Stanton One' }
	self:assertEquals('Stanton One', Body.getTitleAnnotation(ctx(hurston, args, bodyResolved(args))))
	-- A body the ARK names only by designation: the title already says it.
	local gossI = {
		name = 'Goss I',
		starsystem = {
			celestial_objects = { { code = 'GOSS.PLANETS.GOSSI', type = 'PLANET', designation = 'Goss I' } },
		},
	}
	self:assertEquals(nil, Body.getTitleAnnotation(ctx(gossI, {})))
	self:assertEquals(nil, Body.getTitleAnnotation(ctx({}, {})))
	-- Stored as a property regardless, including from the ARK alone.
	self:assertEquals('Stanton I', Body.getStructuredData(ctx(hurston, {})).designation)
	self:assertEquals('Goss I', Body.getStructuredData(ctx(gossI, {})).designation)
end

-- The starmap gives every body a sensor block; a zero is "no reading", not a
-- rating of nothing.
function suite:testBodySensorSection()
	local hurston = { name = 'Hurston', starsystem = bodyStarsystemFixture() }
	local sections = Body.getSections(ctx(hurston, {}))
	local sensor
	for _, section in ipairs(sections) do
		if section.key == 'sensor' then
			sensor = section
		end
	end
	self:assertEquals('Sensor readings', sensor.label)
	self:assertEquals(3, #sensor.items)
	-- A body with no starmap object has no section at all.
	for _, section in ipairs(Body.getSections(ctx({}, {}))) do
		self:assertNotEquals('sensor', section.key)
	end
	-- Stored so a type index page can column and sort on them.
	local data = Body.getStructuredData(ctx(hurston, {}))
	self:assertEquals(6, data.population_rating)
	self:assertEquals(6, data.economy_rating)
	self:assertEquals(4, data.danger_rating)
	-- A zero reading is the starmap's no-data sentinel, so nothing is stored.
	local blank = { name = 'Hurston', starsystem = bodyStarsystemFixture() }
	blank.starsystem.celestial_objects[2].sensor = { population = 0, economy = 0, danger = 0 }
	local none = Body.getStructuredData(ctx(blank, {}))
	self:assertEquals(nil, none.population_rating)
	self:assertEquals(nil, none.danger_rating)
end

-- VerseGuide's path is the system code plus the designation's tail, and it
-- carries only what is in the game.
function suite:testVerseguideUrl()
	local hurston = {
		type = { name = 'Planet' },
		name = 'Hurston',
		starsystem = bodyStarsystemFixture(),
	}
	self:assertEquals('https://verseguide.com/location/STANTON/I', Body._internal.verseguideUrl(hurston, {}, nil))
	local aberdeen = { type = { name = 'Moon' }, starsystem = bodyStarsystemFixture() }
	local args = { designation = 'Stanton 1b' }
	self:assertEquals(
		'https://verseguide.com/location/STANTON/1B',
		Body._internal.verseguideUrl(aberdeen, args, bodyResolved(args))
	)
	-- No game record: the body is not in VerseGuide.
	self:assertEquals(
		nil,
		Body._internal.verseguideUrl({ starsystem = bodyStarsystemFixture() }, args, bodyResolved(args))
	)
	-- No designation to key on.
	self:assertEquals(nil, Body._internal.verseguideUrl({ type = { name = 'Planet' } }, {}, nil))
	-- The button rides alongside the Starmap one.
	local buttons = Body.getFooterButtons(ctx(hurston, {}))
	self:assertEquals(2, #buttons)
	self:assertEquals('Starmap', buttons[1].label)
	self:assertEquals('VerseGuide', buttons[2].label)
end

-- A body with no resolvable system must NOT bridge: attachStarsystem's own
-- fallback would look the body's own name up as a system.
function suite:testEnrichSkipsTheBridgeWithoutASystem()
	local apiData = Body.enrich({ apiData = { name = 'Oberon' }, args = {} })
	self:assertEquals(nil, apiData.starsystem)
end

-- A body need not share its system's affiliation, so it gets its own row and
-- the chain's first tier stays the system's.
function suite:testBodyAffiliationIsItsOwnRow()
	local apiData = bodyApiData()
	-- No statement on the page: the system's affiliation stands in.
	self:assertEquals('[[United Empire of Earth]]', Body._internal.affiliationText(apiData, nil))
	-- A canonical token renders like its siblings, NOT as the editor typed it:
	-- a bare "UEE" next to another page's "United Empire of Earth" is the bug.
	local uee = { affiliation = 'UEE' }
	self:assertEquals('[[United Empire of Earth]]', Body._internal.affiliationText(apiData, bodyResolved(uee)))
	-- Free text keeps the editor's own markup, so they choose whether it links.
	local args = { affiliation = '[[Outsiders]]' }
	local resolved = bodyResolved(args)
	self:assertEquals('[[Outsiders]]', Body._internal.affiliationText(apiData, resolved))
	-- ... and it does not reach the chain, whose first tier links the systems
	-- category and so must describe the system.
	local chain = Body._internal.locationChain(apiData, args)
	self:assertStringContains('UEE space', chain)
	self:assertEquals(nil, chain:find('Outsiders', 1, true))
	-- No system either: nothing to fall back to.
	self:assertEquals(nil, Body._internal.affiliationText({}, nil))
end

-- Stored compact, so a body and its system share one value bucket whatever
-- wording the page uses.
function suite:testBodyStoredAffiliation()
	local apiData = bodyApiData()
	self:assertEquals('UEE', Body._internal.storedAffiliation(apiData, nil))
	for _, wording in ipairs({ 'UEE', 'United Empire of Earth', '[[United Empire of Earth]]' }) do
		local args = { affiliation = wording }
		self:assertEquals('UEE', Body._internal.storedAffiliation(apiData, bodyResolved(args)))
	end
	local free = { affiliation = '[[Outsiders]]' }
	self:assertEquals('Outsiders', Body._internal.storedAffiliation(apiData, bodyResolved(free)))
	-- Two affiliations in one arg against a single-valued column: the first is
	-- the token. Without the split, Editorial.toStoredValue strips the tag with
	-- no separator and the row stores 'VanduulIndependent'.
	local two = { affiliation = '[[Vanduul]]<br/>Independent' }
	self:assertEquals('Vanduul', Body._internal.storedAffiliation(apiData, bodyResolved(two)))
	self:assertEquals(
		'Vanduul',
		Body._internal.storedAffiliation(apiData, bodyResolved({ affiliation = '[[Vanduul]]<br>Independent' }))
	)
	-- The row still shows both, since the page said both.
	self:assertStringContains('Independent', Body._internal.affiliationText(apiData, bodyResolved(two)))
end

-- The system category is what keeps a body on {{Navplate system}}, whose
-- Planets and Moons rows intersect the type category with it.
function suite:testBodyCategories()
	local hurston = { name = 'Hurston', system = 'Stanton System', starsystem = bodyStarsystemFixture() }
	local categories = Body.getCategories(ctx(hurston, {}))
	self:assertEquals('Super-Earths', categories[1])
	self:assertEquals('Stanton system', categories[2])
	-- An editor's classification carries the facet where the ARK object is
	-- absent, in the wiki's spelling or the ARK's.
	local lore = { classification = 'Gas giant', system = 'Goss' }
	self:assertEquals('Gas giants', Body.getCategories(ctx({}, lore))[1])
	self:assertEquals('Goss system', Body.getCategories(ctx({}, lore))[2])
	self:assertEquals('Gas giants', Body.getCategories(ctx({}, { classification = 'Gas Giant' }))[1])
	-- A moon has no facet of its own, so only the system category remains.
	self:assertEquals(1, #Body.getCategories(ctx(bodyApiData(), {})))
	self:assertEquals('Stanton system', Body.getCategories(ctx(bodyApiData(), {}))[1])
end

-- Exactly three tiers, and never an ancestor that is not the direct parent.
function suite:testLocationChainIsThreeTiers()
	local args = { code = 'STANTON.MOONS.CELLIN' }
	local chain = Body._internal.locationChain(bodyApiData(), args, nil)
	self:assertStringContains('UEE space', chain)
	self:assertStringContains('Stanton system', chain)
	self:assertStringContains('Crusader', chain)
	-- The star is an ancestor but NOT the parent, so it must not appear.
	self:assertEquals(nil, string.find(chain, 'Stanton ›%s*Stanton'))
	self:assertEquals(2, select(2, chain:gsub('›', '')))
end

-- The eleven planets in multi-star systems carry parent_id = null, so the
-- chain honestly stops at the system rather than guessing a sun.
function suite:testLocationChainDropsAnAbsentParent()
	local sys = bodyStarsystemFixture()
	sys.celestial_objects = {
		{ id = 9, code = 'GOSS.PLANETS.GOSSI', type = 'PLANET', designation = 'Goss I', parent_id = nil },
	}
	sys.name = 'Goss'
	local chain = Body._internal.locationChain(
		{ starsystem = sys },
		{ code = 'GOSS.PLANETS.GOSSI', system = 'Goss' },
		nil
	)
	self:assertStringContains('Goss system', chain)
	self:assertEquals(1, select(2, chain:gsub('›', '')))
end

function suite:testBodyParentAnchor()
	-- Display names only: the link target prefers a qualified title when one
	-- exists, which the runner's mw.title shim cannot answer.
	self:assertEquals('Crusader', (Body._internal.parentAnchor(bodyApiData(), { code = 'STANTON.MOONS.CELLIN' })))
	local planet = moonFixture()
	planet.parent = { name = 'Stanton', type_name = 'Star' }
	self:assertEquals('Stanton', (Body._internal.parentAnchor(planet, {})))
	-- Record-less: resolved from parent_id against the system's object list.
	local n3, t3 = Body._internal.parentAnchor(
		{ starsystem = bodyStarsystemFixture() },
		{ code = 'STANTON.MOONS.CELLIN' }
	)
	self:assertEquals('Crusader', n3)
end

function suite:testBodyStructuredData()
	local args = { code = 'STANTON.MOONS.CELLIN', designation = 'Stanton 2a', satellites = '2' }
	local data = Body.getStructuredData(ctx(bodyApiData(), args, bodyResolved(args)))
	self:assertEquals('Stanton system', data.system)
	self:assertEquals('Crusader', data.parent)
	self:assertEquals('Stanton 2a', data.designation)
	self:assertEquals(260.333, data.radius)
	self:assertEquals(2, data.moon_count)
end

function suite:testBodyShortDescription()
	local hurston = { starsystem = bodyStarsystemFixture() }
	self:assertEquals(
		'Super-Earth in the Stanton system',
		Body.getShortDescription(ctx(hurston, { code = 'STANTON.PLANETS.STANTONIHURSTONDYNAMICS', system = 'Stanton' }))
	)
	-- A moon names what it orbits; Cellin's record gives Crusader.
	self:assertEquals(
		'Moon of Crusader in the Stanton system',
		Body.getShortDescription(ctx(bodyApiData(), { code = 'STANTON.MOONS.CELLIN' }))
	)
	-- A moon the starmap hangs off the star names nothing extra.
	local offStar = {
		type = { name = 'Moon' },
		parent = { name = 'Stanton', type_name = 'Star' },
		system = 'Stanton System',
		starsystem = bodyStarsystemFixture(),
	}
	self:assertEquals('Moon in the Stanton system', Body.getShortDescription(ctx(offStar, {})))
	-- 'Natural satellite of X' reads; a planet-type classification on a moon
	-- does not, so Pyro IV keeps its class and drops the parent.
	local args = { classification = 'Natural satellite' }
	self:assertEquals(
		'Natural satellite of Crusader in the Stanton system',
		Body.getShortDescription(ctx(bodyApiData(), args, bodyResolved(args)))
	)
	local planetClass = { classification = 'Terrestrial rocky planet' }
	self:assertEquals(
		'Terrestrial rocky planet in the Stanton system',
		Body.getShortDescription(ctx(bodyApiData(), planetClass, bodyResolved(planetClass)))
	)
	self:assertEquals('A planet in Star Citizen', Body.getShortDescription(ctx({}, {})))
end

-- ── Orbital zones (StarSystem) ─────────────────────────────────────────────

function suite:testZoneItems()
	local items = StarSystem._internal.buildZoneItems({
		habitable_zone_inner = 0.89,
		habitable_zone_outer = 3,
		frost_line = 4.96,
	})
	self:assertEquals('Habitable zone', items[1].label)
	self:assertEquals('0.89 – 3 AU', items[1].content)
	self:assertEquals('Frost line', items[2].label)
	self:assertEquals('4.96 AU', items[2].content)
end

-- Zero is the starmap's no-data sentinel, not a measurement: every unsurveyed
-- system reports a flat 0/0/0. Each value is guarded on its own because Oberon
-- publishes a frost line with no habitable zone at all.
function suite:testZoneItemsDropTheZeroSentinel()
	self:assertEquals(0, #StarSystem._internal.buildZoneItems({
		habitable_zone_inner = 0,
		habitable_zone_outer = 0,
		frost_line = 0,
	}))
	local oberon = StarSystem._internal.buildZoneItems({
		habitable_zone_inner = 0,
		habitable_zone_outer = 0,
		frost_line = 0.01,
	})
	self:assertEquals(1, #oberon)
	self:assertEquals('Frost line', oberon[1].label)
	self:assertEquals(0, #StarSystem._internal.buildZoneItems(nil))
end

-- Dispatch: every Location leaf takes an EntityHookContext — a leaf whose
-- hooks aren't written for ctx must fail here, not render wrong values
-- silently on the wiki. StarSystem's getTypeInfo and JumpPoint's
-- getShortDescription are each ctx-dependent (unlike JumpPoint's own
-- getTypeInfo, which is static).
function suite:testLeavesDispatchThroughContext()
	local typeInfo = assembly.callHook(
		StarSystem,
		'getTypeInfo',
		{ apiData = { starsystem = { type = 'SINGLE_STAR' } }, args = {}, resolved = {} }
	)
	self:assertEquals('Single star system', typeInfo.name)

	self:assertEquals(
		'Medium jump point from Pyro to Nyx',
		assembly.callHook(JumpPoint, 'getShortDescription', { apiData = jumpPointApiData(), args = {}, resolved = {} })
	)
end

return suite
