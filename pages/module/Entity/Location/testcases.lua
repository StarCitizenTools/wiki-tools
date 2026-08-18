require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Editorial = require('Module:Entity/Editorial')
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

--- Pyro - Nyx gate location payload (trimmed from the live API response): the
--- record shape the declared-kind trust path fetches for a jump-point uuid.
--- Typed 'Anomaly' — the token the locations API gives jump points AND
--- non-jump-point anomalies; only the exact name suffix separates a gate.
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
	self:assertTrue(f(solarSystemFixture(), { kind = 'Location' })) -- declaring the kind changes nothing
	self:assertTrue(f({}, { kind = 'Location' })) -- editorial fork, kind-declared, NO typed record
	self:assertFalse(f({ type = { name = 'Planet' } }, nil)) -- other location, undeclared
	self:assertFalse(f({}, {})) -- nothing at all
	-- Nil-tolerant (symmetric with isJumpPointRecord): a non-table apiData is
	-- an untyped record, so only the declared kind decides.
	self:assertTrue(f(nil, { kind = 'Location' }))
	self:assertFalse(f(nil, nil))
end

-- The record-aware half of the truth table — a DELIBERATE change from the
-- pre-jump-point behavior, where a declared kind alone was enough: a typed
-- non-SolarSystem record must not fetch even on a kind-declared page. A
-- jump-point record with |kind=Location would otherwise fire a bogus
-- starsystems name-lookup for "Pyro - Nyx Jump Point".
function suite:testShouldFetchStarsystemTypedRecordBeatsDeclaredKind()
	local f = Location._internal.shouldFetchStarsystem
	self:assertFalse(f(jumpPointFixture(), { kind = 'Location' }))
	self:assertFalse(f({ type = { name = 'Planet' } }, { kind = 'Location' }))
end

-- The one predicate shared by resolveSubtype and enrich, exercised directly:
-- the Anomaly type alone is NOT a jump point, and the name check is a real
-- suffix match — the wreck site (suffix mid-name) and the misnamed inactive
-- gate (prefix) must both stay out.
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

-- |starmapcode= wins over the legacy |code= alias; values are trimmed; a
-- blank primary falls through to the alias; no usable value at all → nil
-- (no fetch).
function suite:testStarmapCodeArg()
	local f = Location.starmapCodeArg
	self:assertEquals('PYRO.JUMPPOINTS.NYX', f({ starmapcode = 'PYRO.JUMPPOINTS.NYX' }))
	self:assertEquals('NYX.JUMPPOINTS.PYRO', f({ code = 'NYX.JUMPPOINTS.PYRO' }))
	self:assertEquals('PYRO.JUMPPOINTS.NYX', f({ starmapcode = 'PYRO.JUMPPOINTS.NYX', code = 'NYX.JUMPPOINTS.PYRO' }))
	self:assertEquals('NYX.JUMPPOINTS.PYRO', f({ starmapcode = '  ', code = 'NYX.JUMPPOINTS.PYRO' }))
	self:assertEquals('TRIMMED', f({ starmapcode = ' TRIMMED ' }))
	self:assertEquals(nil, f({ starmapcode = '' }))
	self:assertEquals(nil, f({}))
	self:assertEquals(nil, f(nil))
end

function suite:testResolveLookupNamePrecedence()
	local f = Location._internal.resolveLookupName
	self:assertEquals('Rihlah', f({ name = 'Ignored System' }, { starmapname = 'Rihlah', name = 'Also ignored' }))
	self:assertEquals('Stanton System', f({ name = 'Stanton System' }, { name = 'Ignored' }))
	self:assertEquals('Terra system', f({}, { name = 'Terra system' }))
	-- Last resort: a bare {{Location}} on a lore system supplies no starmapname,
	-- no location record and no |name=, so the page title IS the lookup key.
	-- (The runner's current title is 'Test'.)
	self:assertEquals(mw.title.getCurrentTitle().text, f({}, {}))
	self:assertEquals(mw.title.getCurrentTitle().text, f({}, nil))
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

-- Every subtype leaf in the map conforms to the chain-link contract, strict
-- mode included: a misspelled hook (getMetadateItems) currently no-ops
-- silently at render time, and the trust gate leans on leaf resolution for
-- admission, so a mis-hooked leaf is load-bearing twice over. Kinds and
-- facets get this from Registry/testcases; subtype leaves got nothing until
-- here (final-review recommendation).
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
	self:assertEquals('Entity/Location/StarSystem', Location._internal.LOCATION_SUBTYPE_MAP.SolarSystem)
end

-- Pins the leaf PATH Task 3's module must occupy (Module: prefix added by the
-- SubtypeResolver); the identity assertion lives in
-- testResolveSubtypeJumpPointRecord.
function suite:testSubtypeMapTargetsJumpPoint()
	self:assertEquals('Entity/Location/JumpPoint', Location._internal.LOCATION_SUBTYPE_MAP.JumpPoint)
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
	-- starmapcode: legacy |code= alias, no smw key, no transform — the leaf
	-- surfaces the code itself, and enrich reads the raw args (it runs before
	-- editorial resolution).
	self:assertEquals('starmapcode', manifest.starmapcode.arg[1])
	self:assertEquals('code', manifest.starmapcode.arg[2])
	self:assertEquals(nil, manifest.starmapcode.smw)
	self:assertEquals(nil, manifest.starmapcode.transform)
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

