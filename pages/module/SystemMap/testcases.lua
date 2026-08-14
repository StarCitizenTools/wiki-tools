require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')

local suite = ScribuntoUnit:new()

local DATA = mw.loadJsonData('Module:SystemMap/systems.json')

-- ---------------------------------------------------------------------------
-- systems.json shape
-- ---------------------------------------------------------------------------

--- Walk every body in the file. `fn` receives (body, tier, systemKey).
--- Uses pairs/ipairs rather than # or next: on-wiki, mw.loadJsonData returns a
--- dataWrapper — a genuinely empty table carrying __index/__pairs/__ipairs — so
--- `#t` is 0 and `next(t)` is nil no matter what the JSON holds. mwInit patches
--- the `pairs` and `ipairs` globals to honour those metamethods; it does not
--- patch `next`. The only safe emptiness test on frozen data is `t[1] ~= nil`.
--- The off-wiki runner cannot reproduce this (its freeze() leaves the real
--- table populated), so a `next()`-based assertion here is a false pass.
--- Both stars are optional keys and are guarded rather than indexed blindly:
--- `companion` is absent for every single-star system, and `star` is absent for
--- the systems upstream files none for. Passing a nil body into `fn` would fail
--- every shape assertion below with a nil-index error rather than a verdict.
--- @param fn fun(body: table, tier: string, systemKey: string)
local function eachBody(fn)
	for key, system in pairs(DATA.systems) do
		if system.star then
			fn(system.star, 'star', key)
		end
		if system.companion then
			fn(system.companion, 'companion', key)
		end
		for _, body in ipairs(system.bodies) do
			fn(body, body.tier == 'belt' and 'belt' or 'planet', key)
			if body.moons then
				for _, moon in ipairs(body.moons) do
					-- A planet's `moons` array also carries its rings, marked
					-- `tier: ring`. They are reported as their own tier so that a
					-- caller counting moons does not count a ring as one.
					fn(moon, moon.tier == 'ring' and 'ring' or 'moon', key)
				end
			end
		end
	end
end

function suite:testEverySystemPresent()
	local keys = {
		'Stanton',
		'Pyro',
		'Nyx',
		'Terra',
		'Castra',
		'Sol',
		'Ellis',
		'Kilian',
		'Taranis',
		'Oberon',
		'Tyrol',
		"Kyuk'ya (Indra)",
		'Bacchus',
		'Baker',
		'Goss',
	}
	for _, key in ipairs(keys) do
		self:assertEquals('table', type(DATA.systems[key]), key)
	end
end

-- These move whenever a system is added, which is the point: systems.json is
-- generated now (scripts/cmd/systemmap), and a generator that quietly drops a
-- body would otherwise show up only as a gap on a rendered page.
function suite:testBodyCounts()
	local counts = { star = 0, companion = 0, planet = 0, belt = 0, moon = 0, ring = 0 }
	eachBody(function(_, tier)
		counts[tier] = counts[tier] + 1
	end)
	self:assertEquals(15, counts.star)
	self:assertEquals(5, counts.companion)
	self:assertEquals(84, counts.planet)
	self:assertEquals(47, counts.moon)
	self:assertEquals(16, counts.belt)
	self:assertEquals(6, counts.ring)
end

function suite:testEveryBodyHasPageAndLabel()
	eachBody(function(body, tier, key)
		local where = key .. '/' .. tier .. '/' .. tostring(body.page)
		self:assertEquals('string', type(body.page), where .. ' page')
		self:assertTrue(body.page ~= '', where .. ' page non-empty')
		self:assertEquals('string', type(body.label), where .. ' label')
		self:assertTrue(body.label ~= '', where .. ' label non-empty')
	end)
end

function suite:testPageTitlesAreUnique()
	local seen = {}
	eachBody(function(body)
		self:assertEquals(nil, seen[body.page], 'duplicate page: ' .. tostring(body.page))
		seen[body.page] = true
	end)
end

function suite:testEveryPlanetHasDesignationAndSubtype()
	for key, system in pairs(DATA.systems) do
		for _, body in ipairs(system.bodies) do
			self:assertEquals('string', type(body.designation), key .. '/' .. body.page .. ' designation')
			if body.tier == 'belt' then
				-- A belt deliberately carries no subtype, km or moons.
				self:assertEquals(nil, body.km, body.page .. ' should have no km')
				self:assertEquals(nil, body.moons, body.page .. ' should have no moons')
			else
				self:assertEquals('string', type(body.subtype), key .. '/' .. body.page .. ' subtype')
				self:assertEquals('table', type(body.moons), key .. '/' .. body.page .. ' moons')
				self:assertEquals('number', type(body.km), key .. '/' .. body.page .. ' km')
			end
		end
	end
end

-- A spectral class is OPTIONAL, and that is the contract rather than an
-- oversight. Variable, Subgiant and the fifteen stars upstream leaves
-- unclassified carry none, so the generator writes no `class` key at all and
-- Data.glyphKind falls back to the generic disc — pinned, in this same file, by
-- testGlyphKindStarWithoutAClassFallsBack. Requiring a class here asserted the
-- opposite of that, and would have turned the next rollout batch into a red
-- merge gate reading like a data fault: Nul is a Variable star with five
-- planets, all six pages live, and adding it to the overlay is a one-line edit.
--
-- What is still required is that a class, when written, is USABLE. An empty
-- string or a number reaches mw.ustring.lower and yields a kind — 'star-' or
-- 'star-5' — that no stylesheet rule matches, which is a silent neutral disc
-- rather than a deliberate one.
--
-- A companion is held to exactly the same contract, because it is the same kind
-- of thing: Data.glyphKind builds 'star-' .. lower(class) for both.
function suite:testEverySystemHasAStarWithAUsableClass()
	for key, system in pairs(DATA.systems) do
		self:assertEquals('string', type(system.page), key .. ' page')
		self:assertEquals('table', type(system.star), key .. ' star')
		for _, which in ipairs({ 'star', 'companion' }) do
			local star = system[which]
			if star and star.class ~= nil then
				self:assertEquals('string', type(star.class), key .. ' ' .. which .. ' class')
				self:assertTrue(star.class ~= '', key .. ' ' .. which .. ' class is non-empty')
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- systems.json: the second star
--
-- Five systems have two. The file says which arrangement each is in, because
-- upstream describes two different objects and the rail draws them differently:
-- a companion parented to the primary orbits it, and one that is not co-orbits
-- with it.
-- ---------------------------------------------------------------------------

--- The shape each binary in the file is expected to carry, and the primary that
--- goes with it. Derived from upstream's parent_id by the generator; pinned here
--- so a refetch that rearranges a system fails a test rather than a live page.
local BINARIES = {
	Tyrol = { star = 'Tyrol A', companion = 'Tyrol B', shape = 'nested' },
	["Kyuk'ya (Indra)"] = { star = "Kyuk'ya A", companion = "Kyuk'ya B", shape = 'nested' },
	Bacchus = { star = 'Bacchus A', companion = 'Bacchus B', shape = 'paired' },
	Baker = { star = 'Baker A', companion = 'Baker B', shape = 'paired' },
	Goss = { star = 'Goss A', companion = 'Goss B', shape = 'paired' },
}

function suite:testBinariesCarryTheirCompanionAndItsShape()
	local found = 0
	for key, system in pairs(DATA.systems) do
		local want = BINARIES[key]
		if want then
			found = found + 1
			self:assertEquals('table', type(system.companion), key .. ' companion')
			self:assertEquals(want.star, system.star.label, key .. ' primary')
			self:assertEquals(want.companion, system.companion.label, key .. ' companion label')
			self:assertEquals(want.shape, system.companionShape, key .. ' shape')
		else
			-- Absent, not empty. Every single-star system in the file has to be
			-- unchanged by the model gaining a second star, and this is the shape
			-- half of that promise; the byte-level half is the Go acceptance gate.
			self:assertEquals(nil, system.companion, key .. ' must carry no companion')
			self:assertEquals(nil, system.companionShape, key .. ' must carry no companion shape')
		end
	end
	self:assertEquals(5, found, 'the file holds the five binaries upstream has')
end

-- A companion is a star, and carries a star's keys and no others. In particular
-- no `tier` — the key it is filed under is what says what it is, exactly as
-- `star` does — and no `moons`, because nothing orbits a companion anywhere in
-- the dataset and the rail nests one level.
function suite:testACompanionIsShapedLikeAStar()
	for key, system in pairs(DATA.systems) do
		local companion = system.companion
		if companion then
			self:assertEquals('string', type(companion.page), key .. ' companion page')
			self:assertEquals('string', type(companion.label), key .. ' companion label')
			self:assertEquals('string', type(companion.subtype), key .. ' companion subtype')
			self:assertEquals('number', type(companion.km), key .. ' companion km')
			self:assertEquals(nil, companion.tier, key .. ' companion tier')
			self:assertEquals(nil, companion.moons, key .. ' companion moons')
			self:assertEquals(nil, companion.designation, key .. ' companion designation')
		end
	end
end

-- Editorial corrections applied to RSI's data. These assertions are the record:
-- if a reseed silently reverts one, the suite fails.

function suite:testPyroIVIsTheLastMoonOfPyroV()
	local pyroV
	for _, planet in ipairs(DATA.systems.Pyro.bodies) do
		if planet.page == 'Pyro V' then
			pyroV = planet
		end
	end
	self:assertEquals('table', type(pyroV))
	local last
	for _, moon in ipairs(pyroV.moons) do
		last = moon
	end
	-- Guard the indexing: if a reseed emptied the array, fail with a message
	-- rather than erroring on a nil index.
	self:assertEquals('table', type(last), 'Pyro V should still have moons')
	self:assertEquals('Pyro IV', last.page)
	self:assertEquals('Terrestrial rocky', last.subtype)
end

