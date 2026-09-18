require('strict')

--- @module Entity/Location/Body
--- Planet and moon leaf of the Location kind, serving both: a moon differs from
--- a planet only in what its parent is, and every moon carries the same
--- 'Planetary Moon' sub_type, so there is no second vocabulary to justify a
--- second leaf. Renders from the location record (only 33 bodies have one) plus
--- the starmap STAR-SYSTEM record at apiData.starsystem.
---
--- The system payload, not a per-object fetch, because only it can answer the
--- two questions the infobox asks: the starmap gives a body's parent as a
--- numeric `parent_id`, resolvable only against its own system's object list,
--- and the affiliation tier of the Location row lives on the system.

local Editorial = require('Module:Entity/Editorial')
local format = require('Module:Entity/Format')
local locationUtil = require('Module:Entity/Location/Util')
local sectionBuilder = require('Module:Entity/SectionBuilder')

local p = {}

--- @type string
p.parent = 'Entity/Location'

--- Family token: dispatched by Location.resolveSubtype for Planet and Moon
--- records, and named by a curated |family=body on every record-less page.
p.family = 'body'

--- `code`, `classification`, `system`, `satellites` and `landingzones` are the
--- legacy {{Astronomical object}} arg names. The physical fields are a long
--- tail the API does not carry at all, set on a few dozen pages out of 406, so
--- they exist to preserve those rather than because a body normally has them.
--- No entry takes a property key — getStructuredData stores these itself, so
--- display and store cannot diverge.
--- This leaf declares every entry itself, which is the only reason reading its
--- own fragment below (rather than the merged chain manifest) is correct.
--- @return table
function p.getEditorialManifest()
	return {
		starmapcode = { arg = { 'starmapcode', 'code' } },
		classification = { arg = 'classification' },
		bodytype = { arg = 'type' },
		system = { arg = 'system' },
		satellites = { arg = { 'satellites', 'natural satellites' }, transform = 'number' },
		landingzones = { arg = { 'landingzones', 'landing zones' }, transform = 'number' },
		habitable = { arg = 'habitable' },
		designation = { arg = 'designation' },
		affiliation = { arg = 'affiliation' },
		senator = { arg = 'senator' },
		radius = { arg = 'radius' },
		atmosphere = { arg = 'atmosphere' },
		atmosphericpressure = { arg = { 'atmosphericpressure', 'atmospheric pressure' } },
		orbitalspeed = { arg = { 'orbitalspeed', 'orbital speed' } },
		daylength = { arg = { 'siderealday', 'siderealrotation', 'sidereal rotation' } },
		gravity = { arg = 'gravity' },
		density = { arg = 'density' },
		tidallylocked = { arg = { 'tidallylocked', 'tidally locked' } },
		orbitalperiod = { arg = { 'orbitalperiod', 'orbital period' } },
	}
end

--- @param apiData table
--- @return table|nil
local function getStarsystem(apiData)
	return type(apiData.starsystem) == 'table' and apiData.starsystem or nil
end

--- The raw starmap code, read through the manifest entry so the alias order is
--- declared once. Read from the RAW arg because getTypeInfo runs before
--- editorial resolution.
--- @param args table|nil
--- @return string|nil
local function starmapCode(args)
	return Editorial.rawArg(args, p.getEditorialManifest().starmapcode)
end

--- The ARK object types a body page may resolve to. Passed to celestialByName
--- so a page cannot match a same-named star, station or belt.
local BODY_OBJECT_TYPES = { PLANET = true, SATELLITE = true }

--- This body's own celestial object inside the attached system payload: by the
--- editor's `code` when there is one, else by name. The name fallback is what
--- resolves the in-game bodies at all, which carry no code.
--- @param apiData table
--- @param args table|nil
--- @return table|nil
local function celestial(apiData, args)
	local starsystem = getStarsystem(apiData)
	return locationUtil.celestialByCode(starsystem, starmapCode(args))
		or locationUtil.celestialByName(starsystem, locationUtil.subjectName(apiData, args), BODY_OBJECT_TYPES)
end

