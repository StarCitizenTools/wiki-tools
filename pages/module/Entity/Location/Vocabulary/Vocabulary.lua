require('strict')

--- @module Entity/Location/Vocabulary
--- The RSI starmap's vocabularies as the wiki names them: affiliations, and
--- system, star, body and asteroid-formation types, each with the label, index
--- page and category the wiki uses, plus the resolvers that map a starmap value
--- or an editor's wording onto an entry. Shared by the Location leaves and
--- Module:SystemMap.

local editorial = require('Module:Entity/Editorial')

local p = {}

--- RSI starmap affiliation code (lowercased) → display data. `label` is the
--- display/link name, ported from the legacy Module:System/i18n.json
--- (val_affiliation_*); every label is an existing wiki page, so callers may
--- link them as [[label]]. `short` (falling back to label) is the compact
--- form used in short descriptions AND stored as the `Affiliation` value —
--- it matches the vocabulary the ~266 pre-Entity pages already store
--- ('UEE', 'Unclaimed'), so queries keep one bucket.
p.AFFILIATIONS = {
	uee = { label = 'United Empire of Earth', short = 'UEE' },
	unc = { label = 'Unclaimed' },
	banu = { label = 'Banu Protectorate' },
	xian = { label = "Xi'an Empire" },
	vncl = { label = 'Vanduul' },
	dev = { label = 'Developing' },
}

--- First affiliation entry for a starmap record, or nil. The single accessor
--- every consumer (link row, categories, structured data, short description) goes
--- through.
--- @param starsystem table|nil
--- @return { label: string, short: string|nil }|nil
function p.affiliationEntry(starsystem)
	local affiliation = type(starsystem) == 'table'
			and type(starsystem.affiliation) == 'table'
			and starsystem.affiliation[1]
		or nil
	local code = affiliation and type(affiliation.code) == 'string' and affiliation.code:lower() or nil
	return code and p.AFFILIATIONS[code] or nil
end

