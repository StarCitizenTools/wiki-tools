require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local suite = ScribuntoUnit:new()

local navplates = require('Module:Entity/Navplates')
local countLine = navplates._internal.countLine
local resolveHub = navplates._internal.resolveHub
local kindHub = navplates._internal.kindHub
local countFilter = navplates._internal.countFilter

--- Most of the suite asks only "does this string reach this hub", so the
--- candidate records appear only in the tests that are about the count.
---
--- @param ... string|nil
--- @return string|nil, string|nil, string|nil
local function hubFor(...)
	local candidates = {}
	for i = 1, select('#', ...) do
		candidates[i] = { value = (select(i, ...)) }
	end
	return resolveHub(candidates)
end

function suite:testCountLineNamesTheNoun()
	-- The title is the subject alone, so the noun is new information beside it.
	self:assertEquals('188 products', countLine(188, 'products', 'Behring Applied Technology'))
end

function suite:testCountLineAvoidsRepeatingTheNoun()
	-- The type cell's title already is the noun.
	self:assertEquals('148 in total', countLine(148, 'guns', 'Guns'))
end

function suite:testCountLineMatchesNounCaseInsensitively()
	self:assertEquals('12 in total', countLine(12, 'coolers', 'Coolers'))
	-- A label that keeps its own capitals still matches the title it heads.
	self:assertEquals('16 in total', countLine(16, 'Super-Earths', 'Super-Earths'))
	self:assertEquals('5 in total', countLine(5, 'A-type main-sequence stars', 'A-type main-sequence stars'))
end

function suite:testCountLineMatchesOnlyTheTail()
	-- "arms armor" ends with the noun; a manufacturer whose name merely
	-- contains it does not.
	self:assertEquals('446 in total', countLine(446, 'arms armor', 'Arms armor'))
	self:assertEquals('3 products', countLine(3, 'products', 'Products Unlimited Ltd'))
end

function suite:testCountLineSuppressedWithoutACount()
	self:assertEquals(nil, countLine(nil, 'products', 'More from J-Span'))
	self:assertEquals(nil, countLine(0, 'products', 'More from J-Span'))
end

function suite:testResolveHubTakesSingularOrPlural()
	self:assertEquals('Gun', hubFor('Guns'))
	self:assertEquals('Gun', hubFor('Gun'))
	self:assertEquals('Cooler', hubFor('Coolers'))
end

function suite:testResolveHubReturnsTheHeadingPlural()
	local _, guns = hubFor('Gun')
	self:assertEquals('guns', guns)
	local _, weapons = hubFor('Personal weapon')
	self:assertEquals('personal weapons', weapons)
end

function suite:testResolveHubKeepsArmorUncountable()
	-- "armors" is not a word; the hub headings settled this and the label is
	-- carried in the data rather than pluralised here.
	local _, arms = hubFor('Arm armor')
	self:assertEquals('arms armor', arms)
	local _, heavy = hubFor('Heavy armor')
	self:assertEquals('heavy armor', heavy)
end

function suite:testResolveHubAppendsItemsToAdjectiveHubs()
	local _, hydrating = hubFor('Hydrating')
	self:assertEquals('hydrating items', hydrating)
end

function suite:testResolveHubKeepsProperNounCasing()
	local _, turrets = hubFor('Point Defense Turret')
	self:assertEquals('Point Defense Turrets', turrets)
	local _, tools = hubFor('Multi-Tool attachment')
	self:assertEquals('Multi-Tool attachments', tools)
end

function suite:testResolveHubReachesTheHubFromACapitalisedPlural()
	-- Hub titles are matched lowercased, so a type string that both capitalises
	-- the noun and pluralises it still lands on the one hub page.
	self:assertEquals('Ballistic repeater', hubFor('Ballistic Repeater'))
	local _, label = hubFor('Ballistic repeaters')
	self:assertEquals('ballistic repeaters', label)
end