--- The starmap code to show and link: the editor's arg, else the resolved
--- object's own. Without the fallback every in-game body loses its Starmap
--- button, since none of those pages carries a code.
--- @param apiData table
--- @param args table|nil
--- @return string|nil
local function resolvedStarmapCode(apiData, args)
	local code = starmapCode(args)
	if type(code) == 'string' and code ~= '' then
		return code
	end
	local obj = celestial(apiData, args)
	code = obj and obj.code or nil
	return type(code) == 'string' and code ~= '' and code or nil
end

--- Is this body a moon? The LOCATION record decides when there is one, because
--- it is what a player sees in game. The two sources do disagree: the game
--- calls Delamar a Moon where the starmap types it a PLANET, though the wiki
--- calls it an asteroid and so no Body page renders it today. Were one to, this
--- order would type it a Moon against that judgement.
---
--- An editor's |type= comes next, ahead of the starmap, because neither starmap
--- signal is reliable on its own. The ARK types Pyro IV a PLANET yet parents it
--- to Pyro V, itself a planet, while it types Gainey a SATELLITE and parents it
--- straight to the star: trusting the token breaks the first, trusting the
--- parent's type breaks the second. Both pages say Moon, so the page wins.
---
--- The starmap token is the last signal, and a body with none is assumed a
--- planet, which most are.
--- @param apiData table
--- @param args table|nil
--- @return boolean
local function isMoon(apiData, args)
	-- A record naming a PLANET as its parent describes a moon whatever its own
	-- type says: the game's Pyro IV record is type Planet with parent Pyro V,
	-- itself a planet. Within one record the parent is the reliable field. Only
	-- the positive direction holds, because a record may name a star as the
	-- parent of something it still calls a moon.
	if type(apiData.parent) == 'table' and apiData.parent.type_name == 'Planet' then
		return true
	end
	local recordType = type(apiData.type) == 'table' and apiData.type.name or nil
	if recordType == 'Moon' then
		return true
	end
	if recordType == 'Planet' then
		return false
	end
	local stated = Editorial.rawArg(args, p.getEditorialManifest().bodytype)
	if type(stated) == 'string' then
		stated = mw.ustring.lower(mw.text.trim(stated))
		if stated == 'moon' or stated == 'moons' then
			return true
		end
		if stated == 'planet' or stated == 'planets' then
			return false
		end
	end
	local obj = celestial(apiData, args)
	return obj ~= nil and obj.type == 'SATELLITE'
end

--- The editor's classification text, from the RAW arg for the same reason as
--- the Star leaf's: getTypeInfo runs ahead of editorial resolution and the
--- field is a plain passthrough.
--- @param args table|nil
--- @return string|nil
local function editorialClassification(args)
	return Editorial.rawArg(args, p.getEditorialManifest().classification)
end

--- The body's classification: the editor's text when given, delinked so it can
--- reach the stored `Subject type` and the short description safely; else the
--- starmap sub_type's vocabulary entry; else nil, leaving the bare Planet or
--- Moon type as the subtitle rather than inventing a class. A moon has no
--- classification of its own — every one carries the same sub_type.
--- @param apiData table
--- @param args table|nil
--- @return string|nil
local function classification(apiData, args)
	local editorialText = editorialClassification(args)
	if type(editorialText) == 'string' and editorialText ~= '' then
		return Editorial.toStoredValue(editorialText)
	end
	local entry = locationUtil.bodyTypeEntry((celestial(apiData, args) or {}).sub_type)
	return entry and entry.classification or nil
end

--- The affiliation to STORE: the compact token StarSystem also writes. The
--- single-segment rule that makes a two-affiliation arg queryable lives in
--- locationUtil.storedAffiliation, which every leaf shares.
--- @param apiData table
--- @param resolved table|nil
--- @return string|nil
local function storedAffiliation(apiData, resolved)
	return locationUtil.storedAffiliation(getStarsystem(apiData), resolved)
end

