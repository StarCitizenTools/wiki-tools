require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local suite = ScribuntoUnit:new()
local company = require('Module:Company')

--- Find the first content item with the given label across all sections.
local function findItem(sections, label)
	for _, section in ipairs(sections) do
		for _, item in ipairs(section.items or {}) do
			if item.label == label then
				return item
			end
		end
	end
	return nil
end

-- normalizeRace
function suite:testNormalizeRaceDefaultsToHuman()
	self:assertEquals('Human', company.normalizeRace(nil))
	self:assertEquals('Human', company.normalizeRace(''))
end

function suite:testNormalizeRaceTrims()
	self:assertEquals('Tevarin', company.normalizeRace('  Tevarin '))
end

function suite:testNormalizeRaceEchoes()
	self:assertEquals('Banu', company.normalizeRace('Banu'))
end

-- resolveCode (always resolved from the company name via Module:Manufacturers)
function suite:testResolveCodeResolvesFromName()
	self:assertEquals('AEGS', company.resolveCode({ name = 'Aegis Dynamics' }))
end

function suite:testResolveCodeTrimsName()
	self:assertEquals('AEGS', company.resolveCode({ name = '  Aegis Dynamics  ' }))
end

function suite:testResolveCodeUnknownIsNil()
	self:assertEquals(nil, company.resolveCode({ name = 'Not A Manufacturer' }))
	self:assertEquals(nil, company.resolveCode({}))
end

function suite:testResolveCodeIgnoresCodeArg()
	-- Module:Manufacturers is the source of truth; an explicit code arg is ignored.
	self:assertEquals('AEGS', company.resolveCode({ code = 'ZZZZ', name = 'Aegis Dynamics' }))
	self:assertEquals(nil, company.resolveCode({ code = 'ZZZZ' }))
end

-- raceLink
function suite:testRaceLinkDefault()
	self:assertEquals('[[:Category:Human companies|Human]]', company.raceLink({}))
end

function suite:testRaceLinkExplicit()
	self:assertEquals('[[:Category:Banu companies|Banu]]', company.raceLink({ race = 'Banu' }))
end

-- getStructuredData (multi-value fields are semicolon-separated)
function suite:testStructuredIndustrySingleLcfirst()
	local data = company.getStructuredData({ industry = 'Mining' })
	self:assertDeepEquals({ 'mining' }, data['Industry'])
end

