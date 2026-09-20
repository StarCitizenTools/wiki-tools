require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local ProductionStatus = require('Module:Entity/ProductionStatus')
local Vehicle = require('Module:Entity/Vehicle')
local Ship = require('Module:Entity/Vehicle/Ship')
local GroundVehicle = require('Module:Entity/Vehicle/GroundVehicle')
local Gravlev = require('Module:Entity/Vehicle/Gravlev')
local assembly = require('Module:Entity/Assembly')

local suite = ScribuntoUnit:new()

--- Hook context for direct hook calls (Module:Entity/Types EntityHookContext).
local function ctx(apiData, args, resolved)
	return { apiData = apiData, args = args or {}, resolved = resolved }
end

--- Find a section by key in the sections list returned by getSections().
--- @param sections table[]
--- @param key string
--- @return table|nil
local function findSection(sections, key)
	for _, s in ipairs(sections) do
		if s.key == key then
			return s
		end
	end
	return nil
end

--- Find an item row by label within a section's items list.
--- @param items table[]
--- @param label string
--- @return table|nil
local function findItem(items, label)
	if not items then
		return nil
	end
	for _, item in ipairs(items) do
		if item.label == label then
			return item
		end
	end
	return nil
end

--- Categories the way Module:Entity/Data collects them: every link of the
--- resolved chain contributes, root to leaf.
local function categoriesFor(apiData, args, resolved)
	local leaf = Vehicle.resolveSubtype(apiData, args) or Vehicle
	return assembly.collect(
		assembly.buildChain(leaf),
		'getCategories',
		{ apiData = apiData, args = args, resolved = resolved }
	)
end

local function toSet(list)
	local set = {}
	for _, c in ipairs(list) do
		set[c] = true
	end
	return set
end

function suite:testMatchesNilReturnsFalse()
	self:assertEquals(false, Vehicle.matches(nil))
end

function suite:testMatchesEmptyTableReturnsFalse()
	self:assertEquals(false, Vehicle.matches({}))
end

function suite:testMatchesItemShapedDataReturnsFalse()
	self:assertEquals(false, Vehicle.matches({ uuid = 'abc-123', type = 'Food' }))
end

function suite:testMatchesUuidWithoutIsVehicleReturnsFalse()
	self:assertEquals(false, Vehicle.matches({ uuid = 'abc-123' }))
end

function suite:testMatchesGroundVehicleReturnsTrue()
	self:assertEquals(true, Vehicle.matches({ uuid = 'abc-123', is_vehicle = true }))
end

-- is_vehicle is a family discriminator (ground vehicle vs spaceship vs
-- gravlev), not a generic vehicle flag. Spaceships carry is_vehicle=false
-- but still belong to the vehicle kind — presence of the key is what
-- discriminates a vehicle response from an item response.
function suite:testMatchesSpaceshipReturnsTrue()
	self:assertEquals(true, Vehicle.matches({ uuid = 'abc-123', is_vehicle = false, is_spaceship = true }))
end

function suite:testResolveSubtypeSpaceship()
	self:assertEquals(Ship, Vehicle.resolveSubtype({ is_spaceship = true, is_vehicle = false }))
end

function suite:testResolveSubtypeGroundVehicle()
	self:assertEquals(GroundVehicle, Vehicle.resolveSubtype({ is_vehicle = true }))
end

function suite:testResolveSubtypeGravlevBeatsGroundVehicle()
	self:assertEquals(Gravlev, Vehicle.resolveSubtype({ is_gravlev = true, is_vehicle = true }))
end

function suite:testResolveSubtypeNilWhenNoFamily()
	self:assertEquals(nil, Vehicle.resolveSubtype({ uuid = 'x' }))
end

function suite:testResolveSubtypeNilWhenNotTable()
	self:assertEquals(nil, Vehicle.resolveSubtype(nil))
end

function suite:testShipSpeedSection()
	local s = Vehicle.getSections(ctx({
		is_spaceship = true,
		career = 'Combat',
		role = 'Light Fighter',
		size = 'small',
		crew = { min = 1, max = 1 },
		cargo_capacity = 3,
		speed = { scm = 227, max = 1230 },
		agility = { roll = 137, pitch = 59, yaw = 51 },
	}, {}, {}))
	local mobility = findItem(findSection(s, 'stats').sections, 'Mobility')
	self:assertEquals('227 m/s', findItem(mobility.items, 'SCM speed').content)
	self:assertEquals('137 \194\176/s', findItem(mobility.items, 'Roll rate').content)
	self:assertEquals(nil, findItem(mobility.items, 'Reverse speed'))
	local travel = findItem(findSection(s, 'stats').sections, 'Travel')
	self:assertEquals('1,230 m/s', findItem(travel.items, 'Max speed').content)
	-- Overview is the labelless top section (always shown, never collapsible).
	local ov = findSection(s, 'overview')
	self:assertEquals(nil, ov.label)
	self:assertEquals('Spacecraft', findItem(ov.items, 'Type').content)
	-- Career links to its browse category (legacy behavior restored).
	self:assertEquals('[[:Category:Combat career|Combat]]', findItem(ov.items, 'Career').content)
end

function suite:testOverviewModelFromSeries()
	-- "Model" row shows the editorial series; plain series when no manufacturer resolves.
	local s =
		Vehicle.getSections(ctx({ is_spaceship = true }, {}, { series = { value = 'Avenger', source = 'editorial' } }))
	self:assertEquals('Avenger', findItem(findSection(s, 'overview').items, 'Model').content)
end

function suite:testOverviewModelOmittedWhenNoSeries()
	local s = Vehicle.getSections(ctx({ is_spaceship = true }, {}, {}))
	self:assertEquals(nil, findItem(findSection(s, 'overview').items, 'Model'))
end

function suite:testCareerWikiParamWinsOverApi()
	-- wiki `career` param wins over the API value (curated taxonomy).
	local s = Vehicle.getSections(ctx({ is_spaceship = true, career = 'Transporter' }, { career = 'Transport' }, {}))
	self:assertEquals(
		'[[:Category:Transport career|Transport]]',
		findItem(findSection(s, 'overview').items, 'Career').content
	)
end

function suite:testRoleWikiParamWinsOverApi()
	-- wiki `role` param wins over the API in the Role row (curated taxonomy, like Career).
	local s = Vehicle.getSections(ctx({ is_spaceship = true, role = 'Light Fighter' }, { role = 'Heavy Fighter' }, {}))
	self:assertEquals('Heavy fighter', findItem(findSection(s, 'overview').items, 'Role').content)
end

function suite:testRoleFromApiWhenNoArg()
	-- with no wiki override, the Role row shows the API role.
	local s = Vehicle.getSections(ctx({ is_spaceship = true, role = 'Light Fighter' }, {}, {}))
	self:assertEquals('Light fighter', findItem(findSection(s, 'overview').items, 'Role').content)
end

function suite:testGroundVehicleSpeedUsesDrive()
	local s = Vehicle.getSections(ctx({
		crew = { min = 1, max = 2 },
		cargo_capacity = 1,
		speed = { scm = nil, max = nil },
		agility = { roll = nil, pitch = nil, yaw = nil },
		drive = { max_speed_ms = 36, reverse_speed_ms = 13.558441 },
	}, {}, {}))
	local mobility = findItem(findSection(s, 'stats').sections, 'Mobility')
	self:assertEquals(nil, findItem(mobility.items, 'SCM speed'))
	self:assertEquals('14 m/s', findItem(mobility.items, 'Reverse speed').content)
	self:assertEquals(nil, findItem(mobility.items, 'Roll rate'))
	local travel = findItem(findSection(s, 'stats').sections, 'Travel')
	self:assertEquals('36 m/s', findItem(travel.items, 'Max speed').content)
end

