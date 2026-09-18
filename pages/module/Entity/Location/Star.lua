require('strict')

--- @module Entity/Location/Star
--- Star leaf of the Location kind: one page per star ("Stanton (star)",
--- "Goss A"), plus the single black hole the starmap serves in the same shape
--- (Tamsa). Renders from the merged payload the kind assembles: the location
--- record at the top level, which only three stars have — Stanton, Pyro and
--- Nyx are the only ones in the game — plus the starmap celestial-object
--- record at apiData.celestialobject, attached by this leaf's enrich through
--- locationUtil.attachCelestialObject from the editor's starmap code. Every
--- other star page is record-less and renders from the starmap alone, so every
--- consumer nil-guards and degrades to what it has.

local Editorial = require('Module:Entity/Editorial')
local format = require('Module:Entity/Format')
local locationUtil = require('Module:Entity/Location/Util')
local sectionBuilder = require('Module:Entity/SectionBuilder')

local p = {}

--- @type string
p.parent = 'Entity/Location'

--- Family token: dispatched by Location.resolveSubtype for the three in-game
--- Star records, and named by a curated |family=star on every other star page.
p.family = 'star'

--- @param ctx EntityHookContext
--- @return table apiData
function p.enrich(ctx)
	return locationUtil.attachCelestialObject(
		ctx.apiData,
		Editorial.rawArg(ctx.args, p.getEditorialManifest().starmapcode)
	)
end

--- `code`, `classification` and `system` are the legacy {{Astronomical object}}
--- arg names. `radius` is the only source of a radius for the stars whose
--- starmap size is a placeholder (see radiusKm); `satellites` is the star's own
--- planet count, which no endpoint this leaf fetches carries, and for a binary
--- it is per-star rather than per-system. No entry takes a property key —
--- getStructuredData stores these itself, so display and store cannot diverge.
--- This leaf declares all five itself, which is the only reason reading its own
--- fragment below (rather than the merged chain manifest) is correct.
--- @return table
function p.getEditorialManifest()
	return {
		starmapcode = { arg = { 'starmapcode', 'code' } },
		classification = { arg = 'classification' },
		radius = { arg = 'radius', transform = 'number' },
		satellites = { arg = 'satellites', transform = 'number' },
		system = { arg = 'system' },
	}
end

--- @param apiData table
--- @return table|nil
local function getCelestialObject(apiData)
	return type(apiData.celestialobject) == 'table' and apiData.celestialobject or nil
end

--- Read from the RAW arg, not the editorial view: getTypeInfo runs before
--- editorial resolution in Data.get. The field is a plain passthrough, so the
--- raw arg IS the resolved value and every consumer can share this accessor.
--- @param args table|nil
--- @return string|nil
local function editorialClassification(args)
	return Editorial.rawArg(args, p.getEditorialManifest().classification)
end

--- The vocabulary entry for the record's own sub_type, or nil. The single
--- accessor the subtitle and the category both resolve through, so the link
--- target and the filed category can never name different classes.
--- @param apiData table
--- @return table|nil
local function starTypeEntry(apiData)
	local celestial = getCelestialObject(apiData)
	return celestial and locationUtil.starTypeEntry(celestial.sub_type) or nil
end

--- Editorial text wins: Pyro is a flare star by lore, which the starmap does
--- not carry. nil where nothing classes the object, so callers fall back to the
--- generic rather than inventing a class.
---
--- DELINKED here, once, because three of the four consumers cannot take markup:
--- getTypeInfo's name is stored as the indexed `Subject type` and is the
--- short-description fallback, and getSubtitle wraps the text in a link, so an
--- editor's own `[[…]]` would nest and render as literal brackets.
--- @param apiData table
--- @param args table|nil
--- @return string|nil
local function classification(apiData, args)
	local editorialText = editorialClassification(args)
	if type(editorialText) == 'string' and editorialText ~= '' then
		return Editorial.toStoredValue(editorialText)
	end
	local entry = starTypeEntry(apiData)
	if entry then
		return entry.classification
	end
	local celestial = getCelestialObject(apiData)
	return celestial and celestial.type == 'BLACKHOLE' and 'Black hole' or nil
end

--- The starmap serves star sizes in KILOMETRES, but eighteen unsurveyed stars
--- carry a bare `1` and Stanton a `1.2`, placeholders in no unit at all.
--- Nothing stellar is smaller than a neutron star's ~10 km, so the cut sits
--- below that: it drops all nineteen and keeps Banshee's real 13.91 km.
local MIN_PLAUSIBLE_RADIUS_KM = 5

--- The IAU nominal solar radius, for the R☉ comparison.
local SOLAR_RADIUS_KM = 695700

