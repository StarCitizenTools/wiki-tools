require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local FlightController = require('Module:Entity/Item/FlightController')
local Item = require('Module:Entity/Item')

local suite = ScribuntoUnit:new()

local function findItem(items, label)
	for _, it in ipairs(items or {}) do
		if it.label == label then
			return it
		end
	end
	return nil
end

-- A full flight_controller block: speeds plus base/boosted angular velocity.
local function sampleBlock()
	return {
		flight_controller = {
			scm_speed = 226,
			boost_speed_forward = 520,
			max_speed = 1193,
			pitch = 68,
			yaw = 52,
			roll = 200,
			pitch_boosted = 82,
			yaw_boosted = 62,
			roll_boosted = 240,
		},
	}
end

function suite:testFlightRows()
	local sections = FlightController.getSections(sampleBlock(), {})
	self:assertEquals(1, #sections)
	self:assertEquals('flight_controller', sections[1].key)
	self:assertEquals('Flight performance', sections[1].label)
	-- SCM speed carries forward boost in the parenthetical.
	self:assertEquals('226 (520) m/s', findItem(sections[1].items, 'SCM speed').content)
	self:assertEquals('1,193 m/s', findItem(sections[1].items, 'Max speed').content)
	self:assertEquals('68 (82) °/s', findItem(sections[1].items, 'Pitch').content)
	self:assertEquals('52 (62) °/s', findItem(sections[1].items, 'Yaw').content)
	self:assertEquals('200 (240) °/s', findItem(sections[1].items, 'Roll').content)
end

-- No boosted counterpart -> no parenthetical, just the base value.
function suite:testNoBoostOmitsParenthetical()
	local sections = FlightController.getSections({
		flight_controller = { scm_speed = 200, pitch = 50 },
	}, {})
	self:assertEquals('200 m/s', findItem(sections[1].items, 'SCM speed').content)
	self:assertEquals('50 °/s', findItem(sections[1].items, 'Pitch').content)
end

-- A missing base value collapses the row entirely.
function suite:testMissingBaseCollapsesRow()
	local sections = FlightController.getSections({
		flight_controller = { max_speed = 1000 },
	}, {})
	self:assertEquals(nil, findItem(sections[1].items, 'SCM speed'))
	self:assertEquals(nil, findItem(sections[1].items, 'Pitch'))
	self:assertEquals('1,000 m/s', findItem(sections[1].items, 'Max speed').content)
end

function suite:testEmptyWhenNoBlock()
	self:assertEquals(0, #FlightController.getSections({}, {}))
end

function suite:testStructuredData()
	local data = FlightController.getStructuredData(sampleBlock())
	self:assertEquals(226, data.scm_speed)
	self:assertEquals(520, data.boost_speed)
	self:assertEquals(1193, data.max_speed)
	self:assertEquals(68, data.pitch)
	self:assertEquals(82, data.pitch_boosted)
	self:assertEquals(240, data.roll_boosted)
end

function suite:testResolveSubtypeReturnsFlightController()
	self:assertEquals(FlightController, Item.resolveSubtype({ type = 'FlightController' }))
end

return suite
