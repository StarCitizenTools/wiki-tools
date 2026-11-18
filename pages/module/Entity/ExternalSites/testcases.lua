require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local ExternalSites = require('Module:Entity/ExternalSites')

local suite = ScribuntoUnit:new()

--- @param site string
--- @param url string
--- @return EntityExternalSite
local function entry(site, url)
	return { site = site, url = url }
end

--- @param html string
--- @param needle string
--- @return integer
local function count(html, needle)
	local n, from = 0, 1
	while true do
		local at = html:find(needle, from, true)
		if not at then
			return n
		end
		n, from = n + 1, at + #needle
	end
end

--- Asserts that `first` occurs before `second` in `html`.
--- @param html string
--- @param first string
--- @param second string
function suite:assertBefore(html, first, second)
	local a, b = html:find(first, 1, true), html:find(second, 1, true)
	self:assertTrue(a ~= nil, first .. ' is missing')
	self:assertTrue(b ~= nil, second .. ' is missing')
	self:assertTrue(a < b, first .. ' should come before ' .. second)
end

-- ── fromDefs ────────────────────────────────────────────────────────────────

function suite:testFromDefsQueryEncodesTheValue()
	local entries = ExternalSites.fromDefs(
		{ { site = 'uex', format = 'https://x.example/?q=%s', data = 'name' } },
		{ name = 'P4-AR Rifle' }
	)
	self:assertDeepEquals({ entry('uex', 'https://x.example/?q=P4-AR+Rifle') }, entries)
end

function suite:testFromDefsArgListGivesOneEntryPerUrl()
	local entries = ExternalSites.fromDefs(
		{ { site = 'presentation', arg = 'presentation' } },
		{ presentation = { 'https://p1', 'https://p2' } }
	)
	self:assertDeepEquals({ entry('presentation', 'https://p1'), entry('presentation', 'https://p2') }, entries)
end

function suite:testFromDefsSkipsAbsentAndEmptyValues()
	local defs = {
		{ site = 'galactapedia', arg = 'galactapedia' },
		{ site = 'wikiapi', format = 'https://w.example/%s', data = 'uuid' },
	}
	self:assertDeepEquals({}, ExternalSites.fromDefs(defs, {}))
	self:assertDeepEquals({}, ExternalSites.fromDefs(defs, { galactapedia = '', uuid = '' }))
end

-- ── build ───────────────────────────────────────────────────────────────────

function suite:testNothingToShowGivesNeitherSection()
	local section, buttons = ExternalSites.build({})
	self:assertEquals(nil, section)
	self:assertEquals(nil, buttons)
end

function suite:testSectionIsCollapsedByDefault()
	local section = ExternalSites.build({ entry('erkul', 'https://e') })
	self:assertEquals('External sites', section.label)
	self:assertTrue(section.collapsible)
	self:assertTrue(section.collapsed)
end

function suite:testOfficialGroupComesBeforeCommunity()
	local section = ExternalSites.build({
		entry('erkul', 'https://e'),
		entry('pledgestore', 'https://p'),
	})
	self:assertBefore(section.content, 'Official', 'Community')
	self:assertBefore(section.content, 'https://p', 'https://e')
end

function suite:testRowsFollowTheRegistry()
	local section = ExternalSites.build({
		entry('sctradetools', 'https://s'),
		entry('itemfinder', 'https://i'),
		entry('uex', 'https://u'),
	})
	self:assertBefore(section.content, 'https://i', 'https://u')
	self:assertBefore(section.content, 'https://u', 'https://s')
end

function suite:testARowCarriesItsSiteTagline()
	local section = ExternalSites.build({ entry('erkul', 'https://e') })
	self:assertStringContains('[https://e Erkul]', section.content, true)
	self:assertStringContains('>Loadout and DPS calculator</span>', section.content, true)
end

function suite:testASiteWithoutATaglineHasNoTaglineLine()
	local section = ExternalSites.build({ entry('brochure', 'https://b') })
	self:assertEquals(0, count(section.content, 't-infobox-sites__tagline'))
end

function suite:testIssueCouncilEndsTheOfficialGroup()
	local section = ExternalSites.build({
		entry('issuecouncil', 'https://ic'),
		entry('erkul', 'https://e'),
		entry('pledgestore', 'https://p'),
	})
	self:assertBefore(section.content, 'Official', 'https://p')
	self:assertBefore(section.content, 'https://p', 'https://ic')
	self:assertBefore(section.content, 'https://ic', 'Community')
end

function suite:testAButtonSiteLeavesTheSection()
	local section, buttons = ExternalSites.build({
		entry('wikiapi', 'https://w'),
		entry('erkul', 'https://e'),
	})
	self:assertEquals(0, count(section.content, 'https://w'))
	self:assertStringContains(
		'[button Star Citizen Wiki API -> https://w (t-button--branded t-button--wiki-api)]',
		buttons.content,
		true
	)
	self:assertEquals(nil, buttons.label)
	self:assertEquals('t-infobox-section--sites-buttons', buttons.class)
end

function suite:testAButtonAloneGivesNoSection()
	local section, buttons = ExternalSites.build({ entry('wikiapi', 'https://w') })
	self:assertEquals(nil, section)
	self:assertTrue(buttons ~= nil)
end

function suite:testUnknownSiteIsDropped()
	local section, buttons = ExternalSites.build({ entry('nope', 'https://a') })
	self:assertEquals(nil, section)
	self:assertEquals(nil, buttons)
end

function suite:testAUrlIsListedOnce()
	local section = ExternalSites.build({
		entry('verseguide', 'https://v'),
		entry('verseguide', 'https://v'),
	})
	self:assertEquals(1, count(section.content, 'https://v'))
	self:assertStringContains('[https://v VerseGuide]', section.content, true)
end

function suite:testARepeatedSiteNumbersItsRows()
	local section = ExternalSites.build({
		entry('presentation', 'https://p1'),
		entry('qa', 'https://q'),
		entry('presentation', 'https://p2'),
	})
	self:assertStringContains('[https://p1 Presentation 1]', section.content, true)
	self:assertStringContains('[https://p2 Presentation 2]', section.content, true)
	self:assertStringContains('[https://q Q&A]', section.content, true)
	self:assertBefore(section.content, 'Presentation 2', 'Q&A')
end

function suite:testASpaceInAUrlIsEncoded()
	local section = ExternalSites.build({ entry('trailer', 'https://x.example/a b') })
	self:assertStringContains('[https://x.example/a%20b Trailer]', section.content, true)
end

function suite:testAnIconSizeOverridesTheDefault()
	local section = ExternalSites.build({ entry('brochure', 'https://b'), entry('pledgestore', 'https://p') })
	self:assertEquals(1, count(section.content, 'width: 20px'))
	self:assertEquals(1, count(section.content, 'width: 24px'))
end

function suite:testAMaskLogoRendersAsAMask()
	local section = ExternalSites.build({ entry('pledgestore', 'https://p') })
	self:assertStringContains('t-icon--mask', section.content, true)
end

return suite
