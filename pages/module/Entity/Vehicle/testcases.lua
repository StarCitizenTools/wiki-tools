require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local ProductionStatus = require('Module:Entity/ProductionStatus')
local Vehicle = require('Module:Entity/Vehicle')
local Ship = require('Module:Entity/Vehicle/Ship')
local GroundVehicle = require('Module:Entity/Vehicle/GroundVehicle')
local Gravlev = require('Module:Entity/Vehicle/Gravlev')

local suite = ScribuntoUnit:new()

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
	local s = Vehicle.getSections({
		is_spaceship = true,
		career = 'Combat',
		role = 'Light Fighter',
		size = 'small',
		crew = { min = 1, max = 1 },
		cargo_capacity = 3,
		speed = { scm = 227, max = 1230 },
		agility = { roll = 137, pitch = 59, yaw = 51 },
	}, {}, {})
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
	local s = Vehicle.getSections({ is_spaceship = true }, {}, { series = { value = 'Avenger', source = 'editorial' } })
	self:assertEquals('Avenger', findItem(findSection(s, 'overview').items, 'Model').content)
end

function suite:testOverviewModelOmittedWhenNoSeries()
	local s = Vehicle.getSections({ is_spaceship = true }, {}, {})
	self:assertEquals(nil, findItem(findSection(s, 'overview').items, 'Model'))
end

function suite:testCareerWikiParamWinsOverApi()
	-- wiki `career` param wins over the API value (curated taxonomy).
	local s = Vehicle.getSections({ is_spaceship = true, career = 'Transporter' }, { career = 'Transport' }, {})
	self:assertEquals(
		'[[:Category:Transport career|Transport]]',
		findItem(findSection(s, 'overview').items, 'Career').content
	)
end

function suite:testRoleWikiParamWinsOverApi()
	-- wiki `role` param wins over the API in the Role row (curated taxonomy, like Career).
	local s = Vehicle.getSections({ is_spaceship = true, role = 'Light Fighter' }, { role = 'Heavy Fighter' }, {})
	self:assertEquals('Heavy Fighter', findItem(findSection(s, 'overview').items, 'Role').content)
end

function suite:testRoleFromApiWhenNoArg()
	-- with no wiki override, the Role row shows the API role.
	local s = Vehicle.getSections({ is_spaceship = true, role = 'Light Fighter' }, {}, {})
	self:assertEquals('Light Fighter', findItem(findSection(s, 'overview').items, 'Role').content)
end

function suite:testGroundVehicleSpeedUsesDrive()
	local s = Vehicle.getSections({
		crew = { min = 1, max = 2 },
		cargo_capacity = 1,
		speed = { scm = nil, max = nil },
		agility = { roll = nil, pitch = nil, yaw = nil },
		drive = { max_speed_ms = 36, reverse_speed_ms = 13.558441 },
	}, {}, {})
	local mobility = findItem(findSection(s, 'stats').sections, 'Mobility')
	self:assertEquals(nil, findItem(mobility.items, 'SCM speed'))
	self:assertEquals('14 m/s', findItem(mobility.items, 'Reverse speed').content)
	self:assertEquals(nil, findItem(mobility.items, 'Roll rate'))
	local travel = findItem(findSection(s, 'stats').sections, 'Travel')
	self:assertEquals('36 m/s', findItem(travel.items, 'Max speed').content)
end

function suite:testCapacityCrewRangeAndCargo()
	local s = Vehicle.getSections({ crew = { min = 1, max = 3 }, cargo_capacity = 96 }, {}, {})
	local cap = findSection(s, 'capacity')
	self:assertEquals('1\226\128\1473', findItem(cap.items, 'Crew').content)
	self:assertEquals('96 SCU', findItem(cap.items, 'Cargo').content)
end

function suite:testCapacityInventory()
	local s = Vehicle.getSections({ vehicle_inventory = 1620000 }, {}, {})
	local cap = findSection(s, 'capacity')
	self:assertEquals('1,620,000 µSCU', findItem(cap.items, 'Inventory').content)
end

function suite:testEditorialOverrideFlowsIntoSpeed()
	local s = Vehicle.getSections({ speed = { scm = 227 } }, {}, { scm_speed = { value = 210, source = 'override' } })
	local mobility = findItem(findSection(s, 'stats').sections, 'Mobility')
	self:assertEquals('210 m/s', findItem(mobility.items, 'SCM speed').content)
end

