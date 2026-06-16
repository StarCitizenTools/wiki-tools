require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Hacking = require('Module:Entity/Facet/Hacking')

local suite = ScribuntoUnit:new()

local function findItem(items, label)
	for _, it in ipairs(items or {}) do
		if it.label == label then
			return it
		end
	end
	return nil
end

-- icePick: 3 breach charges, halves the hack duration, 50% error chance.
local function icePickData()
	return {
		sub_type = 'Hacking',
		hacking_chip = {
			max_charges = 3,
			duration_multiplier = 0.5,
			error_chance = 0.5,
			access_tag = 'MissionQuestItem',
		},
	}
end

function suite:testMatches()
	self:assertEquals(true, Hacking.matches(icePickData()))
	self:assertEquals(false, Hacking.matches({}))
	self:assertEquals(false, Hacking.matches(nil))
end

function suite:testRows()
	local sections = Hacking.getSections(icePickData(), {})
	self:assertEquals(1, #sections)
	self:assertEquals('hacking', sections[1].key)
	self:assertEquals('Hacking', sections[1].label)
	self:assertEquals('3', findItem(sections[1].items, 'Charges').content)
	-- Hack time ×0.5 (faster) is lower-better → green buff.
	local hackTime = findItem(sections[1].items, 'Hack time').content
	self:assertStringContains('×0.5', hackTime, true)
	self:assertStringContains('color-success', hackTime, true)
	self:assertEquals('50%', findItem(sections[1].items, 'Error chance').content)
end

-- A neutral duration multiplier (1) is not worth a row; charges of 0 collapse.
function suite:testGatedRows()
	local sections = Hacking.getSections({
		hacking_chip = { max_charges = 0, duration_multiplier = 1, error_chance = 0 },
	}, {})
	self:assertEquals(nil, findItem(sections[1] and sections[1].items, 'Charges'))
	self:assertEquals(nil, findItem(sections[1] and sections[1].items, 'Hack time'))
	-- 0% error chance is still a meaningful, displayable value.
	self:assertEquals('0%', findItem(sections[1].items, 'Error chance').content)
end

function suite:testEmptyWhenNoBlock()
	self:assertEquals(0, #Hacking.getSections({}, {}))
end

function suite:testStructuredData()
	local data = Hacking.getStructuredData(icePickData())
	self:assertEquals(3, data.charges)
	self:assertEquals(50, data.error_chance)
end

return suite