--- The location record's own `size` is never read: Pyro and Nyx share one
--- byte-identical 57,072,000 m value, so it is a placeholder in the game data
--- too, and only Stanton's happens to be real.
--- @param apiData table
--- @param resolved table|nil
--- @return number|nil
local function radiusKm(apiData, resolved)
	local editorialValue = tonumber(Editorial.view(resolved):value('radius'))
	if editorialValue and editorialValue > 0 then
		return editorialValue
	end
	local celestial = getCelestialObject(apiData)
	local size = celestial and tonumber(celestial.size) or nil
	if not size or size < MIN_PLAUSIBLE_RADIUS_KM then
		return nil
	end
	-- A class that declares a ceiling is one whose size the physics pins down
	-- (see STAR_TYPES.maxRadiusKm): above it the figure is not a measurement.
	local entry = starTypeEntry(apiData)
	if entry and entry.maxRadiusKm and size > entry.maxRadiusKm then
		return nil
	end
	return size
end

--- The R☉ test is on the ROUNDED figure, not the raw ratio: a white dwarf at
--- 0.0090 prints a useful '0.01 R☉', while a neutron star's 0.00002 would print
--- a meaningless 0.00 and is dropped. Sub-100 km radii keep their decimals for
--- the same reason.
--- @param km number|nil
--- @return string|nil
local function radiusDisplay(km)
	if not km then
		return nil
	end
	local text = (km < 100 and string.format('%.2f', km) or format.formatNum(math.floor(km + 0.5))) .. ' km'
	local solar = string.format('%.2f', km / SOLAR_RADIUS_KM)
	if solar ~= '0.00' then
		text = text .. ' (' .. solar .. ' R☉)'
	end
	return text
end

--- Never the page title: "Terra Nova" is the star of Terra and "Goss A" one of
--- two suns, so a title-derived name is wrong for exactly the pages a fallback
--- would exist to rescue. The editorial arg is LAST, for the stars the starmap
--- does not list at all (78 Leonis), where nothing else can name the system.
--- @param apiData table
--- @param args table|nil
--- @return string|nil
local function systemName(apiData, args)
	local fromRecord = locationUtil.entrySystem(apiData)
	if fromRecord then
		return fromRecord
	end
	local celestial = getCelestialObject(apiData)
	local starsystem = celestial and type(celestial.starsystem) == 'table' and celestial.starsystem or nil
	if starsystem then
		return locationUtil.systemShortName(starsystem.name)
	end
	return locationUtil.systemShortName(Editorial.rawArg(args, p.getEditorialManifest().system))
end

--- The ARK starmap code, from the record or the arg that would have fetched it.
--- @param apiData table
--- @param args table|nil
--- @return string|nil
local function starmapCode(apiData, args)
	return locationUtil.celestialStarmapCode(apiData, Editorial.rawArg(args, p.getEditorialManifest().starmapcode))
end

--- `name` must stay PLAIN: Entity stores it as `Subject type` and falls back to
--- it for the short description. The linked form is getSubtitle's. No row
--- repeats it, since it is the subtitle. Tamsa files under Stars too; the
--- spectral type is a facet on top (getCategories).
--- @param ctx EntityHookContext
--- @return { name: string, category: string }
function p.getTypeInfo(ctx)
	return {
		name = classification(ctx.apiData, ctx.args) or 'Star',
		category = 'Stars',
	}
end

--- The two classifications that come from no sub_type at all: a star the ARK
--- never classed, and a black hole it gave none. Each carries BOTH its index
--- page and its category, because the pair has to move together — a subtitle
--- reading "Black hole" filed under Unknown spectral type stars would break the
--- invariant starTypeEntry exists to hold.
local GENERIC = {
	['Star'] = { page = 'Star', category = 'Unknown spectral type stars' },
	['Black hole'] = { page = 'Black hole', category = 'Black holes' },
}

--- The classification linked to its index page. DISPLAY ONLY — getTypeInfo
--- keeps the plain form because that one is stored. An editor's wording is kept
--- as the display while the target comes from the record's class, so Pyro reads
--- "flare star" and still points at the K-type index. Nothing resolvable leaves
--- it plain rather than inventing a target.
--- @param ctx EntityHookContext
--- @return string|nil
function p.getSubtitle(ctx)
	local text = classification(ctx.apiData, ctx.args) or 'Star'
	local entry = starTypeEntry(ctx.apiData) or locationUtil.starTypeFromText(editorialClassification(ctx.args))
	if entry then
		return locationUtil.starTypeLink(entry, text)
	end
	local generic = GENERIC[text]
	return generic and ('[[' .. generic.page .. ']]') or text
end

