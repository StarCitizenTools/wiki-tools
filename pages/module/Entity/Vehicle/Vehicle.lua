require('strict')

--- @module Entity/Vehicle
--- Vehicle type module. Exposes the vehicles API endpoint and renders core
--- infobox sections (Overview, Capacity, Speed) from API data.

local base = require('Module:Entity/Base')
local dimensions = require('Module:Dimensions')
local dimensionsPresets = require('Module:Dimensions/presets')
local format = require('Module:Entity/Format')
local productionStatus = require('Module:Entity/ProductionStatus')
local sectionBuilder = require('Module:Entity/SectionBuilder')
local lang = mw.language.getContentLanguage()

local p = {}

--- Render-time unit attach: nil for non-numeric so SectionBuilder drops the row.
--- @return string|nil
local function withUnit(value, unit)
	local n = tonumber(value)
	if n == nil then
		return nil
	end
	return format.formatNum(n) .. unit
end

--- Round a possibly-fractional number to the nearest integer (drive speeds are
--- derived floats, e.g. 13.5584... reverse). nil-safe.
--- @return number|nil
local function roundInt(value)
	local n = tonumber(value)
	if n == nil then
		return nil
	end
	return math.floor(n + 0.5)
end

--- Effective value for an overridable field: the editorial-resolved value when
--- present (encodes override/fill/api), else the API fallback. Forward-compatible
--- with the editorial manifest landing later.
--- @return any
local function effective(resolved, field, apiFallback)
	local entry = resolved and resolved[field]
	if entry ~= nil then
		return entry.value
	end
	return apiFallback
end

--- Min–max of non-zero numeric values at `key` across an array, as "lo – hi aUEC"
--- (single value when lo==hi, en dash between). nil when no non-zero entry.
--- @param rows table|nil
--- @param key string
--- @return string|nil
local function priceRange(rows, key)
	if type(rows) ~= 'table' then
		return nil
	end
	local lo, hi
	for _, row in ipairs(rows) do
		local v = tonumber(row[key])
		if v and v > 0 then
			lo = (lo == nil or v < lo) and v or lo
			hi = (hi == nil or v > hi) and v or hi
		end
	end
	if not lo then
		return nil
	end
	if lo == hi then
		return format.formatNum(lo) .. ' aUEC'
	end
	return format.formatNum(lo) .. ' \226\128\147 ' .. format.formatNum(hi) .. ' aUEC' -- en dash
end

--- A pledge price cell: "$N", with " (was $M)" appended when an original differs. nil when no current.
--- @param current any
--- @param original any
--- @return string|nil
local function pledgeCell(current, original)
	local c = tonumber(current)
	if c == nil then
		return nil
	end
	local s = '$' .. format.formatNum(c)
	local o = tonumber(original)
	if o and o ~= c then
		s = s .. ' (was $' .. format.formatNum(o) .. ')'
	end
	return s
end

--- Editorial-resolved value for a pure-editorial field (no API fallback). nil when absent.
--- @param resolved table|nil
--- @param field string
--- @return any
local function editorialValue(resolved, field)
	local entry = resolved and resolved[field]
	return entry and entry.value or nil
end

--- Crew as "min–max" (en dash) or a single value. nil when neither present.
--- @return string|nil
local function crewRange(minV, maxV)
	minV, maxV = tonumber(minV), tonumber(maxV)
	if minV and maxV and minV ~= maxV then
		return format.formatNum(minV) .. '\226\128\147' .. format.formatNum(maxV)
	end
	if minV or maxV then
		return format.formatNum(minV or maxV)
	end
	return nil
end

--- Canonical kind name; the Data.get() `result.kind` value sibling renderers
--- branch on. Every kind declares one (enforced by the Registry conformance test).
p.name = 'Vehicle'

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

--- Refine a vehicle to its family subtype leaf. Every vehicle record carries all
--- three family flags and exactly one is truthy (a gravlev has is_vehicle=false),
--- so order is just defensive most-specific-first. Returns nil when no family
--- flag is set (the Vehicle kind itself stays the leaf).
--- @param apiData table|nil
--- @return table|nil
function p.resolveSubtype(apiData)
	if type(apiData) ~= 'table' then
		return nil
	end
	if apiData.is_gravlev then
		return require('Module:Entity/Vehicle/Gravlev')
	end
	if apiData.is_spaceship then
		return require('Module:Entity/Vehicle/Ship')
	end
	if apiData.is_vehicle then
		return require('Module:Entity/Vehicle/GroundVehicle')
	end
	return nil
