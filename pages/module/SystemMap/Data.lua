require('strict')

--- @module SystemMap/Data
--- Loads Module:SystemMap/systems.json and turns a system name plus the current
--- page title into a render-ready model. Pure: no HTML building, no page-title
--- lookups, no frame access. Every branch here is covered by
--- Module:SystemMap/testcases, which is why the entry point keeps
--- parser-dependent work (page existence, categories) out of this file.

local p = {}

local DATA = mw.loadJsonData('Module:SystemMap/systems.json')

--- Planet subtype -> glyph kind. The kind becomes a `data-kind` attribute that
--- styles.css keys the disc gradient off. Anything absent degrades to 'unknown',
--- which renders a neutral disc rather than erroring — a new CIG planet type
--- should look plain, not break the page.
---
--- Keys are the SENTENCE-CASE strings systems.json stores, not upstream's Title
--- Case: 'Gas Giant' is stored as 'Gas giant'. The transform is not mechanical —
--- 'Super-Earth' and 'Super Jupiter' keep their proper nouns — so the generator
--- that writes systems.json carries the same explicit mapping. A disagreement
--- between the two is silent: the body just renders 'unknown'. Change them
--- together.
---
--- Twenty-two subtypes share eleven kinds. The grouping is deliberate: a 6-24px
--- disc cannot carry twenty-two distinguishable colours, so subtypes that would
--- read the same at that size share one. The six kinds that were here first are
--- live on 42 pages and must keep their exact colours; widening a bucket is safe
--- only while no live body carries the subtype being added to it.
--- @type table<string, string>
local SUBTYPE_KIND = {
	['Super-Earth'] = 'super-earth',

	-- Anything with a thick envelope. Rendered banded, so size differences within
	-- the bucket read as banding rather than needing separate colours.
	['Gas giant'] = 'gas-giant',
	['Gas dwarf'] = 'gas-giant',
	['Super Jupiter'] = 'gas-giant',
	['Puffy planet'] = 'gas-giant',

	['Ice giant'] = 'ice-giant',
	['Smog planet'] = 'smog',
	['Protoplanet'] = 'protoplanet',

	-- Solid bodies differing mainly in what the rock is made of, which is not a
	-- distinction a disc this size can carry.
	['Terrestrial rocky'] = 'rocky',
	['Iron planet'] = 'rocky',
	['Carbon planet'] = 'rocky',
	['Coreless planet'] = 'rocky',
	['Desert planet'] = 'rocky',
	['Chthonian planet'] = 'rocky',

	-- Solid bodies whose surface IS the identifying fact, so each keeps a colour.
	['Lava planet'] = 'lava',
	['Ice planet'] = 'ice',
	['Ocean planet'] = 'ocean',

	['Dwarf planet'] = 'dwarf',
	['Mesoplanet'] = 'dwarf',

	-- Not a composition: origin (Artificial), orbit (Rogue) and state
	-- (Evaporating). One instance each, and nothing a reader predicts a colour
	-- for — so they share one that reads as "unusual" rather than as a material.
	['Artificial'] = 'exotic',
	['Rogue planet'] = 'exotic',
	['Evaporating planet'] = 'exotic',
}

local UNKNOWN_KIND = 'unknown'
local MOON_KIND = 'moon'
local BELT_KIND = 'belt'
local RING_KIND = 'ring'

--- A belt renders as a fixed band, not a scaled disc: upstream reports its size
--- as 0/null, and a belt has no meaningful diameter to scale anyway.
local BELT_BAND = { width = 11, height = 26 }

--- A planetary ring gets the same treatment for the same reason, turned on its
--- side: it sits in the moon column, where the layout is a row, so the band lies
--- flat the way a ring reads edge-on. It is deliberately NOT a disc — a ring is
--- not a body, and drawing it as one would say it is a moon.
local RING_BAND = { width = 15, height = 5 }

--- The tiers whose glyph is a fixed band rather than a scaled disc.
--- @type table<string, { width: number, height: number }>
local BANDS = { belt = BELT_BAND, ring = RING_BAND }

