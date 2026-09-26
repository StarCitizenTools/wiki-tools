require('strict')

--- @module Entity/Location/Place
--- The place leaf of the Location kind: stations, outposts, landing zones and
--- the venues inside them, in one leaf because a place differs from another
--- in values (class, zone, amenities), not in shape. The class comes from the
--- curated |classification= (Module:Entity/Location/Place/Classes); where the
--- place sits comes from the record, so a racetrack can be on a surface or in
--- space whatever its class.

local Editorial = require('Module:Entity/Editorial')
local Store = require('Module:Entity/Store')
local amenities = require('Module:Entity/Location/Place/Amenities')
local classes = require('Module:Entity/Location/Place/Classes')
local jurisdiction = require('Module:Entity/Location/Jurisdiction')
local locationUtil = require('Module:Entity/Location/Util')
local sectionBuilder = require('Module:Entity/SectionBuilder')

local p = {}

--- @type string
p.parent = 'Entity/Location'

--- Family token: dispatched by Location.resolveSubtype for place records, and
--- named by |family=place on every page with no record.
p.family = 'place'

--- No entry takes a property key: getStructuredData stores what it stores, so
--- display and store cannot diverge.
--- @return table
function p.getEditorialManifest()
	return {
		classification = { arg = 'classification' },
		parent = { arg = 'parent' },
		lagrange = { arg = 'lagrange' },
		zone = { arg = 'zone' },
		operator = { arg = 'operator' },
		jurisdiction = { arg = 'jurisdiction' },
		system = { arg = 'system' },
		starmapcode = { arg = { 'starmapcode', 'code' } },
		founder = { arg = 'founder' },
		founded = { arg = 'founded' },
		population = { arg = 'population' },
	}
end

--- A raw editor arg, through this leaf's own manifest. Raw because
--- getTypeInfo and enrich run before editorial resolution.
--- @param args table|nil
--- @param key string
--- @return string|nil
local function arg(args, key)
	return locationUtil.manifestArg(args, p.getEditorialManifest(), key)
end

--- @param args table|nil
--- @return string|nil
local function starmapCode(args)
	return arg(args, 'starmapcode')
end

--- @param args table|nil
--- @return { name: string, category: string, parent: string, zone: string }|nil
local function classEntry(args)
	return classes.get(arg(args, 'classification'))
end

--- Valid Lagrange point tokens, keyed lower-case for case-insensitive lookup.
local LAGRANGE_POINTS = { l1 = 'L1', l2 = 'L2', l3 = 'L3', l4 = 'L4', l5 = 'L5' }

--- L1-L5, upper-cased; nil for anything else, including an unrecognised
--- |lagrange= value — an invalid value must not force the lagrange zone.
--- @param args table|nil
--- @return string|nil
local function lagrangePoint(args)
	local value = arg(args, 'lagrange')
	return type(value) == 'string' and LAGRANGE_POINTS[mw.ustring.lower(value)] or nil
end

--- @param apiData table
--- @param field 'type'|'parent'
--- @return string|nil
local function recordTypeName(apiData, field)
	local node = type(apiData) == 'table' and apiData[field] or nil
	if type(node) ~= 'table' then
		return nil
	end
	local name = field == 'type' and node.name or node.type_name
	return type(name) == 'string' and name or nil
end

--- Record types that sit on a surface, and in space. A record whose PARENT is
--- one of CONTAINERS is inside that place (a clinic in a station, a hospital
--- in a landing zone), whatever its own type.
local SURFACE_TYPES = { Outpost = true, Outpost_InvalidQT = true, LandingZone = true }
local SPACE_TYPES = { Manmade = true, Manmade_VisibleOnInteraction = true, Asteroid_ValidQT = true }
local CONTAINERS = {
	LandingZone = true,
	Manmade = true,
	Manmade_VisibleOnInteraction = true,
	Outpost = true,
	PointOfInterest = true,
	Asteroid_ValidQT = true,
}

