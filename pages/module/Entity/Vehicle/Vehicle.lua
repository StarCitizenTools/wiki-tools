require('strict')

--- @module Entity/Vehicle
--- Vehicle type module. Exposes the vehicles API endpoint and renders core
--- infobox sections (Overview, Capacity, Speed) from API data.

local base = require('Module:Entity/Base')
local capacity = require('Module:Entity/Vehicle/Capacity')
local cost = require('Module:Entity/Vehicle/Cost')
local development = require('Module:Entity/Vehicle/Development')
local Editorial = require('Module:Entity/Editorial')
local floatingui = require('Module:FloatingUI')
local vehicleDimensions = require('Module:Entity/Vehicle/Dimensions')
local format = require('Module:Entity/Format')
local lore = require('Module:Entity/Vehicle/Lore')
local overview = require('Module:Entity/Vehicle/Overview')
local productionStatus = require('Module:Entity/ProductionStatus')
local stats = require('Module:Entity/Vehicle/Stats')
local vehicleUtil = require('Module:Entity/Vehicle/Util')
local lang = mw.language.getContentLanguage()

local QUANTUM_SPEED_DIVISOR = 1000000
local QUANTUM_RANGE_DIVISOR = 1000000000

local p = {}

--- Normalize a ship-matrix name to a URL slug (lowercase, spaces → hyphens). nil-safe.
--- @return string|nil
local function shipMatrixSlug(name)
	if type(name) ~= 'string' or name == '' then
		return nil
	end
	return (mw.ustring.lower(name):gsub(' ', '-'))
end

--- Canonical kind name; the Data.get() `result.kind` value sibling renderers
--- branch on. Every kind declares one (enforced by the Registry conformance test).
p.name = 'Vehicle'

--- Opt into editorial mode (Module:Entity/Data): a page declared |kind=Vehicle
--- with no genuine API record (a planned / not-yet-in-game vehicle) renders from
--- editorial args alone. The family subtype then comes from |family=. Harmless on
--- a page that later gets a uuid — the genuine record takes over. See README.
p.editorialMode = true

--- @type string
p.parent = 'Entity/Base'

--- The vehicles endpoint includes uex_prices and msrp by default, so
--- no `include` param is required for Availability to render.
---
--- @return EntityApiConfig[]
function p.getApiConfigs()
	return {
		{
			name = 'StarCitizenWikiAPI',
			endpoint = 'vehicles/%s',
			params = { locale = 'en_EN' },
			responseDataPath = 'data',
		},
	}
end

--- Positive identification: vehicles always carry the `is_vehicle`
--- key at the top level alongside `is_spaceship` and `is_gravlev`.
--- The value is the family flag (`is_vehicle=true` for ground vehicles,
--- `is_spaceship=true` for spaceships, `is_gravlev=true` for hover
--- bikes — a Cutlass Black has `is_vehicle=false, is_spaceship=true`),
--- so we check **presence** rather than value. Items don't have any
--- of these keys.
--- Safe on nil / empty / malformed apiData (returns false, never throws).
---
--- @param apiData table|nil
--- @return boolean
function p.matches(apiData)
	return apiData ~= nil and apiData.is_vehicle ~= nil
end

--- Refine a vehicle to its family subtype leaf. A genuine record carries all
--- three family flags (exactly one truthy), so order is defensive
--- most-specific-first. In editorial mode (apiData = {}, no flags) the curated
--- `|family=` arg selects the leaf instead. Returns nil when neither resolves
--- (the Vehicle kind itself stays the leaf).
--- @param apiData table|nil
--- @param args table|nil
--- @return table|nil
function p.resolveSubtype(apiData, args)
	if type(apiData) == 'table' then
		if apiData.is_gravlev then
			return require('Module:Entity/Vehicle/Gravlev')
		end
		if apiData.is_spaceship then
			return require('Module:Entity/Vehicle/Ship')
		end
		if apiData.is_vehicle then
			return require('Module:Entity/Vehicle/GroundVehicle')
		end
	end
	local family = type(args) == 'table' and args.family or nil
	if family == 'gravlev' then
		return require('Module:Entity/Vehicle/Gravlev')
	end
	if family == 'ship' then
		return require('Module:Entity/Vehicle/Ship')
	end
	if family == 'ground' then
		return require('Module:Entity/Vehicle/GroundVehicle')
	end
	return nil
end

local ROLE_SUFFIXES = {
	bomber = true,
	carrier = true,
	corvette = true,
	fighter = true,
	frigate = true,
	gunship = true,
	interceptor = true,
	ship = true,
}