--- @class SystemMapBody
--- @field tier string        'star' | 'planet' | 'belt' | 'moon' | 'ring'
--- @field page string        Wiki page title, MediaWiki-normalised
--- @field label string       Display name (may differ in case from `page`)
--- @field designation string|nil
--- @field subtype string|nil Display string; never parsed
--- @field kind string        Glyph kind for `data-kind`
--- @field disc number        Rendered disc diameter in px (log-scaled within its tier)
--- @field icon string|nil    Wiki file name of the body's render, when one exists
--- @field iconRatio number|nil Width/height, set only when the icon is wider than
---                            tall because the body has rings (Terminus, Pyro IV)
--- @field current boolean    True when this body is the page being rendered
--- @field missing boolean    Set later by Module:SystemMap; always false here
--- @field band { width: number, height: number }|nil Set for the tiers drawn as a
---                            fixed band (belt, ring) instead of a scaled disc
--- @field moons SystemMapBody[]|nil Planets only; holds the planet's rings too

--- @class SystemMapModel
--- @field key string
--- @field page string
--- @field star SystemMapBody
--- @field bodies SystemMapBody[] Planets and belts, in orbital order

--- Resolve a user-supplied system name to a key in systems.json.
--- Accepts 'Stanton', 'stanton', 'STANTON', 'Stanton system', and surrounding
--- whitespace. Returns nil for anything unrecognised.
--- @param input string|nil
--- @return string|nil
function p.resolveKey(input)
	if type(input) ~= 'string' then
		return nil
	end

	local name = mw.text.trim(input)
	if name == '' then
		return nil
	end

	-- Strip a trailing ' system' so {{System map|Stanton system}} works too. No
	-- empty-result guard is needed: the pattern requires whitespace before
	-- 'system', and `name` is already trimmed, so the bare input 'system'
	-- does not match and the gsub can never return ''.
	name = name:gsub('%s+[Ss][Yy][Ss][Tt][Ee][Mm]$', '')

	local wanted = mw.ustring.lower(name)
	for key in pairs(DATA.systems) do
		if mw.ustring.lower(key) == wanted then
			return key
		end
	end

	return nil
end