--- Where the place sits: a valid curated |lagrange= first, then a valid
--- curated |zone=, then the record (a container parent wins over the
--- record's own type — a clinic inside a station is "inside" even though a
--- station is itself an "orbit"/"star" type), then the class's default. A
--- curated |zone= wins over the record because the record can be wrong: the
--- API parents Levski to the star (Nyx) though it sits on Delamar, and some
--- Pyro stations are likewise parented to the star while orbiting a planet;
--- the migration sets |zone= deliberately on those pages, not as stale data.
--- @param apiData table
--- @param args table|nil
--- @return string|nil
local function zone(apiData, args)
	if lagrangePoint(args) then
		return 'lagrange'
	end
	local curated = arg(args, 'zone')
	if type(curated) == 'string' and classes.ZONES[mw.ustring.lower(curated)] then
		return mw.ustring.lower(curated)
	end
	local parentType = recordTypeName(apiData, 'parent')
	if parentType and CONTAINERS[parentType] then
		return 'inside'
	end
	local ownType = recordTypeName(apiData, 'type')
	if ownType and SURFACE_TYPES[ownType] then
		return 'surface'
	end
	if ownType and SPACE_TYPES[ownType] then
		return parentType == 'Star' and 'star' or 'orbit'
	end
	local entry = classEntry(args)
	return entry and entry.zone or nil
end

--- True when a curated |lagrange= or |zone= was given but does not validate
--- (an editor typo, a free-text note): that value is dropped rather than
--- stored or shown, so this tracking category is the only trace it was ever
--- there. Also true for a valid |lagrange= with no curated |parent=, but
--- there the point is NOT dropped: zone() still forces the lagrange zone and
--- getStructuredData still stores the point, so the category there flags only
--- the missing parent, not a missing value.
--- @param args table|nil
--- @return boolean
local function hasInvalidZoneOrLagrange(args)
	local lagrange = arg(args, 'lagrange')
	if type(lagrange) == 'string' and not lagrangePoint(args) then
		return true
	end
	local curatedZone = arg(args, 'zone')
	if type(curatedZone) == 'string' and not classes.ZONES[mw.ustring.lower(curatedZone)] then
		return true
	end
	-- A Lagrange point is a point OF a body: without a curated |parent= the page
	-- attaches it to the record's star.
	if lagrangePoint(args) and not arg(args, 'parent') then
		return true
	end
	return false
end

--- A page name without its trailing disambiguator: "MicroTech (company)" reads
--- "MicroTech". Byte patterns are safe here because the parentheses are ASCII.
--- @param page string
--- @return string
local function withoutQualifier(page)
	return mw.text.trim((page:gsub('%s*%b()$', '')))
end

--- A curated wiki link split into its target and pipe text: "[[A|B]]" gives
--- target A, display B; "[[A]]" gives target A, no display. Text with no
--- link markup passes through Editorial.toStoredValue as the target, with no
--- separate display. The PAGE columns this feeds (Parent, Operator) must
--- store the link TARGET, never the display text a pipe substitutes for it.
--- @param text string
--- @return string target
--- @return string|nil display
local function linkTarget(text)
	local clean = Editorial.stripMarkup(text)
	local target, display = clean:match('^%[%[([^%[%]|]+)|([^%[%]]+)%]%]$')
	if target then
		return mw.text.trim(target), mw.text.trim(display)
	end
	target = clean:match('^%[%[([^%[%]]+)%]%]$')
	if target then
		return mw.text.trim(target), nil
	end
	return Editorial.toStoredValue(text), nil
end

--- The parent as display name plus page. A curated |parent= wins, because the
--- API parents Lagrange stations to the star and pages with no record have
--- none; a piped link shows its own text, else the target with a
--- disambiguating "(planet)" dropped.
--- @param apiData table
--- @param args table|nil
--- @return string|nil name
--- @return string|nil target
local function parentAnchor(apiData, args)
	local curated = arg(args, 'parent')
	if type(curated) == 'string' then
		local target, display = linkTarget(curated)
		return display or withoutQualifier(target), target
	end
	local parent = type(apiData.parent) == 'table' and apiData.parent or nil
	if not parent or type(parent.name) ~= 'string' or parent.name == '' then
		return nil, nil
	end
	if parent.type_name == 'Star' then
		return parent.name, locationUtil.anchorTitle(parent.name, 'star')
	end
	if parent.type_name == 'Planet' or parent.type_name == 'Moon' then
		return parent.name, locationUtil.anchorTitle(parent.name, 'planet')
	end
	return parent.name, parent.name