function suite:testEmptyApiOmitsSections()
	local s = Vehicle.getSections({}, {}, {})
	self:assertEquals(nil, findSection(s, 'stats'))
	self:assertEquals(nil, findSection(s, 'capacity'))
end

function suite:testGetSubtitleReturnsManufacturerLink()
	-- args.manufacturer 'Testco' doesn't resolve, so Base falls back to a
	-- self-referencing record (page == name) → a plain [[Testco]] link.
	self:assertEquals('[[Testco]]', Vehicle.getSubtitle({}, { manufacturer = 'Testco' }))
end

function suite:testGetSubtitleNilWhenNoManufacturer()
	self:assertEquals(nil, Vehicle.getSubtitle({}, {}))
end

function suite:testEditorialManifestLoads()
	local m = Vehicle.getEditorialManifest()
	self:assertEquals('msrp', m.pledge_price.apiPath)
	self:assertEquals('speed.scm', m.scm_speed.apiPath)
	self:assertEquals('Pledge availability', m.pledge_availability.smw)
end

function suite:testStructuredDataPureApiStats()
	local d = Vehicle.getStructuredData(
		{ career = 'Combat', role = 'Light Fighter', size_class = 2, agility = { roll = 137, pitch = 59, yaw = 51 } },
		{},
		{}
	)
	self:assertEquals('Combat', d['Career'])
	self:assertEquals(2, d['Size'])
	self:assertEquals(137, d['Roll rate'])
end

function suite:testStructuredDataRoleWikiParamWins()
	-- the stored Role property honors the wiki `role` override (matches the Role row + short desc).
	local d = Vehicle.getStructuredData({ role = 'Light Fighter' }, { role = 'Heavy Fighter' }, {})
	self:assertEquals('Heavy Fighter', d['Role'])
end

function suite:testStructuredDataRoleFromApiWhenNoArg()
	local d = Vehicle.getStructuredData({ role = 'Light Fighter' }, {}, {})
	self:assertEquals('Light Fighter', d['Role'])
end

function suite:testStructuredDataOmitsManifestOwnedFields()
	-- crew/cargo/speed/mass/pledge are owned by the editorial layer, NOT getStructuredData
	local d = Vehicle.getStructuredData(
		{ crew = { min = 1, max = 3 }, cargo_capacity = 96, speed = { scm = 227 }, mass = 26245, msrp = 30 },
		{},
		{}
	)
	self:assertEquals(nil, d['Minimum crew'])
	self:assertEquals(nil, d['Cargo capacity'])
	self:assertEquals(nil, d['Scm speed'])
	self:assertEquals(nil, d['Pledge price'])
end

function suite:testStructuredDataDropsNilAgility()
	local d = Vehicle.getStructuredData({ agility = { roll = nil, pitch = nil, yaw = nil } }, {}, {})
	self:assertEquals(nil, d['Roll rate'])
end

-- The headless runner supports mw.getCurrentFrame():extensionTag (PASS in probe),
-- so we can test the full badge path end-to-end.
function suite:testHeaderBadgeNilWhenNoState()
	self:assertEquals(nil, Vehicle.getHeaderBadge({}, {}, {}))
	self:assertEquals(nil, Vehicle.getHeaderBadge({ production_status = 'made up' }, {}, {}))
end

function suite:testHeaderBadgeFromApiData()
	-- badge() calls extensionTag; runner supports it → returns a string
	local result = Vehicle.getHeaderBadge({ production_status = 'flight-ready' }, {}, {})
	self:assertEquals(true, type(result) == 'string')
end

function suite:testHeaderBadgeEditorialOverrideBeatsApi()
	-- editorial override (production_state.value) takes priority over apiData.production_status
	local resolved = { production_state = { value = 'In concept', source = 'override' } }
	local result = Vehicle.getHeaderBadge({ production_status = 'flight-ready' }, {}, resolved)
	self:assertEquals(true, type(result) == 'string')
	-- The badge text should contain the overridden label, not the API one
	self:assertEquals(true, result:find('In concept') ~= nil)
end

function suite:testHeaderBadgeNilOverrideResolvesToApi()
	-- resolved with no production_state falls through to apiData
	local result = Vehicle.getHeaderBadge({ production_status = 'in-production' }, {}, {})
	self:assertEquals(true, type(result) == 'string')
end

function suite:testProductionStatusResolvesOverrideAndApiForms()
	self:assertEquals('In concept', ProductionStatus._internal.resolve('In concept').label)
	self:assertEquals('Flight ready', ProductionStatus._internal.resolve('flight-ready').label)
