require('strict')

--- @module Entity/Location/JumpPoint
--- Jump-point leaf of the Location kind: the in-game gate pages (one page per
--- gate, "Pyro - Nyx jump point"). Renders from the merged payload the kind
--- assembles: the location record at the top level (name, system, jurisdiction,
--- quantum_travel radii) plus the starmap celestial-object record at
--- apiData.celestialobject (attached by Location.enrich from the editor's
--- starmap code; may be absent — every consumer nil-guards and degrades to
--- location-only rows). apiData.starsystem is never present here: the two
--- starmap bridges are mutually exclusive by construction.

local location = require('Module:Entity/Location')
local sectionBuilder = require('Module:Entity/SectionBuilder')
local Editorial = require('Module:Entity/Editorial')

local p = {}

--- @type string
p.parent = 'Entity/Location'

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

--- A system name reduced to its bare form: a trailing " System"/" system"
--- stripped, whitespace trimmed ("Pyro System" → "Pyro", "Nyx" → "Nyx").
--- This is the short form the short description uses; page links and stored
--- values append the lowercase " system" suffix to it ("Pyro system"), the
--- wiki's canonical system page-name form.
--- @param name any
--- @return string|nil
local function systemShortName(name)
	if type(name) ~= 'string' then
		return nil
	end
	local short = mw.text.trim(name:gsub('%s+[Ss]ystem$', ''))
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
local function entrySystem(apiData)
	local system = apiData.system
	if type(system) == 'table' then
		system = system.name
	end
	return systemShortName(system)
end

--- The system on the far side of the tunnel (short form), parsed from the
--- celestial designation "<A> - <B>". The destination is WHICHEVER side is not
--- the entry system — the designation's order is not assumed, so a record
--- that leads with the far side still resolves correctly. When the entry
--- system is unknown or matches neither side, nil: guessing a side could name
--- the gate's own system as its destination.
--- @param apiData table
--- @return string|nil
local function destinationSystem(apiData)
	local celestial = getCelestialObject(apiData)
	local designation = celestial and celestial.designation or nil
	if type(designation) ~= 'string' then
		return nil
	end
	local sideA, sideB = designation:match('^(.-)%s+%-%s+(.+)$')
	local entry = entrySystem(apiData)
	if not sideA or not entry then
		return nil
	end
	sideA, sideB = mw.text.trim(sideA), mw.text.trim(sideB)
	if sideA:lower() == entry:lower() then
		return systemShortName(sideB)
	end
	if sideB:lower() == entry:lower() then
		return systemShortName(sideA)
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

--- Distance from the star as a display string ("13 AU"), or nil. The starmap
--- reports 0 where it has no measurement (the withheld-survey lesson: zero is
--- "no data", not a distance), so only a positive number renders or stores.
--- @param celestial table|nil
--- @return string|nil
local function distanceDisplay(celestial)
	local distance = celestial and tonumber(celestial.distance) or nil
	if not distance or distance <= 0 then
		return nil
	end
	return tostring(distance) .. ' AU'
end

--- The ARK starmap code (the `?location=` key): the fetched celestial record's
--- own code first, else the raw |starmapcode=/|code= arg (via the kind's
--- shared starmapCodeArg accessor — the same alias order enrich fetches with,
--- so a page whose fetch soft-failed still gets its button and metadata row
--- from the arg that would have keyed it). One accessor for both consumers
--- (Starmap button, Metadata row), StarSystem's pattern: they cannot drift,
--- and the empty case is rejected once.
--- @param apiData table
--- @param args table|nil
--- @return string|nil
local function starmapCode(apiData, args)
	local celestial = getCelestialObject(apiData)
	local code = celestial and celestial.code or nil
	if type(code) == 'string' and code ~= '' then
		return code
	end
	return location._internal.starmapCodeArg(args)
end

--- @return { name: string, category: string }
function p.getTypeInfo()
	return {
		name = 'Jump point',
		category = 'Jump points',
	}
end

