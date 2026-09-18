require('strict')

--- @module Entity/Location/Util
--- Location-internal shared helpers used by more than one Location leaf: the
--- starmap vocabulary (affiliation and system-type tables with their
--- resolvers), the system-name helpers, and the two starmap bridges the
--- leaves' enrich hooks call. NOT cross-kind (those live in
--- Module:Entity/Facet/Util) and NOT kind identity (Module:Entity/Location
--- owns matches / resolveSubtype).
---
--- For star systems the location record is thin; the substantive data lives in
--- the starmap-derived /api/starsystems endpoint. The two records share no
--- key, so attachStarsystem bridges by name and attaches the record as
--- apiData.starsystem — namespaced, never flat-merged: both payloads carry
--- colliding name/type/description/affiliation keys. Jump points and stars
--- bridge to the starmap differently: by the editor-supplied starmap code, to
--- the /api/celestial-objects endpoint, attached as apiData.celestialobject.
--- The two fetches are mutually exclusive by construction — a page resolves to
--- exactly one leaf, and no leaf calls both.

local api = require('Module:Entity/Api')
local editorial = require('Module:Entity/Editorial')
local meterBar = require('Module:MeterBar')

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

--- The celestial object in a starsystem payload whose code matches, or nil.
--- Codes are compared case-sensitively and whole: a starmap code is an exact
--- key, and prefix matching would collide (SOL.PLANETS.EARTH against a
--- hypothetical SOL.PLANETS.EARTHII).
--- @param starsystem table|nil
--- @param code string|nil
--- @return table|nil
function p.celestialByCode(starsystem, code)
	if type(starsystem) ~= 'table' or type(code) ~= 'string' or code == '' then
		return nil
	end
	local objects = starsystem.celestial_objects
	if type(objects) ~= 'table' then
		return nil
	end
	for _, obj in ipairs(objects) do
		if type(obj) == 'table' and obj.code == code then
			return obj
		end
	end
	return nil
end

--- 0-10 starmap sensor value → display text: one decimal, trailing .0 dropped
--- ("8.13" → "8.1/10", 10 → "10/10"). nil for missing, zero or non-numeric —
--- zero means "no reading" in the starmap data, not an actual rating.
--- @param value any
--- @return string|nil
function p.formatSensor(value)
	local n = tonumber(value)
	if not n or n <= 0 then
		return nil
	end
	local rounded = math.floor(n * 10 + 0.5) / 10
	return tostring(rounded) .. '/10'
end

--- Append a MeterBar sensor row as a full-width block item. Shared so a system
--- and the bodies inside it read their sensor rows the same way.
--- @param items EntityItemData[]
--- @param label string
--- @param value any
function p.appendSensorMeter(items, label, value)
	local text = p.formatSensor(value)
	if not text then
		return
	end
	items[#items + 1] = {
		content = meterBar.render({ label = label, value = tonumber(value), max = 10, text = text }),
		class = 't-infobox-item--block',
	}
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
	if type(text) ~= 'string' or mw.text.trim(text) == '' then
		return nil
	end
	local key = editorial.toStoredValue(mw.text.trim(text)):lower():gsub('[^%w]', '')
	for arkName, entry in pairs(p.BELT_TYPES) do
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
	if type(text) ~= 'string' or mw.text.trim(text) == '' then
		return nil
	end
	local key = editorial.toStoredValue(mw.text.trim(text)):lower():gsub('[^%w]', '')
	for arkName, entry in pairs(p.BODY_TYPES) do
		local forms = {
			entry.classification,
			arkName,
			-- Parenthesised: gsub also returns a count, which the constructor
			-- would otherwise take as a fourth form.
			(entry.category:gsub('s$', '')),
		}
		for _, form in ipairs(forms) do
			if key == form:lower():gsub('[^%w]', '') then
				return entry
			end
		end
	end
	return nil
end

