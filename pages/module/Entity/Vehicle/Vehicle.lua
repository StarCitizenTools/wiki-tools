require('strict')

--- @module Entity/Vehicle
--- Vehicle kind module: the orchestrator for the vehicle family. Exposes the
--- vehicles API endpoint, resolves the family subtype leaf (Ship / GroundVehicle
--- / Gravlev), and dispatches infobox sections to the per-section sub-builders
--- under Vehicle/ (Overview, Capacity, Cost, Stats, Dimensions, Lore, Development).
--- Editorial overlap fields are read through Module:Entity/Editorial's view.

local base = require('Module:Entity/Base')
local subtypeResolver = require('Module:Entity/SubtypeResolver')
local acq = require('Module:Entity/Acquisition')
local capacity = require('Module:Entity/Vehicle/Capacity')
local cost = require('Module:Entity/Vehicle/Cost')
local development = require('Module:Entity/Vehicle/Development')
local Editorial = require('Module:Entity/Editorial')
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

--- Vehicle family → subtype leaf module path. The keys are the family tokens
--- (also each leaf's p.family tag and the curated |family= arg value).
local VEHICLE_FAMILY_MAP = {
	gravlev = 'Entity/Vehicle/Gravlev',
	ship = 'Entity/Vehicle/Ship',
	ground = 'Entity/Vehicle/GroundVehicle',
}

--- Derive the family token: a genuine record's boolean flags (ordered
--- most-specific-first) win; in editorial mode (apiData = {}) the curated
--- |family= arg selects it. nil when neither resolves.
--- @param apiData table|nil
--- @param args table|nil
--- @return string|nil
local function deriveFamily(apiData, args)
	if type(apiData) == 'table' then
		if apiData.is_gravlev then
			return 'gravlev'
		end
		if apiData.is_spaceship then
			return 'ship'
		end
		if apiData.is_vehicle then
			return 'ground'
		end
	end
	return type(args) == 'table' and args.family or nil
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
	return subtypeResolver.resolve(deriveFamily(apiData, args), VEHICLE_FAMILY_MAP)
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
	local role = vehicleUtil.resolveRole(apiData, args)
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
--- @param typeNoun string  'ship' | 'ground vehicle' | 'grav-lev vehicle'
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

--- Vehicle production-state badge for the infobox header overlay. Uses the
--- editorial-resolved production_state (API production_status, override-able).
--- Vehicle-only: other entities are in-game by definition, so a status badge
--- would be noise. The per-ship milestone/note now lives in the Development
--- section (Added in version + production note), so the badge is a plain pill.
--- @param apiData table
--- @param args table
--- @param resolved table|nil
--- @return string|nil
function p.getHeaderBadge(apiData, args, resolved)
	local ed = Editorial.view(resolved)
	return productionStatus.badge(ed:value('production_state', apiData.production_status))
end

--- Return the Vehicle editorial manifest. Used by Module:Entity/Editorial to
--- resolve hybrid API/wikitext fields (crew, cargo, speed, mass, pledge price)
--- and to drive SMW storage for those fields.
--- @return table
function p.getEditorialManifest()
	return mw.loadJsonData('Module:Entity/Vehicle/editorial.json')
end