end

function suite:testCostUniverseBuyShowsEstimatedPrice()
	-- Buy row shows the estimated (median) UEC price; rental with only a zero price is "No".
	local s = Vehicle.getSections({
		uex_prices = { purchase = { { price_buy = 500000 } }, rental = { { price_rent = 0 } } },
	}, {}, {})
	local universe = findItem(findSection(s, 'cost').sections, 'Universe')
	-- Relabelled Buy/Rent (was Buyable/Rentable).
	self:assertEquals(nil, findItem(universe.items, 'Buyable'))
	local buy = findItem(universe.items, 'Buy').content
	self:assertEquals('~', buy:sub(1, 1)) -- estimate marker
	self:assertTrue(buy:find('500,000', 1, true) ~= nil) -- UEC-formatted price
	self:assertTrue(buy:find('aUEC', 1, true) == nil) -- formatted via Module:UEC, no bare unit
	-- Rental has an entry but no non-zero price → definitively No (not Unknown).
	self:assertEquals('No', findItem(universe.items, 'Rent').content)
end

function suite:testCostUniverseBuyPriceIsMedianAcrossTerminals()
	-- Three terminals, same patch → median of buy prices (not min/max/mean-of-extremes).
	local s = Vehicle.getSections({
		uex_prices = {
			purchase = { { price_buy = 1000000 }, { price_buy = 2000000 }, { price_buy = 3000000 } },
		},
	}, {}, {})
	local buy = findItem(findItem(findSection(s, 'cost').sections, 'Universe').items, 'Buy').content
	self:assertTrue(buy:find('2,000,000', 1, true) ~= nil)
	self:assertTrue(buy:find('1,000,000', 1, true) == nil)
	self:assertTrue(buy:find('3,000,000', 1, true) == nil)
end

function suite:testCostUniverseRentShowsEstimatedPrice()
	local s = Vehicle.getSections({
		uex_prices = { rental = { { price_rent = 27000 }, { price_rent = 27000 }, { price_rent = 30000 } } },
	}, {}, {})
	local rent = findItem(findItem(findSection(s, 'cost').sections, 'Universe').items, 'Rent').content
	self:assertEquals('~', rent:sub(1, 1))
	self:assertTrue(rent:find('27,000', 1, true) ~= nil) -- median of 27k, 27k, 30k
end

function suite:testCostUniversePriceUsesLatestPatchOnly()
	-- Older-patch terminal is excluded; median is taken over the newest game_version only.
	local s = Vehicle.getSections({
		uex_prices = {
			purchase = {
				{ price_buy = 1000000, game_version = '4.8.2-LIVE.100' },
				{ price_buy = 2000000, game_version = '4.9.0-LIVE.200' },
				{ price_buy = 4000000, game_version = '4.9.0-LIVE.200' },
			},
		},
	}, {}, {})
	local buy = findItem(findItem(findSection(s, 'cost').sections, 'Universe').items, 'Buy').content
	self:assertTrue(buy:find('3,000,000', 1, true) ~= nil) -- median of 2M, 4M (latest patch)
	self:assertTrue(buy:find('1,000,000', 1, true) == nil) -- older patch dropped
end

function suite:testCostUniverseLatestPatchHandlesMinorVersionRollover()
	-- 4.10 is newer than 4.8 despite a smaller build suffix: versions compare numerically
	-- component-wise, not lexicographically (where "4.8" > "4.10").
	local s = Vehicle.getSections({
		uex_prices = {
			purchase = {
				{ price_buy = 1000000, game_version = '4.8.2-LIVE.999' },
				{ price_buy = 5000000, game_version = '4.10.0-LIVE.100' },
			},
		},
	}, {}, {})
	local buy = findItem(findItem(findSection(s, 'cost').sections, 'Universe').items, 'Buy').content
	self:assertTrue(buy:find('5,000,000', 1, true) ~= nil)
	self:assertTrue(buy:find('1,000,000', 1, true) == nil)
end

function suite:testCostUniverseSkipsZeroPrices()
	local s = Vehicle.getSections({
		uex_prices = { purchase = { { price_buy = 0 }, { price_buy = 2000000 } } },
	}, {}, {})
	local buy = findItem(findItem(findSection(s, 'cost').sections, 'Universe').items, 'Buy').content
	self:assertTrue(buy:find('2,000,000', 1, true) ~= nil)
end

