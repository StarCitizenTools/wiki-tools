require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
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

function suite:testEditorialOverrideFlowsIntoSpeed()
	local s = Vehicle.getSections({ speed = { scm = 227 } }, {}, { scm_speed = { value = 210, source = 'override' } })
	self:assertEquals('210 m/s', findItem(findSection(s, 'speed').items, 'SCM speed').content)
end

function suite:testEmptyApiOmitsSections()
	local s = Vehicle.getSections({}, {}, {})
	self:assertEquals(nil, findSection(s, 'speed'))
	self:assertEquals(nil, findSection(s, 'capacity'))
end

function suite:testManufacturerRowInOverview()
	-- args.manufacturer 'Testco' doesn't resolve, so Base falls back to a
	-- self-referencing record (page == name) → a plain [[Testco]] link.
	local s = Vehicle.getSections({ career = 'Combat' }, { manufacturer = 'Testco' }, {})
	local ov = findSection(s, 'overview')
	self:assertEquals('[[Testco]]', findItem(ov.items, 'Manufacturer').content)
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

return suite
