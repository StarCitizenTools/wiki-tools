require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Util = require('Module:Entity/Location/Util')

local suite = ScribuntoUnit:new()

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

function suite:testResolveLookupNamePrecedence()
	local f = Util._internal.resolveLookupName
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
	local f = Util._internal.plainKey
	self:assertEquals('stanton', f('Stanton System'))
	self:assertEquals('terra', f('Terra system'))
	self:assertEquals("kyuk'ya", f("Kyuk'ya"))
	self:assertEquals(nil, f(nil))
	self:assertEquals(nil, f(''))
	self:assertEquals(nil, f(' System'))
end

function suite:testPickStarsystemExactBeatsAliasBeatsFirst()
	local f = Util._internal.pickStarsystem
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

function suite:testGateEntrySystemFallsBackToDesignation()
	local f = Util.gateEntrySystem
	self:assertEquals('Pyro', f(jumpPointFixture())) -- record system wins
	self:assertEquals('Stanton', f({ celestialobject = { designation = 'Stanton - Nyx' } }))
	self:assertEquals(nil, f({ celestialobject = { designation = 'Malformed' } }))
	self:assertEquals(nil, f({}))
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
	local f = Util._internal.normalizeAggregates
	local record = starsystemFixture()
	record.aggregated.size = 0
	self:assertEquals(nil, f(record).aggregated.size)
end

function suite:testNormalizeAggregatesDropsNonPositiveOrUnparsableSize()
	local f = Util._internal.normalizeAggregates
	for _, bad in ipairs({ -1, '0', 'Unknown' }) do
		local record = starsystemFixture()
		record.aggregated.size = bad
		self:assertEquals(nil, f(record).aggregated.size)
	end
end

function suite:testNormalizeAggregatesKeepsRealSize()
	local f = Util._internal.normalizeAggregates
	self:assertEquals(4.85, f(starsystemFixture()).aggregated.size)
	-- Numeric strings are a legitimate measurement and survive untouched.
	local stringy = starsystemFixture()
	stringy.aggregated.size = '9.83'
	self:assertEquals('9.83', f(stringy).aggregated.size)
end

function suite:testNormalizeAggregatesToleratesMissingShapes()
	local f = Util._internal.normalizeAggregates
	self:assertEquals(nil, f(nil))
	self:assertEquals(nil, next(f({})))
	local noAggregate = { code = 'STANTON' }
	self:assertEquals('STANTON', f(noAggregate).code)
end

-- The stub block is dropped whole — a nonzero size in it is still noise, and the
-- population/economy sensors are the same template default.
function suite:testNormalizeAggregatesDropsWholeWithheldStub()
	local f = Util._internal.normalizeAggregates
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
	local aggregated = Util._internal.normalizeAggregates(record).aggregated
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
	local aggregated = Util._internal.normalizeAggregates(record).aggregated
	self:assertEquals(5.89, aggregated.size)
	self:assertEquals(7.21, aggregated.population)
end

-- Stars must not count as bodies: the stub claims one, so counting it would
-- disable the rule on every page it exists for.
function suite:testNormalizeAggregatesIgnoresStarsInBodyCount()
	local record = withheldStubFixture('M', 7)
	record.aggregated.stars = 1
	self:assertEquals(nil, Util._internal.normalizeAggregates(record).aggregated.size)
end

function suite:testSystemTypeEntryNormalizesLegacyCaseDrift()
	local f = Util.systemTypeEntry
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
		local code, entry = Util.systemTypeEntry(text)
		self:assertEquals(nil, code)
		self:assertEquals(nil, entry)
	end
end

-- The live tree's category is 'Trinary Star systems'; 'Trinary systems' does
-- not exist. Latent until GJ 667 / UDS-2943-01-22 migrated — no starmap-backed
-- system is trinary.
function suite:testTrinaryCategoryMatchesLiveTree()
	self:assertEquals('Trinary Star systems', Util.SYSTEM_TYPES.TRINARY.category)
end

function suite:testAffiliationFromTextMatchesCanonicalSpellings()
	-- Legacy arg spellings collapse into the canonical entries: matched on
	-- code, label or short after stripping case and punctuation.
	self:assertEquals("Xi'an Empire", Util.affiliationFromText("Xi'An").label)
	self:assertEquals('United Empire of Earth', Util.affiliationFromText('UEE').label)
	self:assertEquals('Banu Protectorate', Util.affiliationFromText('Banu Protectorate').label)
	self:assertEquals('Unclaimed', Util.affiliationFromText('Unclaimed').label)
	-- Canonical entries carry no display override: callers link the label.
	self:assertEquals(nil, Util.affiliationFromText('UEE').display)
end

function suite:testAffiliationFromTextFreeTextPassesThrough()
	-- The editor controls linking; label carries the delinked text for the
	-- category and the stored value.
	local krthak = Util.affiliationFromText("[[Kr'Thak]]")
	self:assertEquals("Kr'Thak", krthak.label)
	self:assertEquals("[[Kr'Thak]]", krthak.display)
	local unknown = Util.affiliationFromText('Unknown')
	self:assertEquals('Unknown', unknown.label)
	self:assertEquals('Unknown', unknown.display)
	self:assertEquals(nil, Util.affiliationFromText(''))
	self:assertEquals(nil, Util.affiliationFromText(nil))
end