function suite:testShouldFetchStarsystemFamilyJumpPointNeverFetches()
	local f = Location._internal.shouldFetchStarsystem
	self:assertFalse(f({}, { kind = 'Location', family = 'jumppoint' }))
	self:assertTrue(f({}, { kind = 'Location' })) -- default fork unchanged
end

function suite:testGateEntrySystemFallsBackToDesignation()
	local f = Location.gateEntrySystem
	self:assertEquals('Pyro', f(jumpPointFixture())) -- record system wins
	self:assertEquals('Stanton', f({ celestialobject = { designation = 'Stanton - Nyx' } }))
	self:assertEquals(nil, f({ celestialobject = { designation = 'Malformed' } }))
	self:assertEquals(nil, f({}))
end

function suite:testResolveSubtypeUndeclaredWithoutRecordIsNil()
	self:assertEquals(nil, Location.resolveSubtype({}, {}))
end

-- The empty args table is the call shape of the declared-kind validity gate in
-- Module:Entity/Data, so this doubles as the gate's admission test: matches()
-- stays SolarSystem-narrow, and THIS resolution is how a jump-point uuid gets
-- in.
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
	self:assertEquals(0, #StarSystem.getFooterButtons(apiData, {}))
	self:assertEquals(0, #StarSystem.getMetadataItems(apiData, {}))
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

-- End to end through the real Editorial.resolve: an unparseable count override
-- must not DELETE the starmap tally. The count fields carry no apiPath, so a
-- resolved entry is unconditionally authoritative; a junk `| planets = Unknown`
-- that survived the transform would blank the tile, the stored planet_count and
-- the short-description clause in one go (this is why El'sin shipped "Size: ?").
function suite:testUnparseableCountOverrideKeepsTheStarmapTally()
	local apiData = solarSystemFixture()
	apiData.starsystem = starsystemFixture() -- 2 PLANET objects
	local resolved = Editorial.resolve(apiData, { planets = 'Unknown' }, Location.getEditorialManifest())
	self:assertEquals(nil, resolved.planets)

	local planetTile
	for _, tile in ipairs(StarSystem._internal.buildObjectTiles(apiData.starsystem, Editorial.view(resolved))) do
		if tile.label == 'Planets' then
			planetTile = tile
		end
	end
	self:assertEquals(2, planetTile and planetTile.value)
	self:assertEquals(2, StarSystem.getStructuredData(apiData, {}, resolved).planet_count)
	self:assertEquals(
		'UEE single star system with 2 planets',
		StarSystem.getShortDescription(apiData, {}, StarSystem.getTypeInfo(apiData), nil, resolved)
	)
end

-- The same guard on the one overlap field: a junk `| size =` must not displace
-- the starmap's aggregated size (the live "Size: ? AU" regression).
function suite:testUnparseableSizeOverrideKeepsTheStarmapSize()
	local apiData = solarSystemFixture()
	apiData.starsystem = starsystemFixture()
	local resolved = Editorial.resolve(apiData, { size = '?' }, Location.getEditorialManifest())
	self:assertEquals(4.85, resolved.size.value)
	self:assertEquals('api', resolved.size.source)
	self:assertEquals(
		'4.85 AU',
		findItem(findSection(StarSystem.getSections(apiData, {}, resolved), 'general'), 'Size')
	)
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

-- ── enrich (the starmap fetch seam) ────────────────────────────────────────
--
-- enrich() takes no injection point, but Location holds the Module:Entity/Api
-- module TABLE from the require cache and calls `api.fetchApi` through it, so
-- swapping that field is the seam. Without this, everything between
-- shouldFetchStarsystem and the attachment — the URL encoding of the lookup key
-- and the normalizeAggregates call — could be deleted with the suite still green.

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
		Location.enrich({}, { kind = 'Location', starmapname = "Kyuk'ya" })
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
		local apiData = Location.enrich(solarSystemFixture(), nil)
		self:assertEquals(nil, apiData.starsystem.aggregated.size)
		self:assertEquals(nil, apiData.starsystem.aggregated.population)
		self:assertEquals(nil, apiData.starsystem.aggregated.economy)
	end)
end

-- enrich picks the same row pickStarsystem would: the exact name beats a longer
-- substring match returned by the filter[name] query.
function suite:testEnrichAttachesThePickedRow()
	withStubbedFetch({ { name = 'Vega Prime' }, { name = 'Vega', code = 'VEGA' } }, function()
		local apiData = Location.enrich({ name = 'Vega System', type = { name = 'SolarSystem' } }, nil)
		self:assertEquals('VEGA', apiData.starsystem.code)
	end)
end

-- No fetch at all for a payload the kind does not claim (a planet record on an
-- undeclared page), and nothing attached.
function suite:testEnrichSkipsUnclaimedPayloads()
	withStubbedFetch({ starsystemFixture() }, function(captured)
		local apiData = Location.enrich({ type = { name = 'Planet' } }, nil)
		self:assertEquals(nil, apiData.starsystem)
		self:assertEquals(nil, captured.key)
	end)
end

-- Soft-fail: an empty result list leaves the record absent rather than
-- attaching an empty table the section builders would have to nil-guard.
function suite:testEnrichSoftFailsOnEmptyResult()
	withStubbedFetch({}, function()
		self:assertEquals(nil, Location.enrich(solarSystemFixture(), nil).starsystem)
	end)
end

-- ── enrich: the celestial-object branch (jump-point records) ───────────────

function suite:testEnrichJumpPointFetchesCelestialObject()
	withStubbedFetch(celestialObjectFixture(), function(captured)
		local apiData = Location.enrich(jumpPointFixture(), { kind = 'Location', starmapcode = 'PYRO.JUMPPOINTS.NYX' })
		self:assertEquals('PYRO.JUMPPOINTS.NYX', captured.key)
		self:assertEquals('celestial-objects/%s', captured.config.endpoint)
		-- A plain path endpoint (no query string of its own), so locale rides
		-- params like the primary locations/%s config — NOT the endpoint
		-- string, which the starsystems fetch needs only to survive its
		-- ?filter[…] query.
		self:assertEquals('en_EN', captured.config.params.locale)
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
		Location.enrich(jumpPointFixture(), { code = 'NYX.JUMPPOINTS.PYRO' })
		self:assertEquals('NYX.JUMPPOINTS.PYRO', captured.key)
		Location.enrich(jumpPointFixture(), { starmapcode = 'PYRO.JUMPPOINTS.NYX', code = 'NYX.JUMPPOINTS.PYRO' })
		self:assertEquals('PYRO.JUMPPOINTS.NYX', captured.key)
	end)
end

-- No code arg → no fetch of ANY kind: not the celestial-objects endpoint (no
-- bridge key), and not starsystems either — the record is typed non-
-- SolarSystem, so the kind-declared fallback must not fire.
function suite:testEnrichJumpPointWithoutCodeFetchesNothing()
	withStubbedFetch(celestialObjectFixture(), function(captured)
		local apiData = Location.enrich(jumpPointFixture(), { kind = 'Location' })
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
			local apiData = Location.enrich(jumpPointFixture(), { starmapcode = 'PYRO.JUMPPOINTS.NYX' })
			self:assertEquals(nil, apiData.celestialobject, payload .. ' payload must not attach')
		end)
	end
end

-- The two bridges dispatch on the RECORD shape, not the args: a SolarSystem
-- record keeps the starsystems fetch even when a starmapcode arg is present,
-- and attaches no celestial object.
function suite:testEnrichSolarSystemIgnoresStarmapCodeArg()
	withStubbedFetch({ starsystemFixture() }, function(captured)
		local apiData = Location.enrich(solarSystemFixture(), { starmapcode = 'STANTON' })
		self:assertEquals('starsystems?filter[name]=%s&include=celestialObjects&locale=en_EN', captured.config.endpoint)
		self:assertEquals('STANTON', apiData.starsystem.code)
		self:assertEquals(nil, apiData.celestialobject)
	end)
end

-- The wreck site shares the Anomaly token but is NOT a jump point: no
-- celestial fetch despite a code arg, and — typed, non-SolarSystem — no
-- starsystems fetch despite the declared kind. captured.key doubles as the
-- no-fetch-at-all sentinel for both branches.
function suite:testEnrichWreckSiteFetchesNothing()
	withStubbedFetch(celestialObjectFixture(), function(captured)
		local apiData = Location.enrich(
			{ type = { name = 'Anomaly' }, name = 'Stanton-Pyro Jump Point Wreck Site' },
			{ kind = 'Location', starmapcode = 'STANTON.JUMPPOINTS.PYRO' }
		)
		self:assertEquals(nil, captured.key)
		self:assertEquals(nil, apiData.celestialobject)
		self:assertEquals(nil, apiData.starsystem)
	end)
end

-- ── Editorial identity (the no-record lore systems) ────────────────────────
-- Seven systems exist only in lore: the starmap has no record, so affiliation
-- and system type arrive as editor args, exactly as the legacy {{System}}
-- template took them.

function suite:testSystemTypeEntryNormalizesLegacyCaseDrift()
	local f = Location.systemTypeEntry
	-- The live pages hand-set 'SINGLE_STAR', 'TRINARY' and 'Trinary'.
	for _, text in ipairs({ 'TRINARY', 'Trinary', 'trinary', ' Trinary ' }) do
		local code, entry = f(text)
		self:assertEquals('TRINARY', code)
		self:assertEquals('Trinary star system', entry.label)
	end
	self:assertEquals('SINGLE_STAR', (f('Single star')))
	self:assertEquals('SINGLE_STAR', (f('SINGLE_STAR')))
end

function suite:testSystemTypeEntryRejectsUnknownText()
	for _, text in ipairs({ 'Quaternary', '', nil, 42 }) do
		local code, entry = Location.systemTypeEntry(text)
		self:assertEquals(nil, code)
		self:assertEquals(nil, entry)
	end
end

-- The live tree's category is 'Trinary Star systems'; 'Trinary systems' does
-- not exist. Latent until GJ 667 / UDS-2943-01-22 migrated — no starmap-backed
-- system is trinary.
function suite:testTrinaryCategoryMatchesLiveTree()
	self:assertEquals('Trinary Star systems', Location.SYSTEM_TYPES.TRINARY.category)
end

function suite:testAffiliationFromTextMatchesCanonicalSpellings()
	-- Legacy arg spellings collapse into the canonical entries: matched on
	-- code, label or short after stripping case and punctuation.
	self:assertEquals("Xi'an Empire", Location.affiliationFromText("Xi'An").label)
	self:assertEquals('United Empire of Earth', Location.affiliationFromText('UEE').label)
	self:assertEquals('Banu Protectorate', Location.affiliationFromText('Banu Protectorate').label)
	self:assertEquals('Unclaimed', Location.affiliationFromText('Unclaimed').label)
	-- Canonical entries carry no display override: callers link the label.
	self:assertEquals(nil, Location.affiliationFromText('UEE').display)
end

function suite:testAffiliationFromTextFreeTextPassesThrough()
	-- The editor controls linking; label carries the delinked text for the
	-- category and the stored value.
	local krthak = Location.affiliationFromText("[[Kr'Thak]]")
	self:assertEquals("Kr'Thak", krthak.label)
	self:assertEquals("[[Kr'Thak]]", krthak.display)
	local unknown = Location.affiliationFromText('Unknown')
	self:assertEquals('Unknown', unknown.label)
	self:assertEquals('Unknown', unknown.display)
	self:assertEquals(nil, Location.affiliationFromText(''))
	self:assertEquals(nil, Location.affiliationFromText(nil))
end

function suite:testResolveSystemTypeEditorialBeatsRecord()
	local resolved = { systemtype = { value = 'Trinary', source = 'editorial' } }
	local code, entry = Location.resolveSystemType(starsystemFixture(), resolved)
	self:assertEquals('TRINARY', code)
	self:assertEquals('Trinary Star systems', entry.category)
end

function suite:testResolveSystemTypeKeepsUnmappedRecordCode()
	-- A future ARK code must still store faithfully: raw code, no entry.
	local record = starsystemFixture()
	record.type = 'BLACK_HOLE'
	local code, entry = Location.resolveSystemType(record, nil)
	self:assertEquals('BLACK_HOLE', code)
	self:assertEquals(nil, entry)
end

function suite:testResolveAffiliationEditorialBeatsRecord()
	local resolved = { affiliation = { value = 'Vanduul', source = 'editorial' } }
	self:assertEquals('Vanduul', Location.resolveAffiliation(starsystemFixture(), resolved).label)
	self:assertEquals('UEE', Location.resolveAffiliation(starsystemFixture(), nil).short)
end

function suite:testGetTypeInfoFromEditorialArgs()
	-- Type info runs before editorial resolution, so it reads the raw args;
	-- the legacy `type` arg name works as the alias.
	self:assertEquals('Trinary star system', StarSystem.getTypeInfo({}, { type = 'Trinary' }).name)
	self:assertEquals('Single star system', StarSystem.getTypeInfo({}, { systemtype = 'SINGLE_STAR' }).name)
	self:assertEquals('Star system', StarSystem.getTypeInfo({}, {}).name)
	self:assertEquals('Star system', StarSystem.getTypeInfo({}).name)
end

--- Drive the REAL manifest through Editorial.resolve: the integration seam a
--- hand-built `resolved` table would bypass (arg aliasing included).
--- @param args table
--- @return table resolved
local function resolveEditorially(args)
	return Editorial.resolve({}, args, Location.getEditorialManifest())
end

function suite:testNoRecordPageResolvesIdentityThroughManifest()
	local resolved = resolveEditorially({ type = 'TRINARY', affiliation = 'Unknown' })
	self:assertEquals('TRINARY', (Location.resolveSystemType(nil, resolved)))
	self:assertEquals('Unknown', Location.resolveAffiliation(nil, resolved).label)
end

function suite:testGetCategoriesFromEditorialIdentity()
	local resolved = resolveEditorially({ type = 'Trinary', affiliation = "[[Kr'Thak]]" })
	local categories = Location.getCategories({}, {}, resolved)
	self:assertEquals('Trinary Star systems', categories[1])
	self:assertEquals("Kr'Thak systems", categories[2])
end

function suite:testSectionsAffiliationRowFromEditorial()
	-- Free text renders exactly as written; canonical text renders linked.
	local general =
		findSection(StarSystem.getSections({}, {}, resolveEditorially({ affiliation = "[[Kr'Thak]]" })), 'general')
	self:assertEquals("[[Kr'Thak]]", findItem(general, 'Affiliation'))
	general = findSection(StarSystem.getSections({}, {}, resolveEditorially({ affiliation = "Xi'An" })), 'general')
	self:assertEquals("[[Xi'an Empire]]", findItem(general, 'Affiliation'))
end

function suite:testStructuredDataFromEditorialIdentityWithoutRecord()
	-- The early return without a record is gone: identity and counts store
	-- exactly like a record-backed page, with the free-text affiliation
	-- delinked for the store.
	local resolved = resolveEditorially({ type = 'Trinary', affiliation = "[[Kr'Thak]]", planets = '9' })
	local data = StarSystem.getStructuredData({}, {}, resolved)
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
	self:assertEquals('BLACK_HOLE', StarSystem.getStructuredData(apiData, {}, nil).system_type)
end

function suite:testStructuredDataStillEmptyWithNothingAtAll()
	self:assertEquals(nil, next(StarSystem.getStructuredData({}, {}, resolveEditorially({}))))
end

function suite:testShortDescriptionFromEditorialIdentity()
	-- Ophos shape: canonical affiliation + editorial type + 1 planet.
	local args = { type = 'SINGLE_STAR', affiliation = 'Banu Protectorate', planets = '1' }
	local resolved = resolveEditorially(args)
	local typeInfo = StarSystem.getTypeInfo({}, args)
	self:assertEquals(
		'Banu Protectorate single star system with 1 planet',
		StarSystem.getShortDescription({}, args, typeInfo, nil, resolved)
	)
end

function suite:testShortDescriptionSkipsFreeTextAffiliationPrefix()
	-- UDS shape: 'Unknown trinary star system' would say the wrong thing, so
	-- a free-text affiliation stays out of the prefix.
	local args = { type = 'Trinary', affiliation = 'Unknown' }
	self:assertEquals(
		'Trinary star system',
		StarSystem.getShortDescription({}, args, StarSystem.getTypeInfo({}, args), nil, resolveEditorially(args))
	)
end

-- ── JumpPoint leaf ─────────────────────────────────────────────────────────

local JumpPoint = require('Module:Entity/Location/JumpPoint')

--- The merged payload the leaf renders on the happy path: the location record
--- plus the celestial object Location.enrich attaches.
local function jumpPointApiData()
	local apiData = jumpPointFixture()
	apiData.celestialobject = celestialObjectFixture()
	return apiData
end

function suite:testJumpPointTypeInfo()
	local info = JumpPoint.getTypeInfo(jumpPointApiData(), {})
	self:assertEquals('Jump point', info.name)
	self:assertEquals('Jump points', info.category)
end

-- Promoted to the kind (Location.systemShortName): the kind's getCategories
-- needs it for the per-system gate category, and the kind cannot require the
-- leaf back (cycle), so the helpers live where both can reach them.
function suite:testJumpPointSystemShortName()
	local f = Location.systemShortName
	self:assertEquals('Pyro', f('Pyro System'))
	self:assertEquals('Terra', f('Terra system'))
	self:assertEquals('Nyx', f('Nyx'))
	self:assertEquals(nil, f(''))
	self:assertEquals(nil, f(' System'))
	self:assertEquals(nil, f(nil))
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
	local general = findSection(JumpPoint.getSections(apiData, {}, nil), 'general')
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
	local general = findSection(JumpPoint.getSections(apiData, {}, nil), 'general')
	self:assertEquals(nil, findItem(general, 'Size'))
end

-- Distance from star was removed from the infobox by design review (not
-- important for a gate); the celestial record still carries it, unused.
function suite:testJumpPointDistanceNotRendered()
	local general = findSection(JumpPoint.getSections(jumpPointApiData(), {}, nil), 'general')
	self:assertEquals(nil, findItem(general, 'Distance from star'))
end

function suite:testJumpPointTravelRows()
	local travel = findSection(JumpPoint.getSections(jumpPointApiData(), {}, nil), 'travel')
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
	local travel = findSection(JumpPoint.getSections(apiData, {}, nil), 'travel')
	self:assertStringContains('data%-state="no"', findItem(travel, 'Starmap'))
	self:assertEquals(nil, findItem(travel, 'Arrival radius'))
	apiData.hide_in_starmap = nil
	self:assertEquals(nil, findSection(JumpPoint.getSections(apiData, {}, nil), 'travel'))
end

-- One accessor feeds the Starmap button and the Metadata row: the fetched
-- record's code wins, the raw |starmapcode=/|code= arg (the kind's shared
-- starmapCodeArg, same alias order enrich fetches with) covers a soft-failed
-- fetch, and an empty record code falls through rather than blanking both.
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

function suite:testJumpPointFooterButton()
	local buttons = JumpPoint.getFooterButtons(jumpPointApiData(), {})
	self:assertEquals(1, #buttons)
	self:assertEquals('Starmap', buttons[1].label)
	self:assertEquals('https://robertsspaceindustries.com/starmap?location=PYRO.JUMPPOINTS.NYX', buttons[1].url)
	self:assertEquals('Sc-icon-galactapedia.svg', buttons[1].icon)
	self:assertEquals('t-button--branded t-button--starmap', buttons[1].class)
end

function suite:testJumpPointMetadataItems()
	local items = JumpPoint.getMetadataItems(jumpPointApiData(), {})
	self:assertEquals(1, #items)
	self:assertEquals('Starmap code', items[1].label)
	self:assertEquals('PYRO.JUMPPOINTS.NYX', items[1].content)
	-- The arg fallback feeds the row too (soft-failed fetch).
	local fromArg = JumpPoint.getMetadataItems(jumpPointFixture(), { code = 'NYX.JUMPPOINTS.PYRO' })
	self:assertEquals('NYX.JUMPPOINTS.PYRO', fromArg[1].content)
end

-- No usable code from record or args → neither button nor metadata row.
function suite:testJumpPointAbsentCodeYieldsNeitherButtonNorRow()
	self:assertEquals(0, #JumpPoint.getFooterButtons(jumpPointFixture(), {}))
	self:assertEquals(0, #JumpPoint.getMetadataItems(jumpPointFixture(), {}))
	local blankCode = jumpPointApiData()
	blankCode.celestialobject.code = ''
	self:assertEquals(0, #JumpPoint.getFooterButtons(blankCode, {}))
	self:assertEquals(0, #JumpPoint.getMetadataItems(blankCode, {}))
end

function suite:testJumpPointStructuredData()
	local data = JumpPoint.getStructuredData(jumpPointApiData(), {}, nil)
	self:assertEquals('Medium', data.jump_point_size)
	-- Page-name forms ('Pyro system'), so [[System::…]] resolves wiki pages.
	self:assertEquals('Pyro system', data.system)
	self:assertEquals('Nyx system', data.destination_system)
end

function suite:testJumpPointStructuredDataDegradesWithoutCelestialRecord()
	local data = JumpPoint.getStructuredData(jumpPointFixture(), {}, nil)
	self:assertEquals(nil, data.jump_point_size)
	-- The location record alone still carries the entry system.
	self:assertEquals('Pyro system', data.system)
	self:assertEquals(nil, data.destination_system)
end

function suite:testJumpPointLoreRowsThroughManifest()
	local resolved = resolveEditorially({ discoveredin = '[[2469]]', discoveredby = '[[Nick Croshaw]]' })
	local lore = findSection(JumpPoint.getSections(jumpPointApiData(), {}, resolved), 'lore')
	self:assertEquals('[[2469]]', findItem(lore, 'Discovered in'))
	self:assertEquals('[[Nick Croshaw]]', findItem(lore, 'Discovered by'))
end

-- Gate-directional, no trailing period; no size → unsized head; no resolvable
-- route → the catch-all (size or not: "Medium jump point" alone names no
-- route).
function suite:testJumpPointShortDescription()
	local typeInfo = JumpPoint.getTypeInfo()
	self:assertEquals(
		'Medium jump point from Pyro to Nyx',
		JumpPoint.getShortDescription(jumpPointApiData(), {}, typeInfo)
	)
	local unsized = jumpPointApiData()
	unsized.celestialobject.jumppoints = nil
	self:assertEquals('Jump point from Pyro to Nyx', JumpPoint.getShortDescription(unsized, {}, typeInfo))
	self:assertEquals('A jump point in Star Citizen', JumpPoint.getShortDescription(jumpPointFixture(), {}, typeInfo))
end

-- A gate files under its ENTRY system's category — functional membership:
-- {{System navplate}} builds its "Jump points" row from the per-system
-- category ∩ Jump points, so this is what keeps that row populated. The
-- star-system trees stay out, and the legacy flat 'Astronomical objects' /
-- 'Locations' memberships are deliberately not carried (the classification
-- bucket covers that taxonomy).
function suite:testJumpPointKindCategoriesEntrySystem()
	local categories = Location.getCategories(jumpPointApiData(), {}, nil)
	self:assertEquals('Pyro system', categories[1])
	self:assertEquals(1, #categories)
end

function suite:testJumpPointKindCategoriesEmptyWithoutEntry()
	local record = jumpPointApiData()
	record.system = nil
	record.celestialobject = nil -- no designation fallback either
	self:assertEquals(0, #Location.getCategories(record, {}, nil))
end

-- The record-less family page still files under its entry system: the
-- designation's first side carries it (the entry-first convention).
function suite:testJumpPointKindCategoriesFamilyFallback()
	local apiData = { celestialobject = { designation = 'Stanton - Nyx', jumppoints = { size = 'L' } } }
	local categories = Location.getCategories(apiData, { kind = 'Location', family = 'jumppoint' }, nil)
	self:assertEquals('Stanton system', categories[1])
	self:assertEquals(1, #categories)
end

function suite:testShortDescriptionNoTypeKeepsLegacyShape()
	-- Krell shape: affiliation but no type — the legacy "System with N
	-- planets" branch, unprefixed.
	local args = { affiliation = "[[Kr'Thak]]", planets = '9' }
	self:assertEquals(
		'System with 9 planets',
		StarSystem.getShortDescription({}, args, StarSystem.getTypeInfo({}, args), nil, resolveEditorially(args))
	)
end

return suite