--- The body's own affiliation, which need not match its system's: Charon III
--- reads Independent inside UEE space, and Mya reads Outsiders inside
--- Unclaimed. The page's wording wins and the system's stands in behind it, so
--- the row is never blank on a body that has a system.
--- @param apiData table
--- @param resolved table|nil
--- @return string|nil
local function affiliationText(apiData, resolved)
	local entry = locationUtil.resolveAffiliation(getStarsystem(apiData), resolved)
	if not entry then
		return nil
	end
	-- Same form StarSystem's row uses: an editor's own markup when they wrote
	-- free text, else the canonical label linked. A canonical token must NOT
	-- render as the editor typed it, or |affiliation=UEE would read a bare
	-- "UEE" next to a sibling page's linked "United Empire of Earth".
	return entry.display or ('[[' .. entry.label .. ']]')
end

--- The body's designation: the editor's arg, else the ARK object's own, which
--- it carries for every body. Stored as a property whether or not it repeats
--- the title; only the header suppresses the repetition.
--- @param apiData table
--- @param args table|nil
--- @param resolved table|nil
--- @return string|nil
local function designation(apiData, args, resolved)
	local text = Editorial.view(resolved):value('designation')
	if type(text) ~= 'string' or mw.text.trim(text) == '' then
		text = (celestial(apiData, args) or {}).designation
	end
	if type(text) ~= 'string' or mw.text.trim(text) == '' then
		return nil
	end
	return mw.text.trim(text)
end

--- The body's radius in kilometres, from the LOCATION record's `size`, which it
--- serves in metres: Crusader's 7450000 is the 7,450 km its legacy infobox
--- stated, Cellin's 260333 the 260.0 km of its own.
---
--- The starmap `size` is NOT used here, unlike the Star leaf where it is the
--- only source. For a planet or moon that field carries at least three
--- different units: Crusader 74500 against a 7,450 km radius, Hurston 11853
--- (its LORE diameter), Daymar 0.4 and Cellin 0.67. Nothing reconciles them, so
--- a body with no game record falls back to an editor's |radius=, in
--- kilometres, and otherwise has none.
--- @param apiData table
--- @param resolved table|nil
--- @return number|nil
local function radiusKm(apiData, resolved)
	local metres = tonumber(apiData.size)
	if metres and metres > 0 then
		return metres / 1000
	end
	local km = tonumber(Editorial.view(resolved):value('radius'))
	if km and km > 0 then
		return km
	end
	return nil
end

--- Radius display: whole kilometres with a thousands separator, decimals kept
--- below 100 km where rounding would swallow the value (Cellin is 260.3, but a
--- small outpost-bearing rock can be single digits).
--- @param apiData table
--- @param resolved table|nil
--- @return string|nil
local function radiusDisplay(apiData, resolved)
	local km = radiusKm(apiData, resolved)
	if not km then
		return nil
	end
	if km < 100 then
		return string.format('%.1f', km) .. ' km'
	end
	return format.formatNum(math.floor(km + 0.5)) .. ' km'
end

--- The system's short name: the record's own `system` first, then the editorial
--- arg the sweep writes. NOT the starmap code's first segment, which is not
--- always the system — `MOONS.ELLIS.ELLIS5A` puts `MOONS` there.
--- @param apiData table
--- @param args table|nil
--- @return string|nil
local function systemName(apiData, args)
	local fromRecord = locationUtil.entrySystem(apiData)
	if fromRecord then
		return fromRecord
	end
	return locationUtil.systemShortName(Editorial.rawArg(args, p.getEditorialManifest().system))
end

--- Bridges by the SYSTEM name, explicitly: a body's own `apiData.name` is the
--- body, so attachStarsystem's default lookup chain would search for a system
--- called "Hurston" and attach nothing.
--- @param ctx EntityHookContext
--- @return table apiData
function p.enrich(ctx)
	local system = systemName(ctx.apiData, ctx.args)
	if not system then
		-- No bridge rather than attachStarsystem's own fallback, which would
		-- look the body's OWN name up as a system: a moon called Oberon would
		-- attach the Oberon system and inherit a foreign object list.
		return ctx.apiData
	end
	return locationUtil.attachStarsystem(ctx.apiData, ctx.args, system)