--- Classify a body into a glyph kind.
--- Stars key off spectral class, planets off subtype, moons off subtype when
--- they declare one (Pyro IV is a rocky planet sitting at the moon tier) and
--- fall back to the neutral moon disc otherwise.
---
--- Belts and rings short-circuit before any of that. Neither is a body: upstream
--- gives both a subtype that only restates the tier ('System Belt', 'Planetary
--- Ring'), and both are drawn as bands. A ring sits at the moon tier and must
--- never fall through to the moon disc, which would draw it as the thing it
--- orbits alongside.
---
--- `class` is normally a single spectral letter, giving star-o … star-m. The two
--- remnants upstream describes without one — White Dwarf-Degenerate-A and
--- Neutron — are stored with the WORD as their class ('degenerate', 'neutron'),
--- which falls out of the same concatenation as star-degenerate / star-neutron
--- and needs no branch here. Stars with no class at all (Variable, Subgiant, and
--- the fifteen upstream leaves unclassified) get the generic disc.
--- @param tier string 'star' | 'planet' | 'moon' | 'belt' | 'ring'
--- @param subtype string|nil
--- @param class string|nil Spectral letter, or 'degenerate'/'neutron'; stars only
--- @return string
function p.glyphKind(tier, subtype, class)
	if tier == 'belt' then
		return BELT_KIND
	end

	if tier == 'ring' then
		return RING_KIND
	end

	if tier == 'star' then
		if type(class) == 'string' and class ~= '' then
			return 'star-' .. mw.ustring.lower(class)
		end
		return 'star'
	end

	if type(subtype) == 'string' then
		local kind = SUBTYPE_KIND[subtype]
		if kind then
			return kind
		end
	end

	if tier == 'moon' then
		return MOON_KIND
	end

	return UNKNOWN_KIND
end

--- Rendered disc diameter per tier, in px. The floor is not decoration: at true
--- scale the smallest planet computes to 0.05px, so something has to catch it.
--- @type table<string, { min: number, max: number }>
local DISC = {
	star = { min = 22, max = 30 },
	planet = { min = 6, max = 24 },
	moon = { min = 6, max = 14 },
}

--- The tiers that scale. Belts are absent on purpose: they render as a fixed
--- band, carry no `km`, and have no meaningful diameter to scale.
--- @type string[]
local SCALED_TIERS = { 'star', 'planet', 'moon' }

--- Largest and smallest `km` per tier, measured from a document's own contents.
---
--- This is the FALLBACK. It is correct but not stable: the answer depends on
--- which systems happen to be in the file, so every rollout batch would resize
--- the discs on every page already published — adding Terra and Castra alone
--- moved Nyx's star from 30.0px to 24.3px. The generator therefore records the
--- extents against the whole upstream dataset and this only runs when that key
--- is missing, so an older or hand-trimmed file still renders.
---
--- Exported for the tests, which need to exercise both paths without a second
--- JSON page to load.
--- @param data table Anything shaped like systems.json
--- @return table<string, { min: number, max: number }>
function p.computeExtents(data)
	local computed = {}

	local function note(tier, km)
		if type(km) ~= 'number' or km <= 0 then
			return
		end
		local e = computed[tier]
		if not e then
			computed[tier] = { min = km, max = km }
			return
		end
		if km < e.min then
			e.min = km
		end
		if km > e.max then
			e.max = km
		end
	end

	for _, system in pairs(data.systems or {}) do
		note('star', system.star and system.star.km)
		for _, body in ipairs(system.bodies or {}) do
			-- Belts are skipped rather than assumed to carry no km: one given a
			-- size by hand would otherwise widen the planet tier with a figure
			-- nothing draws.
			if body.tier ~= 'belt' then
				note('planet', body.km)
				if body.moons then
					for _, moon in ipairs(body.moons) do
						-- Rings are skipped for the same reason belts are: they
						-- share the moons array but render as a fixed band, so a
						-- km on one would stretch the moon scale by a figure
						-- nothing draws.
						if moon.tier ~= 'ring' then
							note('moon', moon.km)
						end
					end
				end
			end
		end
	end

	return computed
end

--- Resolve the disc scale for a document: what it records, else what it holds.
---
--- Merged per tier rather than all-or-nothing. A file recording only some tiers
--- would otherwise leave the rest with no extents at all, and `discSize` returns
--- the tier maximum when it has none — every planet on the page drawn at 24px.
--- @param data table
--- @return table<string, { min: number, max: number }>
function p.resolveExtents(data)
	local recorded, found = {}, 0
	if type(data.extents) == 'table' then
		for _, tier in ipairs(SCALED_TIERS) do
			local e = data.extents[tier]
			if type(e) == 'table' and type(e.min) == 'number' and type(e.max) == 'number' then
				recorded[tier] = { min = e.min, max = e.max }
				found = found + 1
			end
		end
	end

	if found == #SCALED_TIERS then
		return recorded
	end

	local resolved = p.computeExtents(data)
	for tier, e in pairs(recorded) do
		resolved[tier] = e
	end
	return resolved
end

--- @type table<string, { min: number, max: number }>|nil
local extents

--- @return table<string, { min: number, max: number }>
local function tierExtents()
	if not extents then
		extents = p.resolveExtents(DATA)
	end
	return extents
end

--- Map a body's diameter to a rendered disc size.
---
--- Logarithmic, anchored at both ends of its tier. Planets span 472:1, so a
--- linear map puts the smallest at 0.05px — invisible. Log spends the pixel
--- budget on the crowded small end, where most bodies actually are, while
--- keeping the ordering exact.
---
--- This is NOT proportional and must not be described as such: Pyro V is 6.6x
--- Hurston by diameter but renders about 1.3x. It is rank-preserving only.
---
--- The extents are now recorded in systems.json against all 90 upstream systems,
--- so a body outside them is a real possibility rather than a contradiction: an
--- upstream refetch can add a larger star before the file is regenerated. Such a
--- body lands on its tier's cap. It reads as "at least as big as anything else
--- here", which is true, and it cannot overflow the rail.
--- @param tier string
--- @param km number|nil
--- @return number px
function p.discSize(tier, km)
	local d = DISC[tier] or DISC.planet
	if type(km) ~= 'number' or km <= 0 then
		return d.max
	end

	local e = tierExtents()[tier]
	-- A non-positive minimum would make math.log(e.min) infinite and the whole
	-- fraction NaN, which none of the comparisons below would catch.
	if not e or type(e.min) ~= 'number' or type(e.max) ~= 'number' or e.min <= 0 or e.max <= e.min then
		return d.max
	end

	local lo, hi = math.log(e.min), math.log(e.max)
	local px = d.min + (d.max - d.min) * (math.log(km) - lo) / (hi - lo)

	-- Clamped in pixels rather than only in the fraction, so that whatever
	-- arrives — a body outside the recorded extents, a corrupt bound, a NaN from
	-- arithmetic that got past the guard above — leaves the rail intact. NaN
	-- fails every comparison, so it is tested by inequality with itself.
	if px ~= px then
		return d.max
	elseif px < d.min then
		return d.min
	elseif px > d.max then
		return d.max
	end
	return px
end

--- Copy one body out of the frozen JSON into a mutable model node.
--- @param source table
--- @param tier string
--- @param currentTitle string
--- @return SystemMapBody
local function toBody(source, tier, currentTitle)
	return {
		tier = tier,
		page = source.page,
		label = source.label,
		designation = source.designation,
		subtype = source.subtype,
		kind = p.glyphKind(tier, source.subtype, source.class),
		disc = p.discSize(tier, source.km),
		icon = source.icon,
		iconRatio = source.iconRatio,
		band = BANDS[tier],
		current = source.page == currentTitle,
		missing = false,
	}
end

--- Build the render model for one system.
--- @param input string|nil    System name as written in the template call
--- @param currentTitle string Page title being rendered, MediaWiki-normalised
--- @return SystemMapModel|nil
function p.buildModel(input, currentTitle)
	local key = p.resolveKey(input)
	if not key then
		return nil
	end

	currentTitle = currentTitle or ''
	local system = DATA.systems[key]

	local model = {
		key = key,
		page = system.page,
		star = toBody(system.star, 'star', currentTitle),
		bodies = {},
	}

	for _, source in ipairs(system.bodies) do
		local tier = source.tier == 'belt' and 'belt' or 'planet'
		local body = toBody(source, tier, currentTitle)
		body.moons = {}
		if source.moons then
			for _, sourceMoon in ipairs(source.moons) do
				-- A planet's rings share this array with its moons, because the
				-- rail nests exactly one level and a ring wants that level. The
				-- `tier: ring` marker is what keeps them apart from there on: it
				-- picks the ring glyph, the band, and the ring row in the summary.
				local moonTier = sourceMoon.tier == 'ring' and 'ring' or 'moon'
				body.moons[#body.moons + 1] = toBody(sourceMoon, moonTier, currentTitle)
			end
		end
		model.bodies[#model.bodies + 1] = body
	end

	return model
end

--- @param count number
--- @param noun string
--- @return string
local function pluralise(count, noun)
	if count == 1 then
		return '1 ' .. noun
	end
	return count .. ' ' .. noun .. 's'
end

--- One-line body count for the card header, e.g. "4 planets, 12 moons".
---
--- The star is not counted: the model holds exactly one per system, so saying so
--- adds nothing. A system with no moons (Nyx) drops that clause rather than
--- printing "0 moons".
---
--- Rings are counted apart from moons even though they share the moons array. A
--- ring is not a moon, and folding Sol's four into its moon count would overstate
--- the moons by a fifth while hiding a thing the system is known for.
--- @param model SystemMapModel
--- @return string
function p.summarise(model)
	local planets, moons, rings, belts = 0, 0, 0, 0

	for _, body in ipairs(model.bodies) do
		if body.tier == 'belt' then
			belts = belts + 1
		else
			planets = planets + 1
		end
		for _, moon in ipairs(body.moons) do
			if moon.tier == 'ring' then
				rings = rings + 1
			else
				moons = moons + 1
			end
		end
	end

	local parts = { pluralise(planets, 'planet') }
	if moons > 0 then
		parts[#parts + 1] = pluralise(moons, 'moon')
	end
	if rings > 0 then
		parts[#parts + 1] = pluralise(rings, 'ring')
	end
	if belts > 0 then
		parts[#parts + 1] = pluralise(belts, 'belt')
	end

	return table.concat(parts, ', ')
end

return p
