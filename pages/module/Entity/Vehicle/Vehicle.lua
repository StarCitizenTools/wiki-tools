require('strict')

--- @module Entity/Vehicle
--- Vehicle type module. Exposes the vehicles API endpoint and renders core
--- infobox sections (Overview, Capacity, Speed) from API data.

local base = require('Module:Entity/Base')
local dimensions = require('Module:Dimensions')
local dimensionsPresets = require('Module:Dimensions/presets')
local floatingui = require('Module:FloatingUI')
local format = require('Module:Entity/Format')
local productionStatus = require('Module:Entity/ProductionStatus')
local progressTiles = require('Module:ProgressTiles')
local sectionBuilder = require('Module:Entity/SectionBuilder')
local statFormat = require('Module:Entity/StatFormat')
local uec = require('Module:UEC')
local yesno = require('Module:Yesno')
local lang = mw.language.getContentLanguage()

local QUANTUM_SPEED_DIVISOR = 1000000
local QUANTUM_RANGE_DIVISOR = 1000000000

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

--- A scaled numeric value with a unit: `format.formatNum(value / divisor)` rounded
--- to `decimals`, plus the unit. nil when non-numeric. divisor defaults to 1.
--- @return string|nil
local function scaledUnit(value, divisor, unit, decimals)
	local n = tonumber(value)
	if n == nil then
		return nil
	end
	local scaled = n / (divisor or 1)
	if decimals and decimals > 0 then
		local mult = 10 ^ decimals
		scaled = math.floor(scaled * mult + 0.5) / mult
	else
		scaled = math.floor(scaled + 0.5)
	end
	return format.formatNum(scaled) .. unit
end

--- A positive-only numeric value with a unit: like withUnit but drops when nil or <= 0.
--- @return string|nil
local function positiveUnit(value, unit)
	local n = tonumber(value)
	if n == nil or n <= 0 then
		return nil
	end
	return format.formatNum(n) .. unit
end

--- A UEC amount rendered via Module:UEC (currency glyph + grouped number), nil
--- when the value isn't numeric.
--- @param value any
--- @return string|nil
local function uecAmount(value)
	local n = tonumber(value)
	return n and uec._main(n) or nil
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

--- Whether the vehicle can be acquired (bought/rented) per UEX data: true when a
--- real price exists, false when there are entries but no price for this side,
--- nil (Unknown) when there's no price array to judge from.
--- @param prices table[]|nil
--- @param key string
--- @return boolean|nil
local function inferCanAcquire(prices, key)
	if type(prices) ~= 'table' or prices[1] == nil then
		return nil
	end
	return priceRange(prices, key) ~= nil
end

--- A Universe acquisition row value: an editorial `canX` override (yes/no) wins,
--- else inferred from UEX prices. "Yes" links to the page's Acquisition section
--- (where the full per-shop price table lives); "No" is plain.
--- A flight-ready ship is in-game, so the absence of a price is a definitive "No"
--- (not sold in-game) and the row stays; an unreleased ship with no data stays
--- Unknown and the row drops. "Yes" always requires real data or an override.
--- @param override any  args.canbuy / args.canrent
--- @param prices table[]|nil
--- @param key string
--- @param flightReady boolean
--- @return string|nil
local function acquireRow(override, prices, key, flightReady)
	local flag = nil
	if override ~= nil and override ~= '' then
		flag = yesno(override)
	end
	if flag == nil then
		flag = inferCanAcquire(prices, key)
	end
	if flag == nil and flightReady then
		flag = false
	end
	if flag == true then
		return '[[#Acquisition|Yes]]'
	elseif flag == false then
		return 'No'
	end
	return nil
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

--- Career value: the wiki `career` arg wins over the API (curated taxonomy).
--- @param apiData table
--- @param args table
--- @return string|nil
local function resolveCareer(apiData, args)
	local c = args.career or apiData.career
	return type(c) == 'string' and c ~= '' and c or nil
end

--- Ship-matrix size string: the curated `|size=` arg wins over `apiData.size`.
--- The wiki overrides the API here (e.g. the Railen is editorially Large but the
--- API reports medium), matching the legacy infobox. nil when neither is set.
--- @param apiData table
--- @param args table
--- @return string|nil
local function matrixSize(apiData, args)
	if type(args.size) == 'string' and args.size ~= '' then
		return args.size
	end
	return type(apiData.size) == 'string' and apiData.size ~= '' and apiData.size or nil
