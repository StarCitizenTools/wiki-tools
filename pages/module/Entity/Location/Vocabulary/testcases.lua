require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local locationVocabulary = require('Module:Entity/Location/Vocabulary')

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

-- The corpus writes several classes in the category's own wording, which is
-- neither the classification nor the ARK's spelling: 96 pages say 'Terrestrial
-- rocky planet' against a 'Terrestrial Rocky' sub_type.
function suite:testBodyTypeFromText()
	self:assertEquals('Gas giants', locationVocabulary.bodyTypeFromText('Gas giant').category)
	self:assertEquals('Gas giants', locationVocabulary.bodyTypeFromText('Gas Giant').category)
	self:assertEquals('Gas giants', locationVocabulary.bodyTypeFromText('[[Gas giant]]').category)
	self:assertEquals(
		'Terrestrial rocky planets',
		locationVocabulary.bodyTypeFromText('Terrestrial rocky planet').category
	)
	self:assertEquals('Terrestrial rocky planets', locationVocabulary.bodyTypeFromText('Terrestrial Rocky').category)
	self:assertEquals('Super-Earths', locationVocabulary.bodyTypeFromText('Super-Earth').category)
	self:assertEquals(nil, locationVocabulary.bodyTypeFromText('Natural satellite'))
	self:assertEquals(nil, locationVocabulary.bodyTypeFromText(''))
	self:assertEquals(nil, locationVocabulary.bodyTypeFromText(nil))
end

function suite:testSystemTypeEntryNormalizesLegacyCaseDrift()
	local f = locationVocabulary.systemTypeEntry
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
		local code, entry = locationVocabulary.systemTypeEntry(text)
		self:assertEquals(nil, code)
		self:assertEquals(nil, entry)
	end
end

-- The live tree's category is 'Trinary Star systems'; 'Trinary systems' does
-- not exist. Latent until GJ 667 / UDS-2943-01-22 migrated — no starmap-backed
-- system is trinary.
function suite:testTrinaryCategoryMatchesLiveTree()
	self:assertEquals('Trinary Star systems', locationVocabulary.SYSTEM_TYPES.TRINARY.category)
end

function suite:testAffiliationFromTextMatchesCanonicalSpellings()
	-- Legacy arg spellings collapse into the canonical entries: matched on
	-- code, label or short after stripping case and punctuation.
	self:assertEquals("Xi'an Empire", locationVocabulary.affiliationFromText("Xi'An").label)
	self:assertEquals('United Empire of Earth', locationVocabulary.affiliationFromText('UEE').label)
	self:assertEquals('Banu Protectorate', locationVocabulary.affiliationFromText('Banu Protectorate').label)
	self:assertEquals('Unclaimed', locationVocabulary.affiliationFromText('Unclaimed').label)
	-- Canonical entries carry no display override: callers link the label.
	self:assertEquals(nil, locationVocabulary.affiliationFromText('UEE').display)
end

function suite:testAffiliationFromTextFreeTextPassesThrough()
	-- The editor controls linking; label carries the delinked text for the
	-- category and the stored value.
	local krthak = locationVocabulary.affiliationFromText("[[Kr'Thak]]")
	self:assertEquals("Kr'Thak", krthak.label)
	self:assertEquals("[[Kr'Thak]]", krthak.display)
	local unknown = locationVocabulary.affiliationFromText('Unknown')
	self:assertEquals('Unknown', unknown.label)
	self:assertEquals('Unknown', unknown.display)
	self:assertEquals(nil, locationVocabulary.affiliationFromText(''))
	self:assertEquals(nil, locationVocabulary.affiliationFromText(nil))
end

function suite:testResolveSystemTypeEditorialBeatsRecord()
	local resolved = { systemtype = { value = 'Trinary', source = 'editorial' } }
	local code, entry = locationVocabulary.resolveSystemType(starsystemFixture(), resolved)
	self:assertEquals('TRINARY', code)
	self:assertEquals('Trinary Star systems', entry.category)
end

function suite:testResolveSystemTypeKeepsUnmappedRecordCode()
	-- A future ARK code must still store faithfully: raw code, no entry.
	local record = starsystemFixture()
	record.type = 'BLACK_HOLE'
	local code, entry = locationVocabulary.resolveSystemType(record, nil)
	self:assertEquals('BLACK_HOLE', code)
	self:assertEquals(nil, entry)
end

function suite:testResolveAffiliationEditorialBeatsRecord()
	local resolved = { affiliation = { value = 'Vanduul', source = 'editorial' } }
	self:assertEquals('Vanduul', locationVocabulary.resolveAffiliation(starsystemFixture(), resolved).label)
	self:assertEquals('UEE', locationVocabulary.resolveAffiliation(starsystemFixture(), nil).short)
end

function suite:testStarTypeEntryAcceptsBothShapes()
	local entry = locationVocabulary.starTypeEntry({ name = 'Main Sequence-Dwarf-G', type = 'STAR' })
	self:assertEquals('G-type main-sequence star', entry.classification)
	self:assertEquals('G-type main-sequence stars', entry.category)
	-- The bare name resolves identically, so callers may pass either.
	self:assertEquals(entry, locationVocabulary.starTypeEntry('Main Sequence-Dwarf-G'))
	self:assertEquals(nil, locationVocabulary.starTypeEntry(nil))
	self:assertEquals(nil, locationVocabulary.starTypeEntry('Main Sequence-Dwarf-Q'))
end

-- The compact form the system infobox's star-type row shows, which is NOT the
-- classification wherever the two wordings differ.
function suite:testStarTypeLabel()
	local f = locationVocabulary.starTypeLabel
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
	local f = locationVocabulary.starTypeLink
	local g = locationVocabulary.starTypeEntry('Main Sequence-Dwarf-G')
	-- Page and text agree: a bare link, not a piped one repeating itself.
	self:assertEquals('[[G-type main-sequence star]]', f(g, 'G-type main-sequence star'))
	-- The system row's compact label pipes to the same page.
	self:assertEquals('[[G-type main-sequence star|G-type main-sequence]]', f(g, 'G-type main-sequence'))
	-- An entry whose page differs from its classification.
	local bh = locationVocabulary.starTypeEntry('Stellar')
	self:assertEquals('[[Black hole|Stellar black hole]]', f(bh, bh.classification))
	-- No entry, or nothing to display: plain text, never an invented target.
	self:assertEquals('Main Sequence-Dwarf-Q', f(nil, 'Main Sequence-Dwarf-Q'))
	self:assertEquals(nil, f(g, nil))
	self:assertEquals(nil, f(g, ''))
end

-- The only route from a record-less page's editorial text to a category.
function suite:testStarTypeFromText()
	local f = locationVocabulary.starTypeFromText
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
