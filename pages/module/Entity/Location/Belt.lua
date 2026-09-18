require('strict')

--- @module Entity/Location/Belt
--- Asteroid-formation leaf of the Location kind: belts, clusters and planetary
--- rings in one module. They differ only in what they orbit and what the wiki
--- calls them, the same argument that puts planets and moons in one leaf.
---
--- Unlike the Body leaf there is effectively no game record behind these. The
--- locations API does type 682 records `Asteroid`, but they are in-system points
--- of interest -- mining claims, mining bases, extraction stations, the Lagrange
--- clusters -- and not the formations the starmap catalogues; only the handful of
--- pages named for a Lagrange point overlap. So this leaf renders from the
--- starmap STAR-SYSTEM record at
--- apiData.starsystem, for the same reason the Body leaf needs it: the starmap
--- gives a parent only as a numeric `parent_id`, resolvable against its own
--- system's object list.

local Editorial = require('Module:Entity/Editorial')
local locationUtil = require('Module:Entity/Location/Util')
local sectionBuilder = require('Module:Entity/SectionBuilder')

local p = {}

--- @type string
p.parent = 'Entity/Location'

--- Family token, curated on every page: no record types these, so nothing
--- dispatches here automatically.
p.family = 'belt'

--- `code`, `classification` and `system` are the legacy {{Astronomical object}}
--- arg names. No entry takes a property key — getStructuredData stores these
--- itself, so display and store cannot diverge. This leaf declares every entry,
--- which is the only reason reading its own fragment below is correct.
--- @return table
function p.getEditorialManifest()
	return {
		starmapcode = { arg = { 'starmapcode', 'code' } },
		classification = { arg = 'classification' },
		system = { arg = 'system' },
		affiliation = { arg = 'affiliation' },
		designation = { arg = 'designation' },
	}
end

--- @param args table|nil
--- @return string|nil
local function starmapCode(args)
	return locationUtil.manifestArg(args, p.getEditorialManifest(), 'starmapcode')
end

--- The ARK object types this leaf may resolve to. The two are one family to the
--- wiki but two tokens to the ARK, and a cluster can carry either.
local BELT_OBJECT_TYPES = { ASTEROID_BELT = true, ASTEROID_FIELD = true }

--- This formation's own object inside the attached system payload: by the
--- editor's `code` when there is one, else by name. A code is never derivable
--- here either — Hades IV split is `HADES.PLANET.HADESIVSPLIT`, a PLANET
--- segment on an asteroid cluster.
--- @param apiData table
--- @param args table|nil
--- @return table|nil
local function celestial(apiData, args)
	local starsystem = locationUtil.starsystemOf(apiData)
	return locationUtil.celestialByCode(starsystem, starmapCode(args))
		or locationUtil.celestialByName(starsystem, locationUtil.subjectName(apiData, args), BELT_OBJECT_TYPES)
end

--- @param apiData table
--- @param args table|nil
--- @return string|nil
local function resolvedStarmapCode(apiData, args)
	return locationUtil.resolvedStarmapCode(args, p.getEditorialManifest(), celestial(apiData, args))
end

--- @param args table|nil
--- @return string|nil
local function editorialClassification(args)
	return locationUtil.manifestArg(args, p.getEditorialManifest(), 'classification')
end

--- The vocabulary entry this page's starmap object resolves to.
--- @param apiData table
--- @param args table|nil
--- @return { classification: string, category: string, page: string }|nil
local function beltEntry(apiData, args)
	local obj = celestial(apiData, args) or {}
	return locationUtil.beltTypeEntry(obj.sub_type, obj.type)
end

--- The formation's classification: the editor's text when given, delinked so it
--- can reach the stored `Subject type` safely; else the starmap object's
--- vocabulary entry; else nil, leaving the bare kind noun.
--- @param apiData table
--- @param args table|nil
--- @return string|nil
local function classification(apiData, args)
	local editorialText = editorialClassification(args)
	if type(editorialText) == 'string' and editorialText ~= '' then
		return Editorial.toStoredValue(editorialText)
	end
	local entry = beltEntry(apiData, args)
	return entry and entry.classification or nil