function suite:testResolveHubUsesOverridesWherePluralisationCannotReach()
	self:assertEquals('Arms armor', hubFor('Arm armor'))
	self:assertEquals('Legs armor', hubFor('Leg armor'))
	self:assertEquals('Optics attachment', hubFor('Optic'))
end

function suite:testResolveHubIsCaseAndSpaceInsensitive()
	self:assertEquals('Gun', hubFor('  guns  '))
end

function suite:testResolveHubPrefersTheFirstCandidateThatResolves()
	self:assertEquals('Cooler', hubFor('Nothing at all', 'Coolers'))
end

function suite:testResolveHubReturnsNilWhenNothingMatches()
	-- Ships have no anchored hub yet, so a spacecraft renders the manufacturer
	-- half alone rather than linking a page with no index on it.
	self:assertEquals(nil, hubFor('Spacecraft'))
	self:assertEquals(nil, hubFor(nil))
	self:assertEquals(nil, hubFor(''))
end

function suite:testResolveHubReportsTheCountValueOfTheCandidateThatMatched()
	-- The count has to size the set the cell links to, so the value it filters
	-- on travels with the candidate rather than being read off the page's type.
	local hub, _, countOn = resolveHub({
		{ value = 'Nothing at all', countOn = 'Nothing' },
		{ value = 'Coolers', countOn = 'Cooler' },
	})
	self:assertEquals('Cooler', hub)
	self:assertEquals('Cooler', countOn)
end

function suite:testResolveHubReportsNoCountForABrowseCategoryHub()
	-- The Freelancer case: its type (Spacecraft) has no hub, so it reaches
	-- Medium ships through a chain browse category. That category is a curated
	-- set of 45 pages, while counting Subject type = Spacecraft would have
	-- captioned the link with all 240 spacecraft on the wiki.
	local hub, _, countOn = resolveHub({
		{ value = 'Spacecraft', countOn = 'Spacecraft' },
		{ value = 'Medium ships' },
	})
	self:assertEquals('Medium ships', hub)
	self:assertEquals(nil, countOn)
end

function suite:testResolveHubSkipsCandidatesWithoutAValue()
	-- The chain contributes holes: a page with no typeInfo still passes the
	-- slots for it, and ipairs must not stop on them.
	self:assertEquals('Gun', resolveHub({ {}, { value = 'Guns', countOn = 'Gun' } }))
end

function suite:testResolveHubTakesACandidateThatNamesItsHub()
	-- A role candidate carries the hub page itself and must not be looked up in
	-- the shared index: the 10 role-only hubs are deliberately absent from it.
	local hub, label, countOn = resolveHub({
		{ hub = 'Light freighters', label = 'light freighters' },
		{ value = 'Guns', countOn = 'Gun' },
	})
	self:assertEquals('Light freighters', hub)
	self:assertEquals('light freighters', label)
	self:assertEquals(nil, countOn)
end

function suite:testRoleHubsBypassTheSharedIndexEvenOnACollision()
	-- The scoping guarantee, stated as the invariant rather than as today's
	-- coincidence: a candidate naming its hub is returned before hubIndex is
	-- consulted at all, so an item hub of the same name cannot capture it. The
	-- value here would resolve to a different page through the index.
	local hub, label, countOn = resolveHub({
		{ hub = 'Medical ships', label = 'medical ships' },
		{ value = 'Guns', countOn = 'Gun' },
	})
	self:assertEquals('Medical ships', hub)
	self:assertEquals('medical ships', label)
	self:assertEquals(nil, countOn)
end

function suite:testEveryRoleEntryNamesAHubAndAFamily()
	-- Each entry must carry both, since roleHub gates on family: an entry
	-- missing one would silently link a ground vehicle to a spacecraft hub.
	local hubs = mw.loadJsonData('Module:Entity/Navplates/hubs.json')
	local families = {}
	for role, entry in pairs(hubs.roles) do
		self:assertEquals('table', type(entry), role)
		self:assertEquals(true, type(entry.hub) == 'string' and entry.hub ~= '', role)
		self:assertEquals(true, mw.ustring.find(entry.hub, '^%u') ~= nil, role)
		self:assertEquals(true, entry.family == 'ship' or entry.family == 'ground', role)
		families[entry.family] = true
	end
	self:assertEquals(true, families.ship)