end

--- The page an anchor should link, preferring a qualified title only when it
--- is actually there. Both directions occur: a planet can share its name with
--- a disambiguation page while the article sits at "<name> (planet)", as
--- ArcCorp and microTech do, so the bare name is not enough even though it
--- exists; but a binary's component star sits at the bare "Goss A", where the
--- letter already disambiguates and no "(star)" page was ever made.
--- @param name string
--- @param qualifier string
--- @return string
local function anchorTitle(name, qualifier)
	local qualified = name .. ' (' .. qualifier .. ')'
	local title = mw.title.new(qualified)
	if title and title.exists then
		return qualified
	end
	return name
end

--- The body's parent, as display name plus link target. The location record
--- names it directly; otherwise it is resolved from the starmap `parent_id`
--- against the system's own object list. nil for the eleven planets in
--- multi-star or star-less systems, whose `parent_id` is null because the ARK
--- does not say which sun they orbit.
---
--- A Star parent prefers its `(star)` page, the title the star sweep settled
--- for a system's sole star, and falls back to the bare name a binary's
--- component uses.
--- @param apiData table
--- @param args table|nil
--- @return string|nil name
--- @return string|nil target
local function parentAnchor(apiData, args)
	local recordParent = type(apiData.parent) == 'table' and apiData.parent or nil
	if recordParent and type(recordParent.name) == 'string' and recordParent.name ~= '' then
		if recordParent.type_name == 'Star' then
			return recordParent.name, anchorTitle(recordParent.name, 'star')
		end
		return recordParent.name, anchorTitle(recordParent.name, 'planet')
	end
	local starsystem = getStarsystem(apiData)
	local obj = locationUtil.celestialParent(starsystem, celestial(apiData, args))
	local name = locationUtil.celestialName(obj)
	if not name then
		return nil, nil
	end
	if obj.type == 'STAR' or obj.type == 'BLACKHOLE' then
		return name, anchorTitle(name, 'star')
	end
	return name, anchorTitle(name, 'planet')
end

--- One linked tier of the Location row. The target is linked only when its page
--- exists, so a chain never paints a red link; the display name survives either
--- way. Kept thin and untested offline — the runner's title shim cannot answer
--- `exists`.
--- @param name string|nil
--- @param target string|nil
--- @return string|nil
local function tier(name, target)
	if type(name) ~= 'string' or name == '' then
		return nil
	end
	local title = type(target) == 'string' and target ~= '' and mw.title.new(target) or nil
	if title and title.exists then
		return '[[' .. target .. '|' .. name .. ']]'
	end
	return name
end