--- The celestial object in a starsystem payload whose name matches, or nil.
--- `types` restricts the candidates to those ARK `type` values, and a body must
--- pass it: Stanton's star is also named "Stanton", so an unrestricted match
--- from a page about a body could land on the star.
---
--- This is how an in-game planet or moon resolves at all. A code is not
--- derivable from a body's name: Hurston's is
--- STANTON.PLANETS.STANTONIHURSTONDYNAMICS, built from the designation and the
--- owning corporation, and the 33 in-game pages carry no `code` arg because
--- they were written from the game API, which has no starmap code. The ARK's
--- own `name` is the body's plain name, so it is the one reliable join.
--- @param starsystem table|nil
--- @param name string|nil
--- @param types table|nil set of accepted ARK `type` values
--- @return table|nil
function p.celestialByName(starsystem, name, types)
	if type(starsystem) ~= 'table' or type(name) ~= 'string' or name == '' then
		return nil
	end
	local objects = starsystem.celestial_objects
	if type(objects) ~= 'table' then
		return nil
	end
	local key = mw.ustring.lower(name)
	for _, obj in ipairs(objects) do
		if type(obj) == 'table' and (types == nil or types[obj.type]) then
			local objName = p.celestialName(obj)
			if objName and mw.ustring.lower(objName) == key then
				return obj
			end
		end
	end
	return nil
end

--- A celestial object's display name: its own `name` when the ARK gives one,
--- else its designation with the alias parenthetical and catalogue decorations
--- stripped. Terra's star is the reason `name` wins: it is "Terra Nova" while
--- the designation is just "Terra". Most objects have no `name` at all, so the
--- designation path is the common one.
---
--- The parenthetical is stripped wherever it sits, not just trailing as
--- systemShortName does it: the ARK embeds a Xi'an alias MID-designation
--- ("Kyuk'ya (Indra) A"), and leaving it in names a page that does not exist.
--- An ARK designation carries no other parentheses.
--- @param obj table|nil
--- @return string|nil
function p.celestialName(obj)
	if type(obj) ~= 'table' then
		return nil
	end
	local name = type(obj.name) == 'string' and obj.name ~= '' and obj.name or nil
	if name then
		return name
	end
	if type(obj.designation) ~= 'string' then
		return nil
	end
	return p.systemShortName((obj.designation:gsub('%s*%b()', '')))
end

--- The object an object orbits, resolved against its own system's object list.
--- The starmap gives only a numeric `parent_id`, so a single-object fetch can
--- never answer this — which is why bodies bridge through attachStarsystem.
--- nil where the ARK records no parent: the eleven planets in multi-star or
--- star-less systems (Goss, Baker, Bacchus, Min) carry `parent_id = null`,
--- because it does not say which sun they orbit.
--- @param starsystem table|nil
--- @param obj table|nil
--- @return table|nil
function p.celestialParent(starsystem, obj)
	local id = type(obj) == 'table' and obj.parent_id or nil
	if id == nil or type(starsystem) ~= 'table' or type(starsystem.celestial_objects) ~= 'table' then
		return nil
	end
	for _, candidate in ipairs(starsystem.celestial_objects) do
		if type(candidate) == 'table' and candidate.id == id then
			return candidate
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

