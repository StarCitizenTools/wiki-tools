require('strict')

--- @module Entity/Location/JumpPoint
--- Jump-point leaf of the Location kind: the in-game gate pages (one page per
--- gate, "Pyro - Nyx jump point"). Renders from the merged payload the kind
--- assembles: the location record at the top level (name, system, jurisdiction,
--- quantum_travel radii) plus the starmap celestial-object record at
--- apiData.celestialobject (attached by this leaf's enrich through
--- locationUtil.attachCelestialObject from the editor's starmap code; may be
--- absent — every consumer nil-guards and degrades to location-only rows).
--- apiData.starsystem is never present here: the two starmap bridges are
--- mutually exclusive by construction.

local boolean = require('Module:Boolean')
local locationUtil = require('Module:Entity/Location/Util')
local sectionBuilder = require('Module:Entity/SectionBuilder')
local Editorial = require('Module:Entity/Editorial')

local p = {}

--- @type string
p.parent = 'Entity/Location'

--- Family token: dispatched by Location.resolveSubtype and named by a curated
--- |family=jumppoint on the starmap-only tunnels that have no location record.
p.family = 'jumppoint'

-- Transitional (see Module:Entity/Assembly.callHook): hooks take an EntityHookContext.
p.contextHooks = true

--- @param ctx EntityHookContext
--- @return table apiData
function p.enrich(ctx)
	return locationUtil.attachCelestialObject(
		ctx.apiData,
		Editorial.rawArg(ctx.args, p.getEditorialManifest().starmapcode)
	)
end

--- The starmap celestial-object code (`code` is the legacy {{Astronomical
--- object}} arg name). No smw key, no transform: this leaf surfaces it itself
--- (metadata row, Starmap button). enrich and the starmapCode accessor read
--- the RAW arg through Editorial.rawArg with this entry, so the alias order
--- is declared here once.
--- This leaf declares the starmapcode entry itself, so its own fragment is
--- the merged chain manifest's value for the field — reading its own entry
--- here (rather than the merged manifest) is correct only because of that.
--- @return table
function p.getEditorialManifest()
	return {
		starmapcode = { arg = { 'starmapcode', 'code' } },
	}
end

--- Jump-point gates file under their entry system's category ("Pyro
--- system") — a FUNCTIONAL membership, not just browse taxonomy:
--- {{System navplate}} builds its "Jump points" row from the per-system
--- category intersected with Jump points. The legacy pages' flat
--- 'Astronomical objects'/'Locations' memberships are deliberately NOT
--- carried over: the classification bucket (typeInfo's 'Jump points', under
--- Astronomy) covers that taxonomy.
--- @param ctx EntityHookContext
--- @return string[]
function p.getCategories(ctx)
	local apiData = ctx.apiData
	local entry = locationUtil.gateEntrySystem(apiData)
	if entry then
		return { entry .. ' system' }
	end
	return {}
end

--- Starmap jumppoints.size letter → display label. An unmapped letter yields
--- nil (no Size row, nothing stored) rather than leaking a raw code.
local SIZE_LABELS = {
	S = 'Small',
	M = 'Medium',
	L = 'Large',
}

--- @param apiData table
--- @return table|nil
local function getCelestialObject(apiData)
	return type(apiData.celestialobject) == 'table' and apiData.celestialobject or nil
end