function suite:testResolveSystemTypeEditorialBeatsRecord()
	local resolved = { systemtype = { value = 'Trinary', source = 'editorial' } }
	local code, entry = Util.resolveSystemType(starsystemFixture(), resolved)
	self:assertEquals('TRINARY', code)
	self:assertEquals('Trinary Star systems', entry.category)
end

function suite:testResolveSystemTypeKeepsUnmappedRecordCode()
	-- A future ARK code must still store faithfully: raw code, no entry.
	local record = starsystemFixture()
	record.type = 'BLACK_HOLE'
	local code, entry = Util.resolveSystemType(record, nil)
	self:assertEquals('BLACK_HOLE', code)
	self:assertEquals(nil, entry)
end

function suite:testResolveAffiliationEditorialBeatsRecord()
	local resolved = { affiliation = { value = 'Vanduul', source = 'editorial' } }
	self:assertEquals('Vanduul', Util.resolveAffiliation(starsystemFixture(), resolved).label)
	self:assertEquals('UEE', Util.resolveAffiliation(starsystemFixture(), nil).short)
end

-- The alias leak (user-reported): the celestial designation carries naming
-- forms that are NOT wiki page names — alias parentheticals, the Vanduul
-- catalogue form, and one bare legacy name. Rendering them produced
-- "[[Kyuk'ya (Indra) system]]": a red link, a bogus category and a junk
-- stored System value.
function suite:testSystemShortNameStripsStarmapDecorations()
	local f = Util.systemShortName
	self:assertEquals("Kyuk'ya", f("Kyuk'ya (Indra)"))
	self:assertEquals("Yā'mon", f("Yā'mon (Hadur) System"))
	self:assertEquals('Vulture', f('VS-9 "Vulture"'))
	self:assertEquals('Pyro', f('Pyro System')) -- unchanged
	self:assertEquals(nil, f(' System'))
end

-- ── Star vocabulary ────────────────────────────────────────────────────────

function suite:testStarTypeEntryAcceptsBothShapes()
	local entry = Util.starTypeEntry({ name = 'Main Sequence-Dwarf-G', type = 'STAR' })
	self:assertEquals('G-type main-sequence star', entry.classification)
	self:assertEquals('G-type main-sequence stars', entry.category)
	-- The bare name resolves identically, so callers may pass either.
	self:assertEquals(entry, Util.starTypeEntry('Main Sequence-Dwarf-G'))
	self:assertEquals(nil, Util.starTypeEntry(nil))
	self:assertEquals(nil, Util.starTypeEntry('Main Sequence-Dwarf-Q'))
end

-- The compact form the system infobox's star-type row shows, which is NOT the
-- classification wherever the two wordings differ.
function suite:testStarTypeLabel()
	local f = Util.starTypeLabel
	self:assertEquals('G-type main-sequence', f({ name = 'Main Sequence-Dwarf-G' }))
	self:assertEquals('Subgiant', f({ name = 'Subgiant' }))
	-- No short form declared: the classification carries the row.
	self:assertEquals('Neutron star', f({ name = 'Neutron' }))
	-- An unmapped ARK class degrades to its raw name rather than vanishing.
	self:assertEquals('Main Sequence-Dwarf-Q', f({ name = 'Main Sequence-Dwarf-Q' }))
	self:assertEquals(nil, f(nil))
end

-- Display, link target and category are spelt alike, and the seven
-- main-sequence pages the links point at exist under exactly these titles.
function suite:testStarTypeLink()
	local f = Util.starTypeLink
	local g = Util.starTypeEntry('Main Sequence-Dwarf-G')
	-- Page and text agree: a bare link, not a piped one repeating itself.
	self:assertEquals('[[G-type main-sequence star]]', f(g, 'G-type main-sequence star'))
	-- The system row's compact label pipes to the same page.
	self:assertEquals('[[G-type main-sequence star|G-type main-sequence]]', f(g, 'G-type main-sequence'))
	-- An entry whose page differs from its classification.
	local bh = Util.starTypeEntry('Stellar')
	self:assertEquals('[[Black hole|Stellar black hole]]', f(bh, bh.classification))
	-- No entry, or nothing to display: plain text, never an invented target.
	self:assertEquals('Main Sequence-Dwarf-Q', f(nil, 'Main Sequence-Dwarf-Q'))
	self:assertEquals(nil, f(g, nil))
	self:assertEquals(nil, f(g, ''))
end

-- The only route from a record-less page's editorial text to a category.
function suite:testStarTypeFromText()
	local f = Util.starTypeFromText
	self:assertEquals('K-type main-sequence stars', f('K-type main-sequence star').category)
	-- Matched on either wording, and case, punctuation and HYPHEN drift are
	-- normalized away — which is what lets the legacy pages' unhyphenated
	-- `| classification = K-type main sequence star` still resolve after the
	-- vocabulary hyphenated.
	self:assertEquals('K-type main-sequence stars', f('K-type main sequence star').category)
	self:assertEquals('K-type main-sequence stars', f('k-type Main Sequence').category)
	self:assertEquals('White dwarfs', f('[[White dwarf]]').category)
	-- Exact, not fuzzy: Pyro's elaborated text must NOT resolve here — the
	-- starmap already classes Pyro and the record owns the category.
	self:assertEquals(nil, f('K-type main-sequence flare star'))
	self:assertEquals(nil, f(''))
	self:assertEquals(nil, f(nil))
end

return suite