--- Return structured data for the pure-API vehicle fields not covered by the
--- editorial manifest (Career, Role, Size, agility rates). Fields owned
--- by the editorial layer (crew/cargo/speed/mass/pledge) are intentionally
--- absent here — the editorial resolver handles their SMW storage.
--- @param apiData table
--- @param args table
--- @param resolved table|nil
--- @return table
function p.getStructuredData(apiData, args, resolved)
	local agility = type(apiData.agility) == 'table' and apiData.agility or {}
	local armor = type(apiData.armor) == 'table' and apiData.armor or {}
	local emission = type(apiData.emission) == 'table' and apiData.emission or {}
	local fuel = type(apiData.fuel) == 'table' and apiData.fuel or {}
	local quantum = type(apiData.quantum) == 'table' and apiData.quantum or {}
	local speed = type(apiData.speed) == 'table' and apiData.speed or {}
	local weaponry = type(apiData.weaponry) == 'table' and apiData.weaponry or {}
	local missiles = type(weaponry.missiles) == 'table' and weaponry.missiles or {}
	local uex = type(apiData.uex_prices) == 'table' and apiData.uex_prices or {}
	local ed = Editorial.view(resolved)
	-- Loaner ship names (Page list), suppressed for flight-ready ships (implemented →
	-- no loaner granted, even though the API may still return stale loaner data).
	local loaner = nil
	if productionStatus.key(ed:value('production_state', apiData.production_status)) ~= 'flightready' then
		local raw = type(apiData.loaner) == 'table' and apiData.loaner or {}
		local names = {}
		for _, entry in ipairs(raw) do
			if type(entry) == 'table' and type(entry.name) == 'string' and entry.name ~= '' then
				names[#names + 1] = entry.name
			end
		end
		loaner = names[1] and names or nil
	end
	-- Curated matrix size name (|size= wins over API), ucfirst'd. The numeric size
	-- class is stored separately as Size; in-game ships have both, concept-only
	-- (legacy {{Vehicle}}) ships carry just the matrix name.
	local matrixSize = vehicleUtil.matrixSize(apiData, args)
	local data = {
		['Career'] = vehicleUtil.resolveCareer(apiData, args), -- wiki param wins (curated taxonomy)
		['Role'] = vehicleUtil.resolveRole(apiData, args),
		['Size'] = tonumber(apiData.size_class),
		['Ship matrix size'] = (matrixSize and matrixSize ~= '') and lang:ucfirst(matrixSize) or nil,
		['Storage capacity'] = tonumber(apiData.vehicle_inventory),
		['Loaner vehicle'] = loaner,
		['Roll rate'] = tonumber(agility.roll),
		['Pitch rate'] = tonumber(agility.pitch),
		['Yaw rate'] = tonumber(agility.yaw),
		['Insurance claim time'] = apiData.insurance and tonumber(apiData.insurance.claim_time) or nil,
		['Insurance expedite time'] = apiData.insurance and tonumber(apiData.insurance.expedite_time) or nil,
		['Insurance expedite cost'] = apiData.insurance and tonumber(apiData.insurance.expedite_cost) or nil,
		-- Estimated in-game prices: same median-of-latest-patch UEX value the Cost
		-- infobox shows (Module:Entity/Acquisition.estimatePrice), stored unitless (aUEC).
		['Average purchase price'] = acq.estimatePrice(uex.purchase, 'price_buy'),
		['Average rental price'] = acq.estimatePrice(uex.rental, 'price_rent'),
		['Health point'] = tonumber(apiData.health),
		['Shield health point'] = tonumber(apiData.shield_hp),
		['Pilot DPS'] = tonumber(weaponry.pilot_dps),
		['Turret DPS'] = tonumber(weaponry.turret_dps),
		['Pilot sustained DPS'] = tonumber(weaponry.pilot_sustained_dps),
		['Turret sustained DPS'] = tonumber(weaponry.turret_sustained_dps),
		['Missile damage'] = type(missiles.damage) == 'table' and tonumber(missiles.damage.total) or nil,
		['Infrared emission'] = tonumber(emission.ir),
		['Electromagnetic emission'] = tonumber(emission.em_max),
		['Cross section'] = vehicleUtil.meanCrossSection(apiData.cross_section),
		['Armor resistance'] = vehicleUtil.meanArmorResistance(armor),
		['Armor deflection'] = vehicleUtil.meanDeflection(armor),
		['Physical deflection'] = type(armor.deflection) == 'table' and tonumber(armor.deflection.physical) or nil,
		['Energy deflection'] = type(armor.deflection) == 'table' and tonumber(armor.deflection.energy) or nil,
		['Zero to Maximum speed time'] = tonumber(speed.zero_to_max),
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
--- brochureurl / trailerurl / presentationurl / qaurl / whitleysguideurl) and Community
--- (ship tools from API identifiers). The brochure/trailer/presentation/Q&A args each accept a
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
		whitleys_guide = format.splitSemi(args.whitleysguideurl),
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
--- @param family string|nil  the leaf family token, threaded from Data.get (no re-resolve)
--- @return string[]
function p.getCategories(apiData, args, resolved, family)
	local ed = Editorial.view(resolved)
	local cats = {}
	-- Family is threaded from Data.get (the leaf's p.family); editorial-mode pages
	-- (apiData = {}, no is_spaceship flag) still classify as ships via |family=.
	local isShip = family == 'ship'
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

--- Acquisition data for {{Entity/Availability}}: Buy/Rent/Pledge summary flags
--- (Loot/Craft omitted — neither applies to vehicles) and Shops + Rentals
--- terminal cards from uex_prices.{purchase,rental}. Pledge derives from msrp.
--- @param apiData table
--- @param args table
--- @return { summary: table[], cards: table[] }
function p.getAcquisition(apiData, args)
	local prices = type(apiData.uex_prices) == 'table' and apiData.uex_prices or {}
	local purchase = type(prices.purchase) == 'table' and prices.purchase or {}
	local rental = type(prices.rental) == 'table' and prices.rental or {}

	local summary = {
		{
			label = 'Buy',
			icon = '🛒',
			value = acq.resolveFlag(args.canBuy, acq.inferCanAcquire(purchase, 'price_buy')),
		},
		{
			label = 'Rent',
			icon = '⏳',
			value = acq.resolveFlag(args.canRent, acq.inferCanAcquire(rental, 'price_rent')),
		},
		{ label = 'Pledge', icon = '💵', value = acq.resolveFlag(args.canPledge, apiData.msrp ~= nil) },
	}

	local hasPurchase = #purchase > 0
	local hasSell = hasPurchase and acq.priceRange(purchase, 'price_sell') ~= nil
	local shopColumns = { { id = 'buy', key = 'price_buy', label = 'Buy' } }
	if hasSell then
		shopColumns[#shopColumns + 1] = { id = 'sell', key = 'price_sell', label = 'Sell' }
	end
	local shopDescription
	if hasPurchase then
		shopDescription = hasSell and acq.buildShopTerminalsDescription(purchase)
			or acq.buildSinglePriceDescription(purchase, 'price_buy')
	else
		shopDescription = 'No shop data in UEX'
	end

	local hasRental = #rental > 0
	return {
		summary = summary,
		cards = {
			{
				type = 'terminals',
				title = '<span aria-hidden="true">🛒</span> Shops',
				caption = 'Shop terminals',
				description = shopDescription,
				prices = hasPurchase and purchase or nil,
				priceColumns = shopColumns,
			},
			{
				type = 'terminals',
				title = '<span aria-hidden="true">⏳</span> Rentals',
				caption = 'Vehicle rental terminals',
				description = hasRental and acq.buildSinglePriceDescription(rental, 'price_rent')
					or 'No rental data in UEX',
				prices = hasRental and rental or nil,
				priceColumns = { { id = 'rent', key = 'price_rent', label = 'Rent' } },
			},
		},
	}
end

return p
