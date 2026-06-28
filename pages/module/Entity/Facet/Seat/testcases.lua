require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Seat = require('Module:Entity/Facet/Seat')

local suite = ScribuntoUnit:new()

local function findItem(items, label)
	for _, it in ipairs(items or {}) do
		if it.label == label then
			return it
		end
	end
	return nil
end

-- The IFR-A77 manned turret: yaw ±20°, pitch -20°/80°, no ejection.
local function turretData()
	return {
		seat = {
			seat_type = 'DUAL_STICK',
			yaw = { min = -20, max = 20 },
			pitch = { min = -20, max = 80 },
			has_ejection = false,
		},
	}
end

function suite:testMatches()
	self:assertEquals(true, Seat.matches(turretData()))
	self:assertEquals(false, Seat.matches({}))
	self:assertEquals(false, Seat.matches(nil))
end

function suite:testRows()
	local sections = Seat.getSections(turretData(), {})
	self:assertEquals(1, #sections)
	self:assertEquals('seat', sections[1].key)
	self:assertEquals('Seat', sections[1].label)
	-- Signed range: typographic minus (U+2212) on bounds, em dash (U+2014) separator.
	self:assertEquals('−20° — 20°', findItem(sections[1].items, 'Yaw').content)
	self:assertEquals('−20° — 80°', findItem(sections[1].items, 'Pitch').content)
	-- boolean rows render via Module:Boolean (icon markup); assert the canonical
	-- data-state marker, not the literal word.
	self:assertStringContains('data-state="no"', findItem(sections[1].items, 'Ejection seat').content, true)
end

-- An ejection seat reports Yes.
function suite:testEjectionYes()
	local sections = Seat.getSections({
		seat = { yaw = { min = 0, max = 0 }, pitch = { min = -90, max = 90 }, has_ejection = true },
	}, {})
	self:assertStringContains('data-state="yes"', findItem(sections[1].items, 'Ejection seat').content, true)
	self:assertEquals('−90° — 90°', findItem(sections[1].items, 'Pitch').content)
end

function suite:testEmptyWhenNoSeat()
	self:assertEquals(0, #Seat.getSections({}, {}))
end

function suite:testStructuredData()
	local data = Seat.getStructuredData(turretData())
	self:assertEquals('−20° — 20°', data.yaw)
	self:assertEquals('−20° — 80°', data.pitch)
	self:assertEquals(-20, data.yaw_min)
	self:assertEquals(20, data.yaw_max)
	self:assertEquals(-20, data.pitch_min)
	self:assertEquals(80, data.pitch_max)
end

return suite