end

--- @param apiData table
--- @param args table|nil
--- @return string|nil
local function systemName(apiData, args)
	return locationUtil.systemNameFrom(apiData, args, p.getEditorialManifest())
end

--- The jurisdiction name: an editor's override, else what enrich resolved.
--- @param apiData table
--- @param args table|nil
--- @return string|nil
local function jurisdictionName(apiData, args)
	local curated = arg(args, 'jurisdiction')
	if type(curated) == 'string' then
		return Editorial.toStoredValue(curated)
	end
	local inherited = apiData.inheritedJurisdiction
	return type(inherited) == 'string' and inherited ~= '' and inherited or nil
end

--- The operator as display text plus page target, the same shape as
--- parentAnchor: a piped link shows its own text, else the bare target with
--- a disambiguating qualifier dropped.
--- @param args table|nil
--- @return string|nil display
--- @return string|nil target
local function operatorAnchor(args)
	local curated = arg(args, 'operator')
	if type(curated) ~= 'string' then
		return nil, nil
	end
	local target, display = linkTarget(curated)
	return display or withoutQualifier(target), target
end

--- The Operator row's content. When the raw |operator= already opens with a
--- wikilink, the row renders that raw arg as written, so a trailing <ref>
--- (a strip marker by the time Lua sees it) survives after the link; the
--- stored value and category still come from operatorAnchor's parsed target.
--- Otherwise the row links the resolved target to its display text, same as
--- getStructuredData/getCategories see it.
--- @param args table|nil
--- @return string|nil
local function operatorRowContent(args)
	local raw = arg(args, 'operator')
	if type(raw) == 'string' and Editorial.stripMarkup(raw):sub(1, 2) == '[[' then
		return raw
	end
	local display, target = operatorAnchor(args)
	return target and ('[[' .. target .. '|' .. display .. ']]') or nil
end

--- Resolves the jurisdiction once and attaches the system payload the Location
--- row's affiliation tier reads. A page with a record walks the GAME parent
--- chain; a page with none reads its curated parent page's stored value.
--- @param ctx EntityHookContext
--- @return table apiData
function p.enrich(ctx)
	local apiData, args = ctx.apiData, ctx.args
	if not arg(args, 'jurisdiction') then
		if type(apiData.uuid) == 'string' and apiData.uuid ~= '' then
			apiData.inheritedJurisdiction = jurisdiction.resolve(apiData)
		else
			local _, target = parentAnchor(apiData, args)
			apiData.inheritedJurisdiction = Store.pageValue(target, 'Jurisdiction', 'Location')
		end
	end
	local system = systemName(apiData, args)
	if system then
		return locationUtil.attachStarsystem(apiData, args, system)
	end
	return apiData
end

--- @param ctx EntityHookContext
--- @return { name: string, category: string }
function p.getTypeInfo(ctx)
	local entry = classEntry(ctx.args)
	if not entry then
		return { name = 'Location', category = 'Locations with an unknown classification' }
	end
	return { name = entry.name, category = entry.category }
end

--- The class, linked to its category.
--- @param ctx EntityHookContext
--- @return string|nil
function p.getSubtitle(ctx)
	local entry = classEntry(ctx.args)
	if not entry then
		return nil
	end
	return '[[:Category:' .. entry.category .. '|' .. entry.name .. ']]'
end