function suite:testEditorialOverrideFlowsIntoSpeed()
	local s =
		Vehicle.getSections(ctx({ speed = { scm = 227 } }, {}, { scm_speed = { value = 210, source = 'override' } }))
	local mobility = findItem(findSection(s, 'stats').sections, 'Mobility')
	self:assertEquals('210 m/s', findItem(mobility.items, 'SCM speed').content)
end

function suite:testEmptyApiOmitsSections()
	local s = Vehicle.getSections(ctx({}, {}, {}))
	self:assertEquals(nil, findSection(s, 'stats'))
	self:assertEquals(nil, findSection(s, 'capacity'))
end

function suite:testGetSubtitleReturnsManufacturerLink()
	-- args.manufacturer 'Testco' doesn't resolve, so Base falls back to a
	-- self-referencing record (page == name) → a plain [[Testco]] link.
	self:assertEquals('[[Testco]]', Vehicle.getSubtitle(ctx({}, { manufacturer = 'Testco' })))
end

function suite:testGetSubtitleNilWhenNoManufacturer()
	self:assertEquals(nil, Vehicle.getSubtitle(ctx({}, {})))
end

function suite:testEditorialManifestLoads()
	local m = Vehicle.getEditorialManifest()
	self:assertEquals('msrp', m.pledge_price.apiPath)
	self:assertEquals('speed.scm', m.scm_speed.apiPath)
	self:assertEquals('Pledge availability', m.pledge_availability.property)
end

function suite:testStructuredDataPureApiStats()
	local d = Vehicle.getStructuredData(ctx({
		career = 'Combat',
		role = 'Light Fighter',
		size_class = 2,
		agility = { roll = 137, pitch = 59, yaw = 51 },
	}, {}, {}))
	self:assertEquals('Combat', d['Career'])
	self:assertEquals(2, d['Size'])
	self:assertEquals(137, d['Roll rate'])
end