--- The gate's two systems, read off the page's own canonical name. The title
--- IS the curated statement of which gate this is ("<Entry> - <Destination>
--- jump point") and it uses canonical system names by construction, whereas
--- the upstream celestial designation carries three naming forms that are not
--- wiki page names: alias parentheticals ("Kyuk'ya (Indra)"), the Vanduul
--- catalogue form (VS-9 "Vulture"), and — on one live tunnel — a bare legacy
--- name ("Th.us'ūng (Pallas) - Hadur", where Hadur is now Yā'mon). Each would
--- render a red link, file a wrong category and store a junk System value, and
--- the legacy-name case cannot be repaired by stripping decorations at all.
--- The designation stays as the fallback for a page whose name is not
--- gate-shaped.
--- @param args table|nil
--- @return string|nil entry
--- @return string|nil destination
local function titleSystems(args)
	local name = args and type(args.name) == 'string' and args.name ~= '' and args.name or nil
	if not name then
		local title = mw.title.getCurrentTitle()
		name = title and title.text or nil
	end
	if type(name) ~= 'string' then
		return nil, nil
	end
	local base = mw.text.trim((name:gsub('%s+[Jj]ump%s+[Pp]oint$', '')))
	local a, b = base:match('^(.-)%s+%-%s+(.+)$')
	if not a then
		return nil, nil
	end
	return locationUtil.systemShortName(a), locationUtil.systemShortName(b)
end

--- The gate's entry system: the canonical name on the page first, then the
--- kind's record/designation chain.
--- @param apiData table
--- @param args table|nil
--- @return string|nil
local function entryFor(apiData, args)
	local fromTitle = titleSystems(args)
	return fromTitle or locationUtil.gateEntrySystem(apiData)
end

--- The system on the far side of the tunnel (short form), parsed from the
--- celestial designation "<A> - <B>". The destination is WHICHEVER side is not
--- the entry system — the designation's order is not assumed, so a record
--- that leads with the far side still resolves correctly. When the entry
--- system is unknown or matches neither side, nil: guessing a side could name
--- the gate's own system as its destination.
--- @param apiData table
--- @return string|nil
local function destinationSystem(apiData, args)
	local _, fromTitle = titleSystems(args)
	if fromTitle then
		return fromTitle
	end
	local celestial = getCelestialObject(apiData)
	local designation = celestial and celestial.designation or nil
	if type(designation) ~= 'string' then
		return nil
	end
	local sideA, sideB = designation:match('^(.-)%s+%-%s+(.+)$')
	local entry = entryFor(apiData, args)
	if not sideA or not entry then
		return nil
	end
	sideA, sideB = mw.text.trim(sideA), mw.text.trim(sideB)
	if sideA:lower() == entry:lower() then
		return locationUtil.systemShortName(sideB)
	end
	if sideB:lower() == entry:lower() then
		return locationUtil.systemShortName(sideA)
	end
	return nil
end

--- @param celestial table|nil
--- @return string|nil 'Small' | 'Medium' | 'Large'
local function sizeLabel(celestial)
	local jumppoints = celestial and type(celestial.jumppoints) == 'table' and celestial.jumppoints or nil
	local size = jumppoints and jumppoints.size or nil
	return size ~= nil and SIZE_LABELS[size] or nil
end

--- The gate's parent anchor (display name + link-candidate title). A Star
--- parent's candidate is its `(star)` page ("Pyro (star)"); anything else —
--- the gateway stations — gets the wiki's system-disambiguated title
--- ("Pyro Gateway (Stanton)": two stations share the name "Pyro Gateway", one
--- per side, so the bare title is a disambiguation page and must not be
--- linked). The candidate may be nil (no entry system to disambiguate with)
--- while the name still displays as plain text.
--- @param apiData table
--- @return string|nil name
--- @return string|nil candidate
local function parentLinkCandidate(apiData, args)
	local parent = type(apiData.parent) == 'table' and apiData.parent or nil
	local name = parent and type(parent.name) == 'string' and parent.name ~= '' and parent.name or nil
	if not name then
		return nil, nil
	end
	if parent.type_name == 'Star' then
		return name, name .. ' (star)'
	end
	local entry = entryFor(apiData, args)
	return name, entry and (name .. ' (' .. entry .. ')') or nil
end

--- Display wrapper over parentLinkCandidate: link the candidate when its page
--- exists (one existence check per render), else plain text. Kept thin and
--- untested offline — the runner's title shim cannot answer `exists`; the
--- candidate selection above carries the logic and the tests.
--- @param apiData table
--- @return string|nil
local function parentDisplay(apiData, args)
	local name, candidate = parentLinkCandidate(apiData, args)
	if not name then
		return nil
	end
	local title = candidate and mw.title.new(candidate) or nil
	if title and title.exists then
		return '[[' .. candidate .. '|' .. name .. ']]'
	end
	return name
end

--- The Starmap row: whether the gate appears in the in-game starmap app, as
--- the standard tri-state boolean icon (Mission's Shareable row is the
--- precedent). The value is `hide_in_starmap` NEGATED — the icon answers "is
--- it on the starmap?", so a shown gate gets the green check. An absent field
--- yields no row, never the Unknown icon: that would claim uncertainty about
--- data the record simply does not carry.
--- @param apiData table
--- @return string|nil
local function starmapVisibility(apiData)
	if type(apiData.hide_in_starmap) ~= 'boolean' then
		return nil
	end
	return boolean.render(not apiData.hide_in_starmap)
end

--- The ARK starmap code (the `?location=` key): the fetched celestial record's
--- own code first, else the raw |starmapcode=/|code= arg read through the
--- manifest entry enrich fetches with, so a page whose fetch soft-failed
--- still gets its button and metadata row from the arg that would have keyed
--- it. One accessor for both consumers (Starmap button, Metadata row): they
--- cannot drift, and the empty case is rejected once.
--- @param apiData table
--- @param args table|nil
--- @return string|nil
local function starmapCode(apiData, args)
	local celestial = getCelestialObject(apiData)
	local code = celestial and celestial.code or nil
	if type(code) == 'string' and code ~= '' then
		return code
	end
	return Editorial.rawArg(args, p.getEditorialManifest().starmapcode)
end

--- @param ctx EntityHookContext
--- @return { name: string, category: string }
function p.getTypeInfo(ctx)
	return {
		name = 'Jump point',
		category = 'Jump points',
	}
end

--- @param ctx EntityHookContext
--- @return EntitySectionEntry[]
function p.getSections(ctx)
	local apiData, args, resolved = ctx.apiData, ctx.args, ctx.resolved
	local ed = Editorial.view(resolved)
	local celestial = getCelestialObject(apiData)

	local general = {}
	local entry = entryFor(apiData, args)
	sectionBuilder.push(general, 'System', entry and ('[[' .. entry .. ' system]]'))
	local destination = destinationSystem(apiData, args)
	sectionBuilder.push(general, 'Destination', destination and ('[[' .. destination .. ' system]]'))
	sectionBuilder.push(general, 'Parent', parentDisplay(apiData, args))
	sectionBuilder.push(general, 'Size', sizeLabel(celestial))
	local jurisdiction = type(apiData.jurisdiction) == 'table' and apiData.jurisdiction.name or nil
	sectionBuilder.push(general, 'Jurisdiction', jurisdiction and ('[[' .. jurisdiction .. ']]'))

	local travel = {}
	local radii = type(apiData.quantum_travel) == 'table' and apiData.quantum_travel or {}
	sectionBuilder.push(travel, 'Arrival radius', radii.arrival_radius_formatted)
	sectionBuilder.push(travel, 'Obstruction radius', radii.obstruction_radius_formatted)
	sectionBuilder.push(travel, 'Starmap', starmapVisibility(apiData))

	local lore = {}
	sectionBuilder.push(lore, 'Discovered in', ed:value('discoveredin'))
	sectionBuilder.push(lore, 'Discovered by', ed:value('discoveredby'))
	sectionBuilder.push(lore, 'Historical names', ed:value('historicalnames'))

	return sectionBuilder.build(
		sectionBuilder.section({ key = 'general', items = general }),
		-- collapsible with no `collapsed` renders open (StarSystem's Lore
		-- idiom): the radii are the gate's headline in-game numbers.
		sectionBuilder.section({
			key = 'travel',
			label = 'Travel',
			collapsible = true,
			items = travel,
		}),
		sectionBuilder.section({ key = 'lore', label = 'Lore', collapsible = true, items = lore })
	)
end

--- Store what the infobox displays: the mapped size label and the two system
--- PAGE names ("Pyro system"), so [[System::Pyro system]] queries resolve the
--- actual wiki pages. discoveredin/discoveredby storage is owned by the
--- editorial manifest — not double-stored here.
--- @param ctx EntityHookContext
--- @return table<string, any>
function p.getStructuredData(ctx)
	local apiData, args = ctx.apiData, ctx.args
	local entry = entryFor(apiData, args)
	local destination = destinationSystem(apiData, args)
	return {
		jump_point_size = sizeLabel(getCelestialObject(apiData)),
		system = entry and (entry .. ' system') or nil,
		destination_system = destination and (destination .. ' system') or nil,
	}
end

--- Gate-directional, no trailing period: "Medium jump point from Pyro to Nyx".
--- No size → "Jump point from Pyro to Nyx"; either system unresolvable → the
--- catch-all (a bare "Medium jump point" names no route and reads wrong).
--- @param ctx EntityHookContext
--- @return string
function p.getShortDescription(ctx)
	local apiData, args = ctx.apiData, ctx.args
	local entry = entryFor(apiData, args)
	local destination = destinationSystem(apiData, args)
	if entry and destination then
		local size = sizeLabel(getCelestialObject(apiData))
		local head = size and (size .. ' jump point') or 'Jump point'
		return head .. ' from ' .. entry .. ' to ' .. destination
	end
	return 'A jump point in Star Citizen'
end

--- RSI Starmap as a footer action button, from the shared code accessor.
--- Same button contract as StarSystem's (the Galactapedia mark doubles as the
--- Starmap's logo); no usable code → no button.
--- @param ctx EntityHookContext
--- @return table[]
function p.getFooterButtons(ctx)
	local apiData, args = ctx.apiData, ctx.args
	local code = starmapCode(apiData, args)
	if not code then
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

--- Chain-contributed Metadata rows: the ARK starmap code, through the same
--- accessor as the footer button so the two cannot disagree.
--- @param ctx EntityHookContext
--- @return EntityItemData[]
function p.getMetadataItems(ctx)
	local apiData, args = ctx.apiData, ctx.args
	local code = starmapCode(apiData, args)
	if not code then
		return {}
	end
	return { { label = 'Starmap code', content = code } }
end

-- Test-only exports. Not part of the public API.
p._internal = {
	destinationSystem = destinationSystem,
	sizeLabel = sizeLabel,
	parentLinkCandidate = parentLinkCandidate,
	parentDisplay = parentDisplay,
	starmapVisibility = starmapVisibility,
	starmapCode = starmapCode,
	SIZE_LABELS = SIZE_LABELS,
}

return p