end

--- The system's short name: the editorial arg the sweep writes, else the
--- record's own. NOT the starmap code's first segment, which is not always the
--- system.
--- @param apiData table
--- @param args table|nil
--- @return string|nil
local function systemName(apiData, args)
	return locationUtil.systemNameFrom(apiData, args, p.getEditorialManifest())
end

--- Bridges by the SYSTEM name, explicitly, for the same reason the Body leaf
--- does: this page's own name is the formation, not its system.
--- @param ctx EntityHookContext
--- @return table apiData
function p.enrich(ctx)
	local system = systemName(ctx.apiData, ctx.args)
	if not system then
		return ctx.apiData
	end
	return locationUtil.attachStarsystem(ctx.apiData, ctx.args, system)
end

--- What this formation orbits, as display name plus link target. A belt or
--- cluster hangs off the star; a ring hangs off its planet, which is the whole
--- difference between them. The starmap parent is the ONLY source here: unlike
--- a body, a formation has no record to carry one.
--- @param apiData table
--- @param args table|nil
--- @return string|nil name
--- @return string|nil target
local function parentAnchor(apiData, args)
	return locationUtil.celestialParentAnchor(locationUtil.starsystemOf(apiData), celestial(apiData, args))
end

--- @param apiData table
--- @param args table|nil
--- @return string|nil
local function locationChain(apiData, args)
	local parentName, parentTarget = parentAnchor(apiData, args)
	return locationUtil.locationChain(
		locationUtil.starsystemOf(apiData),
		systemName(apiData, args),
		parentName,
		parentTarget
	)
end

--- @param apiData table
--- @param resolved table|nil
--- @return string|nil
local function affiliationText(apiData, resolved)
	return locationUtil.affiliationDisplay(locationUtil.starsystemOf(apiData), resolved)
end

--- The distance from what it orbits, in AU. Parent-relative, not star-relative,
--- so it is only comparable between siblings; a ring reports 0 because it sits
--- on its planet.
--- @param apiData table
--- @param args table|nil
--- @return string|nil
local function distanceAu(apiData, args)
	local au = tonumber((celestial(apiData, args) or {}).distance)
	if not au or au <= 0 then
		return nil
	end
	return string.format('%.2f', au):gsub('%.?0+$', '') .. ' AU'
end

--- The classification is the subtitle, so no row repeats it. `name` must stay
--- PLAIN: Entity stores it as `Subject type`.
--- @param ctx EntityHookContext
--- @return { name: string, category: string }
function p.getTypeInfo(ctx)
	local entry = beltEntry(ctx.apiData, ctx.args) or locationUtil.beltTypeFromText(editorialClassification(ctx.args))
	return {
		name = classification(ctx.apiData, ctx.args) or 'Asteroid formation',
		category = entry and entry.category or 'Asteroid Formations',
	}
end

--- The classification linked to its index page. DISPLAY ONLY: getTypeInfo keeps
--- the plain form, because that one is stored.
--- @param ctx EntityHookContext
--- @return string|nil
function p.getSubtitle(ctx)
	local text = classification(ctx.apiData, ctx.args)
	local entry = beltEntry(ctx.apiData, ctx.args) or locationUtil.beltTypeFromText(text)
	if entry and text then
		return locationUtil.starTypeLink(entry, text)
	end
	return text
end

--- Only the system category: the type category is structural and comes from
--- getTypeInfo. {{Navplate system}} intersects `Asteroid belts` with
--- `<System> system` to build its Asteroids row, so a belt without this
--- disappears from its own system's navplate.
--- @param ctx EntityHookContext
--- @return string[]
function p.getCategories(ctx)
	local system = systemName(ctx.apiData, ctx.args)
	return system and { system .. ' system' } or {}
end