function suite:testStructuredDataRoleWikiParamWins()
	-- the stored Role property honors the wiki `role` override (matches the Role row + short desc).
	local d = Vehicle.getStructuredData(ctx({ role = 'Light Fighter' }, { role = 'Heavy Fighter' }, {}))
	self:assertEquals(1, #d['Role'])
	self:assertEquals('Heavy fighter', d['Role'][1])
end

function suite:testStructuredDataRoleFromApiWhenNoArg()
	local d = Vehicle.getStructuredData(ctx({ role = 'Light Fighter' }, {}, {}))
	self:assertEquals(1, #d['Role'])
	self:assertEquals('Light fighter', d['Role'][1])
end

function suite:testStructuredDataRoleSplitsMultiRole()
	-- Role is a repeated field: each role is stored on its own so a per-role
	-- query matches. Joined into one value, a ship listed "Starter / Light
	-- Fighter" is absent from every light-fighter listing.
	local d = Vehicle.getStructuredData(ctx({ role = 'Starter / Light Fighter' }, {}, {}))
	self:assertEquals(2, #d['Role'])
	self:assertEquals('Starter', d['Role'][1])
	self:assertEquals('Light fighter', d['Role'][2])
end

function suite:testRoleIsNormalisedToSentenceCase()
	-- The hub pages and categories a role links to are sentence case
	-- ([[Light fighters]]), so a Title Case value would label a link
	-- differently from its destination. The override decides which role a
	-- vehicle has, not how it is cased, so it is normalised too.
	local d = Vehicle.getStructuredData(ctx({ role = 'Light Fighter' }, { role = 'Heavy Fighter' }, {}))
	self:assertEquals('Heavy fighter', d['Role'][1])
	local e = Vehicle.getStructuredData(ctx({ role = 'Anti-Air' }, {}, {}))
	self:assertEquals('Anti-air', e['Role'][1])
	-- A value that is caps throughout is an editor shouting, not an acronym:
	-- left alone it would store a second casing of an existing role.
	local f = Vehicle.getStructuredData(ctx({ role = 'MULTI-ROLE / Fighter-Bomber' }, {}, {}))
	self:assertEquals('Multi-role', f['Role'][1])
	self:assertEquals('Fighter-bomber', f['Role'][2])
	-- ...but a caps run beside normally-cased words is one, and survives.
	local g = Vehicle.getStructuredData(ctx({ role = 'UEE patrol' }, {}, {}))
	self:assertEquals('UEE patrol', g['Role'][1])
end

function suite:testRoleCasingKeepsAcronyms()
	-- An all-caps run is an acronym; lowercasing it would destroy it.
	local d = Vehicle.getStructuredData(ctx({ role = 'UEE Patrol' }, {}, {}))
	self:assertEquals('UEE patrol', d['Role'][1])
end

function suite:testStructuredDataRoleSplitsOnCommaToo()
	-- One page separated its roles with a comma rather than a slash.
	local d = Vehicle.getStructuredData(ctx({ role = 'Mining, Salvage' }, {}, {}))
	self:assertEquals(2, #d['Role'])
	self:assertEquals('Mining', d['Role'][1])
	self:assertEquals('Salvage', d['Role'][2])
end

function suite:testRoleRowJoinsMultiRoleForDisplay()
	-- The infobox row is a string: the segments come back joined, and with the
	-- separator normalised whatever the source used.
	local s = Vehicle.getSections(ctx({ role = 'Mining, Salvage' }, {}, {}))
	self:assertEquals('Mining / Salvage', findItem(findSection(s, 'overview').items, 'Role').content)
end

function suite:testStructuredDataOmitsManifestOwnedFields()
	-- crew/cargo/speed/mass/pledge are owned by the editorial layer, NOT getStructuredData
	local d = Vehicle.getStructuredData(
		ctx(
			{ crew = { min = 1, max = 3 }, cargo_capacity = 96, speed = { scm = 227 }, mass = 26245, msrp = 30 },
			{},
			{}
		)
	)
	self:assertEquals(nil, d['Minimum crew'])
	self:assertEquals(nil, d['Cargo capacity'])
	self:assertEquals(nil, d['Scm speed'])
	self:assertEquals(nil, d['Pledge price'])
end

function suite:testStructuredDataDropsNilAgility()
	local d = Vehicle.getStructuredData(ctx({ agility = { roll = nil, pitch = nil, yaw = nil } }, {}, {}))
	self:assertEquals(nil, d['Roll rate'])
end

-- The headless runner supports mw.getCurrentFrame():extensionTag (PASS in probe),
-- so we can test the full badge path end-to-end.
function suite:testHeaderBadgeNilWhenNoState()
	self:assertEquals(nil, Vehicle.getHeaderBadge(ctx({}, {}, {})))
	self:assertEquals(nil, Vehicle.getHeaderBadge(ctx({ production_status = 'made up' }, {}, {})))
end

function suite:testHeaderBadgeFromApiData()
	-- badge() calls extensionTag; runner supports it → returns a string
	local result = Vehicle.getHeaderBadge(ctx({ production_status = 'flight-ready' }, {}, {}))
	self:assertEquals(true, type(result) == 'string')
end

function suite:testHeaderBadgeEditorialOverrideBeatsApi()
	-- editorial override (production_state.value) takes priority over apiData.production_status
	local resolved = { production_state = { value = 'In concept', source = 'override' } }
	local result = Vehicle.getHeaderBadge(ctx({ production_status = 'flight-ready' }, {}, resolved))
	self:assertEquals(true, type(result) == 'string')
	-- The badge text should contain the overridden label, not the API one
	self:assertEquals(true, result:find('In concept') ~= nil)
end

function suite:testHeaderBadgeNilOverrideResolvesToApi()
	-- resolved with no production_state falls through to apiData
	local result = Vehicle.getHeaderBadge(ctx({ production_status = 'in-production' }, {}, {}))
	self:assertEquals(true, type(result) == 'string')
end

function suite:testProductionStatusResolvesOverrideAndApiForms()
	self:assertEquals('In concept', ProductionStatus._internal.resolve('In concept').label)
	self:assertEquals('Flight ready', ProductionStatus._internal.resolve('flight-ready').label)
end

function suite:testCostUniverseBuyShowsEstimatedPrice()
	-- Buy row shows the estimated (median) UEC price; rental with only a zero price is "No".
	local s = Vehicle.getSections(ctx({
		uex_prices = { purchase = { { price_buy = 500000 } }, rental = { { price_rent = 0 } } },
	}, {}, {}))
	local universe = findItem(findSection(s, 'cost').sections, 'Universe')
	-- Relabelled Buy/Rent (was Buyable/Rentable).
	self:assertEquals(nil, findItem(universe.items, 'Buyable'))
	local buy = findItem(universe.items, 'Buy').content
	self:assertEquals('~', buy:sub(1, 1)) -- estimate marker
	self:assertTrue(buy:find('500,000', 1, true) ~= nil) -- UEC-formatted price
	self:assertTrue(buy:find('aUEC', 1, true) == nil) -- formatted via Module:UEC, no bare unit
	-- Rental has an entry but no non-zero price → definitively No (not Unknown).
	self:assertStringContains('data%-state="no"', findItem(universe.items, 'Rent').content)
end

function suite:testCostAvailabilitySkippedForLoreOnly()
	-- Lore-only vehicles were never for sale: the Pledge Availability row is
	-- suppressed even when a value is present, while other pledge rows still show.
	local s = Vehicle.getSections(ctx({}, { family = 'ship', manufacturer = 'MISC' }, {
		production_state = { value = 'Lore-only', source = 'editorial' },
		pledge_price = { value = 100, source = 'editorial' },
		pledge_availability = { value = 'Never sold', source = 'editorial' },
	}))
	local pledge = findItem(findSection(s, 'cost').sections, 'Pledge')
	self:assertEquals(nil, findItem(pledge.items, 'Availability'))
	self:assertTrue(findItem(pledge.items, 'Standalone') ~= nil)
end

function suite:testCostAvailabilityShownForNonLore()
	-- A non-lore vehicle still shows the Availability row.
	local s = Vehicle.getSections(ctx({}, { family = 'ship', manufacturer = 'MISC' }, {
		production_state = { value = 'In concept', source = 'editorial' },
		pledge_price = { value = 100, source = 'editorial' },
		pledge_availability = { value = 'Limited', source = 'editorial' },
	}))
	local pledge = findItem(findSection(s, 'cost').sections, 'Pledge')
	self:assertEquals('Limited', findItem(pledge.items, 'Availability').content)
end

function suite:testCostUniverseBuyPriceIsMedianAcrossTerminals()
	-- Three terminals, same patch → median of buy prices (not min/max/mean-of-extremes).
	local s = Vehicle.getSections(ctx({
		uex_prices = {
			purchase = { { price_buy = 1000000 }, { price_buy = 2000000 }, { price_buy = 3000000 } },
		},
	}, {}, {}))
	local buy = findItem(findItem(findSection(s, 'cost').sections, 'Universe').items, 'Buy').content
	self:assertTrue(buy:find('2,000,000', 1, true) ~= nil)
	self:assertTrue(buy:find('1,000,000', 1, true) == nil)
	self:assertTrue(buy:find('3,000,000', 1, true) == nil)
end

function suite:testCostUniverseRentShowsEstimatedPrice()
	local s = Vehicle.getSections(ctx({
		uex_prices = { rental = { { price_rent = 27000 }, { price_rent = 27000 }, { price_rent = 30000 } } },
	}, {}, {}))
	local rent = findItem(findItem(findSection(s, 'cost').sections, 'Universe').items, 'Rent').content
	self:assertEquals('~', rent:sub(1, 1))
	self:assertTrue(rent:find('27,000', 1, true) ~= nil) -- median of 27k, 27k, 30k
end

function suite:testCostUniversePriceUsesLatestPatchOnly()
	-- Older-patch terminal is excluded; median is taken over the newest game_version only.
	local s = Vehicle.getSections(ctx({
		uex_prices = {
			purchase = {
				{ price_buy = 1000000, game_version = '4.8.2-LIVE.100' },
				{ price_buy = 2000000, game_version = '4.9.0-LIVE.200' },
				{ price_buy = 4000000, game_version = '4.9.0-LIVE.200' },
			},
		},
	}, {}, {}))
	local buy = findItem(findItem(findSection(s, 'cost').sections, 'Universe').items, 'Buy').content
	self:assertTrue(buy:find('3,000,000', 1, true) ~= nil) -- median of 2M, 4M (latest patch)
	self:assertTrue(buy:find('1,000,000', 1, true) == nil) -- older patch dropped
end

function suite:testCostUniverseLatestPatchHandlesMinorVersionRollover()
	-- 4.10 is newer than 4.8 despite a smaller build suffix: versions compare numerically
	-- component-wise, not lexicographically (where "4.8" > "4.10").
	local s = Vehicle.getSections(ctx({
		uex_prices = {
			purchase = {
				{ price_buy = 1000000, game_version = '4.8.2-LIVE.999' },
				{ price_buy = 5000000, game_version = '4.10.0-LIVE.100' },
			},
		},
	}, {}, {}))
	local buy = findItem(findItem(findSection(s, 'cost').sections, 'Universe').items, 'Buy').content
	self:assertTrue(buy:find('5,000,000', 1, true) ~= nil)
	self:assertTrue(buy:find('1,000,000', 1, true) == nil)
end

function suite:testCostUniverseSkipsZeroPrices()
	local s = Vehicle.getSections(ctx({
		uex_prices = { purchase = { { price_buy = 0 }, { price_buy = 2000000 } } },
	}, {}, {}))
	local buy = findItem(findItem(findSection(s, 'cost').sections, 'Universe').items, 'Buy').content
	self:assertTrue(buy:find('2,000,000', 1, true) ~= nil)
end

function suite:testCostUniverseEvenTerminalCountAveragesMiddlePair()
	local s = Vehicle.getSections(ctx({
		uex_prices = { purchase = { { price_buy = 1000000 }, { price_buy = 2000002 } } },
	}, {}, {}))
	local buy = findItem(findItem(findSection(s, 'cost').sections, 'Universe').items, 'Buy').content
	self:assertTrue(buy:find('1,500,001', 1, true) ~= nil) -- median = (1,000,000 + 2,000,002) / 2
end

function suite:testCostUniverseCanBuyOverrideNoBeatsPrice()
	-- canBuy=no asserts "not buyable" even when UEX has a price → No, no number. canBuy is the
	-- canonical casing shared with {{Entity/Availability}} (the same arg getAcquisition reads).
	local s = Vehicle.getSections(ctx({
		uex_prices = { purchase = { { price_buy = 2000000 } } },
	}, { canBuy = 'no' }, {}))
	local buy = findItem(findItem(findSection(s, 'cost').sections, 'Universe').items, 'Buy').content
	self:assertStringContains('data%-state="no"', buy)
	self:assertEquals(nil, buy:find('2,000,000', 1, true))
end

function suite:testCostUniverseCanBuyOverrideYesNoData()
	-- canBuy=yes with no UEX data → Yes (no price to show)
	local s = Vehicle.getSections(ctx({ uex_prices = {} }, { canBuy = 'yes' }, {}))
	local buy = findItem(findItem(findSection(s, 'cost').sections, 'Universe').items, 'Buy').content
	self:assertStringContains('data%-state="yes"', buy)
end

function suite:testCostUniverseCanRentOverrideNo()
	-- canRent=no asserts "not rentable" even with a rental price → No (camelCase, shared casing).
	local s = Vehicle.getSections(ctx({
		uex_prices = { rental = { { price_rent = 27000 } } },
	}, { canRent = 'no' }, {}))
	local rent = findItem(findItem(findSection(s, 'cost').sections, 'Universe').items, 'Rent').content
	self:assertStringContains('data%-state="no"', rent)
end

function suite:testCostUniverseFlightReadyNoDataIsNo()
	-- flight-ready ship, no UEX data: Universe stays, Buy/Rent = No (in-game → definitive)
	local s = Vehicle.getSections(ctx({ production_status = 'flight-ready', uex_prices = {} }, {}, {}))
	local universe = findItem(findSection(s, 'cost').sections, 'Universe')
	self:assertStringContains('data%-state="no"', findItem(universe.items, 'Buy').content)
	self:assertStringContains('data%-state="no"', findItem(universe.items, 'Rent').content)
end

function suite:testCostUniverseUnreleasedNoDataDrops()
	-- unreleased ship, no UEX, no override → Unknown → Universe dropped (Pledge still shows)
	local s = Vehicle.getSections(ctx({ production_status = 'in-concept', msrp = 30, uex_prices = {} }, {}, {}))
	local cost = findSection(s, 'cost')
	self:assertEquals(nil, findItem(cost.sections, 'Universe'))
	self:assertEquals('$30', findItem(findItem(cost.sections, 'Pledge').items, 'Standalone').content)
end

function suite:testCostPledgeUsesMsrp()
	local s = Vehicle.getSections(ctx({ msrp = 30 }, {}, {}))
	local pledge = findItem(findSection(s, 'cost').sections, 'Pledge')
	self:assertEquals('$30', findItem(pledge.items, 'Standalone').content)
end

function suite:testCostPledgeShowsOriginalWhenDiffers()
	local s =
		Vehicle.getSections(ctx({ msrp = 30 }, {}, { original_pledge_price = { value = 45, source = 'editorial' } }))
	local pledge = findItem(findSection(s, 'cost').sections, 'Pledge')
	self:assertEquals('$30 (was $45)', findItem(pledge.items, 'Standalone').content)
end

function suite:testCostInsurance()
	local s = Vehicle.getSections(ctx({ insurance = { claim_time = 2.92, expedite_cost = 1631 } }, {}, {}))
	local ins = findItem(findSection(s, 'cost').sections, 'Insurance')
	-- Expedite fee renders via Module:UEC (glyph + grouped number), not a bare unit.
	local fee = findItem(ins.items, 'Expedite fee').content
	self:assertTrue(fee ~= nil and fee:find('1,631', 1, true) ~= nil)
end

function suite:testCostOmittedWhenNoData()
	self:assertEquals(nil, findSection(Vehicle.getSections(ctx({}, {}, {})), 'cost'))
end

function suite:testPledgeLoanerShownForConcept()
	local s = Vehicle.getSections(
		ctx({ production_status = 'in-concept', loaner = { { name = 'C2 Hercules' }, { name = 'Syulen' } } }, {}, {})
	)
	local pledge = findItem(findSection(s, 'cost').sections, 'Pledge')
	self:assertEquals('[[C2 Hercules]], [[Syulen]]', findItem(pledge.items, 'Loaner').content)
end

function suite:testPledgeLoanerSuppressedForFlightReady()
	local s = Vehicle.getSections(
		ctx({ msrp = 30, production_status = 'flight-ready', loaner = { { name = 'C2 Hercules' } } }, {}, {})
	)
	local pledge = findItem(findSection(s, 'cost').sections, 'Pledge')
	self:assertEquals('$30', findItem(pledge.items, 'Standalone').content)
	self:assertEquals(nil, findItem(pledge.items, 'Loaner'))
end

function suite:testStructuredDataInsurance()
	local d = Vehicle.getStructuredData(ctx({ insurance = { claim_time = 2.92, expedite_cost = 1631 } }, {}, {}))
	self:assertEquals(2.92, d['Insurance claim time'])
	self:assertEquals(1631, d['Insurance expedite cost'])
end

function suite:testDimensionsSectionPresent()
	local s =
		Vehicle.getSections(ctx({ dimension = { length = 19, width = 8.75, height = 4.5 }, mass = 26245 }, {}, {}))
	local d = findSection(s, 'dimensions')
	self:assertEquals('dimensions', d.key)
	self:assertEquals(true, type(d.content) == 'string' and #d.content > 0)
end

function suite:testDimensionsOmittedWhenAbsent()
	self:assertEquals(nil, findSection(Vehicle.getSections(ctx({}, {}, {})), 'dimensions'))
end

function suite:testDimensionsOmittedWhenIncomplete()
	-- missing height → no box
	self:assertEquals(
		nil,
		findSection(Vehicle.getSections(ctx({ dimension = { length = 19, width = 8.75 } }, {}, {})), 'dimensions')
	)
end

function suite:testDimensionsFromEditorial()
	-- Planned/concept vehicle: no apiData.dimension; length/width/height/mass come
	-- from editorial args, so the Dimensions box still renders (editorial-first).
	local s = Vehicle.getSections(ctx({}, { family = 'ship' }, {
		length = { value = 372, source = 'editorial' },
		width = { value = 104, source = 'editorial' },
		height = { value = 104, source = 'editorial' },
		mass = { value = 1652000, source = 'editorial' },
	}))
	local d = findSection(s, 'dimensions')
	self:assertEquals('dimensions', d.key)
	self:assertEquals(true, type(d.content) == 'string' and #d.content > 0)
end

function suite:testStatsMobilityTabHasSpeed()
	local s = Vehicle.getSections(ctx({ is_spaceship = true, speed = { scm = 227, max = 1230 } }, {}, {}))
	local mobility = findItem(findSection(s, 'stats').sections, 'Mobility')
	self:assertEquals('227 m/s', findItem(mobility.items, 'SCM speed').content)
end

function suite:testDefenseAndStealthTabs()
	local s = Vehicle.getSections(ctx({
		health = 6110,
		shield_hp = 6336,
		emission = { ir = 4000 },
		armor = { damage_physical = 0.75, signal_infrared = 1.13, signal_electromagnetic = 1 },
	}, {}, {}))
	local defense = findItem(findSection(s, 'stats').sections, 'Defense')
	self:assertEquals('6,110 HP', findItem(defense.items, 'Hull').content)
	self:assertEquals('6,336 HP', findItem(defense.items, 'Shield').content)
	local stealth = findItem(findSection(s, 'stats').sections, 'Stealth')
	-- Effective IR = 4000 × 1.13 = 4520; the +13% armor modifier rides as a colored suffix.
	local ir = findItem(stealth.items, 'IR').content
	self:assertTrue(ir:find('4,520', 1, true) ~= nil)
	self:assertTrue(ir:find('+13%', 1, true) ~= nil)
	-- No EM emission value → no EM row at all (a lone multiplier never surfaces).
	self:assertEquals(nil, findItem(stealth.items, 'EM'))
end

function suite:testHullResistanceTileBlock()
	-- ProgressTiles is stubbed in the runner (returns ''), so assert only that the
	-- block item is present (label-less, string content, block CSS class).
	local s = Vehicle.getSections(ctx({ armor = { damage_physical = 0.75 } }, {}, {}))
	local defense = findItem(findSection(s, 'stats').sections, 'Defense')
	local block = nil
	for _, it in ipairs(defense.items) do
		if it.label == nil and type(it.content) == 'string' then
			block = it
		end
	end
	self:assertTrue(block ~= nil)
	self:assertEquals('t-infobox-item--block', block.class)
end

function suite:testStructuredDataHullArmor()
	local d = Vehicle.getStructuredData(ctx({ health = 6110, armor = { damage_physical = 0.75 } }, {}, {}))
	self:assertEquals(6110, d['Health point'])
	self:assertEquals(0.75, d['Physical damage modifier'])
end

function suite:testFuelHydrogenAndQuantumTabs()
	local s = Vehicle.getSections(ctx({
		fuel = { capacity = 13.5 },
		quantum = { quantum_speed = 190000000, quantum_range = 69817400644, quantum_spool_time = 4 },
	}, {}, {}))
	-- Fuel capacity + quantum drive fold into the Travel tab; consumption rows dropped.
	local travel = findItem(findSection(s, 'stats').sections, 'Travel')
	self:assertEquals('13.5', findItem(travel.items, 'Hydrogen fuel').content)
	self:assertEquals('190 Mm/s', findItem(travel.items, 'Quantum speed').content)
	self:assertEquals('69.8 Gm', findItem(travel.items, 'Quantum range').content)
	self:assertEquals('4 s', findItem(travel.items, 'Spool time').content)
	self:assertEquals(nil, findItem(travel.items, 'Main thruster')) -- consumption dropped
end

function suite:testTravelTabOmittedWhenNoTravelData()
	-- A ship with mobility data but no max speed / fuel / quantum: Mobility but no Travel.
	local s = Vehicle.getSections(ctx({ speed = { scm = 227 } }, {}, {}))
	local stats = findSection(s, 'stats')
	self:assertEquals(nil, findItem(stats.sections, 'Travel'))
	self:assertEquals(true, findItem(stats.sections, 'Mobility') ~= nil)
end

function suite:testNoFuelSection()
	-- Fuel no longer renders as its own top-level section.
	local s = Vehicle.getSections(ctx({ fuel = { capacity = 13.5 } }, {}, {}))
	self:assertEquals(nil, findSection(s, 'fuel'))
end

function suite:testStructuredDataFuelQuantumCommunityUnits()
	local d = Vehicle.getStructuredData(ctx({
		fuel = { capacity = 13.5 },
		quantum = { quantum_speed = 190000000, quantum_range = 70000000000 },
	}, {}, {}))
	self:assertEquals(13.5, d['Hydrogen fuel capacity'])
	self:assertEquals(190, d['Quantum speed']) -- Mm/s, not raw
	self:assertEquals(70, d['Quantum range']) -- Gm
end

function suite:testLoreAndDevelopmentSections()
	local s = Vehicle.getSections(ctx({}, {}, {
		release_date = { value = '2772', source = 'editorial' },
		concept_sale = { value = '2021-06-05', source = 'editorial' },
	}))
	self:assertEquals('2772', findItem(findSection(s, 'lore').items, 'Released').content)
	self:assertEquals('2021-06-05', findItem(findSection(s, 'development').items, 'Concept sale').content)
	self:assertEquals(nil, findItem(findSection(s, 'lore').items, 'Retired')) -- absent → dropped
end

function suite:testLoreDevelopmentOmittedWhenNoDates()
	local s = Vehicle.getSections(ctx({}, {}, {}))
	self:assertEquals(nil, findSection(s, 'lore'))
	self:assertEquals(nil, findSection(s, 'development'))
end

function suite:testEditorialManifestDatesPureEditorial()
	local m = Vehicle.getEditorialManifest()
	self:assertEquals('Lore release date', m.release_date.property)
	self:assertEquals(nil, m.release_date.apiPath)
end

function suite:testExternalOfficialAndCommunity()
	local items = Vehicle.getExternalSiteItems(ctx({
		pledge_url = 'https://rsi/pledge',
		class_name = 'AEGS_Gladius',
		uuid = 'ABC',
		shipmatrix_name = 'Gladius',
	}, { brochureurl = 'https://b' }))
	local byLabel = {}
	for _, it in ipairs(items) do
		byLabel[it.label] = it.content
	end
	self:assertTrue(byLabel['Official sites'] ~= nil and byLabel['Official sites']:find('rsi/pledge', 1, true) ~= nil)
	-- The pledge link is labelled "Pledge store" (single brochure keeps its bare label).
	self:assertTrue(byLabel['Official sites']:find('Pledge store', 1, true) ~= nil)
	self:assertTrue(byLabel['Official sites']:find('[https://b Brochure]', 1, true) ~= nil)
	self:assertTrue(
		byLabel['Community sites'] ~= nil
			and byLabel['Community sites']:find('erkul.games/ship/aegs_gladius', 1, true) ~= nil
	)
end

function suite:testExternalMultipleUrlsSemicolon()
	-- brochure/trailer/presentation/qa each accept a ;-separated list; more than one
	-- URL numbers the labels, a single URL keeps the bare label.
	local items = Vehicle.getExternalSiteItems(ctx({}, {
		presentationurl = 'https://p1; https://p2',
		qaurl = 'https://qa1',
	}))
	local official
	for _, it in ipairs(items) do
		if it.label == 'Official sites' then
			official = it.content
		end
	end
	self:assertTrue(official ~= nil)
	self:assertTrue(official:find('[https://p1 Presentation 1]', 1, true) ~= nil)
	self:assertTrue(official:find('[https://p2 Presentation 2]', 1, true) ~= nil)
	self:assertTrue(official:find('[https://qa1 Q&A]', 1, true) ~= nil)
end

function suite:testExternalEmptyWhenNoData()
	self:assertEquals(0, #Vehicle.getExternalSiteItems(ctx({}, {})))
end

function suite:testSizeDisplayMatrixAndClass()
	local s = Vehicle.getSections(ctx({ is_spaceship = true, size = 'medium', size_class = 3 }, {}, {}))
	self:assertEquals('Medium (S3)', findItem(findSection(s, 'overview').items, 'Size').content)
end

function suite:testSizeDisplayMatrixOnly()
	local s = Vehicle.getSections(ctx({ is_spaceship = true, size = 'large' }, {}, {}))
	self:assertEquals('Large', findItem(findSection(s, 'overview').items, 'Size').content)
end

function suite:testSizeDisplayClassOnly()
	local s = Vehicle.getSections(ctx({ is_spaceship = true, size_class = 2 }, {}, {}))
	self:assertEquals('S2', findItem(findSection(s, 'overview').items, 'Size').content)
end

function suite:testSizeDisplayArgOverridesApi()
	-- |size= (wiki) wins over the API matrix size (Railen: editorially Large, API medium).
	local s = Vehicle.getSections(ctx({ is_spaceship = true, size = 'medium', size_class = 5 }, { size = 'Large' }, {}))
	self:assertEquals('Large (S5)', findItem(findSection(s, 'overview').items, 'Size').content)
end

function suite:testCategoriesSizeFromArg()
	local apiData, args = { is_spaceship = true, size = 'medium' }, { size = 'Large' }
	local set = toSet(categoriesFor(apiData, args, {}))
	self:assertEquals(true, set['Large ships'])
	self:assertEquals(nil, set['Medium ships'])
end

function suite:testSizeDisplayNilWhenNeither()
	local s = Vehicle.getSections(ctx({ is_spaceship = true }, {}, {}))
	self:assertEquals(nil, findItem(findSection(s, 'overview').items, 'Size'))
end

function suite:testModelAppendsGeneration()
	local s = Vehicle.getSections(ctx({ is_spaceship = true }, {}, {
		series = { value = 'Avenger', source = 'editorial' },
		generation = { value = 'II', source = 'editorial' },
	}))
	local model = findItem(findSection(s, 'overview').items, 'Model').content
	self:assertTrue(model:find('Avenger', 1, true) ~= nil)
	self:assertTrue(model:find('[[:Category:Avenger II|II]]', 1, true) ~= nil)
end

function suite:testModelNoGenerationWhenAbsent()
	local s = Vehicle.getSections(ctx({ is_spaceship = true }, {}, {
		series = { value = 'Avenger', source = 'editorial' },
	}))
	local model = findItem(findSection(s, 'overview').items, 'Model').content
	self:assertTrue(model:find('generation', 1, true) == nil)
end

function suite:testHeaderBadgeStillStringForKnownState()
	self:assertEquals(
		true,
		type(Vehicle.getHeaderBadge(ctx({ production_status = 'flight-ready' }, {}, {}))) == 'string'
	)
	self:assertEquals(nil, Vehicle.getHeaderBadge(ctx({ production_status = 'made up' }, {}, {})))
end

function suite:testHeaderBadgeIgnoresProductionNote()
	-- Tooltip removed: production_note no longer affects the header badge.
	local withNote =
		Vehicle.getHeaderBadge(ctx({ production_status = 'in-concept', production_note = 'Delayed' }, {}, {}))
	local without = Vehicle.getHeaderBadge(ctx({ production_status = 'in-concept' }, {}, {}))
	self:assertEquals(without, withNote)
end

function suite:testEditorialManifestHasGeneration()
	local m = Vehicle.getEditorialManifest()
	-- arg is the alias list (legacy [ARG_Generation, ARG_mark]; pages also write |Generation=).
	self:assertEquals('generation', m.generation.arg[1])
	self:assertEquals('Generation', m.generation.arg[2])
	self:assertEquals('mark', m.generation.arg[3])
	self:assertEquals('Generation', m.generation.property)
	self:assertEquals(nil, m.generation.apiPath)
end

function suite:testCategoriesGenerationGrouping()
	-- "<series> <generation>" (legacy category_generation "%s %s"), e.g. "Constellation Mk4".
	local apiData, args = { is_spaceship = true }, {}
	local set = toSet(categoriesFor(apiData, args, {
		series = { value = 'Constellation', source = 'editorial' },
		generation = { value = 'Mk4', source = 'editorial' },
	}))
	self:assertEquals(true, set['Constellation Mk4'])
end

function suite:testCategoriesShip()
	-- Pass args.manufacturer so resolveManufacturer returns a fallback record with
	-- name == 'Gatac Manufacture', enabling the manufacturer+series category.
	local apiData = { is_spaceship = true, size = 'large', msrp = 220, production_status = 'flight-ready' }
	local args = { career = 'Transport', manufacturer = 'Gatac Manufacture' }
	local cats = categoriesFor(apiData, args, { series = { value = 'Railen', source = 'editorial' } })
	local set = toSet(cats)
	self:assertEquals(true, set['Large ships'])
	self:assertEquals(true, set['Pledge ships'])
	self:assertEquals(true, set['Flight ready'])
	self:assertEquals(true, set['Transport career'])
	-- mfr+series depends on resolveManufacturer; assert the series suffix appears
	local hasSeries = false
	for _, c in ipairs(cats) do
		if c:find(' Railen', 1, true) then
			hasSeries = true
		end
	end
	self:assertEquals(true, hasSeries)
end

function suite:testCategoriesGroundNoSizeAndPledgeVehicles()
	local apiData, args = { is_vehicle = true, size = 'small', msrp = 50, production_status = 'flight-ready' }, {}
	local set = toSet(categoriesFor(apiData, args, {}))
	self:assertEquals(nil, set['Small ships']) -- size category is ships-only
	self:assertEquals(true, set['Pledge vehicles']) -- ground uses "Pledge vehicles"
end

function suite:testCategoriesNoPledgeNoSeries()
	local apiData, args = { is_spaceship = true, size = 'large' }, {}
	local cats = categoriesFor(apiData, args, {})
	for _, c in ipairs(cats) do
		self:assertEquals(false, c == 'Pledge ships')
	end
end

function suite:testShortdescSingleSeatFighter()
	self:assertEquals(
		'Aegis single-seat light fighter',
		Vehicle.formatShortDescription(
			{ manufacturer = { code = 'AEGS', name = 'Aegis Dynamics' }, role = 'Light Fighter', crew = { max = 1 } },
			{},
			{},
			'ship',
			false
		)
	)
end

function suite:testShortdescMultiRolePrimary()
	self:assertEquals(
		'RSI large multi-role gunship',
		Vehicle.formatShortDescription({
			manufacturer = { code = 'RSI', name = 'Roberts Space Industries' },
			role = 'Gunship / Light Freight',
			career = 'Multi-role',
			size = 'large',
		}, {}, {}, 'ship', false)
	)
end

function suite:testShortdescAppendsShipWhenNoRoleSuffix()
	self:assertEquals(
		'MISC large heavy freight ship',
		Vehicle.formatShortDescription({
			manufacturer = { code = 'MISC', name = 'Musashi Industrial and Starflight Concern' },
			role = 'Heavy Freight',
			size = 'large',
		}, {}, {}, 'ship', false)
	)
end

function suite:testShortdescGroundOmitsSizeKeepsFullRole()
	self:assertEquals(
		'Tumbril exploration / recon ground vehicle',
		Vehicle.formatShortDescription({
			manufacturer = { code = 'TMBL', name = 'Tumbril Land Systems' },
			role = 'Exploration / Recon',
			career = 'Ground',
			size = 'vehicle',
			crew = { max = 2 },
		}, {}, {}, 'ground vehicle', true)
	)
end

function suite:testShortdescEditorialOverridesApi()
	self:assertEquals(
		'RSI large multi-role gunship',
		Vehicle.formatShortDescription(
			{ manufacturer = { code = 'RSI', name = 'Roberts Space Industries' }, role = 'Passenger', size = 'medium' },
			{ role = 'Gunship / Light Freight', career = 'Multi-role', size = 'large' },
			{},
			'ship',
			false
		)
	)
end

function suite:testShortdescNoRoleNoManufacturer()
	self:assertEquals('Small ship', Vehicle.formatShortDescription({ size = 'small' }, {}, {}, 'ship', false))
end

function suite:testShortdescMultiRoleFighterSuffix()
	-- Cutlass: Multi-role primary "Fighter" ends in a role suffix -> no "ship".
	self:assertEquals(
		'Drake medium multi-role fighter',
		Vehicle.formatShortDescription({
			manufacturer = { code = 'DRAK', name = 'Drake Interplanetary' },
			role = 'Fighter / Light Freight',
			career = 'Multi-role',
			size = 'medium',
		}, {}, {}, 'ship', false)
	)
end

function suite:testShortdescSingleSeatGravlev()
	-- crew==1 -> "single-seat" even for a gravlev (omitSize); type noun "grav-lev vehicle".
	self:assertEquals(
		'Single-seat racing grav-lev vehicle',
		Vehicle.formatShortDescription({ role = 'Racing', crew = { max = 1 } }, {}, {}, 'grav-lev vehicle', true)
	)
end

function suite:testEditorialModeOptIn()
	self:assertEquals(true, Vehicle.editorialMode)
end

function suite:testResolveSubtypeFamilyShipFromArgs()
	self:assertEquals(Ship, Vehicle.resolveSubtype({}, { family = 'ship' }))
end

function suite:testResolveSubtypeFamilyGroundFromArgs()
	self:assertEquals(GroundVehicle, Vehicle.resolveSubtype({}, { family = 'ground' }))
end

function suite:testResolveSubtypeFamilyGravlevFromArgs()
	self:assertEquals(Gravlev, Vehicle.resolveSubtype({}, { family = 'gravlev' }))
end

function suite:testResolveSubtypeApiFlagsBeatFamily()
	-- A genuine record's flags win even when |family= disagrees.
	self:assertEquals(Ship, Vehicle.resolveSubtype({ is_spaceship = true }, { family = 'ground' }))
end

function suite:testResolveSubtypeNilWhenNoFlagsNoFamily()
	self:assertEquals(nil, Vehicle.resolveSubtype({}, {}))
end

function suite:testEditorialModeShortDescription()
	-- Planned Hull E shape: no crew -> not single-seat; matrix size from |size=.
	self:assertEquals(
		'MISC large heavy freight ship',
		Vehicle.formatShortDescription(
			{},
			{ manufacturer = 'MISC', role = 'Heavy Freight', size = 'Large' },
			{},
			'ship',
			false
		)
	)
end

function suite:testEditorialModeCategoriesShip()
	-- apiData = {}: isShip must be derived from |family=, not API flags.
	local apiData = {}
	local args = { family = 'ship', manufacturer = 'MISC', size = 'Large', career = 'Transport' }
	local set = toSet(categoriesFor(apiData, args, {
		series = { value = 'Hull', source = 'editorial' },
		production_state = { value = 'In concept', source = 'override' },
	}))
	self:assertEquals(true, set['Large ships'])
	self:assertEquals(true, set['In concept'])
	self:assertEquals(true, set['Transport career'])
end

function suite:testEditorialModeCategoriesLoreOnly()
	-- Lore-only vehicles get the dedicated "Lore-only vehicles" browse category,
	-- not the plain state label. Both the canonical "Lore-only" and the legacy
	-- "In lore" value land in it.
	local apiData = {}
	local args = { family = 'ship', manufacturer = 'MISC', size = 'Large' }
	for _, value in ipairs({ 'Lore-only', 'In lore' }) do
		local set = toSet(categoriesFor(apiData, args, {
			production_state = { value = value, source = 'editorial' },
		}))
		self:assertEquals(true, set['Lore-only vehicles'])
		self:assertEquals(nil, set['Lore-only'])
		self:assertEquals(nil, set['In lore'])
	end
end

function suite:testEditorialModeCategoriesUnconfirmed()
	-- Unconfirmed vehicles get the dedicated "Unconfirmed vehicles" browse
	-- category, not the plain state label.
	local apiData = {}
	local args = { family = 'ship', manufacturer = 'MISC', size = 'Large' }
	local set = toSet(categoriesFor(apiData, args, {
		production_state = { value = 'Unconfirmed', source = 'editorial' },
	}))
	self:assertEquals(true, set['Unconfirmed vehicles'])
	self:assertEquals(nil, set['Unconfirmed'])
end

function suite:testEditorialModeSectionsNoError()
	-- getSections must not crash on apiData = {} and must resolve the family type.
	local s = Vehicle.getSections(ctx({}, { family = 'ship', manufacturer = 'MISC' }, {
		series = { value = 'Hull', source = 'editorial' },
	}))
	self:assertEquals('Spacecraft', findItem(findSection(s, 'overview').items, 'Type').content)
end

function suite:testFamilyTagsMatchDispatchTokens()
	-- p.family on each leaf must equal the family token that dispatches to it,
	-- so the leaf tag and VEHICLE_FAMILY_MAP can't drift apart.
	self:assertEquals(Ship, Vehicle.resolveSubtype({}, { family = Ship.family }))
	self:assertEquals(GroundVehicle, Vehicle.resolveSubtype({}, { family = GroundVehicle.family }))
	self:assertEquals(Gravlev, Vehicle.resolveSubtype({}, { family = Gravlev.family }))
end

function suite:testGetAcquisitionVehicle()
	local a = Vehicle.getAcquisition(
		ctx({ uex_prices = { purchase = { { price_buy = 500000 } }, rental = {} }, msrp = 200 }, {})
	)
	local byLabel = {}
	for _, r in ipairs(a.summary) do
		byLabel[r.label] = r.value
	end
	self:assertEquals(true, byLabel['Buy'])
	self:assertEquals(true, byLabel['Pledge'])
	self:assertEquals(2, #a.cards) -- Shops + Rentals
	self:assertEquals('No rental data in UEX', a.cards[2].description)
end

function suite:testStructuredDataStoresNewCohortStats()
	local data = Vehicle.getStructuredData(ctx({
		is_spaceship = true,
		shield_hp = 100000,
		weaponry = { pilot_dps = 4909.6 },
		speed = { scm = 190, max = 1000, zero_to_max = 17.36 },
	}, {}, {}))
	self:assertEquals(100000, data['Shield health point'])
	self:assertEquals(4909.6, data['Pilot DPS'])
	self:assertEquals(17.36, data['Zero to Maximum speed time'])
end

function suite:testStructuredDataNewStatsNilSafe()
	local data = Vehicle.getStructuredData(ctx({ is_spaceship = true }, {}, {}))
	self:assertEquals(nil, data['Shield health point'])
	self:assertEquals(nil, data['Pilot DPS'])
	self:assertEquals(nil, data['Zero to Maximum speed time'])
end

function suite:testStructuredDataStoresScoringStats()
	local data = Vehicle.getStructuredData(ctx({
		is_spaceship = true,
		weaponry = { pilot_dps = 4909.6, turret_dps = 2182.4, missiles = { damage = { total = 56600 } } },
		emission = { ir = 7441, em_max = 63969 },
		cross_section = { length = 100, width = 110, height = 120 },
		armor = { damage_physical = 0.75, damage_energy = 0.5 },
	}, {}, {}))
	self:assertEquals(2182.4, data['Turret DPS'])
	self:assertEquals(56600, data['Missile damage'])
	self:assertEquals(7441, data['Infrared emission'])
	self:assertEquals(63969, data['Electromagnetic emission'])
	self:assertEquals(110, data['Cross section']) -- mean of length/width/height (100,110,120)
	self:assertEquals(100, data['Cross section length']) -- raw per-axis (cohort ranks these)
	self:assertEquals(110, data['Cross section width'])
	self:assertEquals(120, data['Cross section height'])
	self:assertEquals(37.5, data['Armor resistance']) -- mean of (1-0.75)*100=25 and (1-0.5)*100=50
end

function suite:testStructuredDataScoringStatsNilSafe()
	local data = Vehicle.getStructuredData(ctx({ is_spaceship = true }, {}, {}))
	self:assertEquals(nil, data['Turret DPS'])
	self:assertEquals(nil, data['Infrared emission'])
	self:assertEquals(nil, data['Armor resistance'])
end

function suite:testStructuredDataSustainedDpsAndDeflection()
	local d = Vehicle.getStructuredData(ctx({
		weaponry = { pilot_sustained_dps = 1455.5, turret_sustained_dps = 200 },
		armor = { deflection = { physical = 11, energy = 9 } },
	}, {}, {}))
	self:assertEquals(1455.5, d['Pilot sustained DPS'])
	self:assertEquals(200, d['Turret sustained DPS'])
	self:assertEquals(10, d['Armor deflection'])
end

function suite:testStructuredDataStoresEstimatedPrices()
	-- Same estimate the infobox shows: median of the latest-patch UEX terminals.
	local d = Vehicle.getStructuredData(ctx({
		uex_prices = {
			purchase = { { price_buy = 1290370 }, { price_buy = 1358280 } },
			rental = { { price_rent = 27165 } },
		},
	}, {}, {}))
	self:assertEquals(1324325, d['Average purchase price']) -- median of the two terminals
	self:assertEquals(27165, d['Average rental price'])
end

function suite:testStructuredDataEstimatedPriceLatestPatchOnly()
	local d = Vehicle.getStructuredData(ctx({
		uex_prices = {
			purchase = {
				{ price_buy = 1000000, game_version = '4.8.2-LIVE.100' },
				{ price_buy = 5000000, game_version = '4.10.0-LIVE.100' },
			},
		},
	}, {}, {}))
	self:assertEquals(5000000, d['Average purchase price']) -- newest patch only
end

function suite:testStructuredDataEstimatedPricesNilSafe()
	local d = Vehicle.getStructuredData(ctx({}, {}, {}))
	self:assertEquals(nil, d['Average purchase price'])
	self:assertEquals(nil, d['Average rental price'])
end

function suite:testStructuredDataCapacityFields()
	local d = Vehicle.getStructuredData(ctx({
		ore_capacity = 32,
		cargo_limits = { max_scu_box = 16 },
		seating = { crew_stations = 12, beds = 7 },
		weapon_storage = { slots_total = 40 },
		max_medical_tier = 'T2',
	}, {}, {}))
	self:assertEquals(32, d['Ore capacity'])
	self:assertEquals(16, d['Maximum cargo container size'])
	self:assertEquals(12, d['Crew stations'])
	self:assertEquals(7, d['Beds'])
	self:assertEquals(40, d['Weapon rack capacity'])
	self:assertEquals(2, d['Medical bed tier'])
end

function suite:testStructuredDataCapacityFieldsAbsent()
	local d = Vehicle.getStructuredData(ctx({}, {}, {}))
	self:assertEquals(nil, d['Ore capacity'])
	self:assertEquals(nil, d['Maximum cargo container size'])
	self:assertEquals(nil, d['Crew stations'])
	self:assertEquals(nil, d['Beds'])
	self:assertEquals(nil, d['Weapon rack capacity'])
	self:assertEquals(nil, d['Medical bed tier'])
end

function suite:testKindCategoriesAreFamilyIndependent()
	-- The kind link contributes only what does not depend on the family; the
	-- leaf owns size and pledge.
	local cats = toSet(Vehicle.getCategories(ctx({ is_spaceship = true, size = 'large', msrp = 220 }, {}, {})))
	self:assertEquals(nil, cats['Large ships'])
	self:assertEquals(nil, cats['Pledge ships'])
	local leafCats = toSet(Ship.getCategories(ctx({ is_spaceship = true, size = 'large', msrp = 220 }, {}, {})))
	self:assertEquals(true, leafCats['Large ships'])
	self:assertEquals(true, leafCats['Pledge ships'])
end

function suite:testNoFamilyLeafMeansNoPledgeCategory()
	-- The pledge category is a family leaf's; a record-less page that resolves
	-- no leaf (no |family=, or an unmapped one) gets none.
	local resolved = { pledge_price = { value = 150, source = 'editorial' } }
	for _, args in ipairs({ {}, { family = 'hovercraft' } }) do
		local cats = toSet(categoriesFor({}, args, resolved))
		self:assertEquals(nil, cats['Pledge ships'])
		self:assertEquals(nil, cats['Pledge vehicles'])
	end
	self:assertEquals(true, toSet(categoriesFor({}, { family = 'ground' }, resolved))['Pledge vehicles'])
end

function suite:testResolveSubtypeFamilyArgIsNormalized()
	self:assertEquals(Ship, Vehicle.resolveSubtype({}, { family = ' Ship ' }))
end

-- Vehicle port trees carry cockpit panels and displays that are not
-- `collapsed` but do not belong in a component's L-tree; the kind asks the
-- Ports pipeline to narrow children. Items (Base default) keep the full tree.
function suite:testGetPortsNarrowsChildrenForEveryVehicleLeaf()
	local apiData = { ports = { { name = 'hardpoint' } } }
	for _, leaf in ipairs({ Vehicle, Ship, GroundVehicle, Gravlev }) do
		local payload =
			assembly.resolveMostSpecific(assembly.buildChain(leaf), 'getPorts', nil, { apiData = apiData, args = {} })
		self:assertEquals(apiData.ports, payload.ports)
		self:assertTrue(payload.narrowChildren)
	end
end

--- Run `fn(calls)` with Module:Entity/Store.selfValue replaced by a stub that
--- returns `result` and records each (displayName, kind) call in `calls`.
--- Always restores the real function (the runner never reloads modules), so
--- one failing test cannot poison the rest of the suite.
--- @param result any
--- @param fn fun(calls: table[])
local function withStubbedSelfValue(result, fn)
	local store = require('Module:Entity/Store')
	local realSelfValue = store.selfValue
	local calls = {}
	store.selfValue = function(displayName, kind)
		calls[#calls + 1] = { displayName, kind }
		return result
	end
	local ok, err = pcall(fn, calls)
	store.selfValue = realSelfValue
	if not ok then
		error(err, 0)
	end
end

function suite:testGetRelatedReturnsSeriesWhenPresent()
	local result = Vehicle.getRelated(ctx({}, {}, { series = { value = 'Avenger', source = 'editorial' } }))
	self:assertDeepEquals({ vehicleSeries = 'Avenger' }, result)
end

-- Editorial series wins outright: the Bucket fallback is not even consulted.
function suite:testGetRelatedDoesNotConsultStoreWhenSeriesPresent()
	withStubbedSelfValue('Constellation', function(calls)
		local result = Vehicle.getRelated(ctx({}, {}, { series = { value = 'Avenger', source = 'editorial' } }))
		self:assertDeepEquals({ vehicleSeries = 'Avenger' }, result)
		self:assertEquals(0, #calls)
	end)
end

function suite:testGetRelatedReadsSeriesFromStoreWhenEditorialSeriesEmpty()
	withStubbedSelfValue('Avenger', function(calls)
		local result = Vehicle.getRelated(ctx({}, {}, { series = { value = '', source = 'editorial' } }))
		self:assertDeepEquals({ vehicleSeries = 'Avenger' }, result)
		self:assertDeepEquals({ 'Series', 'Vehicle' }, calls[1])
	end)
end

-- nil (not an absent {}) so Entity/Related's acceptNonEmpty walk falls
-- through to Base's related_items payload instead of stopping here.
function suite:testGetRelatedReadsSeriesFromStoreWhenNoEditorialSeries()
	withStubbedSelfValue('Avenger', function(calls)
		local result = Vehicle.getRelated(ctx({}, {}, {}))
		self:assertDeepEquals({ vehicleSeries = 'Avenger' }, result)
		self:assertDeepEquals({ 'Series', 'Vehicle' }, calls[1])
	end)
end

function suite:testGetRelatedNilWhenSeriesEmptyAndStoreNil()
	withStubbedSelfValue(nil, function()
		self:assertEquals(nil, Vehicle.getRelated(ctx({}, {}, { series = { value = '', source = 'editorial' } })))
	end)
end

function suite:testGetRelatedNilWhenNoSeriesAndStoreNil()
	withStubbedSelfValue(nil, function()
		self:assertEquals(nil, Vehicle.getRelated(ctx({}, {}, {})))
	end)
end

-- Exercises the real dispatch (assembly.callHook), not a direct call, so a
-- module with an un-rewritten hook head fails here. getTypeInfo's body
-- ignores its params (routing check only); getCategories reads
-- apiData/args/resolved off ctx, so a positional head (ctx misrouted into its
-- first positional param) fails those assertions instead of silently passing.
function suite:testContextHooksDispatchViaAssemblyCallHook()
	local shipInfo = assembly.callHook(Ship, 'getTypeInfo', ctx({}))
	self:assertEquals('Spacecraft', shipInfo.name)
	local groundInfo = assembly.callHook(GroundVehicle, 'getTypeInfo', ctx({}))
	self:assertEquals('Ground vehicle', groundInfo.name)
	local gravlevInfo = assembly.callHook(Gravlev, 'getTypeInfo', ctx({}))
	self:assertEquals('Grav-lev vehicle', gravlevInfo.name)
	local vehicleCats = assembly.callHook(Vehicle, 'getCategories', ctx({ production_status = 'flight-ready' }, {}, {}))
	self:assertEquals(true, toSet(vehicleCats)['Flight ready'])
	local shipCats = assembly.callHook(Ship, 'getCategories', ctx({ size = 'large', msrp = 100 }, {}, {}))
	self:assertEquals(true, toSet(shipCats)['Large ships'])
	local groundCats = assembly.callHook(GroundVehicle, 'getCategories', ctx({ msrp = 100 }, {}, {}))
	self:assertEquals('Pledge vehicles', groundCats[1])
	local gravlevCats = assembly.callHook(Gravlev, 'getCategories', ctx({ msrp = 100 }, {}, {}))
	self:assertEquals('Pledge vehicles', gravlevCats[1])
end

return suite