end

function suite:testKindHubSendsACommodityToTheCommodityHub()
	local candidate = kindHub('Commodity')
	self:assertEquals('Commodity', candidate.hub)
	self:assertEquals('commodities', candidate.label)
end

function suite:testKindHubIgnoresKindsOutsideTheMap()
	-- Item and Location keep resolving through their types, where their hubs
	-- are keyed.
	self:assertEquals(nil, kindHub('Item'))
	self:assertEquals(nil, kindHub('Location'))
	self:assertEquals(nil, kindHub(nil))
end

function suite:testKindHubMatchesTheKindNameExactly()
	self:assertEquals(nil, kindHub('commodity'))
	self:assertEquals(nil, kindHub('Commodities'))
end

function suite:testSystemTypesReachThePlanetarySystemHub()
	-- A record-less system page is reachable only through its stored Subject
	-- type, which is one of these four labels.
	for _, systemType in ipairs({ 'Single star system', 'Binary star system', 'Trinary star system', 'Star system' }) do
		local hub, label = hubFor(systemType)
		self:assertEquals('Planetary system', hub, systemType)
		self:assertEquals('planetary systems', label, systemType)
	end
end

function suite:testCountFilterUsesTheSelectorTheHubsGridUses()
	-- The hub lists every commodity, so the count must too, whatever the page's
	-- own substance is.
	self:assertEquals('Category:Commodities', countFilter('Commodity', 'Metal'))
	self:assertEquals('Category:Commodities', countFilter('Commodity', nil))
	self:assertEquals('Category:Systems', countFilter('Planetary system', 'Single star system'))
end

function suite:testCountFilterFallsBackToTheCandidatesSubjectType()
	self:assertDeepEquals({ 'Subject type', 'Gun' }, countFilter('Gun', 'Gun'))
end

function suite:testCountFilterIsNilWhenNothingCountsTheHub()
	-- A browse-category or role hub carries no count value and is not in
	-- `selects`, so its cell shows no number.
	self:assertEquals(nil, countFilter('Medium ships', nil))
	self:assertEquals(nil, countFilter('Gun', ''))
end

function suite:testKindsAndSelectsNameAnchoredHubs()
	-- A target missing from `hubs` has no heading plural to borrow, and a
	-- selector that is not a category is not what the hub grids select by. A
	-- kind candidate carries no count value of its own, so a `kinds` hub
	-- missing from `selects` would silently show no count.
	local doc = mw.loadJsonData('Module:Entity/Navplates/hubs.json')
	for kind, hub in pairs(doc.kinds) do
		self:assertEquals('string', type(doc.hubs[hub]), kind)
		self:assertEquals('string', type(doc.selects[hub]), kind)
	end
	for hub, selector in pairs(doc.selects) do
		self:assertEquals('string', type(doc.hubs[hub]), hub)
		local categories = type(selector) == 'table' and selector.any or { selector }
		self:assertEquals('table', type(categories), hub)
		for _, category in ipairs(categories) do
			self:assertEquals(true, mw.ustring.find(category, '^Category:.') ~= nil, hub)
		end
	end
end

function suite:testStationClassesReachTheSpaceStationHub()
	-- The hub lists every station class, so a subclass page browses to it
	-- rather than to a hub of its own that does not exist.
	for _, class in ipairs({
		'Space station',
		'Space stations',
		'Alignment facility',
		'Asteroid base',
		'Comm array',
		'Gateway station',
		'Military station',
		'Orbital station',
		'Rest stop',
	}) do
		local hub, label = hubFor(class)
		self:assertEquals('Space station', hub, class)
		self:assertEquals('space stations', label, class)
	end
end