function suite:testCostUniverseEvenTerminalCountAveragesMiddlePair()
	local s = Vehicle.getSections({
		uex_prices = { purchase = { { price_buy = 1000000 }, { price_buy = 2000002 } } },
	}, {}, {})
	local buy = findItem(findItem(findSection(s, 'cost').sections, 'Universe').items, 'Buy').content
	self:assertTrue(buy:find('1,500,001', 1, true) ~= nil) -- median = (1,000,000 + 2,000,002) / 2
end

function suite:testCostUniverseCanBuyOverrideNoBeatsPrice()
	-- canBuy=no asserts "not buyable" even when UEX has a price → No, no number. canBuy is the
	-- canonical casing shared with {{Entity/Availability}} (the same arg getAcquisition reads).
	local s = Vehicle.getSections({
		uex_prices = { purchase = { { price_buy = 2000000 } } },
	}, { canBuy = 'no' }, {})
	local buy = findItem(findItem(findSection(s, 'cost').sections, 'Universe').items, 'Buy').content
	self:assertEquals('No', buy)
end

function suite:testCostUniverseCanBuyOverrideYesNoData()
	-- canBuy=yes with no UEX data → Yes (no price to show)
	local s = Vehicle.getSections({ uex_prices = {} }, { canBuy = 'yes' }, {})
	local buy = findItem(findItem(findSection(s, 'cost').sections, 'Universe').items, 'Buy').content
	self:assertEquals('Yes', buy)
end

function suite:testCostUniverseCanRentOverrideNo()
	-- canRent=no asserts "not rentable" even with a rental price → No (camelCase, shared casing).
	local s = Vehicle.getSections({
		uex_prices = { rental = { { price_rent = 27000 } } },
	}, { canRent = 'no' }, {})
	local rent = findItem(findItem(findSection(s, 'cost').sections, 'Universe').items, 'Rent').content
	self:assertEquals('No', rent)
end

function suite:testCostUniverseFlightReadyNoDataIsNo()
	-- flight-ready ship, no UEX data: Universe stays, Buy/Rent = No (in-game → definitive)
	local s = Vehicle.getSections({ production_status = 'flight-ready', uex_prices = {} }, {}, {})
	local universe = findItem(findSection(s, 'cost').sections, 'Universe')
	self:assertEquals('No', findItem(universe.items, 'Buy').content)
	self:assertEquals('No', findItem(universe.items, 'Rent').content)
end

function suite:testCostUniverseUnreleasedNoDataDrops()
	-- unreleased ship, no UEX, no override → Unknown → Universe dropped (Pledge still shows)
	local s = Vehicle.getSections({ production_status = 'in-concept', msrp = 30, uex_prices = {} }, {}, {})
	local cost = findSection(s, 'cost')
	self:assertEquals(nil, findItem(cost.sections, 'Universe'))
	self:assertEquals('$30', findItem(findItem(cost.sections, 'Pledge').items, 'Standalone').content)
end

function suite:testCostPledgeUsesMsrp()
	local s = Vehicle.getSections({ msrp = 30 }, {}, {})
	local pledge = findItem(findSection(s, 'cost').sections, 'Pledge')
	self:assertEquals('$30', findItem(pledge.items, 'Standalone').content)
end

function suite:testCostPledgeShowsOriginalWhenDiffers()
	local s = Vehicle.getSections({ msrp = 30 }, {}, { original_pledge_price = { value = 45, source = 'editorial' } })
	local pledge = findItem(findSection(s, 'cost').sections, 'Pledge')
	self:assertEquals('$30 (was $45)', findItem(pledge.items, 'Standalone').content)
end

function suite:testCostInsurance()
	local s = Vehicle.getSections({ insurance = { claim_time = 2.92, expedite_cost = 1631 } }, {}, {})
	local ins = findItem(findSection(s, 'cost').sections, 'Insurance')
	-- Expedite fee renders via Module:UEC (glyph + grouped number), not a bare unit.
	local fee = findItem(ins.items, 'Expedite fee').content
	self:assertTrue(fee ~= nil and fee:find('1,631', 1, true) ~= nil)
end

function suite:testCostOmittedWhenNoData()
	self:assertEquals(nil, findSection(Vehicle.getSections({}, {}, {}), 'cost'))
end

function suite:testPledgeLoanerShownForConcept()
	local s = Vehicle.getSections(
		{ production_status = 'in-concept', loaner = { { name = 'C2 Hercules' }, { name = 'Syulen' } } },
		{},
		{}
	)
	local pledge = findItem(findSection(s, 'cost').sections, 'Pledge')
	self:assertEquals('[[C2 Hercules]], [[Syulen]]', findItem(pledge.items, 'Loaner').content)
