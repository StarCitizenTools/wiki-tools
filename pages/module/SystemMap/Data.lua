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
--- @type table<string, string>
local SUBTYPE_KIND = {
	['Super-Earth'] = 'super-earth',
	['Gas giant'] = 'gas-giant',
	['Ice giant'] = 'ice-giant',
	['Smog planet'] = 'smog',
	['Protoplanet'] = 'protoplanet',
	['Terrestrial rocky'] = 'rocky',
}

local UNKNOWN_KIND = 'unknown'
local MOON_KIND = 'moon'
local BELT_KIND = 'belt'

--- A belt renders as a fixed band, not a scaled disc: upstream reports its size
--- as 0/null, and a belt has no meaningful diameter to scale anyway.
local BELT_BAND = { width = 11, height = 26 }

--- @class SystemMapBody
--- @field tier string        'star' | 'planet' | 'belt' | 'moon'
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
--- @field moons SystemMapBody[]|nil Planets only

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
--- @param tier string 'star' | 'planet' | 'moon'
--- @param subtype string|nil
--- @param class string|nil Spectral letter, stars only
--- @return string
function p.glyphKind(tier, subtype, class)
	if tier == 'belt' then
		return BELT_KIND
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

--- Largest and smallest `km` per tier, across every system in the file — not per
--- system, so a body is the same size whichever map it appears on.
--- @type table<string, { min: number, max: number }>|nil
local extents

--- @return table<string, { min: number, max: number }>
local function tierExtents()
	if extents then
		return extents
	end

	extents = {}
	local function note(tier, km)
		if type(km) ~= 'number' then
			return
		end
		local e = extents[tier]
		if not e then
			extents[tier] = { min = km, max = km }
			return
		end
		if km < e.min then
			e.min = km
		end
		if km > e.max then
			e.max = km
		end
	end

	for _, system in pairs(DATA.systems) do
		note('star', system.star.km)
		for _, body in ipairs(system.bodies) do
			-- Belts carry no km and must not skew the planet tier's extents.
			note('planet', body.km)
			if body.moons then
				for _, moon in ipairs(body.moons) do
					note('moon', moon.km)
				end
			end
		end
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
--- Hurston by diameter but renders about 1.4x. It is rank-preserving only.
--- @param tier string
--- @param km number|nil
--- @return number px
function p.discSize(tier, km)
	local d = DISC[tier] or DISC.planet
	if type(km) ~= 'number' or km <= 0 then
		return d.max
	end

	local e = tierExtents()[tier]
	if not e or e.max <= e.min then
		return d.max
	end

	local lo, hi = math.log(e.min), math.log(e.max)
	local f = (math.log(km) - lo) / (hi - lo)
	if f < 0 then
		f = 0
	elseif f > 1 then
		f = 1
	end

	return d.min + (d.max - d.min) * f
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
		band = tier == 'belt' and BELT_BAND or nil,
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
				body.moons[#body.moons + 1] = toBody(sourceMoon, 'moon', currentTitle)
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
--- @param model SystemMapModel
--- @return string
function p.summarise(model)
	local planets, moons, belts = 0, 0, 0

	for _, body in ipairs(model.bodies) do
		if body.tier == 'belt' then
			belts = belts + 1
		else
			planets = planets + 1
		end
		for _ in ipairs(body.moons) do
			moons = moons + 1
		end
	end

	local parts = { pluralise(planets, 'planet') }
	if moons > 0 then
		parts[#parts + 1] = pluralise(moons, 'moon')
	end
	if belts > 0 then
		parts[#parts + 1] = pluralise(belts, 'belt')
	end

	return table.concat(parts, ', ')
end

return p
