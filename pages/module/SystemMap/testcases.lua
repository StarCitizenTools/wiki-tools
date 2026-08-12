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
--- @param fn fun(body: table, tier: string, systemKey: string)
local function eachBody(fn)
	for key, system in pairs(DATA.systems) do
		fn(system.star, 'star', key)
		for _, body in ipairs(system.bodies) do
			fn(body, body.tier == 'belt' and 'belt' or 'planet', key)
			if body.moons then
				for _, moon in ipairs(body.moons) do
					fn(moon, 'moon', key)
				end
			end
		end
	end
end

function suite:testThreeSystemsPresent()
	self:assertEquals('table', type(DATA.systems.Stanton))
	self:assertEquals('table', type(DATA.systems.Pyro))
	self:assertEquals('table', type(DATA.systems.Nyx))
end

function suite:testBodyCounts()
	local counts = { star = 0, planet = 0, belt = 0, moon = 0 }
	eachBody(function(_, tier)
		counts[tier] = counts[tier] + 1
	end)
	self:assertEquals(3, counts.star)
	self:assertEquals(13, counts.planet)
	self:assertEquals(19, counts.moon)
	self:assertEquals(4, counts.belt)
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

function suite:testEverySystemHasAStarWithAClass()
	for key, system in pairs(DATA.systems) do
		self:assertEquals('string', type(system.star.class), key .. ' star class')
		self:assertEquals('string', type(system.page), key .. ' page')
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

function suite:testResolveKeyUnknownReturnsNil()
	self:assertEquals(nil, Data.resolveKey('Terra'))
	self:assertEquals(nil, Data.resolveKey(''))
	self:assertEquals(nil, Data.resolveKey(nil))
	self:assertEquals(nil, Data.resolveKey('system'))
end

-- ---------------------------------------------------------------------------
-- Data: glyph classification
-- ---------------------------------------------------------------------------

function suite:testGlyphKindPlanetSubtypes()
	self:assertEquals('super-earth', Data.glyphKind('planet', 'Super-Earth'))
	self:assertEquals('gas-giant', Data.glyphKind('planet', 'Gas giant'))
	self:assertEquals('ice-giant', Data.glyphKind('planet', 'Ice giant'))
	self:assertEquals('smog', Data.glyphKind('planet', 'Smog planet'))
	self:assertEquals('protoplanet', Data.glyphKind('planet', 'Protoplanet'))
	self:assertEquals('rocky', Data.glyphKind('planet', 'Terrestrial rocky'))
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

function suite:testGlyphKindMoonsDefaultToMoonButHonourSubtype()
	self:assertEquals('moon', Data.glyphKind('moon', nil))
	self:assertEquals('rocky', Data.glyphKind('moon', 'Terrestrial rocky'))
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
	self:assertEquals(nil, Data.buildModel('Terra', 'Whatever'))
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
	local out = SystemMap.render('Terra', 'Whatever', nil, nil, true)
	self:assertEquals('[[Category:System map with unknown system]]', out)
end

-- A sandbox or module subpage with a bad call should not pollute a category
-- documented as "should normally be empty" -- once it permanently holds
-- non-articles, editors learn to ignore it.
function suite:testTrackingCategoriesAreSuppressedOutsideMainNamespace()
	self:assertEquals('', SystemMap.render('Terra', 'Whatever', nil, nil, false))
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
	self:assertEquals(19, total, 'Stanton is the worst case at 19 probes')
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
	self:assertTrue(html:find('Nyx Belt Alpha') ~= nil, 'Glaciem Ring keeps its designation')
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
	-- Pyro V is the largest planet in the file, Delamar the smallest.
	self:assertEquals(24, Data.discSize('planet', 78123))
	self:assertEquals(6, Data.discSize('planet', 165.4))
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

function suite:testDiscSizeFallsBackWhenSizeIsMissing()
	self:assertEquals(24, Data.discSize('planet', nil))
	self:assertEquals(24, Data.discSize('planet', 0))
	self:assertEquals(24, Data.discSize('planet', -5))
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

-- The tier cap belongs to Pyro V, the largest planet in the FILE — extents are
-- global, not per system, so Stanton's own largest (Crusader) sits just below it
-- even though it is the biggest thing on its own map. Asserted on discSize
-- rather than the rendered markup: the thumbnail spec is an integer, and
-- Crusader's 23.86px rounds to the same x24px as Pyro V's 24.0px.
function suite:testTierCapIsGlobalNotPerSystem()
	self:assertEquals(24, Data.discSize('planet', 78123), 'Pyro V takes the cap exactly')
	local crusader = Data.discSize('planet', 74500)
	self:assertTrue(crusader < 24, 'Crusader is below the cap')
	self:assertTrue(crusader > 23, 'but only just')
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

-- The ring is drawn on the glyph and sized from this custom property, because
-- most bodies render as an <img> with no .__disc element to hang a box-shadow
-- on. Custom properties in an inline style survive MediaWiki's sanitizer
-- (probed against the live parser) -- unlike aria-current.
function suite:testGlyphPublishesItsDiscSize()
	local html = tostring(Renderer.renderRail(Data.buildModel('Stanton', '')))
	self:assertTrue(html:find('%-%-t%-system%-map%-disc:%d') ~= nil, 'glyph carries the disc size')
end

return suite