function suite:testDelamarSitsBetweenNyxIIAndNyxIII()
	local order = {}
	for _, planet in ipairs(DATA.systems.Nyx.bodies) do
		order[#order + 1] = planet.page
	end
	self:assertEquals('Nyx II', order[2])
	self:assertEquals('Glaciem Ring', order[3])
	self:assertEquals('Delamar', order[4])
	self:assertEquals('Nyx III', order[5])
	self:assertEquals('Keeger Belt', order[6])
end

-- t[1] rather than next(): `planet.moons` here is frozen data straight out of
-- mw.loadJsonData, where next() returns nil unconditionally on-wiki. This
-- assertion would pass for Pyro V and its seven moons if it used next().
function suite:testNyxPlanetsHaveNoMoons()
	for _, body in ipairs(DATA.systems.Nyx.bodies) do
		-- Belts carry no moons array at all; planets carry an empty one.
		if body.moons then
			self:assertEquals(nil, body.moons[1], body.page .. ' should have no moons')
		end
	end
end

-- Third editorial correction: keying on page titles means RSI's starmap codes
-- (with their upstream typos and stale IDs) never enter the schema. This test
-- ensures a reseed script cannot silently reintroduce a code/starmapId field.
function suite:testNoBodiesCarryStarmapCodes()
	eachBody(function(body, tier, key)
		local where = key .. '/' .. tier .. '/' .. tostring(body.page)
		self:assertEquals(nil, body.code, where .. ' should not have code field')
		self:assertEquals(nil, body.starmapCode, where .. ' should not have starmapCode field')
		self:assertEquals(nil, body.starmapId, where .. ' should not have starmapId field')
	end)
end

-- ---------------------------------------------------------------------------
-- Data: system-name resolution
-- ---------------------------------------------------------------------------

local Data = require('Module:SystemMap/Data')

function suite:testResolveKeyExact()
	self:assertEquals('Stanton', Data.resolveKey('Stanton'))
	self:assertEquals('Pyro', Data.resolveKey('Pyro'))
	self:assertEquals('Nyx', Data.resolveKey('Nyx'))
end

function suite:testResolveKeyIsCaseInsensitive()
	self:assertEquals('Stanton', Data.resolveKey('stanton'))
	self:assertEquals('Stanton', Data.resolveKey('STANTON'))
	self:assertEquals('Pyro', Data.resolveKey('pYrO'))
end

function suite:testResolveKeyStripsSystemSuffix()
	self:assertEquals('Stanton', Data.resolveKey('Stanton system'))
	self:assertEquals('Nyx', Data.resolveKey('nyx system'))
end

function suite:testResolveKeyTrimsWhitespace()
	self:assertEquals('Stanton', Data.resolveKey('  Stanton  '))
	self:assertEquals('Stanton', Data.resolveKey('\tStanton system\n'))
end

-- The unknown-system fixture has to be a name no system will ever have. It was
-- 'Terra', which stopped being unknown the moment Terra entered the file, and
-- took four tests down with it.
function suite:testResolveKeyUnknownReturnsNil()
	self:assertEquals(nil, Data.resolveKey('No Such Place'))
	self:assertEquals(nil, Data.resolveKey(''))
	self:assertEquals(nil, Data.resolveKey(nil))
	self:assertEquals(nil, Data.resolveKey('system'))
end

-- The key is upstream's name for the system, which is not always what the wiki
-- calls it and is never what an editor types. Upstream still carries a Perry Line
-- alias and names one system "Kyuk'ya (Indra)"; the article is "Kyuk'ya system"
-- and every other template on it is called {{... |Kyuk'ya}}. Without the article
-- name resolving, {{System map|Kyuk'ya}} lands in the unknown-system category and
-- renders nothing — a whole page's map missing, with only a tracking category to
-- say so.
function suite:testResolveKeyAcceptsTheArticleNameToo()
	self:assertEquals("Kyuk'ya (Indra)", Data.resolveKey("Kyuk'ya"))
	self:assertEquals("Kyuk'ya (Indra)", Data.resolveKey("Kyuk'ya system"))
	self:assertEquals("Kyuk'ya (Indra)", Data.resolveKey("kyuk'ya SYSTEM"))
	-- And the upstream key itself still works, so a call written before the
	-- article was checked keeps rendering.
	self:assertEquals("Kyuk'ya (Indra)", Data.resolveKey("Kyuk'ya (Indra)"))
	self:assertEquals("Kyuk'ya (Indra)", Data.resolveKey("Kyuk'ya (Indra) system"))
end

-- Every system in the file has to be reachable by the name of its own article,
-- because that is the name the template call on that article will use.
function suite:testEverySystemResolvesFromItsArticleName()
	for key, system in pairs(DATA.systems) do
		local article = system.page:gsub('%s+system$', '')
		self:assertEquals(key, Data.resolveKey(article), key .. ' from ' .. system.page)
		self:assertEquals(key, Data.resolveKey(system.page), key .. ' from its full page title')
	end
end

-- ---------------------------------------------------------------------------
-- Data: glyph classification
-- ---------------------------------------------------------------------------

-- The six kinds that existed before the full-rollout palette. Stanton, Pyro and
-- Nyx are live on 42 pages, so these six pairings are frozen: widening a bucket
-- may add subtypes to a kind, but must never move one of these to a different
-- kind, which would repaint a published page.
function suite:testGlyphKindPlanetSubtypes()
	self:assertEquals('super-earth', Data.glyphKind('planet', 'Super-Earth'))
	self:assertEquals('gas-giant', Data.glyphKind('planet', 'Gas giant'))
	self:assertEquals('ice-giant', Data.glyphKind('planet', 'Ice giant'))
	self:assertEquals('smog', Data.glyphKind('planet', 'Smog planet'))
	self:assertEquals('protoplanet', Data.glyphKind('planet', 'Protoplanet'))
	self:assertEquals('rocky', Data.glyphKind('planet', 'Terrestrial rocky'))
end

--- Every planet subtype upstream's starmap declares, in the sentence-case form
--- systems.json stores it. Upstream writes Title Case ('Gas Giant'); the
--- generator converts, keeping proper nouns intact ('Super-Earth', 'Super
--- Jupiter'), so the conversion is a mapping and not a lowercase() call.
---
--- This table is the contract between the generator and SUBTYPE_KIND. A
--- disagreement is silent — the body renders 'unknown' and looks like a
--- fallback — which is exactly why it is pinned by string here.
--- @type table<string, string>
local UPSTREAM_PLANET_SUBTYPES = {
	['Super-Earth'] = 'super-earth',

	['Gas giant'] = 'gas-giant',
	['Gas dwarf'] = 'gas-giant',
	['Super Jupiter'] = 'gas-giant',
	['Puffy planet'] = 'gas-giant',

	['Ice giant'] = 'ice-giant',
	['Smog planet'] = 'smog',
	['Protoplanet'] = 'protoplanet',

	['Terrestrial rocky'] = 'rocky',
	['Iron planet'] = 'rocky',
	['Carbon planet'] = 'rocky',
	['Coreless planet'] = 'rocky',
	['Desert planet'] = 'rocky',
	['Chthonian planet'] = 'rocky',

	['Lava planet'] = 'lava',
	['Ice planet'] = 'ice',
	['Ocean planet'] = 'ocean',

	['Dwarf planet'] = 'dwarf',
	['Mesoplanet'] = 'dwarf',

	['Artificial'] = 'exotic',
	['Rogue planet'] = 'exotic',
	['Evaporating planet'] = 'exotic',
}

-- Twenty-two subtypes, eleven kinds, across all 90 systems. The counts are
-- asserted so that dropping a key fails here rather than surfacing as one body
-- rendering neutral on a system nobody is looking at.
function suite:testEveryUpstreamPlanetSubtypeIsMapped()
	local subtypes, kinds = 0, {}
	for subtype, kind in pairs(UPSTREAM_PLANET_SUBTYPES) do
		self:assertEquals(kind, Data.glyphKind('planet', subtype), subtype)
		subtypes = subtypes + 1
		kinds[kind] = true
	end
	self:assertEquals(22, subtypes, 'the full upstream planet vocabulary')

	local distinct = 0
	for _ in pairs(kinds) do
		distinct = distinct + 1
	end
	self:assertEquals(11, distinct, 'grouped into eleven glyph kinds')
end

-- Widening gas-giant and rocky is only safe while no LIVE body carries one of
-- the added subtypes — widening a bucket a live body already fell into would
-- repaint it on 42 published pages. Scoped to the three in-game systems by name
-- on purpose: Castra I is a 'Coreless planet', so a file-wide assertion would
-- start failing the moment the pilot systems land, for no real reason.
function suite:testWidenedBucketsRepaintNothingLive()
	local added = {
		['Gas dwarf'] = true,
		['Super Jupiter'] = true,
		['Puffy planet'] = true,
		['Iron planet'] = true,
		['Carbon planet'] = true,
		['Coreless planet'] = true,
		['Desert planet'] = true,
		['Chthonian planet'] = true,
	}
	for _, key in ipairs({ 'Stanton', 'Pyro', 'Nyx' }) do
		for _, body in ipairs(DATA.systems[key].bodies) do
			self:assertEquals(nil, added[body.subtype], key .. '/' .. body.page .. ' predates the widened bucket')
			if body.moons then
				for _, moon in ipairs(body.moons) do
					self:assertEquals(
						nil,
						added[moon.subtype],
						key .. '/' .. moon.page .. ' predates the widened bucket'
					)
				end
			end
		end
	end
end

function suite:testGlyphKindUnknownSubtypeDegrades()
	self:assertEquals('unknown', Data.glyphKind('planet', 'Ringworld'))
	self:assertEquals('unknown', Data.glyphKind('planet', nil))
end

function suite:testGlyphKindStars()
	self:assertEquals('star-g', Data.glyphKind('star', 'G-type main sequence', 'G'))
	self:assertEquals('star-k', Data.glyphKind('star', 'K-type main sequence', 'K'))
	self:assertEquals('star-f', Data.glyphKind('star', 'F-type main sequence', 'F'))
	self:assertEquals('star', Data.glyphKind('star', 'Unclassified', nil))
end

-- The rest of the sequence, parsed out of upstream's 'Main Sequence-Dwarf-<X>'
-- by the generator. Giants-Giant-M lands on star-m too: the class letter is the
-- colour, and luminosity class is not something a 22-30px disc can show.
function suite:testGlyphKindRemainingSpectralClasses()
	self:assertEquals('star-o', Data.glyphKind('star', 'O-type main sequence', 'O'))
	self:assertEquals('star-b', Data.glyphKind('star', 'B-type main sequence', 'B'))
	self:assertEquals('star-a', Data.glyphKind('star', 'A-type main sequence', 'A'))
	self:assertEquals('star-m', Data.glyphKind('star', 'M-type main sequence', 'M'))
	self:assertEquals('star-m', Data.glyphKind('star', 'M-type giant', 'M'))
end

-- White Dwarf-Degenerate-A and Neutron carry no usable class letter upstream, so
-- systems.json stores the WORD as the class. 'star-' .. lower(class) then yields
-- star-degenerate / star-neutron with no branch in Data.lua at all. Pinned
-- because it is the one place a data convention stands in for code: change the
-- generator's spelling and the colour silently disappears.
function suite:testGlyphKindClasslessRemnantsUseAWordAsTheirClass()
	self:assertEquals('star-degenerate', Data.glyphKind('star', 'White dwarf', 'degenerate'))
	self:assertEquals('star-neutron', Data.glyphKind('star', 'Neutron star', 'neutron'))
end

-- Variable, Subgiant and the fifteen stars upstream leaves unclassified get no
-- class written at all, and fall back to the generic disc rather than each
-- earning a colour a reader could not predict anyway.
function suite:testGlyphKindStarWithoutAClassFallsBack()
	self:assertEquals('star', Data.glyphKind('star', 'Variable', nil))
	self:assertEquals('star', Data.glyphKind('star', 'Subgiant', nil))
	self:assertEquals('star', Data.glyphKind('star', nil, nil))
	self:assertEquals('star', Data.glyphKind('star', nil, ''))
end

function suite:testGlyphKindMoonsDefaultToMoonButHonourSubtype()
	self:assertEquals('moon', Data.glyphKind('moon', nil))
	self:assertEquals('rocky', Data.glyphKind('moon', 'Terrestrial rocky'))
end

-- Upstream labels all 74 satellites 'Planetary Moon'. It deliberately has NO
-- SUBTYPE_KIND entry — the moon tier's own fallback is already the right answer,
-- and a key would only duplicate it. This is why the table holds 22 subtypes and
-- not 23; it pins that the fallback still fires should the generator start
-- writing the subtype through.
function suite:testGlyphKindPlanetaryMoonSubtypeStillUsesTheMoonDisc()
	self:assertEquals('moon', Data.glyphKind('moon', 'Planetary moon'))
end

-- A belt short-circuits before the subtype lookup, so upstream's three belt
-- subtypes never need entries either.
function suite:testGlyphKindBeltIgnoresItsSubtype()
	self:assertEquals('belt', Data.glyphKind('belt', 'System belt'))
	self:assertEquals('belt', Data.glyphKind('belt', 'System cluster'))
	self:assertEquals('belt', Data.glyphKind('belt', nil))
end

-- A ring short-circuits for the same reason, and it MUST: it sits at the moon
-- tier, so anything that fell through would land on the moon disc and draw a
-- ring as one of the bodies beside it.
function suite:testGlyphKindRingIgnoresItsSubtypeAndNeverFallsBackToMoon()
	self:assertEquals('ring', Data.glyphKind('ring', 'Planetary ring'))
	self:assertEquals('ring', Data.glyphKind('ring', nil))
	-- Even handed a subtype that IS mapped, which is the fallthrough that would
	-- have painted it as a body.
	self:assertEquals('ring', Data.glyphKind('ring', 'Terrestrial rocky'))
end

function suite:testEverySubtypeInTheDataIsRecognised()
	for _, system in pairs(DATA.systems) do
		for _, body in ipairs(system.bodies) do
			if body.tier ~= 'belt' then
				self:assertTrue(
					Data.glyphKind('planet', body.subtype) ~= 'unknown',
					'unmapped planet subtype: ' .. tostring(body.subtype)
				)
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Data: model building
-- ---------------------------------------------------------------------------

function suite:testBuildModelUnknownSystemReturnsNil()
	self:assertEquals(nil, Data.buildModel('No Such Place', 'Whatever'))
	self:assertEquals(nil, Data.buildModel(nil, 'Whatever'))
end

function suite:testBuildModelHeader()
	local model = Data.buildModel('Stanton', 'Cellin')
	self:assertEquals('Stanton', model.key)
	self:assertEquals('Stanton system', model.page)
end

function suite:testBuildModelPreservesPlanetOrder()
	local model = Data.buildModel('Stanton', '')
	local order = {}
	for _, planet in ipairs(model.bodies) do
		order[#order + 1] = planet.label
	end
	self:assertEquals('Hurston', order[1])
	self:assertEquals('Crusader', order[2])
	self:assertEquals('Aaron Halo', order[3])
	self:assertEquals('ArcCorp', order[4])
	self:assertEquals('microTech', order[5])
end

function suite:testBuildModelPreservesMoonOrder()
	local model = Data.buildModel('Pyro', '')
	local pyroV
	for _, planet in ipairs(model.bodies) do
		if planet.page == 'Pyro V' then
			pyroV = planet
		end
	end
	local order = {}
	for _, moon in ipairs(pyroV.moons) do
		order[#order + 1] = moon.label
	end
	self:assertEquals('Ignis', order[1])
	self:assertEquals('Vuur', order[6])
	self:assertEquals('Pyro IV', order[7])
end

function suite:testBuildModelAttachesGlyphKinds()
	local model = Data.buildModel('Stanton', '')
	self:assertEquals('star-g', model.star.kind)
	self:assertEquals('super-earth', model.bodies[1].kind)
	self:assertEquals('gas-giant', model.bodies[2].kind)
	self:assertEquals('moon', model.bodies[2].moons[1].kind)
end

function suite:testBuildModelPyroIVKeepsRockyKindAtMoonTier()
	local model = Data.buildModel('Pyro', '')
	local pyroV
	for _, planet in ipairs(model.bodies) do
		if planet.page == 'Pyro V' then
			pyroV = planet
		end
	end
	local pyroIV = pyroV.moons[7]
	self:assertEquals('Pyro IV', pyroIV.label)
	self:assertEquals('rocky', pyroIV.kind)
	self:assertEquals('moon', pyroIV.tier)
end

--- Count bodies flagged current, and return the count plus the last one seen.
--- @param model table
--- @return number, table|nil
local function countCurrent(model)
	local n, found = 0, nil
	local function check(body)
		if body.current then
			n = n + 1
			found = body
		end
	end
	check(model.star)
	for _, planet in ipairs(model.bodies) do
		check(planet)
		for _, moon in ipairs(planet.moons) do
			check(moon)
		end
	end
	return n, found
end

function suite:testBuildModelMarksCurrentMoon()
	local n, body = countCurrent(Data.buildModel('Stanton', 'Cellin'))
	self:assertEquals(1, n)
	self:assertEquals('Cellin', body.label)
end

function suite:testBuildModelMarksCurrentPlanetWithDisambiguatedTitle()
	local n, body = countCurrent(Data.buildModel('Stanton', 'MicroTech (planet)'))
	self:assertEquals(1, n)
	self:assertEquals('microTech', body.label)
end

function suite:testBuildModelMarksCurrentStar()
	local n, body = countCurrent(Data.buildModel('Stanton', 'Stanton (star)'))
	self:assertEquals(1, n)
	self:assertEquals('Stanton', body.label)
end

function suite:testBuildModelMarksNothingOnASystemArticle()
	local n = countCurrent(Data.buildModel('Stanton', 'Stanton system'))
	self:assertEquals(0, n)
end

function suite:testBuildModelMarksNothingForUnrelatedTitle()
	local n = countCurrent(Data.buildModel('Stanton', 'Comm Array ST1-02'))
	self:assertEquals(0, n)
end

-- These moon lists are built locally by Data.buildModel, not frozen, so next()
-- would be correct here — t[1] is used anyway so the safe idiom is the one on
-- show for anyone copying an emptiness test out of this file.
function suite:testBuildModelNyxPlanetsHaveEmptyMoonLists()
	local model = Data.buildModel('Nyx', '')
	for _, planet in ipairs(model.bodies) do
		self:assertEquals(nil, planet.moons[1], planet.label .. ' should have no moons')
	end
end

-- ---------------------------------------------------------------------------
-- Renderer: markup contract
--
-- Not a look-and-feel test — appearance is verified in a browser against a
-- sandbox deploy. These assertions pin the things the MediaWiki sanitizer and
-- assistive technology depend on, which HTML inspection genuinely can prove.
-- ---------------------------------------------------------------------------

local Renderer = require('Module:SystemMap/Renderer')

--- Compose the two renderer entry points exactly as Module:SystemMap does.
--- Renderer's whole output is the rail: the card frame, header and chevron
--- come from Module:CollapsibleCard, so there is nothing here to compose.
--- @param model SystemMapModel
--- @return string
local function renderModel(model)
	return tostring(Renderer.renderRail(model))
end

local function renderStanton(currentTitle)
	return renderModel(Data.buildModel('Stanton', currentTitle or ''))
end

function suite:testRenderEmitsNoSanitizerRejectedTags()
	local html = renderStanton()
	for _, tag in ipairs({ 'section', 'nav', 'figure', 'header', 'footer', 'article', 'aside', 'main' }) do
		self:assertEquals(nil, html:find('<' .. tag .. '[%s>]'), 'must not emit <' .. tag .. '>')
	end
	for level = 1, 6 do
		self:assertEquals(nil, html:find('<h' .. level .. '[%s>]'), 'must not emit <h' .. level .. '>')
	end
end

function suite:testRenderHasRailAndScrollContainer()
	local html = renderStanton()
	self:assertTrue(html:find('t%-system%-map__scroll') ~= nil, 'needs the overflow-x container')
	self:assertTrue(html:find('t%-system%-map__rail') ~= nil, 'needs the rail')
end

function suite:testRenderEmitsWikitextLinks()
	local html = renderStanton()
	self:assertTrue(html:find('%[%[Cellin|Cellin%]%]') ~= nil, 'moon link')
	self:assertTrue(html:find('%[%[MicroTech %(planet%)|microTech%]%]') ~= nil, 'disambiguated planet link')
end

-- data-current, not aria-current: MediaWiki's sanitizer allowlist does not
-- include aria-current and strips it from the output, so a CSS hook keyed on it
-- can never match. This suite runs upstream of that sanitizer, so an
-- aria-current assertion here passed for weeks while the highlight was dead on
-- the live wiki. Verified against the live parser: aria-label and aria-level
-- survive, aria-current does not.
function suite:testRenderMarksExactlyOneCurrent()
	local html = renderStanton('Cellin')
	local count = select(2, html:gsub('data%-current="page"', ''))
	self:assertEquals(1, count)
end

function suite:testRenderMarksNoCurrentOnSystemArticle()
	local html = renderStanton('Stanton system')
	self:assertEquals(nil, html:find('data%-current'))
end

function suite:testRenderEmitsDataKind()
	local html = renderStanton()
	self:assertTrue(html:find('data%-kind="star%-g"') ~= nil)
	self:assertTrue(html:find('data%-kind="gas%-giant"') ~= nil)
	self:assertTrue(html:find('data%-kind="moon"') ~= nil)
end

function suite:testRenderOmitsMoonListWhenPlanetHasNoMoons()
	local html = renderModel(Data.buildModel('Nyx', ''))
	self:assertEquals(nil, html:find('t%-system%-map__moons'), 'Nyx has no moons anywhere')
end

function suite:testRenderMarksMissingBodies()
	local model = Data.buildModel('Stanton', '')
	model.bodies[1].missing = true
	local html = renderModel(model)
	self:assertTrue(html:find('t%-system%-map__item%-%-missing') ~= nil)
end

-- The moon-column connector is drawn from this modifier class because the :has
-- pseudo-class is not in TemplateStyles' allowlist — an unrecognised selector
-- makes the stylesheet save fail outright, so the structural selector is not an
-- option to fall back to.
function suite:testRenderFlagsPlanetsThatHaveMoons()
	local model = Data.buildModel('Stanton', '')
	local html = renderModel(model)
	-- Stanton's four planets all have moons; the star has none.
	local count = select(2, html:gsub('t%-system%-map__item%-%-has%-moons', ''))
	self:assertEquals(4, count, 'every Stanton planet carries the has-moons modifier')

	-- And it lands on the planet <li>, not somewhere incidental.
	self:assertTrue(
		html:find('t%-system%-map__item t%-system%-map__item%-%-planet t%-system%-map__item%-%-has%-moons') ~= nil,
		'the modifier sits on the planet item itself'
	)
end

function suite:testRenderOmitsHasMoonsModifierWhenPlanetHasNoMoons()
	local html = renderModel(Data.buildModel('Nyx', ''))
	self:assertEquals(
		nil,
		html:find('t%-system%-map__item%-%-has%-moons'),
		'no Nyx planet has moons, so none may carry the modifier'
	)
end

function suite:testRenderNestsMoonsInsideTheirPlanet()
	-- Crusader's <li> must contain Cellin; Hurston's must not. Ordering alone is
	-- not enough — a flattened rail with every moon emitted between Crusader and
	-- ArcCorp would satisfy it — so this also pins the <ul> that does the
	-- nesting to the window between the two planet links.
	local html = renderStanton()
	local crusaderAt = html:find('%[%[Crusader|Crusader%]%]')
	local arcCorpAt = html:find('%[%[ArcCorp %(planet%)|ArcCorp%]%]')
	local cellinAt = html:find('%[%[Cellin|Cellin%]%]')
	self:assertTrue(crusaderAt ~= nil and arcCorpAt ~= nil and cellinAt ~= nil)
	self:assertTrue(cellinAt > crusaderAt, 'Cellin renders after Crusader')
	self:assertTrue(cellinAt < arcCorpAt, 'Cellin renders before the next planet')

	local moonsAt = html:find('<ul class="t%-system%-map__moons"', crusaderAt)
	self:assertTrue(moonsAt ~= nil, 'a moon list opens after Crusader')
	self:assertTrue(moonsAt < arcCorpAt, "the moon list opens inside Crusader's item, before ArcCorp")
	self:assertTrue(cellinAt > moonsAt, 'Cellin sits inside that moon list, not loose on the rail')
end

-- ---------------------------------------------------------------------------
-- Renderer: renderHeader / renderRail split
--
-- Renderer emits only the rail; Module:CollapsibleCard supplies the shell.
-- ---------------------------------------------------------------------------

function suite:testRenderRailContainsScrollAndBodies()
	local model = Data.buildModel('Stanton', '')
	local html = tostring(Renderer.renderRail(model))
	self:assertTrue(html:find('t%-system%-map__rail') ~= nil)
	self:assertTrue(html:find('%[%[Cellin|Cellin%]%]') ~= nil, 'moon link present in rail body')
end

-- ---------------------------------------------------------------------------
-- Entry point
--
-- Module:Details is stubbed by the runner with an echoing stand-in mirroring
-- its real contract (<details>/<summary>, `open` serialised as 'yes'/'no'), so
-- the wrapped markup IS observable here — an inert stub would have made every
-- assertion below about the rail, the summary and the collapse flag vacuous.
-- Only the visual result of [open] is left to the browser.
-- ---------------------------------------------------------------------------

local SystemMap = require('Module:SystemMap')

-- The 5th argument is the main-namespace flag: tracking categories exist to
-- flag ARTICLE problems, so they are suppressed elsewhere.
function suite:testMainUnknownSystemEmitsTrackingCategoryOnly()
	local out = SystemMap.render('No Such Place', 'Whatever', nil, nil, true)
	self:assertEquals('[[Category:System map with unknown system]]', out)
end

-- A sandbox or module subpage with a bad call should not pollute a category
-- documented as "should normally be empty" -- once it permanently holds
-- non-articles, editors learn to ignore it.
function suite:testTrackingCategoriesAreSuppressedOutsideMainNamespace()
	self:assertEquals('', SystemMap.render('No Such Place', 'Whatever', nil, nil, false))
	local html = SystemMap.render('Stanton', '', function()
		return false
	end, nil, false)
	self:assertEquals(nil, html:find('Category:Pages with a broken system map link'))
end

function suite:testMainMissingArgumentIsTreatedAsUnknown()
	self:assertEquals('[[Category:System map with unknown system]]', SystemMap.render(nil, 'Whatever', nil, nil, true))
	self:assertEquals('[[Category:System map with unknown system]]', SystemMap.render('', 'Whatever', nil, nil, true))
end

function suite:testAnnotateExistenceFlagsMissingBodies()
	local model = Data.buildModel('Stanton', '')
	-- Two missing bodies under two different planets, so the assertion on
	-- `category` below actually exercises "emitted exactly once even when
	-- several bodies are missing" rather than being true merely because only
	-- one body was ever flagged.
	local exists = function(page)
		return page ~= 'Ita' and page ~= 'Cellin'
	end
	local category = SystemMap.annotateExistence(model, exists)

	local ita, cellin
	for _, moon in ipairs(model.bodies[1].moons) do
		if moon.page == 'Ita' then
			ita = moon
		end
	end
	for _, moon in ipairs(model.bodies[2].moons) do
		if moon.page == 'Cellin' then
			cellin = moon
		end
	end
	self:assertTrue(ita.missing, 'Ita should be flagged missing')
	self:assertTrue(cellin.missing, 'Cellin should be flagged missing')
	self:assertEquals(false, model.bodies[1].missing, 'Hurston should not be flagged')
	self:assertEquals(false, model.bodies[2].missing, 'Crusader should not be flagged')
	self:assertEquals('[[Category:Pages with a broken system map link]]', category)
end

-- The header links the system article too, so a move of THAT page has to trip
-- the category. There is no body to flag for it, only the category.
function suite:testAnnotateExistenceFlagsAMovedSystemArticle()
	local model = Data.buildModel('Stanton', '')
	local category = SystemMap.annotateExistence(model, function(page)
		return page ~= 'Stanton system'
	end)
	self:assertEquals('[[Category:Pages with a broken system map link]]', category)
	self:assertEquals(false, model.star.missing, 'no body should be flagged')
end

function suite:testAnnotateExistenceProbesTheSystemArticleOnce()
	local model = Data.buildModel('Stanton', '')
	local seen = {}
	SystemMap.annotateExistence(model, function(page)
		seen[page] = (seen[page] or 0) + 1
		return true
	end)
	self:assertEquals(1, seen['Stanton system'], 'system article probed exactly once')
	-- 1 star + 4 planets + 1 belt + 12 moons + the system article. This is the
	-- number the expensive-parser-function budget note in SystemMap.lua reasons
	-- about, so the two must move together.
	local total = 0
	for _, n in pairs(seen) do
		total = total + n
	end
	self:assertEquals(19, total, 'Stanton costs 19 probes')
end

-- Sol is the worst case in the file, and the reason the budget note is worth
-- keeping honest: 1 star + 9 planets + 2 belts + 19 moons + 4 rings + the system
-- article. Rings are probed like anything else — they link to articles, and a
-- moved one should still trip the tracking category — so they count against the
-- expensive-parser-function limit too.
function suite:testAnnotateExistenceCostsMostOnSol()
	local model = Data.buildModel('Sol', '')
	local total = 0
	SystemMap.annotateExistence(model, function()
		total = total + 1
		return true
	end)
	self:assertEquals(36, total, 'Sol is the worst case at 36 probes, against a measured limit of 100')
end

function suite:testAnnotateExistenceReturnsEmptyWhenAllPagesExist()
	local model = Data.buildModel('Stanton', '')
	local category = SystemMap.annotateExistence(model, function()
		return true
	end)
	self:assertEquals('', category)
end

-- p.render's happy path (a valid system, no `exists` probe) is otherwise
-- uncovered: every other test hits the unknown-system early return or calls
-- annotateExistence directly. Module:CollapsibleCard puts our `class` on the
-- card root, which is what scopes any map-specific card styling.
function suite:testRenderPassesItsClassToTheCard()
	local html = SystemMap.render('Stanton', '')
	self:assertTrue(type(html) == 'string' and html ~= '', 'render should return non-empty wikitext')
	-- Anchored to the card root's class attribute, not a bare substring: every
	-- rail element below is also prefixed `t-system-map`, so a loose find() would
	-- still match after the class stopped being passed to the card at all.
	self:assertTrue(
		html:find('class="t%-card t%-collapsible%-card t%-system%-map"') ~= nil,
		'the map class lands on the card root alongside the shell classes'
	)
end

-- The collapsible wrapper actually carries the map. Without these, replacing
-- the rail with '' or dropping the summary would still leave the suite green.
function suite:testRenderWrapsTheRailInTheCollapsibleBody()
	local html = SystemMap.render('Stanton', '')
	self:assertTrue(html:find('t%-collapsible%-card__body') ~= nil, 'card supplies the details body')
	self:assertTrue(html:find('t%-system%-map__rail') ~= nil, 'the rail survives into the wrapped output')
	self:assertTrue(html:find('%[%[Cellin|Cellin%]%]') ~= nil, 'body links survive into the wrapped output')
end

function suite:testRenderPutsTheBodyCountInTheCardDescription()
	local html = SystemMap.render('Stanton', '')
	self:assertTrue(html:find('4 planets, 12 moons') ~= nil, 'header describes the system by its contents')
	self:assertEquals(nil, html:find('System map'), 'and not by a label restating the obvious')
end

function suite:testRenderPutsTheSystemTitleInTheCardHeader()
	local html = SystemMap.render('Stanton', '')
	local headerAt = html:find('t%-collapsible%-card__header')
	local titleAt = html:find('%[%[Stanton system|Stanton system%]%]')
	local railAt = html:find('t%-system%-map__rail')
	self:assertTrue(headerAt ~= nil, 'card header present')
	self:assertTrue(titleAt ~= nil and titleAt > headerAt, 'system title renders in the header')
	self:assertTrue(railAt ~= nil and railAt > titleAt, 'and the rail follows it as the body')
end

-- Subtype drives the glyph colour but is deliberately not printed as text.
function suite:testRenderDoesNotPrintSubtypeText()
	local html = SystemMap.render('Stanton', '')
	self:assertEquals(nil, html:find('t%-system%-map__subtype'), 'no subtype row is emitted')
	self:assertEquals(nil, html:find('Super%-Earth'), 'subtype text stays out of the render')
	self:assertTrue(html:find('data%-kind="super%-earth"') ~= nil, 'but still drives the glyph kind')
end

-- Extension:Details needs the string 'yes'/'no', not a boolean.
function suite:testRenderDefaultsToOpen()
	local html = SystemMap.render('Stanton', '')
	self:assertTrue(html:find('open="yes"') ~= nil, 'default render is expanded')
end

function suite:testRenderCollapsedEmitsOpenNo()
	local html = SystemMap.render('Stanton', '', nil, true)
	self:assertTrue(html:find('open="no"') ~= nil, 'collapsed=true renders closed')
	self:assertEquals(nil, html:find('open="yes"'), 'and not also open')
	self:assertTrue(html:find('t%-system%-map__rail') ~= nil, 'the rail is still present, just closed')
end

function suite:testRenderOmitsDesignationWhenItRepeatsTheName()
	-- Pyro I / Nyx III / Delamar are titled by their designation, so printing
	-- both would render the same string twice.
	local html = tostring(Renderer.renderRail(Data.buildModel('Nyx', '')))
	-- Every Nyx PLANET is titled by its designation, so none prints one. The two
	-- belts have distinct formal designations and correctly keep theirs.
	local desigs = select(2, html:gsub('t%-system%-map__desig', ''))
	self:assertEquals(2, desigs, 'only the two belts carry a designation line')
	-- Lower case after the system name is house style, applied by the generator
	-- rather than stored as a correction. Asserted in the RENDERED output, which
	-- is where a reader meets it.
	self:assertTrue(html:find('Nyx belt alpha') ~= nil, 'Glaciem Ring keeps its designation')
	self:assertEquals(nil, html:find('Nyx Belt Alpha'), 'and it is not title-cased')
	self:assertEquals(
		nil,
		html:find('Nyx III</a></span><span class="t%-system%-map__desig'),
		'no planet repeats its own name'
	)
end

function suite:testRenderKeepsDesignationWhenItDiffersFromTheName()
	local html = tostring(Renderer.renderRail(Data.buildModel('Stanton', '')))
	self:assertTrue(html:find('t%-system%-map__desig') ~= nil, 'Stanton bodies have distinct designations')
	self:assertTrue(html:find('Stanton II') ~= nil, 'Crusader keeps its Stanton II designation')
end

--- Build a one-belt rail without going through systems.json, so a shape the file
--- does not yet contain can still be rendered.
--- @param belt table
--- @return string
local function renderBeltRail(belt)
	return tostring(Renderer.renderRail({
		star = { page = 'X (star)', label = 'X', tier = 'star', kind = 'star-k', disc = 26 },
		bodies = { belt },
	}))
end

-- Upstream names only some belts, and the generator sentence-cases an unnamed
-- one's label and page along with its designation, so generated input usually
-- has all three agreeing exactly. (Not always: a designation whose remainder
-- starts with a digit loses its system prefix, so "Taranis 2a Debris" is
-- labelled "Taranis 2a debris" against designation "2a debris".) This covers
-- the other input that survives that: a
-- HAND-AUTHORED overlay `label`, which is judgement and is stored verbatim — the
-- escape hatch for a belt whose article really is titled in Title Case. An exact
-- compare would then stack "Branaugh belt alpha" under "Branaugh Belt Alpha".
--
-- Synthetic, and it has to be: the generator cannot produce this pairing any
-- more, which is the point. The renderer takes no data dependency and must be
-- right for any model handed to it, not only for what today's generator emits.
function suite:testRenderOmitsDesignationWhenItRepeatsTheNameInAnotherCase()
	local html = renderBeltRail({
		page = 'Branaugh Belt Alpha',
		label = 'Branaugh Belt Alpha',
		designation = 'Branaugh belt alpha',
		tier = 'belt',
		kind = 'belt',
		disc = 10,
	})
	self:assertTrue(html:find('%[%[Branaugh Belt Alpha|Branaugh Belt Alpha%]%]') ~= nil, 'the belt still links')
	self:assertEquals(nil, html:find('t%-system%-map__desig'), 'and does not echo its own name in lower case')
end

-- The generated shape, now that label, page and designation agree exactly for an
-- unnamed belt: the same suppression, reached by the exact-compare path.
function suite:testRenderOmitsDesignationWhenItIsTheLabel()
	local html = renderBeltRail({
		page = 'Branaugh belt alpha',
		label = 'Branaugh belt alpha',
		designation = 'Branaugh belt alpha',
		tier = 'belt',
		kind = 'belt',
		disc = 10,
	})
	self:assertTrue(html:find('%[%[Branaugh belt alpha|Branaugh belt alpha%]%]') ~= nil, 'the belt still links')
	self:assertEquals(nil, html:find('t%-system%-map__desig'), 'and does not print its own name twice')
end

-- The other half of the same rule: this suppresses a DUPLICATE, not every belt
-- designation. A belt upstream did name keeps both lines, because the two say
-- different things.
function suite:testRenderKeepsABeltDesignationThatIsNotJustTheNameRecased()
	local html = renderBeltRail({
		page = 'Aaron Halo',
		label = 'Aaron Halo',
		designation = 'Stanton belt alpha',
		tier = 'belt',
		kind = 'belt',
		disc = 10,
	})
	self:assertTrue(html:find('t%-system%-map__desig') ~= nil, 'a designation that adds something is printed')
	self:assertTrue(html:find('Stanton belt alpha') ~= nil, 'and reads as house style intends')
end

-- ---------------------------------------------------------------------------
-- Data: body-count summary (the card header's description line)
-- ---------------------------------------------------------------------------

function suite:testSummariseCountsPlanetsAndMoons()
	self:assertEquals('4 planets, 12 moons, 1 belt', Data.summarise(Data.buildModel('Stanton', '')))
	self:assertEquals('5 planets, 7 moons, 1 belt', Data.summarise(Data.buildModel('Pyro', '')))
end

-- Nyx has no moons at all; the clause is dropped rather than reading "0 moons".
function suite:testSummariseOmitsMoonsWhenThereAreNone()
	self:assertEquals('4 planets, 2 belts', Data.summarise(Data.buildModel('Nyx', '')))
end

function suite:testSummarisePluralisesSingletons()
	local model = { bodies = { { moons = {} } } }
	self:assertEquals('1 planet', Data.summarise(model))
	model.bodies[1].moons = { {} }
	self:assertEquals('1 planet, 1 moon', Data.summarise(model))
	model.bodies[2] = { tier = 'belt', moons = {} }
	self:assertEquals('1 planet, 1 moon, 1 belt', Data.summarise(model))
end

-- The star is deliberately uncounted: there is exactly one per system.
function suite:testSummariseDoesNotCountTheStar()
	self:assertEquals(nil, Data.summarise(Data.buildModel('Stanton', '')):find('star'))
end

-- ---------------------------------------------------------------------------
-- Data: disc sizing (log-scaled within each tier)
-- ---------------------------------------------------------------------------

function suite:testDiscSizeAnchorsBothEndsOfTheTier()
	-- The anchors are the RECORDED extents, which span all 90 upstream systems,
	-- not the largest and smallest body this file happens to hold.
	self:assertEquals(24, Data.discSize('planet', DATA.extents.planet.max))
	self:assertEquals(6, Data.discSize('planet', DATA.extents.planet.min))
	self:assertEquals(30, Data.discSize('star', DATA.extents.star.max))
	self:assertEquals(14, Data.discSize('moon', DATA.extents.moon.max))
end

function suite:testDiscSizePreservesOrdering()
	local a = Data.discSize('planet', 2850)
	local b = Data.discSize('planet', 11853)
	local c = Data.discSize('planet', 74500)
	self:assertTrue(a < b, 'Terminus smaller than Hurston')
	self:assertTrue(b < c, 'Hurston smaller than Crusader')
end

-- Log is rank-preserving, NOT proportional. If this ever starts asserting a
-- ratio close to the real 6.6x, someone has switched it to a linear map and the
-- smallest planet has become invisible.
function suite:testDiscSizeIsCompressedNotProportional()
	local hurston = Data.discSize('planet', 11853)
	local pyroV = Data.discSize('planet', 78123)
	self:assertTrue(pyroV / hurston < 2, 'rendered ratio stays well under the true 6.6x')
end

-- Each tier is anchored to its own extremes and given its own px band, so the
-- same diameter renders differently depending on which tier it sits in. 3214 km
-- is the moon tier's ceiling (14px) but only mid-range for planets (14.7px).
function suite:testDiscSizeScalesEachTierIndependently()
	local asMoon = Data.discSize('moon', 3214)
	local asPlanet = Data.discSize('planet', 3214)
	self:assertTrue(asMoon ~= asPlanet, 'same diameter, different tier, different size')
	self:assertEquals(14, asMoon, 'tops out the moon tier')
end

-- An unsized body falls to its tier's FLOOR, not its ceiling.
--
-- It used to return the ceiling, and that was actively misleading: Lanisto is
-- the only body in the file upstream gives no size for, and at the moon maximum
-- it drew 14.0px against the 13.3px of Tyrol I, the planet it orbits. A moon
-- rendered larger than its own planet asserts something the data never said.
-- The floor cannot exceed a sized sibling, so the worst it can do is understate.
function suite:testDiscSizeFallsBackToTheFloorWhenSizeIsMissing()
	self:assertEquals(6, Data.discSize('planet', nil))
	self:assertEquals(6, Data.discSize('planet', 0))
	self:assertEquals(6, Data.discSize('planet', -5))
	-- Each tier has its own floor, and an unsized body takes the one for the
	-- tier it is measured against — a companion star is measured as a star.
	self:assertEquals(6, Data.discSize('moon', nil), 'moon floor')
	self:assertEquals(22, Data.discSize('star', nil), 'star floor')
	self:assertEquals(22, Data.discSize('companion', nil), 'companion measures as a star')
end

function suite:testEveryBodyInTheModelCarriesADiscSize()
	for _, key in ipairs({ 'Stanton', 'Pyro', 'Nyx' }) do
		local model = Data.buildModel(key, '')
		self:assertTrue(model.star.disc > 0, key .. ' star')
		for _, planet in ipairs(model.bodies) do
			self:assertTrue(planet.disc > 0, planet.label)
			for _, moon in ipairs(planet.moons) do
				self:assertTrue(moon.disc > 0, moon.label)
			end
		end
	end
end

-- Pyro IV is far larger than any true moon, and the moon tier's extents must
-- reflect that rather than clipping it.
function suite:testPyroIVRendersAsTheLargestMoon()
	local model = Data.buildModel('Pyro', '')
	local pyroV
	for _, planet in ipairs(model.bodies) do
		if planet.page == 'Pyro V' then
			pyroV = planet
		end
	end
	local biggest, name = 0, nil
	for _, moon in ipairs(pyroV.moons) do
		if moon.disc > biggest then
			biggest, name = moon.disc, moon.label
		end
	end
	self:assertEquals('Pyro IV', name)
end

function suite:testRenderEmitsAnInlineDiscSize()
	local html = tostring(Renderer.renderRail(Data.buildModel('Stanton', '')))
	self:assertTrue(html:find('t%-system%-map__disc') ~= nil, 'disc is a real element')
	self:assertTrue(html:find('width:%d') ~= nil, 'carries an inline diameter')
end

-- Extents are shared across the file, not recomputed per system, so Stanton's
-- own largest planet (Crusader) still renders smaller than Pyro's — it is the
-- biggest thing on its own map and not on the scale. Asserted on discSize rather
-- than the rendered markup: the thumbnail spec is an integer, and the two round
-- to the same x22px.
function suite:testTierCapIsGlobalNotPerSystem()
	local crusader = Data.discSize('planet', 74500)
	local pyroV = Data.discSize('planet', 78123)
	self:assertTrue(crusader < pyroV, 'Crusader is below Pyro V')
	self:assertTrue(pyroV - crusader < 0.5, 'but only just')
end

-- The tier cap belongs to the whole upstream dataset, not to this file. Pyro V
-- is the largest planet HERE and no longer takes it, because the recorded
-- planet maximum is Helios III at 137,932 km — a body in a system that has not
-- been rolled out. That is the entire point: the next batch to land cannot
-- resize a disc on any of the 42 pages already published.
function suite:testTierCapComesFromTheWholeDatasetNotThisFile()
	local recorded = DATA.extents.planet.max
	local largestHere = 0
	eachBody(function(body, tier)
		if tier == 'planet' and type(body.km) == 'number' and body.km > largestHere then
			largestHere = body.km
		end
	end)
	self:assertTrue(largestHere > 0, 'the file has planets to compare against')
	self:assertTrue(recorded > largestHere, 'the recorded maximum reaches past the file')
	self:assertTrue(Data.discSize('planet', largestHere) < 24, 'so nothing in the file takes the cap')
end

-- ---------------------------------------------------------------------------
-- Data: the recorded disc scale
-- ---------------------------------------------------------------------------

-- systems.json records the extents so the sizes stop moving. While they were
-- measured from the file's own contents, every rollout batch silently rescaled
-- every page already published: adding Terra and Castra alone moved Nyx's star
-- from 30.0px to 24.3px, and the full rollout would have moved it again.
function suite:testFileRecordsExtentsForEveryScaledTier()
	self:assertEquals('table', type(DATA.extents), 'systems.json records the disc scale')
	for _, tier in ipairs({ 'star', 'planet', 'moon' }) do
		local e = DATA.extents[tier]
		self:assertEquals('table', type(e), tier)
		self:assertEquals('number', type(e.min), tier .. ' min')
		self:assertEquals('number', type(e.max), tier .. ' max')
		-- A non-positive minimum makes math.log infinite and the fraction NaN.
		self:assertTrue(e.min > 0, tier .. ' min is positive')
		self:assertTrue(e.max > e.min, tier .. ' spans a range')
	end
	self:assertEquals(nil, DATA.extents.belt, 'a belt is a fixed band with nothing to scale')
end

-- Every body in the file has to sit inside its own tier's recorded range, or its
-- disc is clamped to the cap and two bodies of different sizes draw identically.
-- The generator guarantees this by unioning the upstream measurement with what
-- it actually writes; Pyro IV is why it has to — upstream types it a planet, the
-- overlay renders it as a moon, and at 3,214 km it is nearly twice the largest
-- true moon in all 90 systems.
function suite:testEveryBodyFallsInsideItsRecordedTier()
	eachBody(function(body, tier, key)
		-- Belts and rings are regions drawn at a fixed size, so neither carries a
		-- km to be inside anything.
		if tier == 'belt' or tier == 'ring' or type(body.km) ~= 'number' then
			return
		end
		-- A companion is a star and is scaled as one: `extents` has three tiers,
		-- and a second star belongs to the same one its primary does. Looking it
		-- up under its own name would find nothing, which is precisely the miss
		-- Data.lua's SCALE_TIER exists to prevent — there it would silently draw
		-- every companion at the 30px cap.
		local scaled = tier == 'companion' and 'star' or tier
		local e = DATA.extents[scaled]
		self:assertTrue(body.km >= e.min, key .. '/' .. body.page .. ' is above the ' .. scaled .. ' minimum')
		self:assertTrue(body.km <= e.max, key .. '/' .. body.page .. ' is below the ' .. scaled .. ' maximum')
	end)
end

-- The recorded block wins outright. A file whose contents disagree with it is
-- the normal case, not an error: the extents describe 90 upstream systems and
-- the file holds five of them.
function suite:testResolveExtentsPrefersWhatTheFileRecords()
	local resolved = Data.resolveExtents({
		extents = {
			star = { min = 1, max = 2 },
			planet = { min = 10, max = 20 },
			moon = { min = 100, max = 200 },
		},
		systems = {
			Vector = {
				star = { km = 999999 },
				bodies = { { km = 888888, moons = { { km = 777777 } } } },
			},
		},
	})
	self:assertEquals(1, resolved.star.min)
	self:assertEquals(2, resolved.star.max)
	self:assertEquals(10, resolved.planet.min)
	self:assertEquals(20, resolved.planet.max)
	self:assertEquals(100, resolved.moon.min)
	self:assertEquals(200, resolved.moon.max)
end

-- The fallback keeps an older or hand-written file rendering. It is what this
-- module did unconditionally before the generator existed, so the path is not
-- hypothetical — it is the behaviour every published page was drawn with.
function suite:testResolveExtentsFallsBackToTheFileWhenTheKeyIsAbsent()
	local resolved = Data.resolveExtents({
		systems = {
			Vector = {
				star = { km = 500 },
				bodies = {
					{ km = 100, moons = { { km = 10 }, { km = 40 } } },
					-- A belt must not widen the planet tier even if it is given a
					-- size: nothing draws a belt as a scaled disc.
					{ km = 300, tier = 'belt' },
					{ km = 900, moons = {} },
				},
			},
		},
	})
	self:assertEquals(500, resolved.star.min)
	self:assertEquals(500, resolved.star.max)
	self:assertEquals(100, resolved.planet.min)
	self:assertEquals(900, resolved.planet.max)
	self:assertEquals(10, resolved.moon.min)
	self:assertEquals(40, resolved.moon.max)
	self:assertEquals(nil, resolved.belt)
end

-- Merged per tier rather than all-or-nothing, so a file recording only some
-- tiers does not leave the rest with no scale at all — which would draw every
-- planet on the page at the 24px cap.
function suite:testResolveExtentsMergesAPartialRecordWithTheFileContents()
	local resolved = Data.resolveExtents({
		extents = { planet = { min = 1, max = 1000 } },
		systems = {
			Vector = {
				star = { km = 500 },
				bodies = { { km = 100, moons = { { km = 10 } } } },
			},
		},
	})
	self:assertEquals(1, resolved.planet.min, 'the recorded tier wins')
	self:assertEquals(1000, resolved.planet.max)
	self:assertEquals(500, resolved.star.max, 'the missing tiers are still measured')
	self:assertEquals(10, resolved.moon.max)
end

-- A malformed entry is treated as absent rather than trusted, because a string
-- or a null in there would reach math.log.
function suite:testResolveExtentsIgnoresAMalformedTier()
	local resolved = Data.resolveExtents({
		extents = { star = { min = 'lots', max = 2 }, planet = {}, moon = { min = 1, max = 2 } },
		systems = {
			Vector = {
				star = { km = 500 },
				bodies = { { km = 100, moons = { { km = 10 } } } },
			},
		},
	})
	self:assertEquals(500, resolved.star.max, 'the unusable tier is measured instead')
	self:assertEquals(100, resolved.planet.max)
	self:assertEquals(2, resolved.moon.max, 'the usable one is still honoured')
end

-- A body outside the recorded extents is reachable rather than contradictory:
-- the extents are recorded against an upstream mirror, so a refetch can add a
-- larger star before this file is regenerated. It must land on its tier's cap.
function suite:testDiscSizeClampsBodiesOutsideTheRecordedExtents()
	self:assertEquals(24, Data.discSize('planet', DATA.extents.planet.max * 1000), 'far above the maximum')
	self:assertEquals(6, Data.discSize('planet', DATA.extents.planet.min / 1000), 'far below the minimum')
	self:assertEquals(14, Data.discSize('moon', DATA.extents.moon.max * 1000))
	self:assertEquals(6, Data.discSize('moon', 0.001))
	self:assertEquals(30, Data.discSize('star', DATA.extents.star.max * 1000))
	self:assertEquals(22, Data.discSize('star', 1))
end

-- The clamp has to survive arithmetic that is not merely out of range. An
-- infinite input produces an infinite fraction, which no `f > 1` test in the
-- middle of the calculation would have caught on its own.
function suite:testDiscSizeNeverReturnsSomethingUnrenderable()
	local caps = { star = 30, planet = 24, moon = 14 }
	for tier, cap in pairs(caps) do
		local px = Data.discSize(tier, math.huge)
		self:assertEquals(px, px, tier .. ' is not NaN')
		self:assertEquals(cap, px, tier .. ' takes its cap')
	end
end

-- ---------------------------------------------------------------------------
-- Planetary rings
--
-- A ring nests where a moon nests, because that is the one level of nesting the
-- rail has. Everything below is about it not being mistaken for one.
-- ---------------------------------------------------------------------------

--- The moons array of one planet, by page title.
--- @param systemKey string
--- @param page string
--- @return table
local function moonsOf(systemKey, page)
	local model = Data.buildModel(systemKey, '')
	for _, planet in ipairs(model.bodies) do
		if planet.page == page then
			return planet.moons
		end
	end
	error('no planet ' .. page .. ' in ' .. systemKey)
end

function suite:testRingsNestInTheirPlanetsMoonList()
	local moons = moonsOf('Sol', 'Jupiter')
	local ring = moons[1]
	self:assertEquals('Jovian Rings', ring.page)
	self:assertEquals('Jovian Rings', ring.label)
	self:assertEquals('ring', ring.tier)
	self:assertEquals('ring', ring.kind, 'a ring must never carry the moon kind')
	-- The ring leads, then the four Galilean moons in their lettered order: the
	-- column reads outward from the planet, and the ring is inside all of them.
	self:assertEquals('Io', moons[2].label)
	self:assertEquals('Callisto', moons[5].label)
	self:assertEquals(5, #moons)
end

-- A ring is drawn at a fixed size, like a belt band, and lying flat rather than
-- standing up: it sits in the moon column, where the layout is a row.
function suite:testRingsCarryABandRatherThanADisc()
	local moons = moonsOf('Sol', 'Saturn')
	local ring = moons[1]
	self:assertEquals('Rings of Saturn', ring.page)
	self:assertEquals('table', type(ring.band), 'a ring renders as a band')
	self:assertTrue(ring.band.width > ring.band.height, 'and the band lies flat')
	-- Its neighbours in the same column are still scaled discs.
	self:assertEquals(nil, moons[2].band, 'a real moon keeps its disc')
end

-- The rule that lets rings ship at all: they must not resize the 57 pages that
-- are already live. A ring carries no km — not "happens to have none upstream",
-- but never — so it cannot enter the moon tier's extents.
function suite:testRingsCarryNoSizeAndSoCannotMoveTheMoonScale()
	local rings = 0
	eachBody(function(body, tier, key)
		if tier ~= 'ring' then
			return
		end
		rings = rings + 1
		self:assertEquals(nil, body.km, key .. '/' .. body.page .. ' must carry no km')
		self:assertEquals(nil, body.moons, key .. '/' .. body.page .. ' cannot have moons')
		self:assertEquals('string', type(body.designation), key .. '/' .. body.page .. ' designation')
	end)
	self:assertTrue(rings > 0, 'the file has rings to check')

	-- Pinned rather than merely "unchanged": the moon tier still runs from the
	-- smallest true moon upstream to Pyro IV, the reparented planet, exactly as it
	-- did before rings existed.
	self:assertEquals(3214, DATA.extents.moon.max)
	self:assertEquals(44.6, DATA.extents.moon.min)
end

-- The fallback path has to agree with the generator, or a hand-written file
-- would scale its moons against a ring. Belts are skipped at the planet tier for
-- the same reason, and the same test shape covers both.
function suite:testComputeExtentsIgnoresARingWithASize()
	local resolved = Data.computeExtents({
		systems = {
			Vector = {
				star = { km = 500 },
				bodies = {
					{ km = 100, moons = { { km = 40 }, { km = 99999, tier = 'ring' } } },
				},
			},
		},
	})
	self:assertEquals(40, resolved.moon.max, 'a ring must not stretch the moon tier')
	self:assertEquals(40, resolved.moon.min)
end

-- A ring around a MOON is dropped by the generator, because the rail nests one
-- level and there is nowhere to draw it. Stanton is the only system upstream
-- with one, and it is live on the wiki, so this is the regression that would be
-- visible to readers.
function suite:testAMoonsRingIsNotRendered()
	local html = tostring(Renderer.renderRail(Data.buildModel('Stanton', '')))
	self:assertEquals(nil, html:find('data%-kind="ring"'), 'Stanton draws no ring')
	self:assertEquals(nil, html:find('Ring of Yela'), 'Ring of Yela orbits a moon and is dropped')
end

function suite:testRenderMarksRingsWithTheirOwnKindAndTier()
	local html = tostring(Renderer.renderRail(Data.buildModel('Sol', '')))
	local kinds = select(2, html:gsub('data%-kind="ring"', ''))
	self:assertEquals(4, kinds, 'Sol draws four rings')
	self:assertTrue(html:find('t%-system%-map__item%-%-ring') ~= nil, 'and marks the tier for the row layout')
	self:assertTrue(html:find('%[%[Rings of Uranus|Rings of Uranus%]%]') ~= nil, 'a ring links to its own article')
	-- The band, not a disc: wider than it is tall, which no moon ever is.
	self:assertTrue(html:find('width:15%.0px;height:5%.0px') ~= nil, 'the ring band is inline-sized')
end

-- Counted apart from moons. Folding four rings into Sol's moon count would both
-- overstate the moons and hide something the system is known for.
function suite:testSummariseCountsRingsSeparately()
	self:assertEquals('9 planets, 19 moons, 4 rings, 2 belts', Data.summarise(Data.buildModel('Sol', '')))
end

-- ---------------------------------------------------------------------------
-- Body icons
-- ---------------------------------------------------------------------------

function suite:testRenderUsesTheWikiIconWhenOneExists()
	local html = tostring(Renderer.renderRail(Data.buildModel('Stanton', '')))
	-- Pinned to the exact file on purpose: two Hurston renders exist and the
	-- 879px "Hurston Icon.png" is a washed-out older one. This assertion is what
	-- catches a silent swap back to it.
	self:assertTrue(html:find('%[%[File:Hurston%-Icon%.png|x%d+px|link=|alt=%]%]') ~= nil, 'Hurston renders its icon')
	self:assertTrue(html:find('t%-system%-map__glyph%-%-image') ~= nil, 'and is marked as an image glyph')
end

-- Sizing is by HEIGHT, never width: Terminus's icon is 2.8:1 because it includes
-- the ring system, so a width constraint would shrink the planet to a third of
-- its proper size.
function suite:testRingedIconsAreSizedByHeight()
	local html = tostring(Renderer.renderRail(Data.buildModel('Pyro', '')))
	self:assertTrue(html:find('TerminusIcon%.png|x%d+px') ~= nil, 'Terminus sized by height')
	self:assertEquals(nil, html:find('TerminusIcon%.png|%d+px'), 'never by width')
end

-- Stars and belts have no wiki render, and the procedural treatments are right
-- for those tiers anyway — a star IS a glowing disc, a belt IS a speckled band.
function suite:testBodiesWithoutAnIconKeepTheProceduralDisc()
	local html = tostring(Renderer.renderRail(Data.buildModel('Nyx', '')))
	self:assertTrue(html:find('t%-system%-map__disc') ~= nil, 'the star still draws a disc')
	self:assertEquals(nil, html:find('Nyx %(star%)|x'), 'and no icon is invented for it')
end

-- Guards the sanitizer trap directly. mw.html will happily emit any attribute;
-- MediaWiki decides at parse time which survive, and this suite never sees that
-- step. Pinning the attribute name here means a well-meaning swap back to the
-- "more semantic" aria-current fails loudly instead of silently killing the
-- highlight on every page.
function suite:testCurrentMarkerUsesASanitizerSafeAttribute()
	local html = tostring(Renderer.renderRail(Data.buildModel('Stanton', 'Cellin')))
	self:assertTrue(html:find('data%-current="page"') ~= nil, 'uses data-current')
	self:assertEquals(nil, html:find('aria%-current'), 'never aria-current, which MediaWiki strips')
end

-- The ring and dot are CSS-only, so without this the highlight is invisible to
-- assistive technology entirely.
function suite:testCurrentBodyCarriesAScreenReaderMarker()
	local html = tostring(Renderer.renderRail(Data.buildModel('Stanton', 'Cellin')))
	self:assertTrue(html:find('t%-system%-map__sr') ~= nil, 'visually-hidden marker present')
	self:assertTrue(html:find('%(current page%)') ~= nil, 'and says so in words')
	local count = select(2, html:gsub('t%-system%-map__sr', ''))
	self:assertEquals(1, count, 'exactly one body is marked')
end

-- ---------------------------------------------------------------------------
-- Binary stars
--
-- Two arrangements, drawn differently on purpose. Where upstream parents the
-- companion to the primary it genuinely orbits it, and it nests where a moon
-- nests. Where neither is parented the two co-orbit, and they share the head
-- slot so the orbit line begins at the pair rather than at either star.
-- ---------------------------------------------------------------------------

-- A companion is a STAR, whichever tier it is laid out at. Missing this is
-- silent twice over: glyphKind would fall through to the planet branch and give
-- it the neutral 'unknown' disc, and discSize would find no extents for the tier
-- and return the tier maximum.
function suite:testGlyphKindTreatsBothCompanionTiersAsStars()
	self:assertEquals('star-degenerate', Data.glyphKind('companion', nil, 'degenerate'))
	self:assertEquals('star-k', Data.glyphKind('paired', nil, 'K'))
	self:assertEquals('star-g', Data.glyphKind('paired', 'G-type main sequence', 'G'))
	-- And the same classless fallback a star gets, not 'unknown'.
	self:assertEquals('star', Data.glyphKind('companion', nil, nil))
	self:assertEquals('star', Data.glyphKind('paired', 'Subgiant', nil))
end

-- Tyrol B is 14,834 km and renders at 22.8px — the star tier's floor plus a
-- little — while sitting in the row where moons are 6-14px. It is a star and has
-- to read as one; drawn on the moon scale it would be an absurd moon, and drawn
-- with no scale at all it would take the 30px cap reserved for the largest star
-- in the file.
function suite:testDiscSizeMeasuresACompanionAtTheStarTier()
	local km = 14834
	self:assertEquals(Data.discSize('star', km), Data.discSize('companion', km))
	self:assertEquals(Data.discSize('star', km), Data.discSize('paired', km))
	self:assertTrue(
		Data.discSize('companion', km) > Data.discSize('moon', DATA.extents.moon.max),
		'bigger than any moon'
	)
	self:assertTrue(Data.discSize('companion', km) < 30, 'and not silently pinned to the star cap')
end

-- The fallback path has to agree with the generator here too: a file with no
-- recorded extents still has to measure a companion at the star tier, or the
-- primary and the companion would be scaled against different ranges.
function suite:testComputeExtentsMeasuresACompanionAtTheStarTier()
	local resolved = Data.computeExtents({
		systems = {
			Vector = {
				star = { km = 500 },
				companion = { km = 20 },
				bodies = { { km = 100, moons = {} } },
			},
			-- A system with no star at all must not stop the walk, which is the
			-- shape Tamsa and Min take.
			Headless = { bodies = { { km = 300, moons = {} } } },
		},
	})
	self:assertEquals(20, resolved.star.min, 'the companion widens the star tier')
	self:assertEquals(500, resolved.star.max)
	self:assertEquals(100, resolved.planet.min, 'and the headless system is still measured')
	self:assertEquals(300, resolved.planet.max)
end

function suite:testBuildModelNestsACompanionWhereAMoonGoes()
	local model = Data.buildModel('Tyrol', '')
	self:assertEquals('nested', model.companionShape)
	self:assertEquals('Tyrol A', model.star.label)
	self:assertEquals('Tyrol B', model.companion.label)
	self:assertEquals('companion', model.companion.tier)
	self:assertEquals('star-degenerate', model.companion.kind)

	-- It is put in the primary's moon list, which is the one level of nesting
	-- the rail has, and it is the SAME table — so a flag set on model.companion
	-- (missing, current) reaches the node that is actually drawn.
	self:assertEquals('table', type(model.star.moons), 'the primary carries a nested list')
	self:assertEquals(model.companion, model.star.moons[1], 'and it holds the companion itself')
	self:assertEquals(nil, model.star.moons[2], 'and nothing else')
end

function suite:testBuildModelPairsCoOrbitingStars()
	local model = Data.buildModel('Bacchus', '')
	self:assertEquals('paired', model.companionShape)
	self:assertEquals('Bacchus A', model.star.label)
	self:assertEquals('Bacchus B', model.companion.label)
	-- Both take the pair tier: they are drawn as equals, so the primary is laid
	-- out the same way the companion is.
	self:assertEquals('paired', model.star.tier)
	self:assertEquals('paired', model.companion.tier)
	-- Each keeps its own glyph. Bacchus A is a G-type and B a K-type, which is
	-- why the pair cannot be one merged node.
	self:assertEquals('star-g', model.star.kind)
	self:assertEquals('star-k', model.companion.kind)
	-- And nothing is nested: a pair has no hierarchy to express.
	self:assertEquals(nil, model.star.moons, 'a paired primary carries no nested list')
end

function suite:testBuildModelSingleStarSystemsGainNothing()
	local model = Data.buildModel('Stanton', '')
	self:assertEquals(nil, model.companion)
	self:assertEquals(nil, model.companionShape)
	self:assertEquals('star', model.star.tier)
	self:assertEquals(nil, model.star.moons, 'the star of a single-star system nests nothing')
end

function suite:testRenderNestsACompanionInsideTheStarsColumn()
	local html = tostring(Renderer.renderRail(Data.buildModel('Tyrol', '')))

	local starAt = html:find('%[%[Tyrol A|Tyrol A%]%]')
	local companionAt = html:find('%[%[Tyrol B|Tyrol B%]%]')
	local firstPlanetAt = html:find('%[%[Tyrol I|Tyrol I%]%]')
	self:assertTrue(starAt ~= nil and companionAt ~= nil and firstPlanetAt ~= nil)
	self:assertTrue(companionAt > starAt, 'the companion renders after its primary')
	self:assertTrue(companionAt < firstPlanetAt, 'and before the first planet, inside the star column')

	local nestedAt = html:find('<ul class="t%-system%-map__moons"', starAt)
	self:assertTrue(nestedAt ~= nil and nestedAt < companionAt, 'it sits in the nested list, not loose on the rail')

	-- The connector line down that column is drawn from the modifier class,
	-- because :has() is not in TemplateStyles' allowlist.
	self:assertTrue(
		html:find('t%-system%-map__item t%-system%-map__item%-%-star t%-system%-map__item%-%-has%-moons') ~= nil,
		'the primary carries the has-moons modifier so the connector is drawn'
	)
	-- Its own tier class, so styles.css can give it the moon row layout while it
	-- keeps a star's glyph and a star's size.
	self:assertTrue(html:find('t%-system%-map__item%-%-companion') ~= nil, 'the companion has its own tier class')
	self:assertTrue(html:find('data%-kind="star%-degenerate"') ~= nil, 'and a star glyph, not a moon disc')
	self:assertTrue(html:find('width:22%.8px;height:22%.8px') ~= nil, 'sized at the star tier, not the moon tier')
end

function suite:testRenderGivesAPairOneRailSlot()
	local html = tostring(Renderer.renderRail(Data.buildModel('Bacchus', '')))

	self:assertEquals(1, select(2, html:gsub('t%-system%-map__item%-%-pair"', '')), 'exactly one pair slot')
	self:assertEquals(2, select(2, html:gsub('t%-system%-map__item%-%-paired', '')), 'holding two stars')

	local pairAt = html:find('<ul class="t%-system%-map__pair"')
	local aAt = html:find('%[%[Bacchus A|Bacchus A%]%]')
	local bAt = html:find('%[%[Bacchus B|Bacchus B%]%]')
	local firstPlanetAt = html:find('%[%[Bacchus I|Bacchus I%]%]')
	self:assertTrue(pairAt ~= nil and aAt ~= nil and bAt ~= nil and firstPlanetAt ~= nil)
	self:assertTrue(
		pairAt < aAt and aAt < bAt and bAt < firstPlanetAt,
		'both stars sit in the slot, before the planets'
	)

	-- Neither is nested under the other: a co-orbiting pair has no hierarchy,
	-- and the moon list is what would claim one.
	self:assertEquals(nil, html:find('<ul class="t%-system%-map__moons"', pairAt))

	-- Each keeps its own kind, which is why they cannot share a node.
	self:assertTrue(html:find('data%-kind="star%-g"') ~= nil, 'Bacchus A is a G-type')
	self:assertTrue(html:find('data%-kind="star%-k"') ~= nil, 'Bacchus B is a K-type')
end

-- The you-are-here marker lands on the INDIVIDUAL star, never on the pair.
-- Bacchus A and Bacchus B are separate articles, and a reader on either has to
-- be able to find themselves; a merged "A · B" label could not do it, which is
-- why the pair is two markable nodes rather than one.
function suite:testRenderMarksTheIndividualStarOfAPair()
	for _, star in ipairs({ 'A', 'B' }) do
		local title = 'Bacchus ' .. star
		local html = tostring(Renderer.renderRail(Data.buildModel('Bacchus', title)))

		self:assertEquals(1, select(2, html:gsub('data%-current="page"', '')), title .. ': exactly one node marked')

		-- data-current sits on the node, which opens just before that star's
		-- link, so the marker's position is what identifies which star it is on.
		local markerAt = html:find('data%-current="page"')
		local aAt = html:find('%[%[Bacchus A|Bacchus A%]%]')
		local bAt = html:find('%[%[Bacchus B|Bacchus B%]%]')
		if star == 'A' then
			self:assertTrue(markerAt < aAt, 'the marker is on Bacchus A')
		else
			self:assertTrue(markerAt > aAt and markerAt < bAt, 'the marker is on Bacchus B, not on the pair')
		end
		self:assertTrue(html:find('%(current page%)') ~= nil, title .. ': and says so to a screen reader')
	end
end

-- The same, for a nested companion: Tyrol B is its own article too.
function suite:testRenderMarksANestedCompanion()
	local html = tostring(Renderer.renderRail(Data.buildModel('Tyrol', 'Tyrol B')))
	self:assertEquals(1, select(2, html:gsub('data%-current="page"', '')))
	local markerAt = html:find('data%-current="page"')
	local starAt = html:find('%[%[Tyrol A|Tyrol A%]%]')
	local companionAt = html:find('%[%[Tyrol B|Tyrol B%]%]')
	self:assertTrue(markerAt > starAt and markerAt < companionAt, 'marked on the companion, not on the primary')
end

-- Stars are not counted in the header, whether there are two or one: how many a
-- system has is the first thing the picture says.
function suite:testSummariseCountsNeitherStar()
	self:assertEquals('7 planets, 1 moon, 1 belt', Data.summarise(Data.buildModel('Tyrol', '')))
	self:assertEquals('3 planets, 1 belt', Data.summarise(Data.buildModel('Bacchus', '')))
	self:assertEquals(nil, Data.summarise(Data.buildModel('Goss', '')):find('star'))
end

-- Both stars are probed for existence, so a moved or deleted star article trips
-- the tracking category. A nested companion is reachable through the primary's
-- moon list and a paired one is not reachable from `bodies` at all, so the walk
-- visits them directly rather than relying on the rail.
function suite:testAnnotateExistenceProbesBothStars()
	for _, case in ipairs({
		{ system = 'Tyrol', star = 'Tyrol A', companion = 'Tyrol B' },
		{ system = 'Bacchus', star = 'Bacchus A', companion = 'Bacchus B' },
	}) do
		local model = Data.buildModel(case.system, '')
		local probed = {}
		local category = SystemMap.annotateExistence(model, function(page)
			probed[page] = (probed[page] or 0) + 1
			return page ~= case.companion
		end)
		self:assertEquals(1, probed[case.star], case.star .. ' is probed once')
		self:assertEquals(1, probed[case.companion], case.companion .. ' is probed once')
		self:assertEquals('[[Category:Pages with a broken system map link]]', category, case.system)
		self:assertTrue(model.companion.missing, case.companion .. ' is flagged missing')
		self:assertEquals(false, model.star.missing, case.star .. ' is not')
	end
end

-- Two upstream systems (Tamsa, Min) have no star and still carry planets — Min
-- carries four moons as well — so nothing downstream of the data may assume a
-- head. Neither is rolled out, so the model is built by hand here: this is the
-- render and walk half of the guarantee, and the file-shape half is the Go
-- suite's TestBuildWithoutAStar.
function suite:testAHeadlessSystemStillRendersItsPlanets()
	local model = {
		key = 'Vector',
		page = 'Vector system',
		bodies = {
			{
				tier = 'planet',
				page = 'Vector I',
				label = 'Vector I',
				kind = 'rocky',
				disc = 12,
				current = false,
				missing = false,
				moons = {},
			},
		},
	}

	local html = tostring(Renderer.renderRail(model))
	self:assertTrue(html:find('t%-system%-map__rail') ~= nil, 'the rail is still drawn')
	self:assertTrue(html:find('%[%[Vector I|Vector I%]%]') ~= nil, 'and so is the planet')
	self:assertEquals(nil, html:find('t%-system%-map__item%-%-star'), 'with no star slot at all')

	-- And the existence walk does not trip over the absent star either.
	local category = SystemMap.annotateExistence(model, function()
		return true
	end)
	self:assertEquals('', category)
	self:assertEquals('1 planet', Data.summarise(model))
end

return suite