--- Editorial affiliation text → an AFFILIATIONS-shaped entry. Canonical names
--- resolve to their table entry, matched on code, label or short after
--- normalizing case and punctuation, so the legacy arg spellings land in one
--- bucket ('Xi'An' → the xian entry, 'UEE' → uee). Anything else passes
--- through as free text: the starmap vocabulary has no code for the
--- affiliations only lore knows (Kr'Thak, Unknown), and the legacy template
--- accepted them, so the kind must too. A free-text entry keeps the editor's
--- markup for display (they choose whether [[Kr'Thak]] links; auto-linking
--- would paint 'Unknown' red) while `label` carries the delinked text for the
--- category and the stored value.
--- @param text any
--- @return { label: string, short: string|nil, display: string|nil }|nil
function p.affiliationFromText(text)
	if type(text) ~= 'string' or mw.text.trim(text) == '' then
		return nil
	end
	text = mw.text.trim(text)
	local plain = editorial.toStoredValue(text)
	local key = plain:lower():gsub('[^%w]', '')
	for code, entry in pairs(p.AFFILIATIONS) do
		local label = entry.label:lower():gsub('[^%w]', '')
		local short = entry.short and entry.short:lower():gsub('[^%w]', '') or nil
		if key == code or key == label or key == short then
			return entry
		end
	end
	return { label = plain, display = text }
end

--- RSI starmap system type → infobox display label + browse category. The
--- category names match the live category tree, which kept the legacy
--- "Single Star" casing.
p.SYSTEM_TYPES = {
	SINGLE_STAR = { label = 'Single star system', category = 'Single Star systems' },
	BINARY = { label = 'Binary star system', category = 'Binary systems' },
	-- The live tree kept the legacy "Trinary Star" casing (Category:Trinary
	-- systems does not exist). Latent until the no-record trinary pages
	-- (GJ 667, UDS-2943-01-22) migrated: no starmap-backed system is trinary.
	TRINARY = { label = 'Trinary star system', category = 'Trinary Star systems' },
}

--- Editorial system-type text → normalized starmap code + SYSTEM_TYPES entry.
--- The legacy {{System}} pages hand-set the raw codes with case drift
--- ('SINGLE_STAR', 'TRINARY', 'Trinary'), so normalize case and separators
--- before the lookup. Unrecognized text resolves to nothing: a typo'd code
--- must not invent a type row, a category, or a stored value.
--- @param text any
--- @return string|nil code normalized starmap code ('TRINARY')
--- @return { label: string, category: string }|nil entry
function p.systemTypeEntry(text)
	if type(text) ~= 'string' or text == '' then
		return nil, nil
	end
	local code = mw.text.trim(text):upper():gsub('[%s%-]+', '_')
	local entry = p.SYSTEM_TYPES[code]
	if not entry then
		return nil, nil
	end
	return code, entry
end

--- RSI starmap `sub_type.name` → star vocabulary: `classification` is the star
--- page's subtitle and stored value, `label` (default: classification) the
--- compact form the system's "Star type" row shows, `page` (default:
--- classification) the index page both link to, `category` the spectral-type
--- category. All four are spelt alike, hyphenated as the wiki's own page titles
--- and Wikipedia have it.
---
--- `maxRadiusKm` is declared only where the physics pins the size down, because
--- Tanga's white dwarf carries 58,460,000 km — byte-identical to La'uo's M
--- giant, so a copy-paste — and would otherwise render as an 84-solar-radius
--- white dwarf. Main-sequence and giant ranges overlap too much to police.
---
--- 'Stellar' is black-hole vocabulary, not a star class: the ARK uses it as the
--- sub_type of its one BLACKHOLE-typed object (Tamsa).
---
--- Every white dwarf the ARK serves is `Degenerate-A`, and that letter is NOT
--- the temperature class the main-sequence letters are — on a degenerate
--- remnant it denotes atmospheric composition. "A-type white dwarf" would
--- invite exactly that confusion, so the class is simply "White dwarf".
p.STAR_TYPES = {
	['Main Sequence-Dwarf-O'] = {
		classification = 'O-type main-sequence star',
		label = 'O-type main-sequence',
		category = 'O-type main-sequence stars',
	},
	['Main Sequence-Dwarf-B'] = {
		classification = 'B-type main-sequence star',
		label = 'B-type main-sequence',
		category = 'B-type main-sequence stars',
	},
	['Main Sequence-Dwarf-A'] = {
		classification = 'A-type main-sequence star',
		label = 'A-type main-sequence',
		category = 'A-type main-sequence stars',
	},
	['Main Sequence-Dwarf-F'] = {
		classification = 'F-type main-sequence star',
		label = 'F-type main-sequence',
		category = 'F-type main-sequence stars',
	},
	['Main Sequence-Dwarf-G'] = {
		classification = 'G-type main-sequence star',
		label = 'G-type main-sequence',
		category = 'G-type main-sequence stars',
	},
	['Main Sequence-Dwarf-K'] = {
		classification = 'K-type main-sequence star',
		label = 'K-type main-sequence',
		category = 'K-type main-sequence stars',
	},
	['Main Sequence-Dwarf-M'] = {
		classification = 'M-type main-sequence star',
		label = 'M-type main-sequence',
		category = 'M-type main-sequence stars',
	},
	['Giants-Giant-M'] = { classification = 'M-type giant', category = 'M-type giants' },
	['White Dwarf-Degenerate-A'] = {
		classification = 'White dwarf',
		category = 'White dwarfs',
		maxRadiusKm = 20000,
	},
	Subgiant = {
		classification = 'Subgiant star',
		label = 'Subgiant',
		page = 'Subgiant',
		category = 'Subgiants',
	},
	Neutron = { classification = 'Neutron star', category = 'Neutron stars', maxRadiusKm = 50 },
	Variable = { classification = 'Variable star', category = 'Variable stars' },
	Stellar = { classification = 'Stellar black hole', page = 'Black hole', category = 'Black holes' },
}

--- RSI starmap planet `sub_type.name` → body vocabulary, the planet counterpart
--- of STAR_TYPES. `classification` doubles as the index page title, which is why
--- no entry needs a separate `page`: every one of these 22 titles exists in
--- Category:Planet types. Their categories sit under Category:Planets except
--- Dwarf planets and Protoplanets, which the wiki files under Planetoids
--- instead, so a query must not assume the type tree hangs off Planets.
--- The ARK spells its sub_types in Title Case while the wiki uses sentence case
--- ('Smog Planet' → 'Smog planet'), so these cannot be derived from the ARK
--- string: they are transcribed from the live page and category names.
--- 'Artificial', 'Super Jupiter' and 'Terrestrial Rocky' are the three the ARK
--- does not name the way the wiki does at all. Moons carry a uniform
--- 'Planetary Moon' sub_type and so have no type tree; the Body leaf handles
--- them from the record type instead.
p.BODY_TYPES = {
	['Artificial'] = { classification = 'Artificial planet', category = 'Artificial planets' },
	['Carbon Planet'] = { classification = 'Carbon planet', category = 'Carbon planets' },
	['Chthonian Planet'] = { classification = 'Chthonian planet', category = 'Chthonian planets' },
	['Coreless Planet'] = { classification = 'Coreless planet', category = 'Coreless planets' },
	['Desert Planet'] = { classification = 'Desert planet', category = 'Desert planets' },
	['Dwarf Planet'] = { classification = 'Dwarf planet', category = 'Dwarf planets' },
	['Evaporating Planet'] = { classification = 'Evaporating planet', category = 'Evaporating planets' },
	['Gas Dwarf'] = { classification = 'Gas dwarf', category = 'Gas dwarfs' },
	['Gas Giant'] = { classification = 'Gas giant', category = 'Gas giants' },
	['Ice Giant'] = { classification = 'Ice giant', category = 'Ice giants' },
	['Ice Planet'] = { classification = 'Ice planet', category = 'Ice planets' },
	['Iron Planet'] = { classification = 'Iron planet', category = 'Iron planets' },
	['Lava Planet'] = { classification = 'Lava planet', category = 'Lava planets' },
	['Mesoplanet'] = { classification = 'Mesoplanet', category = 'Mesoplanets' },
	['Ocean Planet'] = { classification = 'Ocean planet', category = 'Ocean planets' },
	['Protoplanet'] = { classification = 'Protoplanet', category = 'Protoplanets' },
	['Puffy Planet'] = { classification = 'Puffy planet', category = 'Puffy planets' },
	['Rogue Planet'] = { classification = 'Rogue planet', category = 'Rogue planets' },
	['Smog Planet'] = { classification = 'Smog planet', category = 'Smog planets' },
	['Super Jupiter'] = { classification = 'Super-Jupiter', category = 'Super-Jupiters' },
	['Super-Earth'] = { classification = 'Super-Earth', category = 'Super-Earths' },
	['Terrestrial Rocky'] = { classification = 'Terrestrial rocky planet', category = 'Terrestrial rocky planets' },
}

--- The STAR_TYPES entry for a celestial object's sub_type, accepting either the
--- sub_type table the starmap serves or its bare name. nil for an unmapped or
--- absent class — callers decide whether that means the raw upstream name
--- (the system's star-type row) or no claim at all (the star page's subtitle).
--- @param subType table|string|nil
--- @return { classification: string, label: string|nil, category: string }|nil
function p.starTypeEntry(subType)
	local name = type(subType) == 'table' and subType.name or subType
	if type(name) ~= 'string' or name == '' then
		return nil
	end
	return p.STAR_TYPES[name]
end

--- The compact "Star type" label for a sub_type: the vocabulary's short form,
--- its classification where it has none, else the raw upstream name — an
--- unmapped ARK class degrades to a visible string instead of vanishing, and
--- self-heals once STAR_TYPES learns it.
--- @param subType table|string|nil
--- @return string|nil
function p.starTypeLabel(subType)
	local entry = p.starTypeEntry(subType)
	if entry then
		return entry.label or entry.classification
	end
	local name = type(subType) == 'table' and subType.name or subType
	return type(name) == 'string' and name ~= '' and name or nil
end

--- A star or body type linked to its index page. `text` is the caller's own
--- wording (the leaf's classification, the system row's label, an editor's
--- phrasing), so one target serves every surface. Plain text when the entry
--- names no page, which keeps an unmapped ARK class from linking at nothing.
--- @param entry table|nil a STAR_TYPES or BODY_TYPES entry
--- @param text string|nil display wording
--- @return string|nil
function p.starTypeLink(entry, text)
	if type(text) ~= 'string' or text == '' then
		return nil
	end
	local page = entry and (entry.page or entry.classification) or nil
	if type(page) ~= 'string' or page == '' then
		return text
	end
	if page == text then
		return '[[' .. page .. ']]'
	end
	return '[[' .. page .. '|' .. text .. ']]'
end

--- The BODY_TYPES entry for a planet's sub_type, accepting the sub_type table or
--- its bare name. nil for a moon (uniform 'Planetary Moon', no type tree) and
--- for an unmapped class.
--- @param subType table|string|nil
--- @return { classification: string, category: string }|nil
function p.bodyTypeEntry(subType)
	local name = type(subType) == 'table' and subType.name or subType
	if type(name) ~= 'string' or name == '' then
		return nil
	end
	return p.BODY_TYPES[name]
end

--- RSI starmap `sub_type.name` → asteroid-formation vocabulary, the third of
--- these tables. `classification` is the display noun and doubles as the index
--- page title; `category` is the wiki's own, which does NOT follow the ARK's
--- wording in any of the three cases and cannot be derived from it:
--- `Planetary Ring` files under 'Planetary ring systems', the category the ring
--- pages actually carry, and the ARK says 'System' where the wiki says
--- 'Asteroid'.
---
--- All three sit under Category:Asteroid Formations, the container. No entry
--- here names it, because a page belongs in its own leaf category; only
--- getTypeInfo's fallback emits it, for an object no entry resolves.
---
--- Every entry names `page` because this family has ONE concept page, not the
--- per-type index pages planets and stars have: 'Asteroid belt', 'Asteroid
--- field' and 'Planetary ring system' are all redlinks, and 'Asteroid cluster'
--- is itself a redirect to 'Asteroid formation'. Without `page` the subtitle
--- would link at nothing on every page this leaf renders.
p.BELT_TYPES = {
	['System Belt'] = {
		classification = 'Asteroid belt',
		category = 'Asteroid belts',
		page = 'Asteroid formation',
	},
	['System Cluster'] = {
		classification = 'Asteroid cluster',
		category = 'Asteroid clusters',
		page = 'Asteroid formation',
	},
	-- 'Planetary ring system', not 'Planetary ring': the wording all ten pages
	-- already carry, and the exact singular of their category.
	['Planetary Ring'] = {
		classification = 'Planetary ring system',
		category = 'Planetary ring systems',
		page = 'Asteroid formation',
	},
}

--- The ARK object type to read when an object carries no sub_type. Only
--- ASTEROID_BELT ever lacks one, on 3 objects against the 55 that name 'System
--- Belt', so the token names the class rather than inventing it. Every
--- ASTEROID_FIELD names a sub_type, which is why none is mapped here.
local BELT_OBJECT_TYPE_CLASS = { ASTEROID_BELT = 'System Belt' }

--- The BELT_TYPES entry for a starmap object, from its sub_type where it has
--- one and its bare type token otherwise. Accepts the sub_type table or its
--- name. nil for an object with neither, which keeps the bare kind noun.
--- @param subType table|string|nil
--- @param objectType string|nil the object's ARK `type`, read only without a sub_type
--- @return { classification: string, category: string, page: string }|nil
function p.beltTypeEntry(subType, objectType)
	local name = type(subType) == 'table' and subType.name or subType
	if type(name) ~= 'string' or name == '' then
		name = type(objectType) == 'string' and BELT_OBJECT_TYPE_CLASS[objectType] or nil
	end
	if type(name) ~= 'string' or name == '' then
		return nil
	end
	return p.BELT_TYPES[name]
end

--- The BELT_TYPES entry an editor's classification text names, matching the
--- classification, the ARK's own spelling and the singular of the category, the
--- same three forms bodyTypeFromText accepts.
--- @param text string|nil
--- @return { classification: string, category: string, page: string }|nil
function p.beltTypeFromText(text)
	return p.vocabularyFromText(p.BELT_TYPES, text)
end

--- The BODY_TYPES entry an editor's classification text names, the body
--- counterpart of starTypeFromText. It matches the wiki classification, the
--- ARK's own spelling and the singular of the category name, so 'Gas giant',
--- 'Gas Giant' and 'Terrestrial rocky planet' all resolve. The category form
--- is the one the corpus actually writes for several classes.
---
--- Without this a page whose ARK object is missing lands in no type category
--- while its subtitle still reads the class.
--- @param text string|nil
--- @return { classification: string, category: string }|nil
function p.bodyTypeFromText(text)
	return p.vocabularyFromText(p.BODY_TYPES, text)
end

--- The entry an editor's wording names in one of these vocabularies, matching
--- the classification, the ARK's own spelling, or the singular of the category.
--- Comparison is on alphanumerics only, so punctuation and case do not matter.
--- @param vocab table one of BODY_TYPES / BELT_TYPES / STAR_TYPES
--- @param text string|nil
--- @return table|nil
function p.vocabularyFromText(vocab, text)
	if type(text) ~= 'string' or mw.text.trim(text) == '' then
		return nil
	end
	local key = editorial.toStoredValue(mw.text.trim(text)):lower():gsub('[^%w]', '')
	for arkName, entry in pairs(vocab) do
		-- The category singular is parenthesised because gsub also returns a
		-- count, which the constructor would otherwise take as a fourth form.
		local forms = { entry.classification, arkName, (entry.category:gsub('s$', '')) }
		for _, form in ipairs(forms) do
			if key == form:lower():gsub('[^%w]', '') then
				return entry
			end
		end
	end
	return nil
end

--- Editorial classification text → a STAR_TYPES entry, matched on either
--- wording after normalizing case and punctuation. The reverse of starTypeEntry,
--- and the only way a record-less star page reaches a spectral-type category.
--- Deliberately exact rather than fuzzy: Pyro's editorial "K-type main sequence
--- flare star" must NOT resolve here, because the starmap already classes Pyro
--- and the record wins the category (see the Star leaf's getCategories).
--- @param text any
--- @return { classification: string, label: string|nil, category: string }|nil
function p.starTypeFromText(text)
	if type(text) ~= 'string' or mw.text.trim(text) == '' then
		return nil
	end
	local key = editorial.toStoredValue(mw.text.trim(text)):lower():gsub('[^%w]', '')
	for _, entry in pairs(p.STAR_TYPES) do
		local classification = entry.classification:lower():gsub('[^%w]', '')
		local label = entry.label and entry.label:lower():gsub('[^%w]', '') or nil
		if key == classification or key == label then
			return entry
		end
	end
	return nil
end

--- The system-type entry for a page: the editorial value when one resolved
--- (hand value beats starmap, the house rule), else the starmap record's.
--- Single accessor so the type row, categories, structured data and short description
--- cannot disagree.
--- @param starsystem table|nil
--- @param resolved table|nil
--- @return string|nil code
--- @return { label: string, category: string }|nil entry
function p.resolveSystemType(starsystem, resolved)
	local code, entry = p.systemTypeEntry(editorial.view(resolved):value('systemtype'))
	if entry then
		return code, entry
	end
	-- The record's raw code is returned even when SYSTEM_TYPES has no entry
	-- for it: an unmapped code still stores faithfully (a future ARK type
	-- should degrade to no label/category, not vanish from the store).
	local recordType = type(starsystem) == 'table' and starsystem.type or nil
	return recordType, recordType and p.SYSTEM_TYPES[recordType] or nil
end

--- The affiliation entry for a page: editorial first (same precedence as
--- resolveSystemType), else the starmap record's.
--- @param starsystem table|nil
--- @param resolved table|nil
--- @return { label: string, short: string|nil, display: string|nil }|nil
function p.resolveAffiliation(starsystem, resolved)
	return p.affiliationFromText(editorial.view(resolved):value('affiliation')) or p.affiliationEntry(starsystem)
end

--- The affiliation to STORE: the compact token, from the FIRST <br>-delimited
--- segment of the page's own value, else the system's.
---
--- The split is only for the stored side. A page may name two affiliations in
--- one arg ('[[Vanduul]]<br/>Independent' on Armitage) against a single-valued
--- column, and Editorial.toStoredValue strips the tag with no separator, so the
--- raw value would store as the unqueryable 'VanduulIndependent'. The DISPLAY
--- row keeps both, through resolveAffiliation, because the page said both.
--- @param starsystem table|nil
--- @param resolved table|nil
--- @return string|nil
function p.storedAffiliation(starsystem, resolved)
	local stated = editorial.view(resolved):value('affiliation')
	if type(stated) == 'string' then
		stated = mw.text.split(stated, '<%s*[bB][rR]%s*/?%s*>')[1]
	end
	local entry = p.affiliationFromText(stated) or p.affiliationEntry(starsystem)
	return entry and (entry.short or entry.label) or nil
end

return p