--- A system name reduced to its bare form: a trailing " System"/" system"
--- stripped, whitespace trimmed ("Pyro System" → "Pyro", "Nyx" → "Nyx").
--- This is the short form the short description uses; page links and stored
--- values append the lowercase " system" suffix to it ("Pyro system"), the
--- wiki's canonical system page-name form.
--- @param name any
--- @return string|nil
function p.systemShortName(name)
	if type(name) ~= 'string' then
		return nil
	end
	-- Strip the starmap's naming decorations before the ' System' suffix: an
	-- alias parenthetical ("Kyuk'ya (Indra)") and the Vanduul catalogue form
	-- (VS-9 "Vulture"). Both appear in celestial designations and neither is a
	-- wiki page name, so leaving one in renders a red link, files a bogus
	-- "<alias> system" category and stores a junk System value. Defence in
	-- depth for the fallback paths; a gate page's own canonical name is the
	-- primary source (see the JumpPoint leaf's titleSystems).
	-- Order matters: the ' System' suffix is stripped from the UNTRIMMED string
	-- so a bare ' System' collapses to empty (nil) rather than surviving as the
	-- word 'System'.
	local short = name:match('^%s*VS%-%d+%s*"(.+)"%s*$') or name
	short = short:gsub('%s+[Ss]ystem$', '') -- before the parenthetical: "Yā'mon (Hadur) System"
	short = mw.text.trim((short:gsub('%s*%b()%s*$', '')))
	if short == '' then
		return nil
	end
	return short
end

--- The gate's entry system (short form) from the location record. The live
--- locations endpoint serves `system` as a plain string ("Pyro System"); the
--- table-with-name shape is tolerated defensively in case the API ever
--- upgrades the field to an embedded record.
--- @param apiData table
--- @return string|nil
function p.entrySystem(apiData)
	local system = apiData.system
	if type(system) == 'table' then
		system = system.name
	end
	return p.systemShortName(system)
end

--- The gate's entry system for ANY jump-point page: the location record's
--- system when one exists, else the first side of the celestial designation.
--- The designation is entry-first for the object's own system by starmap
--- convention (every observed object under <SYS>.JUMPPOINTS.* leads with
--- <SYS>'s name), which is what lets a record-less |family=jumppoint page
--- (the starmap-only tunnels) still know which system it sits in — feeding
--- the System row, the destination disambiguation, the entry-system category
--- and the stored System property alike.
--- @param apiData table
--- @return string|nil
function p.gateEntrySystem(apiData)
	local entry = p.entrySystem(apiData)
	if entry then
		return entry
	end
	local celestial = type(apiData.celestialobject) == 'table' and apiData.celestialobject or nil
	local designation = celestial and celestial.designation or nil
	if type(designation) ~= 'string' then
		return nil
	end
	local sideA = designation:match('^(.-)%s+%-%s+')
	return sideA and p.systemShortName(mw.text.trim(sideA)) or nil
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

--- The name of the subject this page is about: explicit override, then the
--- location record's name, then the editor's display name, then the page
--- title. It is the starmap lookup key for a system page and the body's own
--- name for a planet or moon, which is why it is public.
--- @param apiData table
--- @param args table|nil
--- @return string|nil
function p.subjectName(apiData, args)
	if args and type(args.starmapname) == 'string' and args.starmapname ~= '' then
		return args.starmapname
	end
	if type(apiData.name) == 'string' and apiData.name ~= '' then
		return apiData.name
	end
	if args and type(args.name) == 'string' and args.name ~= '' then
		return args.name
	end
	return mw.title.getCurrentTitle().text
end

--- Plain lowercase key for a system name: trailing " System" stripped. This
--- key drives BOTH the filter query and result selection; it is URL-encoded
--- only where it enters the endpoint.
--- @param name string|nil
--- @return string|nil
local function plainKey(name)
	-- One suffix-stripper: p.systemShortName owns the ' System' handling (and
	-- trims); this is just its lowercased form for the filter[name] URL key.
	local short = p.systemShortName(name)
	return short and short:lower() or nil
end

--- The row for a plain key from a filter[name] result list. filter[name] is a
--- substring match, so short names can return several rows: prefer the exact
--- name, then the Xi'an "<name> (<alias>)" form, then the first row.
--- @param results table
--- @param key string
--- @return table|nil
local function pickStarsystem(results, key)
	for _, row in ipairs(results) do
		if type(row.name) == 'string' and row.name:lower() == key then
			return row
		end
	end
	for _, row in ipairs(results) do
		if type(row.name) == 'string' and row.name:lower():sub(-(#key + 2)) == '(' .. key .. ')' then
			return row
		end
	end
	return results[1]
end

--- Statuses where the ARK has not published a survey: M (UEE Military
--- Classified, the Vanduul-held systems) and N (probe data incomplete).
--- @type table<string, boolean>
local UNPUBLISHED_SURVEY = { M = true, N = true }

--- Drop the ARK's withheld-survey aggregate, which is a stub rather than a set
--- of measurements. Every unpublished system with no catalogued bodies carries
--- the *same* block — the twelve Vanduul systems all report population 1.08 and
--- economy 0.12 with a size of 0, 1 or 7, and the three incomplete-probe systems
--- report straight zeros. One value repeated across twelve systems is a template
--- default, not twelve measurements, so none of it may reach the infobox or the store:
--- left alone these pages claim a 7 AU extent and a 0.1/10 economy for space
--- nobody has surveyed, and store a `System size` that satisfies a "smaller than
--- N AU" query.
---
--- The test is "no catalogued bodies AND the survey is unpublished" rather than
--- the tempting shorter ones, both of which are wrong on live data:
---   * `size <= 0` misses the four stubs that report 1 or 7 AU.
---   * "no bodies" alone would strip Gurzil, which is published with no bodies
---     and a real 4.2 AU extent.
---   * status alone would strip Caliban (5.89), Orion (5), Virgil (16) and
---     Oretani (36.91), which are unpublished but properly catalogued.
--- Stars are deliberately excluded from the body count: the stub block claims one
--- star, so counting it would disable the rule entirely. A zero size is dropped
--- unconditionally as well — it is never a measurement, whatever the status. An
--- editorial `|size=` override still wins wherever an editor knows better.
---
--- @param record table|nil starmap record; mutated in place
--- @return table|nil record the same record, for call chaining
local function normalizeAggregates(record)
	local aggregated = type(record) == 'table' and record.aggregated or nil
	if type(aggregated) ~= 'table' then
		return record
	end
	if (tonumber(aggregated.size) or 0) <= 0 then
		aggregated.size = nil
	end
	local bodies = (tonumber(aggregated.planets) or 0)
		+ (tonumber(aggregated.moons) or 0)
		+ (tonumber(aggregated.stations) or 0)
	if bodies == 0 and UNPUBLISHED_SURVEY[record.status] then
		aggregated.size = nil
		aggregated.population = nil
		aggregated.economy = nil
	end
	return record
end

--- Attach the starmap celestial-object record as apiData.celestialobject: the
--- JumpPoint leaf's enrich. The bridge key is the editor-supplied starmap
--- code (the leaf reads it from its manifest entry); no code, no fetch.
--- Soft-fails: on a fetch error or an empty result the record stays absent
--- and the infobox renders what it has.
---
--- @param apiData table
--- @param code string|nil
--- @return table apiData
function p.attachCelestialObject(apiData, code)
	if type(code) ~= 'string' or code == '' then
		return apiData
	end
	-- `include=starsystem` names the object's system authoritatively, which is
	-- the only reliable way to get it: the code's own first segment is a code,
	-- not a name, and starsystems' filter[name] does not accept codes (KYUKYA,
	-- RILA, THUSUNG and KAPARI all miss). The included record is compact
	-- ({ id, code, name }) — the zone and aggregate fields live on the full
	-- starsystems record that attachStarsystem fetches.
	-- locale rides the endpoint, NOT `params`: Apiunto appends params as
	-- `?query`, which after an endpoint that already carries `?include=` would
	-- produce a second `?` and corrupt the include value.
	local data = api.fetchApi({
		name = 'StarCitizenWikiAPI',
		endpoint = 'celestial-objects/%s?include=starsystem&locale=en_EN',
		responseDataPath = 'data',
	}, code)
	if type(data) == 'table' and next(data) ~= nil then
		apiData.celestialobject = data
	end
	return apiData
end

--- Attach the starmap star-system record as apiData.starsystem: the
--- StarSystem leaf's enrich, for SolarSystem records (uuid path) and for
--- kind-declared lore pages (the editorial fork, apiData empty). Soft-fails:
--- on a fetch error or an empty result the record stays absent and the
--- infobox renders what it has.
---
--- `name`, when given, names the system outright and wins over every heuristic
--- in p.subjectName. A leaf whose subject is NOT the system must pass it:
--- for a planet or moon `apiData.name` is the body's own name, so the default
--- chain would look up a system called "Hurston" and attach nothing.
--- @param apiData table
--- @param args table|nil
--- @param name string|nil explicit system name
--- @return table apiData
function p.attachStarsystem(apiData, args, name)
	local key = plainKey(name or p.subjectName(apiData, args))
	if not key then
		return apiData
	end
	-- locale rides the endpoint, NOT `params`: Apiunto appends params as
	-- `?query`, which after an endpoint that already carries `?filter[…]`
	-- produces a second `?` that corrupts the include value.
	local data = api.fetchApi({
		name = 'StarCitizenWikiAPI',
		endpoint = 'starsystems?filter[name]=%s&include=celestialObjects&locale=en_EN',
		responseDataPath = 'data',
	}, mw.uri.encode(key, 'QUERY'))
	if type(data) == 'table' and data[1] ~= nil then
		apiData.starsystem = normalizeAggregates(pickStarsystem(data, key))
	end
	return apiData
end

--- The ARK starmap code carried by an attached celestial-object record, else
--- the raw |starmapcode=/|code= arg the fetch would have used — so a page
--- whose fetch soft-failed still gets the button and metadata row keyed by the
--- code the editor supplied. Shared by the two leaves that bridge by code
--- (JumpPoint, Star); the empty case is rejected once, here.
--- @param apiData table
--- @param fallback string|nil the raw starmap-code arg
--- @return string|nil
function p.celestialStarmapCode(apiData, fallback)
	local celestial = type(apiData.celestialobject) == 'table' and apiData.celestialobject or nil
	local code = celestial and celestial.code or nil
	if type(code) == 'string' and code ~= '' then
		return code
	end
	return type(fallback) == 'string' and fallback ~= '' and fallback or nil
end

--- The RSI Starmap footer action button for a starmap code, or no buttons at
--- all when there is no usable code. The Galactapedia mark doubles as the
--- icon (it is technically the Starmap's logo) and the brand class is shared
--- with every other Starmap button on the wiki. One definition for every leaf,
--- so their buttons cannot drift apart.
--- @param code string|nil
--- @return table[]
function p.starmapFooterButtons(code)
	if type(code) ~= 'string' or code == '' then
		return {}
	end
	return {
		{
			label = 'Starmap',
			url = 'https://robertsspaceindustries.com/starmap?location=' .. code,
			icon = 'Sc-icon-galactapedia.svg',
			class = 't-button--branded t-button--starmap',
		},
	}
end

--- The chain-contributed Metadata row for a starmap code: the `?location=` key
--- on the RSI starmap, the same vocabulary the legacy System and Astronomical
--- object templates exposed. Pairs with starmapFooterButtons so a page's button
--- and its printed code always come from the same value.
--- @param code string|nil
--- @return EntityItemData[]
function p.starmapMetadataItems(code)
	if type(code) ~= 'string' or code == '' then
		return {}
	end
	-- One unbreakable token of up to 39 characters
	-- (STANTON.PLANETS.STANTONIHURSTONDYNAMICS), which the row otherwise breaks
	-- mid-segment. <wbr> offers the dots as break points instead and survives
	-- the sanitizer. Parenthesised because gsub also returns a count.
	return { { label = 'Starmap code', content = (code:gsub('%.', '.<wbr>')) } }
end

-- Test-only exports. Not part of the public API.
p._internal = {
	plainKey = plainKey,
	pickStarsystem = pickStarsystem,
	normalizeAggregates = normalizeAggregates,
}

return p