--- @param ctx EntityHookContext
--- @return EntitySectionEntry[]
function p.getSections(ctx)
	local apiData, args, resolved = ctx.apiData, ctx.args, ctx.resolved
	local ed = Editorial.view(resolved)

	local general = {}
	sectionBuilder.push(general, 'Location', locationChain(apiData, args))
	sectionBuilder.push(general, 'Affiliation', affiliationText(apiData, resolved))
	sectionBuilder.push(general, 'Designation', ed:value('designation'))
	sectionBuilder.push(general, 'Distance', distanceAu(apiData, args))

	-- The same rows a body gets, from the same block. A formation's readings are
	-- often all zero, which is the starmap's no-reading sentinel, so the section
	-- simply does not appear.
	local sensor = {}
	local readings = (celestial(apiData, args) or {}).sensor
	if type(readings) == 'table' then
		locationUtil.appendSensorMeter(sensor, 'Economy', readings.economy)
		locationUtil.appendSensorMeter(sensor, 'Population', readings.population)
		locationUtil.appendSensorMeter(sensor, 'Danger', readings.danger)
	end

	local lore = {}
	sectionBuilder.push(lore, 'Discovered in', ed:value('discoveredin'))

	return sectionBuilder.build(
		sectionBuilder.section({ key = 'general', items = general }),
		sectionBuilder.section({ key = 'sensor', label = 'Sensor readings', items = sensor }),
		sectionBuilder.section({ key = 'lore', label = 'Lore', collapsible = true, items = lore })
	)
end

--- The system and parent store as wiki PAGE names, the vocabulary the other
--- Location leaves use, so queries resolve real pages.
--- @param ctx EntityHookContext
--- @return table<string, any>
function p.getStructuredData(ctx)
	local apiData, args, resolved = ctx.apiData, ctx.args, ctx.resolved
	local system = systemName(apiData, args)
	local _, parentTarget = parentAnchor(apiData, args)
	local readings = (celestial(apiData, args) or {}).sensor
	readings = type(readings) == 'table' and readings or {}
	local function rating(value)
		return locationUtil.formatSensor(value) and tonumber(value) or nil
	end
	return {
		system = system and (system .. ' system') or nil,
		affiliation = locationUtil.storedAffiliation(locationUtil.starsystemOf(apiData), resolved),
		parent = parentTarget,
		classification = classification(apiData, args),
		designation = Editorial.view(resolved):value('designation'),
		population_rating = rating(readings.population),
		economy_rating = rating(readings.economy),
		danger_rating = rating(readings.danger),
	}
end

--- "Asteroid belt in the Osiris system"; a ring names the planet it sits on,
--- which is the fact that distinguishes it from every other ring.
--- @param ctx EntityHookContext
--- @return string
function p.getShortDescription(ctx)
	local apiData, args = ctx.apiData, ctx.args
	local system = systemName(apiData, args)
	local head = classification(apiData, args) or 'Asteroid formation'
	if not system then
		return head .. ' in Star Citizen'
	end
	-- Keyed on the resolved entry, not `head`: an editor's |classification= is a
	-- display string and any variant wording would drop the parent clause.
	if beltEntry(apiData, args) == locationUtil.BELT_TYPES['Planetary Ring'] then
		local parentName = parentAnchor(apiData, args)
		if parentName then
			head = head .. ' of ' .. parentName
		end
	end
	return head .. ' in the ' .. system .. ' system'
end

--- @param ctx EntityHookContext
--- @return table[]
function p.getFooterButtons(ctx)
	return locationUtil.starmapFooterButtons(resolvedStarmapCode(ctx.apiData, ctx.args))
end

--- @param ctx EntityHookContext
--- @return EntityItemData[]
function p.getMetadataItems(ctx)
	return locationUtil.starmapMetadataItems(resolvedStarmapCode(ctx.apiData, ctx.args))
end

-- Test-only exports. Not part of the public API.
p._internal = {
	classification = classification,
	systemName = systemName,
	parentAnchor = parentAnchor,
	locationChain = locationChain,
	affiliationText = affiliationText,
	distanceAu = distanceAu,
	resolvedStarmapCode = resolvedStarmapCode,
}

return p