end

function suite:testPledgeLoanerSuppressedForFlightReady()
	local s = Vehicle.getSections(
		{ msrp = 30, production_status = 'flight-ready', loaner = { { name = 'C2 Hercules' } } },
		{},
		{}
	)
	local pledge = findItem(findSection(s, 'cost').sections, 'Pledge')
	self:assertEquals('$30', findItem(pledge.items, 'Standalone').content)
	self:assertEquals(nil, findItem(pledge.items, 'Loaner'))
end

function suite:testStructuredDataInsurance()
	local d = Vehicle.getStructuredData({ insurance = { claim_time = 2.92, expedite_cost = 1631 } }, {}, {})
	self:assertEquals(2.92, d['Insurance claim time'])
	self:assertEquals(1631, d['Insurance expedite cost'])
end

function suite:testDimensionsSectionPresent()
	local s = Vehicle.getSections({ dimension = { length = 19, width = 8.75, height = 4.5 }, mass = 26245 }, {}, {})
	local d = findSection(s, 'dimensions')
	self:assertEquals('dimensions', d.key)
	self:assertEquals(true, type(d.content) == 'string' and #d.content > 0)
end

function suite:testDimensionsOmittedWhenAbsent()
	self:assertEquals(nil, findSection(Vehicle.getSections({}, {}, {}), 'dimensions'))
end

function suite:testDimensionsOmittedWhenIncomplete()
	-- missing height → no box
	self:assertEquals(
		nil,
		findSection(Vehicle.getSections({ dimension = { length = 19, width = 8.75 } }, {}, {}), 'dimensions')
	)
end

function suite:testDimensionsFromEditorial()
	-- Planned/concept vehicle: no apiData.dimension; length/width/height/mass come
	-- from editorial args, so the Dimensions box still renders (editorial-first).
	local s = Vehicle.getSections({}, { family = 'ship' }, {
		length = { value = 372, source = 'editorial' },
		width = { value = 104, source = 'editorial' },
		height = { value = 104, source = 'editorial' },
		mass = { value = 1652000, source = 'editorial' },
	})
	local d = findSection(s, 'dimensions')
	self:assertEquals('dimensions', d.key)
	self:assertEquals(true, type(d.content) == 'string' and #d.content > 0)
end

function suite:testStatsMobilityTabHasSpeed()
	local s = Vehicle.getSections({ is_spaceship = true, speed = { scm = 227, max = 1230 } }, {}, {})
	local mobility = findItem(findSection(s, 'stats').sections, 'Mobility')
	self:assertEquals('227 m/s', findItem(mobility.items, 'SCM speed').content)
end

function suite:testDefenseAndStealthTabs()
	local s = Vehicle.getSections({
		health = 6110,
		shield_hp = 6336,
		armor = { damage_physical = 0.75, signal_infrared = 1.13, signal_electromagnetic = 1 },
	}, {}, {})
	local defense = findItem(findSection(s, 'stats').sections, 'Defense')
	self:assertEquals('6,110 HP', findItem(defense.items, 'Hull').content)
	self:assertEquals('6,336 HP', findItem(defense.items, 'Shield').content)
	local stealth = findItem(findSection(s, 'stats').sections, 'Stealth')
	self:assertTrue(findItem(stealth.items, 'IR modifier').content:find('+13%', 1, true) ~= nil)
	self:assertEquals(nil, findItem(stealth.items, 'EM modifier')) -- multiplier 1.0 omitted
end

function suite:testHullResistanceTileBlock()
	-- ProgressTiles is stubbed in the runner (returns ''), so assert only that the
	-- block item is present (label-less, string content, block CSS class).
	local s = Vehicle.getSections({ armor = { damage_physical = 0.75 } }, {}, {})
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
	local d = Vehicle.getStructuredData({ health = 6110, armor = { damage_physical = 0.75 } }, {}, {})
	self:assertEquals(6110, d['Health point'])
	self:assertEquals(0.75, d['Physical damage modifier'])
end

function suite:testFuelHydrogenAndQuantumTabs()
	local s = Vehicle.getSections({
		fuel = { capacity = 13.5 },
		quantum = { quantum_speed = 190000000, quantum_range = 69817400644, quantum_spool_time = 4 },
	}, {}, {})
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
	local s = Vehicle.getSections({ speed = { scm = 227 } }, {}, {})
	local stats = findSection(s, 'stats')
	self:assertEquals(nil, findItem(stats.sections, 'Travel'))
	self:assertEquals(true, findItem(stats.sections, 'Mobility') ~= nil)
end

function suite:testNoFuelSection()
	-- Fuel no longer renders as its own top-level section.
	local s = Vehicle.getSections({ fuel = { capacity = 13.5 } }, {}, {})
	self:assertEquals(nil, findSection(s, 'fuel'))
end

function suite:testStructuredDataFuelQuantumCommunityUnits()
	local d = Vehicle.getStructuredData({
		fuel = { capacity = 13.5 },
		quantum = { quantum_speed = 190000000, quantum_range = 70000000000 },
	}, {}, {})
	self:assertEquals(13.5, d['Hydrogen fuel capacity'])
	self:assertEquals(190, d['Quantum speed']) -- Mm/s, not raw
	self:assertEquals(70, d['Quantum range']) -- Gm
end

function suite:testLoreAndDevelopmentSections()
	local s = Vehicle.getSections({}, {}, {
		release_date = { value = '2772', source = 'editorial' },
		concept_sale = { value = '2021-06-05', source = 'editorial' },
	})
	self:assertEquals('2772', findItem(findSection(s, 'lore').items, 'Released').content)
	self:assertEquals('2021-06-05', findItem(findSection(s, 'development').items, 'Concept sale').content)
	self:assertEquals(nil, findItem(findSection(s, 'lore').items, 'Retired')) -- absent → dropped
end

function suite:testLoreDevelopmentOmittedWhenNoDates()
	local s = Vehicle.getSections({}, {}, {})
	self:assertEquals(nil, findSection(s, 'lore'))
	self:assertEquals(nil, findSection(s, 'development'))
end

function suite:testEditorialManifestDatesPureEditorial()
	local m = Vehicle.getEditorialManifest()
	self:assertEquals('Lore release date', m.release_date.smw)
	self:assertEquals(nil, m.release_date.apiPath)
end

function suite:testExternalOfficialAndCommunity()
	local items = Vehicle.getExternalSiteItems(
		{ pledge_url = 'https://rsi/pledge', class_name = 'AEGS_Gladius', uuid = 'ABC', shipmatrix_name = 'Gladius' },
		{ brochureurl = 'https://b' }
	)
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
	local items = Vehicle.getExternalSiteItems({}, {
		presentationurl = 'https://p1; https://p2',
		qaurl = 'https://qa1',
	})
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
	self:assertEquals(0, #Vehicle.getExternalSiteItems({}, {}))
end

function suite:testSizeDisplayMatrixAndClass()
	local s = Vehicle.getSections({ is_spaceship = true, size = 'medium', size_class = 3 }, {}, {})
	self:assertEquals('Medium (S3)', findItem(findSection(s, 'overview').items, 'Size').content)
end

function suite:testSizeDisplayMatrixOnly()
	local s = Vehicle.getSections({ is_spaceship = true, size = 'large' }, {}, {})
	self:assertEquals('Large', findItem(findSection(s, 'overview').items, 'Size').content)
end

function suite:testSizeDisplayClassOnly()
	local s = Vehicle.getSections({ is_spaceship = true, size_class = 2 }, {}, {})
	self:assertEquals('S2', findItem(findSection(s, 'overview').items, 'Size').content)
end

function suite:testSizeDisplayArgOverridesApi()
	-- |size= (wiki) wins over the API matrix size (Railen: editorially Large, API medium).
	local s = Vehicle.getSections({ is_spaceship = true, size = 'medium', size_class = 5 }, { size = 'Large' }, {})
	self:assertEquals('Large (S5)', findItem(findSection(s, 'overview').items, 'Size').content)
end

function suite:testCategoriesSizeFromArg()
	local apiData, args = { is_spaceship = true, size = 'medium' }, { size = 'Large' }
	local cats = Vehicle.getCategories(
		apiData,
		args,
		{},
		(function()
			local s = Vehicle.resolveSubtype(apiData, args)
			return s and s.family
		end)()
	)
	local set = {}
	for _, c in ipairs(cats) do
		set[c] = true
	end
	self:assertEquals(true, set['Large ships'])
	self:assertEquals(nil, set['Medium ships'])
end

function suite:testSizeDisplayNilWhenNeither()
	local s = Vehicle.getSections({ is_spaceship = true }, {}, {})
	self:assertEquals(nil, findItem(findSection(s, 'overview').items, 'Size'))
end

function suite:testModelAppendsGeneration()
	local s = Vehicle.getSections({ is_spaceship = true }, {}, {
		series = { value = 'Avenger', source = 'editorial' },
		generation = { value = 'II', source = 'editorial' },
	})
	local model = findItem(findSection(s, 'overview').items, 'Model').content
	self:assertTrue(model:find('Avenger', 1, true) ~= nil)
	self:assertTrue(model:find('[[:Category:Avenger II|II]]', 1, true) ~= nil)
end

function suite:testModelNoGenerationWhenAbsent()
	local s = Vehicle.getSections({ is_spaceship = true }, {}, {
		series = { value = 'Avenger', source = 'editorial' },
	})
	local model = findItem(findSection(s, 'overview').items, 'Model').content
	self:assertTrue(model:find('generation', 1, true) == nil)
end

function suite:testHeaderBadgeStillStringForKnownState()
	self:assertEquals(true, type(Vehicle.getHeaderBadge({ production_status = 'flight-ready' }, {}, {})) == 'string')
	self:assertEquals(nil, Vehicle.getHeaderBadge({ production_status = 'made up' }, {}, {}))
end

function suite:testHeaderBadgeIgnoresProductionNote()
	-- Tooltip removed: production_note no longer affects the header badge.
	local withNote = Vehicle.getHeaderBadge({ production_status = 'in-concept', production_note = 'Delayed' }, {}, {})
	local without = Vehicle.getHeaderBadge({ production_status = 'in-concept' }, {}, {})
	self:assertEquals(without, withNote)
end

function suite:testEditorialManifestHasGeneration()
	local m = Vehicle.getEditorialManifest()
	-- arg is the alias list (legacy [ARG_Generation, ARG_mark]; pages also write |Generation=).
	self:assertEquals('generation', m.generation.arg[1])
	self:assertEquals('Generation', m.generation.arg[2])
	self:assertEquals('mark', m.generation.arg[3])
	self:assertEquals('Generation', m.generation.smw)
	self:assertEquals(nil, m.generation.apiPath)
end

function suite:testCategoriesGenerationGrouping()
	-- "<series> <generation>" (legacy category_generation "%s %s"), e.g. "Constellation Mk4".
	local apiData, args = { is_spaceship = true }, {}
	local cats = Vehicle.getCategories(
		apiData,
		args,
		{
			series = { value = 'Constellation', source = 'editorial' },
			generation = { value = 'Mk4', source = 'editorial' },
		},
		(function()
			local s = Vehicle.resolveSubtype(apiData, args)
			return s and s.family
		end)()
	)
	local set = {}
	for _, c in ipairs(cats) do
		set[c] = true
	end
	self:assertEquals(true, set['Constellation Mk4'])
end

function suite:testCategoriesShip()
	-- Pass args.manufacturer so resolveManufacturer returns a fallback record with
	-- name == 'Gatac Manufacture', enabling the manufacturer+series category.
	local apiData = { is_spaceship = true, size = 'large', msrp = 220, production_status = 'flight-ready' }
	local args = { career = 'Transport', manufacturer = 'Gatac Manufacture' }
	local cats = Vehicle.getCategories(
		apiData,
		args,
		{ series = { value = 'Railen', source = 'editorial' } },
		(function()
			local s = Vehicle.resolveSubtype(apiData, args)
			return s and s.family
		end)()
	)
	local set = {}
	for _, c in ipairs(cats) do
		set[c] = true
	end
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
	local cats = Vehicle.getCategories(
		apiData,
		args,
		{},
		(function()
			local s = Vehicle.resolveSubtype(apiData, args)
			return s and s.family
		end)()
	)
	local set = {}
	for _, c in ipairs(cats) do
		set[c] = true
	end
	self:assertEquals(nil, set['Small ships']) -- size category is ships-only
	self:assertEquals(true, set['Pledge vehicles']) -- ground uses "Pledge vehicles"
end

function suite:testCategoriesNoPledgeNoSeries()
	local apiData, args = { is_spaceship = true, size = 'large' }, {}
	local cats = Vehicle.getCategories(
		apiData,
		args,
		{},
		(function()
			local s = Vehicle.resolveSubtype(apiData, args)
			return s and s.family
		end)()
	)
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
	local cats = Vehicle.getCategories(
		apiData,
		args,
		{
			series = { value = 'Hull', source = 'editorial' },
			production_state = { value = 'In concept', source = 'override' },
		},
		(function()
			local s = Vehicle.resolveSubtype(apiData, args)
			return s and s.family
		end)()
	)
	local set = {}
	for _, c in ipairs(cats) do
		set[c] = true
	end
	self:assertEquals(true, set['Large ships'])
	self:assertEquals(true, set['In concept'])
	self:assertEquals(true, set['Transport career'])
end

function suite:testEditorialModeSectionsNoError()
	-- getSections must not crash on apiData = {} and must resolve the family type.
	local s = Vehicle.getSections({}, { family = 'ship', manufacturer = 'MISC' }, {
		series = { value = 'Hull', source = 'editorial' },
	})
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
		{ uex_prices = { purchase = { { price_buy = 500000 } }, rental = {} }, msrp = 200 },
		{}
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
	local data = Vehicle.getStructuredData({
		is_spaceship = true,
		shield_hp = 100000,
		weaponry = { pilot_dps = 4909.6 },
		speed = { scm = 190, max = 1000, zero_to_max = 17.36 },
	}, {}, {})
	self:assertEquals(100000, data['Shield health point'])
	self:assertEquals(4909.6, data['Pilot DPS'])
	self:assertEquals(17.36, data['Zero to Maximum speed time'])
end

function suite:testStructuredDataNewStatsNilSafe()
	local data = Vehicle.getStructuredData({ is_spaceship = true }, {}, {})
	self:assertEquals(nil, data['Shield health point'])
	self:assertEquals(nil, data['Pilot DPS'])
	self:assertEquals(nil, data['Zero to Maximum speed time'])
end

function suite:testStructuredDataStoresScoringStats()
	local data = Vehicle.getStructuredData({
		is_spaceship = true,
		weaponry = { pilot_dps = 4909.6, turret_dps = 2182.4, missiles = { damage = { total = 56600 } } },
		emission = { ir = 7441, em_max = 63969 },
		cross_section = { length = 100, width = 110, height = 120 },
		armor = { damage_physical = 0.75, damage_energy = 0.5 },
	}, {}, {})
	self:assertEquals(2182.4, data['Turret DPS'])
	self:assertEquals(56600, data['Missile damage'])
	self:assertEquals(7441, data['Infrared emission'])
	self:assertEquals(63969, data['Electromagnetic emission'])
	self:assertEquals(110, data['Cross section']) -- mean of length/width/height (100,110,120)
	self:assertEquals(37.5, data['Armor resistance']) -- mean of (1-0.75)*100=25 and (1-0.5)*100=50
end

function suite:testStructuredDataScoringStatsNilSafe()
	local data = Vehicle.getStructuredData({ is_spaceship = true }, {}, {})
	self:assertEquals(nil, data['Turret DPS'])
	self:assertEquals(nil, data['Infrared emission'])
	self:assertEquals(nil, data['Armor resistance'])
end

function suite:testStructuredDataSustainedDpsAndDeflection()
	local d = Vehicle.getStructuredData({
		weaponry = { pilot_sustained_dps = 1455.5, turret_sustained_dps = 200 },
		armor = { deflection = { physical = 11, energy = 9 } },
	}, {}, {})
	self:assertEquals(1455.5, d['Pilot sustained DPS'])
	self:assertEquals(200, d['Turret sustained DPS'])
	self:assertEquals(10, d['Armor deflection'])
end

function suite:testStructuredDataStoresEstimatedPrices()
	-- Same estimate the infobox shows: median of the latest-patch UEX terminals.
	local d = Vehicle.getStructuredData({
		uex_prices = {
			purchase = { { price_buy = 1290370 }, { price_buy = 1358280 } },
			rental = { { price_rent = 27165 } },
		},
	}, {}, {})
	self:assertEquals(1324325, d['Average purchase price']) -- median of the two terminals
	self:assertEquals(27165, d['Average rental price'])
end

function suite:testStructuredDataEstimatedPriceLatestPatchOnly()
	local d = Vehicle.getStructuredData({
		uex_prices = {
			purchase = {
				{ price_buy = 1000000, game_version = '4.8.2-LIVE.100' },
				{ price_buy = 5000000, game_version = '4.10.0-LIVE.100' },
			},
		},
	}, {}, {})
	self:assertEquals(5000000, d['Average purchase price']) -- newest patch only
end

function suite:testStructuredDataEstimatedPricesNilSafe()
	local d = Vehicle.getStructuredData({}, {}, {})
	self:assertEquals(nil, d['Average purchase price'])
	self:assertEquals(nil, d['Average rental price'])
end

return suite