--- The operator's category, the system's, and a tracking category for an
--- invalid curated |zone= or |lagrange=. The class category comes from
--- getTypeInfo; nothing here describes where the place is.
--- @param ctx EntityHookContext
--- @return string[]
function p.getCategories(ctx)
	local categories = {}
	local _, operatorTarget = operatorAnchor(ctx.args)
	if operatorTarget then
		categories[#categories + 1] = operatorTarget
	end
	local system = systemName(ctx.apiData, ctx.args)
	if system then
		categories[#categories + 1] = system .. ' system'
	end
	if hasInvalidZoneOrLagrange(ctx.args) then
		categories[#categories + 1] = 'Locations with an invalid zone or Lagrange point'
	end
	return categories
end

--- The Location row: the kind's `affiliation space › system › parent`, plus
--- the Lagrange point as a last tier.
--- @param apiData table
--- @param args table|nil
--- @return string|nil
local function locationChain(apiData, args)
	local name, target = parentAnchor(apiData, args)
	local chain =
		locationUtil.locationChain(locationUtil.starsystemOf(apiData), systemName(apiData, args), name, target)
	local point = lagrangePoint(args)
	if chain and point then
		return chain .. ' › ' .. point
	end
	return chain
end

--- @param ctx EntityHookContext
--- @return EntitySectionEntry[]
function p.getSections(ctx)
	local apiData, args = ctx.apiData, ctx.args
	local ed = Editorial.view(ctx.resolved)

	local general = {}
	sectionBuilder.push(general, 'Location', locationChain(apiData, args))
	sectionBuilder.push(general, 'Operator', operatorRowContent(args))
	sectionBuilder.push(general, 'Jurisdiction', jurisdiction.display(jurisdictionName(apiData, args)))

	local amenityItems = {}
	for _, row in ipairs(amenities.group(amenities.names(apiData))) do
		sectionBuilder.push(amenityItems, row.label, row.text)
	end

	local lore = {}
	sectionBuilder.push(lore, 'Founder', ed:value('founder'))
	sectionBuilder.push(lore, 'Founded', ed:value('founded'))
	sectionBuilder.push(lore, 'Population', ed:value('population'))

	return sectionBuilder.build(
		sectionBuilder.section({ key = 'general', items = general }),
		sectionBuilder.section({ key = 'amenities', label = 'Amenities', collapsible = true, items = amenityItems }),
		sectionBuilder.section({ key = 'lore', label = 'Lore', collapsible = true, items = lore })
	)
end

--- @param ctx EntityHookContext
--- @return table<string, any>
function p.getStructuredData(ctx)
	local apiData, args = ctx.apiData, ctx.args
	local entry = classEntry(args)
	local system = systemName(apiData, args)
	local _, parentTarget = parentAnchor(apiData, args)
	local _, operatorTarget = operatorAnchor(args)
	local names = amenities.names(apiData)
	return {
		classification = entry and entry.name or nil,
		zone = zone(apiData, args),
		lagrange_point = lagrangePoint(args),
		parent = parentTarget,
		system = system and (system .. ' system') or nil,
		operator = operatorTarget,
		jurisdiction = jurisdictionName(apiData, args),
		amenities = names[1] and names or nil,
	}
end

--- The word that places a class against its parent, by zone.
local PREPOSITIONS = { surface = 'on', inside = 'in', orbit = 'orbiting' }

--- "Landing zone on microTech in the Stanton system", "Rest stop at ArcCorp L2
--- in the Stanton system", "Spaceport in Area18 in the Stanton system".
--- @param ctx EntityHookContext
--- @return string
function p.getShortDescription(ctx)
	local apiData, args = ctx.apiData, ctx.args
	local entry = classEntry(args)
	local text = entry and entry.name or 'Location'
	local parentName = parentAnchor(apiData, args)
	local where = zone(apiData, args)
	local point = lagrangePoint(args)
	if parentName then
		if where == 'lagrange' and point then
			text = text .. ' at ' .. parentName .. ' ' .. point
		elseif PREPOSITIONS[where] then
			text = text .. ' ' .. PREPOSITIONS[where] .. ' ' .. parentName
		end
	end
	local system = systemName(apiData, args)
	if system then
		text = text .. ' in the ' .. system .. ' system'
	end
	return text
end

--- @param ctx EntityHookContext
--- @return table[]
function p.getFooterButtons(ctx)
	return locationUtil.starmapFooterButtons(starmapCode(ctx.args))
end

--- @param ctx EntityHookContext
--- @return EntityItemData[]
function p.getMetadataItems(ctx)
	return locationUtil.starmapMetadataItems(starmapCode(ctx.args))
end

-- Test-only exports. Not part of the public API.
p._internal = {
	zone = zone,
	parentAnchor = parentAnchor,
	jurisdictionName = jurisdictionName,
	locationChain = locationChain,
	starmapCode = starmapCode,
}

return p