--- @param apiData table
--- @param args table
--- @param resolved table|nil
--- @return EntitySectionEntry[]
function p.getSections(apiData, args, resolved)
	local ed = Editorial.view(resolved)
	local celestial = getCelestialObject(apiData)

	local general = {}
	local entry = entrySystem(apiData)
	sectionBuilder.push(general, 'System', entry and ('[[' .. entry .. ' system]]'))
	local destination = destinationSystem(apiData)
	sectionBuilder.push(general, 'Destination', destination and ('[[' .. destination .. ' system]]'))
	sectionBuilder.push(general, 'Size', sizeLabel(celestial))
	local jurisdiction = type(apiData.jurisdiction) == 'table' and apiData.jurisdiction.name or nil
	sectionBuilder.push(general, 'Jurisdiction', jurisdiction and ('[[' .. jurisdiction .. ']]'))
	sectionBuilder.push(general, 'Distance from star', distanceDisplay(celestial))

	local quantumTravel = {}
	local radii = type(apiData.quantum_travel) == 'table' and apiData.quantum_travel or {}
	sectionBuilder.push(quantumTravel, 'Arrival radius', radii.arrival_radius_formatted)
	sectionBuilder.push(quantumTravel, 'Adoption radius', radii.adoption_radius_formatted)
	sectionBuilder.push(quantumTravel, 'Obstruction radius', radii.obstruction_radius_formatted)

	local lore = {}
	sectionBuilder.push(lore, 'Discovered in', ed:value('discoveredin'))
	sectionBuilder.push(lore, 'Discovered by', ed:value('discoveredby'))
	sectionBuilder.push(lore, 'Historical names', ed:value('historicalnames'))

	return sectionBuilder.build(
		sectionBuilder.section({ key = 'general', items = general }),
		-- collapsible with no `collapsed` renders open (StarSystem's Lore
		-- idiom): the radii are the gate's headline in-game numbers.
		sectionBuilder.section({
			key = 'quantumtravel',
			label = 'Quantum travel',
			collapsible = true,
			items = quantumTravel,
		}),
		sectionBuilder.section({ key = 'lore', label = 'Lore', collapsible = true, items = lore })
	)
end

--- Store what the infobox displays: the mapped size label and the two system
--- PAGE names ("Pyro system"), so [[System::Pyro system]] queries resolve the
--- actual wiki pages. discoveredin/discoveredby storage is owned by the
--- editorial manifest — not double-stored here.
--- @param apiData table
--- @param args table
--- @param resolved table|nil
--- @return table<string, any>
function p.getStructuredData(apiData, args, resolved)
	local entry = entrySystem(apiData)
	local destination = destinationSystem(apiData)
	return {
		jump_point_size = sizeLabel(getCelestialObject(apiData)),
		system = entry and (entry .. ' system') or nil,
		destination_system = destination and (destination .. ' system') or nil,
	}
end

--- Gate-directional, no trailing period: "Medium jump point from Pyro to Nyx".
--- No size → "Jump point from Pyro to Nyx"; either system unresolvable → the
--- catch-all (a bare "Medium jump point" names no route and reads wrong).
--- @param apiData table
--- @param args table
--- @param typeInfo table
--- @param prefix string|nil
--- @param resolved table|nil
--- @return string
function p.getShortDescription(apiData, args, typeInfo, prefix, resolved)
	local entry = entrySystem(apiData)
	local destination = destinationSystem(apiData)
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
--- @param apiData table
--- @param args table
--- @return table[]
function p.getFooterButtons(apiData, args)
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
--- @param apiData table
--- @param args table
--- @return EntityItemData[]
function p.getMetadataItems(apiData, args)
	local code = starmapCode(apiData, args)
	if not code then
		return {}
	end
	return { { label = 'Starmap code', content = code } }
end

-- Test-only exports. Not part of the public API.
p._internal = {
	systemShortName = systemShortName,
	entrySystem = entrySystem,
	destinationSystem = destinationSystem,
	sizeLabel = sizeLabel,
	distanceDisplay = distanceDisplay,
	starmapCode = starmapCode,
	SIZE_LABELS = SIZE_LABELS,
}

return p