--- The role phrase (lowercased): "multi-role <primary>" for a Multi-role career,
--- else the full role. nil when no role resolves.
--- @param apiData table
--- @param args table
--- @return string|nil
local function rolePhrase(apiData, args)
	local role = args.role or apiData.role
	if type(role) == 'table' then
		role = table.concat(role, ' / ')
	end
	if type(role) ~= 'string' or role == '' then
		return nil
	end
	local career = vehicleUtil.resolveCareer(apiData, args)
	if career ~= nil and mw.ustring.lower(career) == 'multi-role' then
		local primary = mw.text.trim(mw.ustring.match(role, '^[^/]+') or role)
		return 'multi-role ' .. mw.ustring.lower(primary)
	end
	return mw.ustring.lower(role)
end

--- True when the phrase's last alphabetic word is a ship-type role suffix.
--- @param phrase string|nil
--- @return boolean
local function endsWithRoleSuffix(phrase)
	if not phrase then
		return false
	end
	local last = mw.ustring.match(phrase, '(%a+)%s*$')
	return last ~= nil and ROLE_SUFFIXES[mw.ustring.lower(last)] == true
end

--- Compose a manufacturer-led vehicle short description:
--- "<mfr-short> <size|single-seat> <role-phrase> <type-noun>". Editorial-first.
--- @param apiData table
--- @param args table
--- @param resolved table|nil
--- @param typeNoun string  'ship' | 'ground vehicle' | 'gravlev vehicle'
--- @param omitSize boolean  true for ground/gravlev (no meaningful matrix size)
--- @return string
function p.formatShortDescription(apiData, args, resolved, typeNoun, omitSize)
	local ed = Editorial.view(resolved)
	local parts = {}
	local mfr = base.resolveManufacturer(apiData, args)
	if mfr and mfr.short then
		parts[#parts + 1] = mfr.short
	end
	local crewMax = tonumber(ed:value('crew_max', apiData.crew and apiData.crew.max))
	if crewMax == 1 then
		parts[#parts + 1] = 'single-seat'
	elseif not omitSize then
		local size = vehicleUtil.matrixSize(apiData, args)
		if size and size ~= '' then
			parts[#parts + 1] = mw.ustring.lower(size)
		end
	end
	local role = rolePhrase(apiData, args)
	if role then
		parts[#parts + 1] = role
	end
	if not endsWithRoleSuffix(role) then
		parts[#parts + 1] = typeNoun
	end
	return lang:ucfirst(mw.text.trim(table.concat(parts, ' ')))
end

--- Manufacturer as a wikilink ([[Page]] or [[Page|Name]]), or nil when none
--- resolves. Shared by the header subtitle.
--- @param apiData table
--- @param args table
--- @return string|nil
local function manufacturerLink(apiData, args)
	local mfr = base.resolveManufacturer(apiData, args)
	if not mfr or not mfr.page then
		return nil
	end
	if mfr.name and mfr.name ~= mfr.page then
		return '[[' .. mfr.page .. '|' .. mfr.name .. ']]'
	end
	return '[[' .. mfr.page .. ']]'
end

--- @param apiData table
--- @param args table
--- @param resolved table|nil
--- @return table[]
function p.getSections(apiData, args, resolved)
	local ed = Editorial.view(resolved)
	local subtype = p.resolveSubtype(apiData, args)
	local typeName = nil
	if subtype and subtype.getTypeInfo then
		local typeInfo = subtype.getTypeInfo(apiData, args)
		typeName = typeInfo and typeInfo.name
	end
	local sections = {}
	local function add(section)
		if section ~= nil then
			sections[#sections + 1] = section
		end
	end
	add(overview.build(apiData, args, ed, typeName))
	add(capacity.build(apiData, args, ed))
	add(cost.build(apiData, args, ed))
	add(stats.build(apiData, args, ed))
	add(vehicleDimensions.build(apiData, args, ed))
	add(lore.build(apiData, args, ed))
	add(development.build(apiData, args, ed))
	return sections
end

--- Vehicle header subtitle: the manufacturer (linked), shown in place of the
--- default type subtitle so vehicles are identified by maker (as the legacy
--- infobox did). nil when no manufacturer resolves → the infobox falls back to
--- the display type.
--- @param apiData table
--- @param args table
--- @return string|nil
function p.getSubtitle(apiData, args)
	return manufacturerLink(apiData, args)
end

--- Build the FloatingUI tooltip content for a production state badge.
--- Returns a section string (via FloatingUI.renderSection) for the state
--- description, plus an additional section for the per-ship note when it is
--- present and differs from the description. Returns nil when both are absent.
--- @param desc string|nil  State description from ProductionStatus.tooltip()
--- @param note string|nil  Per-ship production note from apiData.production_note
--- @return string|nil
local function buildProductionTooltip(desc, note)
	local hasDesc = type(desc) == 'string' and desc ~= ''
	-- The API returns the literal string "None" for ships with no note.
	local hasNote = type(note) == 'string' and note ~= '' and note:lower() ~= 'none' and note ~= desc
	if not hasDesc and not hasNote then
		return nil
	end
	local content = ''
	if hasDesc then
		content = content .. floatingui.renderSection({ desc = desc })
	end
	if hasNote then
		content = content .. floatingui.renderSection({ label = 'Note', desc = note })
	end
	return content ~= '' and content or nil
end

--- Vehicle production-state badge for the infobox header overlay. Uses the
--- editorial-resolved production_state (API production_status, override-able).
--- The badge is wrapped in a FloatingUI tooltip showing the state description
--- and any per-ship production note. The FloatingUI JS/CSS loader is prepended
--- so the tooltip can open on the live page.
--- Vehicle-only: other entities are in-game by definition, so a status badge
--- would be noise.
--- @param apiData table
--- @param args table
--- @param resolved table|nil
--- @return string|nil
function p.getHeaderBadge(apiData, args, resolved)
	local ed = Editorial.view(resolved)
	local state = ed:value('production_state', apiData.production_status)
	local badge = productionStatus.badge(state)
	if not badge then
		return nil
	end
	-- Per-ship note: the editorial `productionstatedesc` (wiki-curated) wins, with the
	-- API production_note as fallback (usually "None", dropped by buildProductionTooltip).
	local note = ed:value('production_state_desc') or apiData.production_note
	local content = buildProductionTooltip(productionStatus.tooltip(state), note)
	if not content then
		return badge
	end
	-- floatingui.load() emits <templatestyles> + #floatingui parser function —
	-- prepend it so the tooltip JS/CSS is guaranteed loaded on the page.
	return floatingui.load(mw.getCurrentFrame()) .. floatingui.render(badge, content, true)
end

--- Return the Vehicle editorial manifest. Used by Module:Entity/Editorial to
--- resolve hybrid API/wikitext fields (crew, cargo, speed, mass, pledge price)
--- and to drive SMW storage for those fields.
--- @return table
function p.getEditorialManifest()
	return mw.loadJsonData('Module:Entity/Vehicle/editorial.json')
end

--- Return structured data for the pure-API vehicle fields not covered by the
--- editorial manifest (Career, Role, Size class, agility rates). Fields owned
--- by the editorial layer (crew/cargo/speed/mass/pledge) are intentionally
--- absent here — the editorial resolver handles their SMW storage.
--- @param apiData table
--- @param args table
--- @param resolved table|nil
--- @return table
function p.getStructuredData(apiData, args, resolved)
	local agility = type(apiData.agility) == 'table' and apiData.agility or {}
	local armor = type(apiData.armor) == 'table' and apiData.armor or {}
	local fuel = type(apiData.fuel) == 'table' and apiData.fuel or {}
	local quantum = type(apiData.quantum) == 'table' and apiData.quantum or {}
	local data = {
		['Career'] = vehicleUtil.resolveCareer(apiData, args), -- wiki param wins (curated taxonomy)
		['Role'] = apiData.role,
		['Size class'] = tonumber(apiData.size_class),
		['Roll rate'] = tonumber(agility.roll),
		['Pitch rate'] = tonumber(agility.pitch),
		['Yaw rate'] = tonumber(agility.yaw),
		['Insurance claim time'] = apiData.insurance and tonumber(apiData.insurance.claim_time) or nil,
		['Insurance expedite time'] = apiData.insurance and tonumber(apiData.insurance.expedite_time) or nil,
		['Insurance expedite cost'] = apiData.insurance and tonumber(apiData.insurance.expedite_cost) or nil,
		['Health point'] = tonumber(apiData.health),
		['Cross section signature modifier'] = armor.signal_cross_section and tonumber(armor.signal_cross_section)
			or nil,
		['Electromagnetic signature modifier'] = armor.signal_electromagnetic and tonumber(
			armor.signal_electromagnetic
		) or nil,
		['Infrared signature modifier'] = armor.signal_infrared and tonumber(armor.signal_infrared) or nil,
		['Hydrogen fuel capacity'] = tonumber(fuel.capacity),
		['Hydrogen fuel intake rate'] = tonumber(fuel.intake_rate),
		['Quantum fuel capacity'] = tonumber(quantum.quantum_fuel_capacity),
		['Quantum speed'] = (function()
			local qsRaw = tonumber(quantum.quantum_speed)
			return qsRaw and (qsRaw / QUANTUM_SPEED_DIVISOR) or nil -- Mm/s, matches QuantumDrive
		end)(),
		['Quantum range'] = (function()
			local qrRaw = tonumber(quantum.quantum_range)
			return qrRaw and (qrRaw / QUANTUM_RANGE_DIVISOR) or nil -- Gm
		end)(),
		['Quantum spool time'] = tonumber(quantum.quantum_spool_time),
	}
	for _, dt in ipairs(vehicleUtil.DAMAGE_TYPES) do
		data[dt.label .. ' damage modifier'] = tonumber(armor[dt.key])
	end
	return data
end

--- External-site links: Official (pledgeurl from API + editorial galactapediaurl /
--- brochureurl / trailerurl / presentationurl / qaurl) and Community (ship tools from
--- API identifiers). The brochure/trailer/presentation/Q&A args each accept a
--- semicolon-separated list for multiple URLs (e.g. presentationurl = url1; url2 — the
--- wiki multi-value convention). The footer merges the "Official sites" row with Base's
--- same-label row.
--- @param apiData table
--- @param args table
--- @return table[]
function p.getExternalSiteItems(apiData, args)
	local items = {}
	local official = format.buildSiteLinks(mw.loadJsonData('Module:Entity/Vehicle/officialSites.json'), {
		pledge_url = args.pledgeurl or apiData.pledge_url,
		galactapedia = args.galactapediaurl,
		brochure = format.splitSemi(args.brochureurl),
		trailer = format.splitSemi(args.trailerurl),
		presentation = format.splitSemi(args.presentationurl),
		qa = format.splitSemi(args.qaurl),
	})
	if official then
		items[#items + 1] = { label = 'Official sites', content = official }
	end
	local className = type(apiData.class_name) == 'string' and mw.ustring.lower(apiData.class_name) or nil
	local uuid = args.uuid or apiData.uuid
	local community = format.buildSiteLinks(mw.loadJsonData('Module:Entity/Vehicle/communitySites.json'), {
		uuid = type(uuid) == 'string' and mw.ustring.lower(uuid) or nil,
		class_name = className,
		ship_matrix = shipMatrixSlug(apiData.shipmatrix_name),
	})
	if community then
		items[#items + 1] = { label = 'Community sites', content = community }
	end
	return items
end

--- Legacy {{Vehicle}}-parity browse categories beyond the structural bucket
--- (Ships / Ground vehicles) and the manufacturer category. Size/career/etc. are
--- ALSO SMW facets; these categories are additive for navigation. Pure.
--- @param apiData table
--- @param args table
--- @param resolved table
--- @return string[]
function p.getCategories(apiData, args, resolved)
	local ed = Editorial.view(resolved)
	local cats = {}
	-- Derive the family from the resolved subtype so editorial-mode pages
	-- (apiData = {}, no is_spaceship flag) still classify as ships via |family=.
	local isShip = p.resolveSubtype(apiData, args) == require('Module:Entity/Vehicle/Ship')
	-- Size (ships only): "Large ships" — the curated |size= wins (API may disagree)
	local size = vehicleUtil.matrixSize(apiData, args)
	if isShip and size then
		cats[#cats + 1] = lang:ucfirst(size) .. ' ships'
	end
	-- Pledge: ship -> "Pledge ships"; ground/gravlev -> "Pledge vehicles" (when a pledge price exists)
	local pledge = tonumber(ed:value('pledge_price', apiData.msrp))
	if pledge and pledge > 0 then
		cats[#cats + 1] = isShip and 'Pledge ships' or 'Pledge vehicles'
	end
	-- Production state label: "Flight ready"
	local state = ed:value('production_state', apiData.production_status)
	local stateLabel = productionStatus.label(state)
	if stateLabel then
		cats[#cats + 1] = stateLabel
	end
	-- Series grouping "<mfr name> <series>" (e.g. "Gatac Manufacture Railen"), and
	-- generation grouping "<series> <generation>" (e.g. "Constellation Mk4").
	local series = ed:value('series')
	if series ~= nil and series ~= '' then
		local mfr = base.resolveManufacturer(apiData, args)
		if mfr and mfr.name then
			cats[#cats + 1] = mfr.name .. ' ' .. series
		end
		local generation = ed:value('generation')
		if generation ~= nil and generation ~= '' then
			cats[#cats + 1] = series .. ' ' .. generation
		end
	end
	-- Career: "Transport career"
	local career = vehicleUtil.resolveCareer(apiData, args)
	if career ~= nil then
		cats[#cats + 1] = lang:ucfirst(career) .. ' career'
	end
	return cats
end

return p