--- The Location row: `affiliation space › system › parent`, exactly three tiers
--- at any depth. Never an ancestor that is not the direct parent — a record
--- names only ONE parent hop, so inserting the star would assert that a moon's
--- planet orbits it, which is false for anything below a planet.
--- @param apiData table
--- @param args table|nil
--- @return string|nil
local function locationChain(apiData, args)
	local starsystem = getStarsystem(apiData)
	local parts = {}
	-- The SYSTEM's affiliation, never the page's: this tier links the systems
	-- category, so it has to describe the system. A body whose own affiliation
	-- differs states it in its own row.
	local affiliation = locationUtil.affiliationEntry(starsystem)
	if affiliation then
		-- The COMPACT form for the tier ("UEE space", the wording the legacy
		-- pages used); the long label would spend a breadcrumb tier on "United
		-- Empire of Earth space". The category the tier links is the long form,
		-- which is what StarSystem files systems under.
		local text = (affiliation.short or affiliation.label) .. ' space'
		parts[#parts + 1] = tier(text, ':Category:' .. affiliation.label .. ' systems')
	end
	local system = systemName(apiData, args)
	if system then
		parts[#parts + 1] = tier(system .. ' system', system .. ' system')
	end
	local parentName, parentTarget = parentAnchor(apiData, args)
	parts[#parts + 1] = tier(parentName, parentTarget)
	if #parts == 0 then
		return nil
	end
	return table.concat(parts, ' › ')
end

--- The type is the subtitle, so no row repeats it; the classification refines it
--- where the starmap gives one. `name` must stay PLAIN — Entity stores it as
--- `Subject type` and falls back to it for the short description.
--- @param ctx EntityHookContext
--- @return { name: string, category: string }
function p.getTypeInfo(ctx)
	local moon = isMoon(ctx.apiData, ctx.args)
	return {
		name = classification(ctx.apiData, ctx.args) or (moon and 'Moon' or 'Planet'),
		category = moon and 'Moons' or 'Planets',
	}
end

--- The designation, shown after the header title rather than in a row of its
--- own: a name and a designation are two names for one body, and this reads the
--- same on a page titled by name (Hurston) and one titled by designation
--- (Goss I). Suppressed where it would merely repeat the title, which is every
--- body the ARK names by designation alone.
--- @param ctx EntityHookContext
--- @return string|nil
function p.getTitleAnnotation(ctx)
	local text = designation(ctx.apiData, ctx.args, ctx.resolved)
	if not text then
		return nil
	end
	local name = locationUtil.subjectName(ctx.apiData, ctx.args)
	if name and mw.ustring.lower(mw.text.trim(name)) == mw.ustring.lower(text) then
		return nil
	end
	return text
end

--- The classification linked to its index page. DISPLAY ONLY: getTypeInfo keeps
--- the plain form, because that one is stored. An editor's wording is kept as
--- the display while the target comes from the class itself.
--- @param ctx EntityHookContext
--- @return string|nil
function p.getSubtitle(ctx)
	local text = classification(ctx.apiData, ctx.args)
	local entry = locationUtil.bodyTypeEntry((celestial(ctx.apiData, ctx.args) or {}).sub_type)
		or locationUtil.bodyTypeFromText(text)
	if entry and text then
		return locationUtil.starTypeLink(entry, text)
	end
	return text
end

--- The type facet plus the system category. The system one is not decoration:
--- {{Navplate system}} builds its Planets and Moons rows from
--- Category:Planets (or Moons) intersected with Category:<System> system, so a
--- body without it disappears from its own system's navplate.
--- @param ctx EntityHookContext
--- @return string[]
function p.getCategories(ctx)
	local entry = locationUtil.bodyTypeEntry((celestial(ctx.apiData, ctx.args) or {}).sub_type)
		or locationUtil.bodyTypeFromText(editorialClassification(ctx.args))
	local categories = {}
	if entry then
		categories[#categories + 1] = entry.category
	end
	local system = systemName(ctx.apiData, ctx.args)
	if system then
		categories[#categories + 1] = system .. ' system'
	end
	return categories
end

--- @param ctx EntityHookContext
--- @return EntitySectionEntry[]
function p.getSections(ctx)
	local apiData, args, resolved = ctx.apiData, ctx.args, ctx.resolved
	local ed = Editorial.view(resolved)

	local general = {}
	sectionBuilder.push(general, 'Location', locationChain(apiData, args))
	sectionBuilder.push(general, 'Affiliation', affiliationText(apiData, resolved))
	local jurisdiction = type(apiData.jurisdiction) == 'table' and apiData.jurisdiction.name or nil
	sectionBuilder.push(general, 'Jurisdiction', tier(jurisdiction, jurisdiction))
	sectionBuilder.push(general, 'Habitable', ed:value('habitable'))
	sectionBuilder.push(general, 'Satellites', format.formatNum(ed:value('satellites')))
	sectionBuilder.push(general, 'Landing zones', format.formatNum(ed:value('landingzones')))
	sectionBuilder.push(general, 'Senator', ed:value('senator'))

	-- Reference numbers with no bearing on play, so collapsed: the same
	-- treatment the system infobox gives its orbital zones. Labelled for what
	-- they are rather than by a taxonomy, since the rotation and orbit figures
	-- sit here beside the physical ones.
	local physical = {}
	sectionBuilder.push(physical, 'Radius', radiusDisplay(apiData, resolved))
	sectionBuilder.push(physical, 'Gravity', ed:value('gravity'))
	sectionBuilder.push(physical, 'Density', ed:value('density'))
	sectionBuilder.push(physical, 'Atmosphere', ed:value('atmosphere'))
	sectionBuilder.push(physical, 'Atmospheric pressure', ed:value('atmosphericpressure'))
	sectionBuilder.push(physical, 'Day length', ed:value('daylength'))
	sectionBuilder.push(physical, 'Orbital period', ed:value('orbitalperiod'))
	sectionBuilder.push(physical, 'Orbital speed', ed:value('orbitalspeed'))
	sectionBuilder.push(physical, 'Tidally locked', ed:value('tidallylocked'))

	-- Nearly every starmap body carries a populated sensor block. Same rows and
	-- order as the system infobox, plus Danger, which the system's aggregate
	-- cannot supply: it publishes a usable one for a single system.
	local sensor = {}
	local readings = (celestial(apiData, args) or {}).sensor
	if type(readings) == 'table' then
		locationUtil.appendSensorMeter(sensor, 'Economy', readings.economy)
		locationUtil.appendSensorMeter(sensor, 'Population', readings.population)
		locationUtil.appendSensorMeter(sensor, 'Danger', readings.danger)
	end

	local lore = {}
	sectionBuilder.push(lore, 'Discovered in', ed:value('discoveredin'))
	sectionBuilder.push(lore, 'Discovered by', ed:value('discoveredby'))
	sectionBuilder.push(lore, 'Historical names', ed:value('historicalnames'))

	return sectionBuilder.build(
		sectionBuilder.section({ key = 'general', items = general }),
		sectionBuilder.section({
			key = 'physical',
			label = 'Measurements',
			collapsible = true,
			collapsed = true,
			items = physical,
		}),
		sectionBuilder.section({ key = 'sensor', label = 'Sensor readings', items = sensor }),
		sectionBuilder.section({ key = 'lore', label = 'Lore', collapsible = true, items = lore })
	)
end

--- The system and parent store as wiki PAGE names, the vocabulary JumpPoint and
--- Star already use, so queries resolve real pages. discoveredin/discoveredby
--- belong to the kind's manifest, not here.
--- @param ctx EntityHookContext
--- @return table<string, any>
function p.getStructuredData(ctx)
	local apiData, args, resolved = ctx.apiData, ctx.args, ctx.resolved
	local ed = Editorial.view(resolved)
	local system = systemName(apiData, args)
	local _, parentTarget = parentAnchor(apiData, args)
	-- Stored in the COMPACT vocabulary ('UEE'), the same form StarSystem writes,
	-- so both kinds share one value bucket for queries. The row above shows the
	-- editor's own wording instead, which may link.
	local affiliation = storedAffiliation(apiData, resolved)
	-- Zero is the starmap's no-reading sentinel, so a reading is stored only
	-- when positive: formatSensor returning nil is that test.
	local readings = (celestial(apiData, args) or {}).sensor
	readings = type(readings) == 'table' and readings or {}
	local function rating(value)
		return locationUtil.formatSensor(value) and tonumber(value) or nil
	end
	return {
		system = system and (system .. ' system') or nil,
		affiliation = affiliation,
		parent = parentTarget,
		classification = classification(apiData, args),
		designation = designation(apiData, args, resolved),
		moon_count = tonumber(ed:value('satellites')),
		radius = radiusKm(apiData, resolved),
		population_rating = rating(readings.population),
		economy_rating = rating(readings.economy),
		danger_rating = rating(readings.danger),
	}
end

--- "Terrestrial rocky planet in the Stanton system"; an unclassed body reads
--- "Moon in the Stanton system". No system resolves → the catch-all.
---
--- A moon names the body it orbits, which is the fact a reader wants and the
--- system alone does not give: "Moon of Crusader in the Stanton system". Only a
--- moon, because a planet's parent is the star the system is named after.
--- Suppressed where the parent IS that star, as it is for the moons the starmap
--- hangs straight off one (Gainey, Delamar), since "Moon of Odin in the Odin
--- system" says nothing twice.
--- @param ctx EntityHookContext
--- @return string
function p.getShortDescription(ctx)
	local apiData, args = ctx.apiData, ctx.args
	local system = systemName(apiData, args)
	if not system then
		-- The two fictional bodies have no system but do state a class.
		return classification(apiData, args) or 'A planet in Star Citizen'
	end
	local moon = isMoon(apiData, args)
	local head = classification(apiData, args) or (moon and 'Moon' or 'Planet')
	-- "of <parent>" only reads after a moon noun. A moon carrying a planet-type
	-- classification would otherwise read "Terrestrial rocky planet of Pyro V",
	-- so the parent is dropped rather than the classification the page chose.
	local moonNoun = head == 'Moon' or mw.ustring.match(mw.ustring.lower(head), 'satellite$') ~= nil
	if moon and moonNoun then
		local parentName = parentAnchor(apiData, args)
		if parentName and mw.ustring.lower(parentName) ~= mw.ustring.lower(system) then
			head = head .. ' of ' .. parentName
		end
	end
	return head .. ' in the ' .. system .. ' system'
end

--- VerseGuide keys a body by its system code and the tail of its designation:
--- Hurston's "Stanton I" is STANTON/I, Aberdeen's "Stanton 1b" is STANTON/1B.
--- It covers only what is in the game, so the link is limited to bodies with a
--- game record; a starmap-only body has no page there.
--- @param apiData table
--- @param args table|nil
--- @param resolved table|nil
--- @return string|nil
local function verseguideUrl(apiData, args, resolved)
	if type(apiData.type) ~= 'table' or type(apiData.type.name) ~= 'string' then
		return nil
	end
	local starsystem = getStarsystem(apiData)
	local code = starsystem and starsystem.code or nil
	local text = designation(apiData, args, resolved)
	if type(code) ~= 'string' or code == '' or not text then
		return nil
	end
	-- The designation leads with the system's own name, which the path carries
	-- as the code instead. Compared rather than pattern-matched: system names
	-- hold apostrophes and dots (Kai'pua, T.āl, R.il'a).
	local name = type(starsystem.name) == 'string' and starsystem.name or nil
	if name and mw.ustring.lower(mw.ustring.sub(text, 1, mw.ustring.len(name))) == mw.ustring.lower(name) then
		text = mw.text.trim(mw.ustring.sub(text, mw.ustring.len(name) + 1))
	end
	local suffix = (mw.ustring.upper(text):gsub('%s+', ''))
	if suffix == '' then
		return nil
	end
	return 'https://verseguide.com/location/' .. mw.ustring.upper(code) .. '/' .. suffix
end

--- RSI Starmap and VerseGuide as footer action buttons, both keyed off values
--- already resolved for the page.
--- @param ctx EntityHookContext
--- @return table[]
function p.getFooterButtons(ctx)
	local buttons = locationUtil.starmapFooterButtons(resolvedStarmapCode(ctx.apiData, ctx.args))
	local verseguide = verseguideUrl(ctx.apiData, ctx.args, ctx.resolved)
	if verseguide then
		buttons[#buttons + 1] = {
			label = 'VerseGuide',
			url = verseguide,
			icon = 'VerseGuide logo.svg',
			class = 't-button--branded t-button--verseguide',
		}
	end
	return buttons
end

--- Chain-contributed Metadata rows: the ARK starmap code.
--- @param ctx EntityHookContext
--- @return EntityItemData[]
function p.getMetadataItems(ctx)
	return locationUtil.starmapMetadataItems(resolvedStarmapCode(ctx.apiData, ctx.args))
end

-- Test-only exports. Not part of the public API.
p._internal = {
	isMoon = isMoon,
	storedAffiliation = storedAffiliation,
	verseguideUrl = verseguideUrl,
	affiliationText = affiliationText,
	resolvedStarmapCode = resolvedStarmapCode,
	radiusKm = radiusKm,
	radiusDisplay = radiusDisplay,
	classification = classification,
	systemName = systemName,
	parentAnchor = parentAnchor,
	locationChain = locationChain,
}

return p