function suite:testSpaceStationHubCountsEveryStationClass()
	-- A rest stop page must caption the hub with the size of the whole list,
	-- not with the number of rest stops.
	local selector = countFilter('Space station', 'Rest stop')
	self:assertEquals('table', type(selector))
	local categories = {}
	for _, category in ipairs(selector.any) do
		categories[category] = true
	end
	self:assertEquals(true, categories['Category:Space stations'])
	self:assertEquals(true, categories['Category:Rest stops'])
	self:assertEquals(true, categories['Category:Orbital stations'])
end

-- Where each place class browses to, by its parent in classes.json. A class
-- whose group has no list of its own and too few pages for one has no hub.
local PLACE_GROUP_HUBS = {
	['Outposts'] = 'Outposts',
	['Settlements'] = 'Settlements',
	['City venues'] = 'City venues',
	['Space stations'] = 'Space station',
}
local PLACE_CLASS_HUBS = {
	['Space station'] = 'Space station',
	['Settlement'] = 'Settlements',
	['Racetrack'] = 'Racing',
	['Asteroid cluster'] = 'Asteroid formation',
}
local HUBLESS_CLASSES = { Cave = true, ['Crash site'] = true, Monument = true, Prison = true }

function suite:testEveryPlaceClassReachesItsGroupHub()
	local classes = mw.loadJsonData('Module:Entity/Location/Place/classes.json').classes
	for name, class in pairs(classes) do
		local want = PLACE_CLASS_HUBS[name] or PLACE_GROUP_HUBS[class.parent]
		if HUBLESS_CLASSES[name] then
			self:assertEquals(nil, hubFor(name), name)
		else
			self:assertEquals(want, hubFor(name), name)
		end
	end
end

function suite:testPlaceOverridesNameAPlaceClass()
	-- The class names reach their hubs through the shared overrides, because a
	-- record-less place resolves as an Item in a sibling call. An override into a
	-- place hub that names no class is a typo or a class that was renamed.
	local classes = mw.loadJsonData('Module:Entity/Location/Place/classes.json').classes
	local placeHubs = {}
	for _, hub in pairs(PLACE_GROUP_HUBS) do
		placeHubs[hub] = true
	end
	for name, hub in pairs(PLACE_CLASS_HUBS) do
		-- Asteroid formation also lists the belt family's own types, which are
		-- not place classes.
		if hub ~= 'Asteroid formation' then
			placeHubs[hub] = true
		end
	end
	local overrides = mw.loadJsonData('Module:Entity/Navplates/hubs.json').overrides
	for from, to in pairs(overrides) do
		if placeHubs[to] then
			self:assertEquals('table', type(classes[from]), from)
		end
	end
end

function suite:testGroupHubsCountEveryClassTheirGridLists()
	local classes = mw.loadJsonData('Module:Entity/Location/Place/classes.json').classes
	for group, hub in pairs(PLACE_GROUP_HUBS) do
		local selected = {}
		for _, category in ipairs(countFilter(hub, nil).any) do
			selected[category] = true
		end
		for name, class in pairs(classes) do
			if class.parent == group then
				self:assertEquals(true, selected['Category:' .. class.category], name)
			end
		end
	end
end

function suite:testBeltTypesReachTheAsteroidFormationHub()
	-- Its list covers belts, rings and debris fields as well as the clusters.
	for _, belt in ipairs({
		'Asteroid belt',
		'Planetary ring system',
		'Debris field',
		'Asteroid cluster',
		'Asteroid formation',
	}) do
		self:assertEquals('Asteroid formation', hubFor(belt), belt)
	end
end

function suite:testRacetrackReachesTheRacingHub()
	local hub, label, countOn =
		resolveHub({ { value = 'Racetracks', countOn = 'Racetrack' }, { value = 'Racetrack', countOn = 'Racetrack' } })
	self:assertEquals('Racing', hub)
	self:assertEquals('racetracks', label)
	self:assertEquals('Racetrack', countOn)
end

return suite