function suite:testStructuredIndustryMultiLcfirstPerItem()
	-- Each item is lcfirst + delinked independently (fixes the legacy "only the
	-- first item lowercased" quirk).
	local data = company.getStructuredData({ industry = 'Mining; Salvage' })
	self:assertDeepEquals({ 'mining', 'salvage' }, data['Industry'])
end

function suite:testStructuredIndustryLinkedLcfirstNoop()
	-- lcfirst is a no-op when an item starts with '[', then delink keeps the label.
	local data = company.getStructuredData({ industry = '[[Mining]]; [[Salvage]]' })
	self:assertDeepEquals({ 'Mining', 'Salvage' }, data['Industry'])
end

function suite:testStructuredFounderIsDelinkedPageList()
	local data = company.getStructuredData({ founder = '[[Jane Doe]]; [[John Roe]]' })
	self:assertDeepEquals({ 'Jane Doe', 'John Roe' }, data['Founder'])
end

function suite:testStructuredParentIsPageTarget()
	-- Page properties store the link TARGET, not the label.
	self:assertEquals('Foo Corp', company.getStructuredData({ parent = '[[Foo Corp]]' })['Parent company'])
	self:assertEquals(
		'Roberts Space Industries',
		company.getStructuredData({ parent = '[[Roberts Space Industries|RSI]]' })['Parent company']
	)
end

function suite:testStructuredPredecessorSuccessorArePageLists()
	-- Predecessor/Successor are multi-value (mergers/splits): semicolon-split,
	-- each item's link target, like Founder/Subsidiaries.
	local data = company.getStructuredData({
		predecessor = '[[Aegis Macrocomputing]]; [[Dynamic Production Systems]]',
		successor = '[[New Co]]',
	})
	self:assertDeepEquals({ 'Aegis Macrocomputing', 'Dynamic Production Systems' }, data['Predecessor'])
	self:assertDeepEquals({ 'New Co' }, data['Successor'])
end

function suite:testStructuredFounderTargetsAndTrims()
	local data = company.getStructuredData({ founder = ' [[Jane Doe]] ; [[John Roe|Johnny]] ' })
	self:assertDeepEquals({ 'Jane Doe', 'John Roe' }, data['Founder'])
end

function suite:testStructuredHeadquartersSystemPerHq()
	-- One system per ';'-separated HQ: the last wikilink of each segment (the
	-- convention is "place, …, system"). Non-link prose is ignored.
	local data = company.getStructuredData({
		headquarters = '332 Yedilin Blvd, [[Nova Kyiv]], [[Terra (planet)|Terra]], [[Terra system|Terra]]; [[MacArthur]], [[Killian]]',
	})
	self:assertDeepEquals({ 'Terra system', 'Killian' }, data['Headquarters'])
end

function suite:testStructuredHeadquartersNoLinksOmitted()
	self:assertEquals(nil, company.getStructuredData({ headquarters = 'Somewhere unlinked' })['Headquarters'])
end

function suite:testStructuredAreaServedStoresPageTargets()
	-- Area served is a Page list: semicolon-split, each item's link TARGET stored
	-- (every served place is queryable, not collapsed to a system like HQ).
	local data = company.getStructuredData({ areaserved = '[[Lorville]]; [[Hurston]]' })
	self:assertDeepEquals({ 'Lorville', 'Hurston' }, data['Area served'])
end

function suite:testStructuredAreaServedSingleTarget()
	local data = company.getStructuredData({ areaserved = '[[Crusader]]' })
	self:assertDeepEquals({ 'Crusader' }, data['Area served'])
end

function suite:testStructuredAreaServedPipedTargets()
	-- Page targets, not labels: [[Target|Label]] -> Target.
	local data = company.getStructuredData({
		areaserved = '[[Stanton system|Stanton]]; [[microTech (planet)|microTech]]',
	})
	self:assertDeepEquals({ 'Stanton system', 'microTech (planet)' }, data['Area served'])
end

function suite:testStructuredAreaServedAbsentWhenEmpty()
	self:assertEquals(nil, company.getStructuredData({ name = 'X' })['Area served'])
end

function suite:testStructuredFoundedStoresCleanYear()
	-- The editor passes a clean year, so SMW stores the year (not rendered output).
	self:assertEquals('2554', company.getStructuredData({ founded = '2554' })['Founded'])
end

function suite:testStructuredRaceDefaultsAndCodeResolves()
	local data = company.getStructuredData({ name = 'Aegis Dynamics' })
	self:assertEquals('Human', data['Race'])
	self:assertEquals('AEGS', data['Manufacturer code'])
end

function suite:testStructuredOmitsDisplayOnlyAndEmpty()
	local data = company.getStructuredData({ name = 'X', fate = 'Acquired', allies = '[[Y]]' })
	self:assertEquals(nil, data['Fate'])
	self:assertEquals(nil, data['Allies'])
	self:assertEquals(nil, data['Headquarters'])
end

-- getShortDescription
function suite:testShortDescWithIndustry()
	self:assertEquals(
		'Banu company in the trade industry',
		company.getShortDescription({ race = 'Banu', industry = 'Trade' })
	)
end

function suite:testShortDescWithoutIndustry()
	self:assertEquals('Human company in Star Citizen', company.getShortDescription({}))
end

function suite:testShortDescWithWikilinkedIndustry()
	-- lcfirst is a no-op on '[' then delink: '[[Mining]]' -> 'Mining' (capital kept)
	self:assertEquals('Human company in the Mining industry', company.getShortDescription({ industry = '[[Mining]]' }))
end

function suite:testShortDescTrimsIndustry()
	self:assertEquals('Human company in the trade industry', company.getShortDescription({ industry = '  Trade  ' }))
end

function suite:testShortDescUsesFirstIndustry()
	-- With multiple industries the description uses only the first (primary) one.
	self:assertEquals(
		'Human company in the weapons manufacture industry',
		company.getShortDescription({ industry = 'Weapons manufacture; Munitions' })
	)
end

-- getCategories
function suite:testCategoriesDefault()
	self:assertDeepEquals({ 'Companies', 'Human companies' }, company.getCategories({}))
end

function suite:testCategoriesByRace()
	self:assertDeepEquals({ 'Companies', 'Banu companies' }, company.getCategories({ race = 'Banu' }))
end

-- getHeader
function suite:testHeaderBasics()
	local h = company.getHeader({ name = 'Foo', image = 'Foo.png', imagebg = 'dark' })
	self:assertEquals('Foo', h.title)
	self:assertEquals('Company', h.subtitle)
	self:assertEquals('Foo.png', h.image.src)
	self:assertEquals('t-infobox-image--dark', h.image.class)
end

function suite:testHeaderNoImage()
	local h = company.getHeader({ name = 'Foo' })
	self:assertEquals(nil, h.image)
end

function suite:testHeaderImagebgLightAndUnknown()
	self:assertEquals('t-infobox-image--light', company.getHeader({ image = 'A.png', imagebg = 'light' }).image.class)
	self:assertEquals(nil, company.getHeader({ image = 'A.png', imagebg = 'zzz' }).image.class)
end

function suite:testHeaderEmptyNameFallsBackLikeNil()
	-- '' must fall back to the page title, same as nil (not produce an empty title).
	self:assertEquals(company.getHeader({}).title, company.getHeader({ name = '' }).title)
end

-- getContentSections
function suite:testContentSectionsEmptyHasOnlyTop()
	local sections = company.getContentSections({})
	self:assertEquals(1, #sections)
	self:assertEquals(nil, sections[1].label) -- top group is unlabelled / inline
	self:assertEquals(1, #sections[1].items)
	self:assertEquals('Race', sections[1].items[1].label)
end

function suite:testLabelledSectionsAreCollapsible()
	-- The labelled sections collapse; the unlabelled top group stays inline.
	local sections = company.getContentSections({ founder = '[[X]]', fate = 'Gone', parent = '[[Y]]' })
	for _, section in ipairs(sections) do
		if section.label then
			self:assertTrue(section.collapsible)
		end
	end
end

function suite:testContentSectionsHasNoManufacturerCode()
	-- Manufacturer code moved to the Metadata section; never a content row.
	local sections = company.getContentSections({ name = 'Aegis Dynamics' })
	for _, section in ipairs(sections) do
		for _, item in ipairs(section.items or {}) do
			self:assertNotEquals('Manufacturer code', item.label)
		end
	end
end

-- getMetadataSection
function suite:testMetadataSectionPresentForManufacturer()
	local s = company.getMetadataSection({ name = 'Aegis Dynamics' })
	self:assertEquals('Metadata', s.label)
	self:assertTrue(s.collapsible)
	self:assertTrue(s.collapsed)
	self:assertEquals('Manufacturer code', s.items[1].label)
	self:assertEquals('AEGS', s.items[1].content)
end

function suite:testMetadataSectionAbsentForNonManufacturer()
	self:assertEquals(nil, company.getMetadataSection({ name = "Big Benny's" }))
	self:assertEquals(nil, company.getMetadataSection({}))
end

function suite:testSectionsIncludesMetadataForManufacturer()
	local labels = {}
	for _, s in ipairs(company.getSections({ name = 'Aegis Dynamics' })) do
		if s.label then
			labels[s.label] = true
		end
	end
	self:assertTrue(labels['Metadata'])
end

function suite:testContentSectionsDropsEmptyGroups()
	local sections = company.getContentSections({ founder = '[[X]]' })
	self:assertEquals(2, #sections)
	self:assertEquals('People', sections[2].label)
end

function suite:testContentSectionsDropsEmptyRows()
	local sections = company.getContentSections({ industry = 'Mining' })
	self:assertEquals(2, #sections[1].items)
	self:assertEquals('Industry', sections[1].items[1].label)
	self:assertEquals('Race', sections[1].items[2].label)
end

-- getExternalSitesSection
function suite:testExternalSitesPresent()
	local s = company.getExternalSitesSection({ portfoliourl = 'https://example.com/p' })
	self:assertEquals('External sites', s.label)
	self:assertTrue(s.collapsible)
	self:assertTrue(s.collapsed)
	self:assertEquals('Portfolio', s.items[1].label)
	self:assertEquals('[https://example.com/p RSI Portfolio]', s.items[1].content)
end

function suite:testExternalSitesAbsent()
	self:assertEquals(nil, company.getExternalSitesSection({}))
end

-- getSections (no galactapediaurl -> no frame/ButtonLua call)
function suite:testSectionsAppendsExternalNoFooter()
	local sections = company.getSections({ portfoliourl = 'https://example.com/p' })
	local last = sections[#sections]
	self:assertEquals('External sites', last.label)
end

function suite:testSectionsEmptyIsJustContent()
	-- {} -> only the content sections (top group with Race); no external/footer.
	self:assertEquals(1, #company.getSections({}))
end

-- multi-value display (semicolon -> Module:list unbulleted list). The test
-- harness stubs Module:list.makeList to a plain <ul><li>…</li></ul>; the real
-- list markup (plainlist div, hanging indent) is verified on-wiki / in-browser.
-- Assert via containment (plain=true), not exact HTML: the real Module:list
-- wraps items in <div class="plainlist"><ul>…, which the test stub does not, so
-- only the item content + the <li> structure are stable across both.
function suite:testMultiListRendersUnbulletedList()
	local content =
		findItem(company.getContentSections({ products = '[[Fighter]]s; [[Capital ship]]s' }), 'Products').content
	self:assertStringContains('<li', content, true)
	self:assertStringContains('[[Fighter]]s', content, true)
	self:assertStringContains('[[Capital ship]]s', content, true)
end

function suite:testMultiListSingleItemPlain()
	local sections = company.getContentSections({ products = '[[Fighter]]s' })
	self:assertEquals('[[Fighter]]s', findItem(sections, 'Products').content)
end

function suite:testMultiListKeepsPipedLinks()
	-- Items pass to Module:list as Lua values, so piped links are not mangled
	-- (no {{!}} escaping needed, unlike a wikitext template invocation).
	local content = findItem(company.getContentSections({ products = '[[A|B]]; [[C]]' }), 'Products').content
	self:assertStringContains('[[A|B]]', content, true)
	self:assertStringContains('[[C]]', content, true)
end

function suite:testHeadquartersListsMultipleHqs()
	-- Semicolon separates distinct HQs; the comma WITHIN an HQ is preserved.
	local content = findItem(
		company.getContentSections({ headquarters = '[[Terra]]; [[MacArthur]], [[Killian]]' }),
		'Headquarters'
	).content
	self:assertStringContains('<li', content, true)
	self:assertStringContains('[[Terra]]', content, true)
	self:assertStringContains('[[MacArthur]], [[Killian]]', content, true)
end

function suite:testAreaServedListsMultiplePlaces()
	-- Semicolon separates distinct served places; renders as a list (like HQ).
	local content =
		findItem(company.getContentSections({ areaserved = '[[Lorville]]; [[New Babbage]]' }), 'Area served').content
	self:assertStringContains('<li', content, true)
	self:assertStringContains('[[Lorville]]', content, true)
	self:assertStringContains('[[New Babbage]]', content, true)
end

function suite:testAreaServedSinglePlacePlain()
	local sections = company.getContentSections({ areaserved = '[[Crusader]]' })
	self:assertEquals('[[Crusader]]', findItem(sections, 'Area served').content)
end

-- founded display (clean year -> {{Start date and age}}; other -> as-is)
function suite:testFoundedDisplayWrapsYear()
	local sections = company.getContentSections({ founder = '[[X]]', founded = '2554' })
	self:assertEquals('{{Start date and age|2554|sctime=yes}}', findItem(sections, 'Founded').content)
end

function suite:testFoundedDisplayPassesThroughNonYear()
	local sections = company.getContentSections({ founder = '[[X]]', founded = 'Unknown' })
	self:assertEquals('Unknown', findItem(sections, 'Founded').content)
end

return suite
