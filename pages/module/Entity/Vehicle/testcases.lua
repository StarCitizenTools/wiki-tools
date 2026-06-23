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
	local sp = findSection(s, 'speed')
	self:assertEquals('227 m/s', findItem(sp.items, 'SCM speed').content)
	self:assertEquals('1,230 m/s', findItem(sp.items, 'Max speed').content)
	self:assertEquals('137 \194\176/s', findItem(sp.items, 'Roll rate').content)
	self:assertEquals(nil, findItem(sp.items, 'Reverse speed'))
	-- Overview is the labelless top section (always shown, never collapsible).
	local ov = findSection(s, 'overview')
	self:assertEquals(nil, ov.label)
	self:assertEquals('Spacecraft', findItem(ov.items, 'Type').content)
	self:assertEquals('Combat', findItem(ov.items, 'Career').content)
end

function suite:testGroundVehicleSpeedUsesDrive()
	local s = Vehicle.getSections({
		crew = { min = 1, max = 2 },
		cargo_capacity = 1,
		speed = { scm = nil, max = nil },
		agility = { roll = nil, pitch = nil, yaw = nil },
		drive = { max_speed_ms = 36, reverse_speed_ms = 13.558441 },
	}, {}, {})
	local sp = findSection(s, 'speed')
	self:assertEquals(nil, findItem(sp.items, 'SCM speed'))
	self:assertEquals('36 m/s', findItem(sp.items, 'Max speed').content)
	self:assertEquals('14 m/s', findItem(sp.items, 'Reverse speed').content)
	self:assertEquals(nil, findItem(sp.items, 'Roll rate'))
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
	self:assertEquals('210 m/s', findItem(findSection(s, 'speed').items, 'SCM speed').content)
end

function suite:testEmptyApiOmitsSections()
	local s = Vehicle.getSections({}, {}, {})
	self:assertEquals(nil, findSection(s, 'speed'))
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
	self:assertEquals(2, d['Size class'])
	self:assertEquals(137, d['Roll rate'])
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

function suite:testCostUniverseBuyableRentable()
	local s = Vehicle.getSections({
		uex_prices = { purchase = { { price_buy = 500000 } }, rental = { { price_rent = 0 } } },
	}, {}, {})
	local universe = findItem(findSection(s, 'cost').sections, 'Universe')
	self:assertEquals('[[#Acquisition|Yes]]', findItem(universe.items, 'Buyable').content)
	self:assertEquals('No', findItem(universe.items, 'Rentable').content)
end

function suite:testCostUniverseCanBuyOverride()
	-- editorial canbuy override beats inferred (no UEX data → would be Unknown)
	local s = Vehicle.getSections({ uex_prices = {} }, { canbuy = 'yes' }, {})
	local universe = findItem(findSection(s, 'cost').sections, 'Universe')
	self:assertEquals('[[#Acquisition|Yes]]', findItem(universe.items, 'Buyable').content)
end

function suite:testCostUniverseFlightReadyNoDataIsNo()
	-- flight-ready ship, no UEX data: Universe stays, Buyable/Rentable = No (in-game → definitive)
	local s = Vehicle.getSections({ production_status = 'flight-ready', uex_prices = {} }, {}, {})
	local universe = findItem(findSection(s, 'cost').sections, 'Universe')
	self:assertEquals('No', findItem(universe.items, 'Buyable').content)
	self:assertEquals('No', findItem(universe.items, 'Rentable').content)
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

return suite
