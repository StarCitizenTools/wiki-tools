require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local suite = ScribuntoUnit:new()

local navplates = require('Module:Entity/Navplates')
local countLine = navplates._internal.countLine
local resolveHub = navplates._internal.resolveHub

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

function suite:testResolveHubPicksTheLiveHubOfADuplicatePair()
	-- "Ballistic Repeater" and "Ballistic repeater" are two real pages; the
	-- capitalised one is a 320-byte orphan with no inbound links, so only the
	-- lowercase hub is in the map and resolution is not a coin flip.
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

return suite