end

--- Size as "<matrix> (S<class>)" — ship-matrix size + the in-game size class.
--- Either part alone when the other is absent; nil when neither.
--- @param apiData table
--- @param args table
--- @return string|nil
local function sizeDisplay(apiData, args)
	local size = matrixSize(apiData, args)
	local matrix = size and lang:ucfirst(size) or nil
	local cls = tonumber(apiData.size_class)
	local game = cls and ('S' .. math.floor(cls + 0.5)) or nil
	if matrix and game then
		return matrix .. ' (' .. game .. ')'
	end
	return matrix or game
end

--- Loaner ships as a comma-joined wikilink list, or nil. Suppressed for
--- flight-ready ships: the vehicle is implemented, so no loaner is granted even
--- when the API still returns stale loaner data.
--- @param apiData table
--- @param state any  effective production state
--- @return string|nil
local function loanerList(apiData, state)
	if productionStatus.key(state) == 'flightready' then
		return nil
	end
	local loaner = apiData.loaner
	if type(loaner) ~= 'table' or loaner[1] == nil then
		return nil
	end
	local links = {}
	for _, entry in ipairs(loaner) do
		if type(entry) == 'table' and type(entry.name) == 'string' and entry.name ~= '' then
			links[#links + 1] = '[[' .. entry.name .. ']]'
		end
	end
	return links[1] and table.concat(links, ', ') or nil
end

--- Normalize a ship-matrix name to a URL slug (lowercase, spaces → hyphens). nil-safe.
--- @return string|nil
local function shipMatrixSlug(name)
	if type(name) ~= 'string' or name == '' then
		return nil
	end
	return (mw.ustring.lower(name):gsub(' ', '-'))
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

--- Armor damage types for the resistance tiles (abbr under tile, full name on hover).
local DAMAGE_TYPES = {
	{ key = 'damage_physical', abbr = 'PHY', label = 'Physical' },
	{ key = 'damage_energy', abbr = 'ENG', label = 'Energy' },
	{ key = 'damage_distortion', abbr = 'DST', label = 'Distortion' },
	{ key = 'damage_thermal', abbr = 'THM', label = 'Thermal' },
	{ key = 'damage_biochemical', abbr = 'BIO', label = 'Biochemical' },
	{ key = 'damage_stun', abbr = 'STN', label = 'Stun' },
}

--- Signed-% signature label from a multiplier (1.13 -> "+13%"), colored by sign
--- (higher signature = worse: + uses the destructive color, - the success color).
--- nil when absent or exactly 1.0 (no effect -> row omitted).
--- @return string|nil
local function signatureLabel(mult)
	local m = tonumber(mult)
	if m == nil then
		return nil
	end
	local pct = math.floor((m - 1) * 100 + 0.5)
	if pct == 0 then
		return nil
	end
	local sign = pct > 0 and '+' or '\226\136\146' -- U+2212 minus
	local color = pct > 0 and 'var(--color-destructive)' or 'var(--color-success)'
	return tostring(mw.html.create('span'):css('color', color):wikitext(sign .. math.abs(pct) .. '%'))
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
	local career = resolveCareer(apiData, args)
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
	local parts = {}
	local mfr = base.resolveManufacturer(apiData, args)
	if mfr and mfr.short then
		parts[#parts + 1] = mfr.short
	end
	local crewMax = tonumber(effective(resolved, 'crew_max', apiData.crew and apiData.crew.max))
	if crewMax == 1 then
		parts[#parts + 1] = 'single-seat'
	elseif not omitSize then
		local size = matrixSize(apiData, args)
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

--- Career as a link to its browse category ("[[:Category:Combat career|Combat]]").
--- Capitalizes the first letter; "Multi" → "Multi-role" (matches the legacy module).
--- nil when no career.
--- @param career any
--- @return string|nil
local function careerLink(career)
	if type(career) ~= 'string' or career == '' then
		return nil
	end
	local c = lang:ucfirst(career)
	if c == 'Multi' then
		c = 'Multi-role'
	end
	return '[[:Category:' .. c .. ' career|' .. c .. ']]'
end

--- "Model" row (legacy label for the series): the editorial series as
--- "<mfr code> <series>" linked to the manufacturer's series browse category,
--- or the plain series when no manufacturer resolves. Appends a generation
--- link when a `generation` editorial field resolves and series is present.
--- nil when no series.
--- @param apiData table
--- @param args table
--- @param resolved table|nil
--- @return string|nil
local function modelLink(apiData, args, resolved)
	local series = editorialValue(resolved, 'series')
	if series == nil or series == '' then
		return nil
	end
	local mfr = base.resolveManufacturer(apiData, args)
	local out
	if mfr and mfr.code and mfr.name then
		out = '[[:Category:' .. mfr.name .. ' ' .. series .. '|' .. mfr.code .. ' ' .. series .. ']]'
	else
		out = tostring(series)
	end
	local generation = editorialValue(resolved, 'generation')
	if generation ~= nil and generation ~= '' then
		-- Generation browse category is "<series> <generation>" (legacy
		-- category_generation = "%s %s"), e.g. "Constellation Mk4" — no suffix.
		out = out .. ' [[:Category:' .. series .. ' ' .. generation .. '|' .. generation .. ']]'
	end
	return out
end

--- Overview section (labelless top section): type + identity rows under the title.
--- Type comes from the resolved subtype's getTypeInfo so it stays the single
--- source of truth (the header subtitle now shows the manufacturer instead).
--- @param apiData table
--- @param args table
--- @param resolved table|nil
--- @return table
local function buildOverview(apiData, args, resolved)
	local overview = {}
	local subtype = p.resolveSubtype(apiData, args)
	local typeName = nil
	if subtype and subtype.getTypeInfo then
		local typeInfo = subtype.getTypeInfo(apiData, args)
		typeName = typeInfo and typeInfo.name
	end
	sectionBuilder.push(overview, 'Type', typeName)
	-- Career: the wiki `career` param wins over the API value (the wiki curates the
	-- career taxonomy, e.g. "Transport" vs the API's "Transporter"). Direct arg read
	-- (not an editorial overlap field) — the difference is systematic, so it should
	-- not flag every vehicle into the manual-API-data maintenance category.
	sectionBuilder.push(overview, 'Career', careerLink(resolveCareer(apiData, args)))
	sectionBuilder.push(overview, 'Role', apiData.role)
	sectionBuilder.push(overview, 'Size', sizeDisplay(apiData, args))
	sectionBuilder.push(overview, 'Model', modelLink(apiData, args, resolved))
	-- Labelless top section: identity rows show plainly under the title (always
	-- visible, not collapsible) — InfoboxLua renders a section with no label as
	-- the general top group.
	return sectionBuilder.section({ key = 'overview', items = overview })
end

--- Capacity section: crew range, cargo, and personal inventory.
--- @param apiData table
--- @param args table
--- @param resolved table|nil
--- @return table
local function buildCapacity(apiData, args, resolved)
	local crew = type(apiData.crew) == 'table' and apiData.crew or {}
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
	-- Personal stowage (the API's `vehicle_inventory`, in µSCU — same unit as the
	-- item Inventory facet's scu_converted); labelled "Inventory" in the infobox.
	sectionBuilder.push(capacity, 'Inventory', withUnit(apiData.vehicle_inventory, ' µSCU'))
	return sectionBuilder.section({ key = 'capacity', label = 'Capacity', items = capacity })
end

--- Cost section: three subsection-tabs (Universe / Pledge / Insurance).
--- aUEC summary links out to {{Entity/Availability}}.
--- @param apiData table
--- @param args table
--- @param resolved table|nil
--- @return table|nil
local function buildCost(apiData, args, resolved)
	local uex = type(apiData.uex_prices) == 'table' and apiData.uex_prices or {}
	local insurance = type(apiData.insurance) == 'table' and apiData.insurance or {}

	-- Universe: whether the ship is buyable/rentable in-game (the legacy at-a-glance),
	-- "Yes" linking to the Acquisition section for the full per-shop price table. A
	-- flight-ready ship always shows the rows (no price = a definitive "No"); an
	-- unreleased ship with no data drops them (Unknown).
	local effectiveState = effective(resolved, 'production_state', apiData.production_status)
	local flightReady = productionStatus.key(effectiveState) == 'flightready'
	local universe = {}
	sectionBuilder.push(universe, 'Buyable', acquireRow(args.canbuy, uex.purchase, 'price_buy', flightReady))
	sectionBuilder.push(universe, 'Rentable', acquireRow(args.canrent, uex.rental, 'price_rent', flightReady))

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
	sectionBuilder.push(pledge, 'Loaner', loanerList(apiData, effectiveState))

	local insuranceItems = {}
	sectionBuilder.push(insuranceItems, 'Claim time', withUnit(insurance.claim_time, ' min'))
	sectionBuilder.push(insuranceItems, 'Expedite time', withUnit(insurance.expedite_time, ' min'))
	sectionBuilder.push(insuranceItems, 'Expedite fee', uecAmount(insurance.expedite_cost))

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
	return costTabs[1] and sectionBuilder.section({ key = 'cost', label = 'Cost', sections = costTabs }) or nil
end

--- Stats section: performance figures across four subsection tabs
--- (Flight | Hull | Hydrogen | Quantum). Speed uses speed.* for ships/gravlevs
--- and drive.* for ground vehicles. Fuel tabs are included here (collapsed into
--- Stats rather than rendered as a separate section).
--- @param apiData table
--- @param args table
--- @param resolved table|nil
--- @return table|nil
local function buildStats(apiData, args, resolved)
	local speed = type(apiData.speed) == 'table' and apiData.speed or {}
	local agility = type(apiData.agility) == 'table' and apiData.agility or {}
	local drive = type(apiData.drive) == 'table' and apiData.drive or {}
	local armor = type(apiData.armor) == 'table' and apiData.armor or {}
	local fuel = type(apiData.fuel) == 'table' and apiData.fuel or {}
	local usage = type(fuel.usage) == 'table' and fuel.usage or {}
	local quantum = type(apiData.quantum) == 'table' and apiData.quantum or {}

	-- Flight tab: speed + agility rows. Ships/gravlevs use speed.*; ground vehicles
	-- use drive.* (speed.* is null).
	local statsItems = {}
	sectionBuilder.push(statsItems, 'SCM speed', withUnit(effective(resolved, 'scm_speed', speed.scm), ' m/s'))
	local maxSpeed = effective(resolved, 'max_speed', speed.max)
	if maxSpeed == nil then
		maxSpeed = roundInt(drive.max_speed_ms)
	end
	sectionBuilder.push(statsItems, 'Max speed', withUnit(maxSpeed, ' m/s'))
	sectionBuilder.push(statsItems, 'Reverse speed', withUnit(roundInt(drive.reverse_speed_ms), ' m/s'))
	sectionBuilder.push(statsItems, 'Roll rate', withUnit(agility.roll, ' \194\176/s'))
	sectionBuilder.push(statsItems, 'Pitch rate', withUnit(agility.pitch, ' \194\176/s'))
	sectionBuilder.push(statsItems, 'Yaw rate', withUnit(agility.yaw, ' \194\176/s'))

	-- Hull tab: HP rows + armor resistance tiles + signature labels.
	local hull = {}
	sectionBuilder.push(hull, 'Hull', withUnit(apiData.health, ' HP'))
	sectionBuilder.push(hull, 'Shield', withUnit(apiData.shield_hp, ' HP'))
	local tiles = {}
	for _, dt in ipairs(DAMAGE_TYPES) do
		local pct = statFormat.resistancePercent(armor[dt.key])
		if pct ~= nil then
			tiles[#tiles + 1] = { value = pct, label = dt.abbr, title = dt.label }
		end
	end
	if tiles[1] ~= nil then
		hull[#hull + 1] = { content = progressTiles.render({ tiles = tiles }), class = 't-infobox-item--block' }
	end
	sectionBuilder.push(hull, 'Infrared', signatureLabel(armor.signal_infrared))
	sectionBuilder.push(hull, 'Electromagnetic', signatureLabel(armor.signal_electromagnetic))
	sectionBuilder.push(hull, 'Cross-section', signatureLabel(armor.signal_cross_section))

	-- Hydrogen tab: fuel capacity, intake, and per-thruster usage.
	local hydrogen = {}
	sectionBuilder.push(hydrogen, 'Capacity', withUnit(fuel.capacity, ''))
	sectionBuilder.push(hydrogen, 'Intake rate', positiveUnit(fuel.intake_rate, ''))
	sectionBuilder.push(hydrogen, 'Main', positiveUnit(usage.main, ''))
	sectionBuilder.push(hydrogen, 'Retro', positiveUnit(usage.retro, ''))
	sectionBuilder.push(hydrogen, 'VTOL', positiveUnit(usage.vtol, ''))
	sectionBuilder.push(hydrogen, 'Maneuvering', positiveUnit(usage.maneuvering, ''))

	-- Quantum tab: QD speed, range, spool, and fuel capacity.
	local qSpeed = tonumber(quantum.quantum_speed)
	local quantumItems = {}
	sectionBuilder.push(
		quantumItems,
		'Quantum speed',
		qSpeed and (format.formatNum(qSpeed / QUANTUM_SPEED_DIVISOR) .. ' Mm/s') or nil
	)
	sectionBuilder.push(
		quantumItems,
		'Quantum range',
		scaledUnit(quantum.quantum_range, QUANTUM_RANGE_DIVISOR, ' Gm', 1)
	)
	sectionBuilder.push(quantumItems, 'Spool time', withUnit(quantum.quantum_spool_time, ' s'))
	sectionBuilder.push(quantumItems, 'Quantum fuel', withUnit(quantum.quantum_fuel_capacity, ''))

	-- Assemble tabs in order: Flight | Hull | Hydrogen | Quantum (subsection tabs are
	-- raw {label, items} with NO key — a keyed subsection fails InfoboxLua's schema).
	local statsTabs = {}
	if statsItems[1] ~= nil then
		statsTabs[#statsTabs + 1] = { label = 'Flight', items = statsItems }
	end
	if hull[1] ~= nil then
		statsTabs[#statsTabs + 1] = { label = 'Hull', items = hull }
	end
	if hydrogen[1] ~= nil then
		statsTabs[#statsTabs + 1] = { label = 'Hydrogen', items = hydrogen }
	end
	if quantumItems[1] ~= nil then
		statsTabs[#statsTabs + 1] = { label = 'Quantum', items = quantumItems }
	end
	return statsTabs[1] and sectionBuilder.section({ key = 'stats', label = 'Stats', sections = statsTabs }) or nil
end

--- Dimensions section: thin adapter over Module:Dimensions. Vehicles carry flat
--- dimension.{length,width,height} (the item Dimensions facet reads a nested
--- .dimensions and so does not match vehicles).
--- @param apiData table
--- @param args table
--- @param resolved table|nil
--- @return table|nil
local function buildDimensions(apiData, args, resolved)
	local dim = type(apiData.dimension) == 'table' and apiData.dimension or nil
	if not (dim and tonumber(dim.length) and tonumber(dim.width) and tonumber(dim.height)) then
		return nil
	end
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
	if not boxHtml then
		return nil
	end
	return sectionBuilder.section({ key = 'dimensions', label = 'Dimensions', content = tostring(boxHtml) })
end

--- Lore section: in-lore dates (release / retirement). Collapsed by default.
--- @param apiData table
--- @param args table
--- @param resolved table|nil
--- @return table|nil
local function buildLore(apiData, args, resolved)
	local lore = {}
	sectionBuilder.push(lore, 'Released', editorialValue(resolved, 'release_date'))
	sectionBuilder.push(lore, 'Retired', editorialValue(resolved, 'retirement_date'))
	return lore[1]
			and sectionBuilder.section({
				key = 'lore',
				label = 'Lore',
				items = lore,
				collapsible = true,
				collapsed = true,
			})
		or nil
end

--- Development section: real-world dates (concept announced / concept sale).
--- Collapsed by default.
--- @param apiData table
--- @param args table
--- @param resolved table|nil
--- @return table|nil
local function buildDevelopment(apiData, args, resolved)
	local development = {}
	sectionBuilder.push(development, 'Announced', editorialValue(resolved, 'concept_announced'))
	sectionBuilder.push(development, 'Concept sale', editorialValue(resolved, 'concept_sale'))
	return development[1]
			and sectionBuilder.section({
				key = 'development',
				label = 'Development',
				items = development,
				collapsible = true,
				collapsed = true,
			})
		or nil
end

--- @param apiData table
--- @param args table
--- @param resolved table|nil
--- @return table[]
function p.getSections(apiData, args, resolved)
	local sections = {}
	local function add(section)
		if section ~= nil then
			sections[#sections + 1] = section
		end
	end
	add(buildOverview(apiData, args, resolved))
	add(buildCapacity(apiData, args, resolved))
	add(buildCost(apiData, args, resolved))
	add(buildStats(apiData, args, resolved))
	add(buildDimensions(apiData, args, resolved))
	add(buildLore(apiData, args, resolved))
	add(buildDevelopment(apiData, args, resolved))
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
	local state = resolved and resolved.production_state and resolved.production_state.value
		or apiData.production_status
	local badge = productionStatus.badge(state)
	if not badge then
		return nil
	end
	-- Per-ship note: the editorial `productionstatedesc` (wiki-curated) wins, with the
	-- API production_note as fallback (usually "None", dropped by buildProductionTooltip).
	local note = editorialValue(resolved, 'production_state_desc') or apiData.production_note
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
		['Career'] = resolveCareer(apiData, args), -- wiki param wins (curated taxonomy)
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
	for _, dt in ipairs(DAMAGE_TYPES) do
		data[dt.label .. ' damage modifier'] = tonumber(armor[dt.key])
	end
	return data
end

--- External-site links: Official (pledge from API + editorial galactapedia/brochure/
--- trailer/presentation/Q&A) and Community (ship tools from API identifiers).
--- The footer merges the "Official sites" row with Base's same-label row.
--- @param apiData table
--- @param args table
--- @return table[]
function p.getExternalSiteItems(apiData, args)
	local items = {}
	local official = format.buildSiteLinks(mw.loadJsonData('Module:Entity/Vehicle/officialSites.json'), {
		pledge_url = args.pledgeurl or apiData.pledge_url,
		galactapedia = args.galactapedia_url,
		brochure = args.brochure,
		trailer = args.trailer,
		presentations = args.presentations,
		qa = args.qa,
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
	local cats = {}
	-- Derive the family from the resolved subtype so editorial-mode pages
	-- (apiData = {}, no is_spaceship flag) still classify as ships via |family=.
	local isShip = p.resolveSubtype(apiData, args) == require('Module:Entity/Vehicle/Ship')
	-- Size (ships only): "Large ships" — the curated |size= wins (API may disagree)
	local size = matrixSize(apiData, args)
	if isShip and size then
		cats[#cats + 1] = lang:ucfirst(size) .. ' ships'
	end
	-- Pledge: ship -> "Pledge ships"; ground/gravlev -> "Pledge vehicles" (when a pledge price exists)
	local pledge = tonumber(effective(resolved, 'pledge_price', apiData.msrp))
	if pledge and pledge > 0 then
		cats[#cats + 1] = isShip and 'Pledge ships' or 'Pledge vehicles'
	end
	-- Production state label: "Flight ready"
	local state = (resolved.production_state and resolved.production_state.value) or apiData.production_status
	local stateLabel = productionStatus.label(state)
	if stateLabel then
		cats[#cats + 1] = stateLabel
	end
	-- Series grouping "<mfr name> <series>" (e.g. "Gatac Manufacture Railen"), and
	-- generation grouping "<series> <generation>" (e.g. "Constellation Mk4").
	local series = editorialValue(resolved, 'series')
	if series ~= nil and series ~= '' then
		local mfr = base.resolveManufacturer(apiData, args)
		if mfr and mfr.name then
			cats[#cats + 1] = mfr.name .. ' ' .. series
		end
		local generation = editorialValue(resolved, 'generation')
		if generation ~= nil and generation ~= '' then
			cats[#cats + 1] = series .. ' ' .. generation
		end
	end
	-- Career: "Transport career"
	local career = resolveCareer(apiData, args)
	if career ~= nil then
		cats[#cats + 1] = lang:ucfirst(career) .. ' career'
	end
	return cats
end

return p