end

--- Compose a vehicle short description: "<role> <familyNoun> by <manufacturer>".
--- role from apiData.role (a multi-role array joins on '/'); manufacturer from
--- the shared resolver (editorial-overridable via args.manufacturer). Pure.
--- @param apiData table
--- @param args table
--- @param familyNoun string  e.g. 'spaceship', 'ground vehicle', 'gravlev'
--- @return string
function p.formatShortDescription(apiData, args, familyNoun)
	local role = apiData.role
	-- The live vehicles API returns role as a plain string; this branch is
	-- defensive for legacy/multi-role vehicles that expose role as an array
	-- (historically '/'-joined).
	if type(role) == 'table' then
		role = table.concat(role, '/')
	end
	local parts = {}
	if role and role ~= '' then
		parts[#parts + 1] = role
	end
	parts[#parts + 1] = familyNoun
	local desc = table.concat(parts, ' ')
	local mfr = base.resolveManufacturer(apiData, args)
	if mfr and mfr.short then
		desc = desc .. ' by ' .. mfr.short
	end
	return mw.text.trim(desc)
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
	local speed = type(apiData.speed) == 'table' and apiData.speed or {}
	local agility = type(apiData.agility) == 'table' and apiData.agility or {}
	local drive = type(apiData.drive) == 'table' and apiData.drive or {}
	local crew = type(apiData.crew) == 'table' and apiData.crew or {}

	-- Overview (labelless top section): type + identity rows under the title.
	-- Type comes from the resolved subtype's getTypeInfo so it stays the single
	-- source of truth (the header subtitle now shows the manufacturer instead).
	local overview = {}
	local subtype = p.resolveSubtype(apiData)
	local typeName = nil
	if subtype and subtype.getTypeInfo then
		local typeInfo = subtype.getTypeInfo(apiData, args)
		typeName = typeInfo and typeInfo.name
	end
	sectionBuilder.push(overview, 'Type', typeName)
	sectionBuilder.push(overview, 'Career', apiData.career)
	sectionBuilder.push(overview, 'Role', apiData.role)
	sectionBuilder.push(overview, 'Size', apiData.size and lang:ucfirst(tostring(apiData.size)) or nil)

	-- Capacity
	local capacity = {}
	sectionBuilder.push(
		capacity,
		'Crew',
		crewRange(effective(resolved, 'crew_min', crew.min), effective(resolved, 'crew_max', crew.max))
	)
	sectionBuilder.push(
		capacity,
		'Cargo',
		withUnit(effective(resolved, 'cargo_capacity', apiData.cargo_capacity), ' SCU')
	)

	-- Speed: ships/gravlevs use speed.*; ground vehicles use drive.* (speed.* is null).
	local speedItems = {}
	sectionBuilder.push(speedItems, 'SCM speed', withUnit(effective(resolved, 'scm_speed', speed.scm), ' m/s'))
	local maxSpeed = effective(resolved, 'max_speed', speed.max)
	if maxSpeed == nil then
		maxSpeed = roundInt(drive.max_speed_ms)
	end
	sectionBuilder.push(speedItems, 'Max speed', withUnit(maxSpeed, ' m/s'))
	sectionBuilder.push(speedItems, 'Reverse speed', withUnit(roundInt(drive.reverse_speed_ms), ' m/s'))
	sectionBuilder.push(speedItems, 'Roll rate', withUnit(agility.roll, ' \194\176/s'))
	sectionBuilder.push(speedItems, 'Pitch rate', withUnit(agility.pitch, ' \194\176/s'))
	sectionBuilder.push(speedItems, 'Yaw rate', withUnit(agility.yaw, ' \194\176/s'))

	-- Cost: three subsection-tabs. aUEC summary links out to {{Entity/Availability}}.
	local uex = type(apiData.uex_prices) == 'table' and apiData.uex_prices or {}
	local insurance = type(apiData.insurance) == 'table' and apiData.insurance or {}

	local universe = {}
	sectionBuilder.push(universe, 'Purchase', priceRange(uex.purchase, 'price_buy'))
	sectionBuilder.push(universe, 'Rental', priceRange(uex.rental, 'price_rent'))
	sectionBuilder.push(
		universe,
		'Shops',
		(uex.purchase or uex.rental) and '[[#Acquisition|View all locations]]' or nil
	)

	local pledge = {}
	sectionBuilder.push(
		pledge,
		'Standalone',
		pledgeCell(effective(resolved, 'pledge_price', apiData.msrp), editorialValue(resolved, 'original_pledge_price'))
	)
	sectionBuilder.push(
		pledge,
		'Warbond',
		pledgeCell(editorialValue(resolved, 'warbond_price'), editorialValue(resolved, 'original_warbond_price'))
	)
	sectionBuilder.push(pledge, 'Availability', editorialValue(resolved, 'pledge_availability'))

	local insuranceItems = {}
	sectionBuilder.push(insuranceItems, 'Claim time', withUnit(insurance.claim_time, ' min'))
	sectionBuilder.push(insuranceItems, 'Expedite time', withUnit(insurance.expedite_time, ' min'))
	sectionBuilder.push(insuranceItems, 'Expedite fee', withUnit(insurance.expedite_cost, ' aUEC'))

	-- Subsection tabs are raw InfoboxLua section data ({ label, items }) with NO
	-- `key`: mergeSections strips the Entity-internal `key` only at the top level,
	-- so a keyed subsection fails InfoboxLua's schema validation. Matches the
	-- Dimensions facet's subsection shape.
	local costTabs = {}
	if universe[1] ~= nil then
		costTabs[#costTabs + 1] = { label = 'Universe', items = universe }
	end
	if pledge[1] ~= nil then
		costTabs[#costTabs + 1] = { label = 'Pledge', items = pledge }
	end
	if insuranceItems[1] ~= nil then
		costTabs[#costTabs + 1] = { label = 'Insurance', items = insuranceItems }
	end
	local cost = costTabs[1] and sectionBuilder.section({ key = 'cost', label = 'Cost', sections = costTabs }) or nil

	-- Dimensions: thin adapter over Module:Dimensions. Vehicles carry flat
	-- dimension.{length,width,height} (the item Dimensions facet reads a nested
	-- .dimensions and so does not match vehicles).
	local dimensionsSection = nil
	local dim = type(apiData.dimension) == 'table' and apiData.dimension or nil
	if dim and tonumber(dim.length) and tonumber(dim.width) and tonumber(dim.height) then
		local metrics = {}
		if tonumber(apiData.mass) then
			metrics[#metrics + 1] = { label = 'Mass', value = format.formatNum(apiData.mass) .. ' kg' }
		end
		local boxHtml = dimensions._main({
			length = tonumber(dim.length),
			width = tonumber(dim.width),
			height = tonumber(dim.height),
			lengthAlt = tonumber(effective(resolved, 'retracted_length', nil)),
			widthAlt = tonumber(effective(resolved, 'retracted_width', nil)),
			heightAlt = tonumber(effective(resolved, 'retracted_height', nil)),
			reference = dimensionsPresets.human,
			metrics = metrics,
		})
		if boxHtml then
			dimensionsSection =
				sectionBuilder.section({ key = 'dimensions', label = 'Dimensions', content = tostring(boxHtml) })
		end
	end

	return sectionBuilder.build(
		-- Labelless top section: identity rows show plainly under the title (always
		-- visible, not collapsible) — InfoboxLua renders a section with no label as
		-- the general top group.
		sectionBuilder.section({ key = 'overview', items = overview }),
		sectionBuilder.section({ key = 'capacity', label = 'Capacity', items = capacity }),
		sectionBuilder.section({ key = 'speed', label = 'Speed', items = speedItems }),
		dimensionsSection,
		cost
	)
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

--- Vehicle production-state badge for the infobox header overlay. Uses the
--- editorial-resolved production_state (API production_status, override-able).
--- Vehicle-only: other entities are in-game by definition, so a status badge
--- would be noise.
--- @param apiData table
--- @param args table
--- @param resolved table|nil
--- @return string|nil
function p.getHeaderBadge(apiData, args, resolved)
	local state = resolved and resolved.production_state and resolved.production_state.value
		or apiData.production_status
	return productionStatus.badge(state)
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
	return {
		['Career'] = apiData.career,
		['Role'] = apiData.role,
		['Size class'] = tonumber(apiData.size_class),
		['Roll rate'] = tonumber(agility.roll),
		['Pitch rate'] = tonumber(agility.pitch),
		['Yaw rate'] = tonumber(agility.yaw),
		['Insurance claim time'] = apiData.insurance and tonumber(apiData.insurance.claim_time) or nil,
		['Insurance expedite time'] = apiData.insurance and tonumber(apiData.insurance.expedite_time) or nil,
		['Insurance expedite cost'] = apiData.insurance and tonumber(apiData.insurance.expedite_cost) or nil,
	}
end

return p