--- Two categories, one browse and one functional.
---
--- The spectral facet comes from the record FIRST, so an editor who elaborates
--- the wording still files under the class the data gives. Editorial text is
--- matched back only where the record classes nothing, the record-less pages'
--- one route to a category; a star nothing classes is genuinely of unknown
--- spectral type, itself a live category.
---
--- The system category is FUNCTIONAL: {{Navplate system}} builds its Stars row
--- from it intersected with Stars, so dropping it empties that row on every
--- system page. JumpPoint files its gates the same way.
--- @param ctx EntityHookContext
--- @return string[]
function p.getCategories(ctx)
	local entry = starTypeEntry(ctx.apiData) or locationUtil.starTypeFromText(editorialClassification(ctx.args))
	local generic = not entry and GENERIC[classification(ctx.apiData, ctx.args) or 'Star'] or nil
	local categories = { entry and entry.category or (generic and generic.category) or 'Unknown spectral type stars' }
	local system = systemName(ctx.apiData, ctx.args)
	if system then
		categories[#categories + 1] = system .. ' system'
	end
	return categories
end

--- @param ctx EntityHookContext
--- @return EntitySectionEntry[]
function p.getSections(ctx)
	local apiData, resolved = ctx.apiData, ctx.resolved
	local ed = Editorial.view(resolved)

	local general = {}
	local system = systemName(apiData, ctx.args)
	sectionBuilder.push(general, 'System', system and ('[[' .. system .. ' system]]'))
	sectionBuilder.push(general, 'Radius', radiusDisplay(radiusKm(apiData, resolved)))
	-- formatNum, not the raw value: InfoboxLua's item schema requires STRING
	-- content, and validateAndConstruct drops a number without a word.
	sectionBuilder.push(general, 'Satellites', format.formatNum(ed:value('satellites')))
	local jurisdiction = type(apiData.jurisdiction) == 'table' and apiData.jurisdiction.name or nil
	sectionBuilder.push(general, 'Jurisdiction', jurisdiction and ('[[' .. jurisdiction .. ']]'))

	local lore = {}
	sectionBuilder.push(lore, 'Discovered in', ed:value('discoveredin'))
	sectionBuilder.push(lore, 'Discovered by', ed:value('discoveredby'))
	sectionBuilder.push(lore, 'Historical names', ed:value('historicalnames'))

	return sectionBuilder.build(
		sectionBuilder.section({ key = 'general', items = general }),
		sectionBuilder.section({ key = 'lore', label = 'Lore', collapsible = true, items = lore })
	)
end

--- The system stores as the wiki PAGE name ("Stanton system"), JumpPoint's
--- vocabulary, so queries resolve real pages. A star's satellites reuse Planet
--- count rather than adding a column for the same fact; note that every live
--- binary carries the SYSTEM total on both stars (Tyrol A and B both 7), so a
--- star row's planet_count is not a per-star figure and an aggregate query must
--- filter by subject_type. discoveredin/discoveredby belong to the kind's
--- manifest, not here.
--- @param ctx EntityHookContext
--- @return table<string, any>
function p.getStructuredData(ctx)
	local apiData, args, resolved = ctx.apiData, ctx.args, ctx.resolved
	local system = systemName(apiData, args)
	local class = classification(apiData, args)
	return {
		system = system and (system .. ' system') or nil,
		classification = class and Editorial.toStoredValue(class) or nil,
		star_radius = radiusKm(apiData, resolved),
		planet_count = tonumber(Editorial.view(resolved):value('satellites')),
	}
end

--- "G-type main-sequence star in the Stanton system". No system resolves → the
--- catch-all, since a bare classification names no place and reads like a
--- definition.
--- @param ctx EntityHookContext
--- @return string
function p.getShortDescription(ctx)
	local system = systemName(ctx.apiData, ctx.args)
	if not system then
		return 'A star in Star Citizen'
	end
	return (classification(ctx.apiData, ctx.args) or 'Star') .. ' in the ' .. system .. ' system'
end

--- RSI Starmap as a footer action button, from the shared code accessor.
--- @param ctx EntityHookContext
--- @return table[]
function p.getFooterButtons(ctx)
	return locationUtil.starmapFooterButtons(starmapCode(ctx.apiData, ctx.args))
end

--- Chain-contributed Metadata rows: the ARK starmap code, through the same
--- accessor as the footer button so the two cannot disagree.
--- @param ctx EntityHookContext
--- @return EntityItemData[]
function p.getMetadataItems(ctx)
	return locationUtil.starmapMetadataItems(starmapCode(ctx.apiData, ctx.args))
end

-- Test-only exports. Not part of the public API.
p._internal = {
	classification = classification,
	starTypeEntry = starTypeEntry,
	radiusKm = radiusKm,
	radiusDisplay = radiusDisplay,
	systemName = systemName,
	starmapCode = starmapCode,
	MIN_PLAUSIBLE_RADIUS_KM = MIN_PLAUSIBLE_RADIUS_KM,
	SOLAR_RADIUS_KM = SOLAR_RADIUS_KM,
}

return p
