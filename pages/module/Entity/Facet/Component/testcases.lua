require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Component = require('Module:Entity/Facet/Component')

local suite = ScribuntoUnit:new()

local function fixture()
	return {
		durability = {
			health = 860,
			resistance = { physical = 0.85, energy = 0.7, thermal = 0.1, distortion = 1, biochemical = 1, stun = 1 },
		},
		emission = { ir = 0, em_max = 9900 },
		distortion = { max = 7500 },
	}
end

local function findItem(items, label)
	for _, it in ipairs(items or {}) do
		if it.label == label then
			return it
		end
	end
	return nil
end

-- matches()

function suite:testMatchesOnDurability()
	self:assertEquals(true, Component.matches(fixture()))
end

function suite:testNoMatchWithoutDurability()
	self:assertEquals(false, Component.matches({ emission = { em_max = 1 } }))
end

function suite:testNoMatchNil()
	self:assertEquals(false, Component.matches(nil))
end

-- formatResistance()

function suite:testResistanceListsResistingTypesOnly()
	-- physical 0.85 -> 15%, energy 0.7 -> 30%, thermal 0.1 -> 90%; 1.0 entries omitted
	self:assertEquals(
		'Physical 15% · Energy 30% · Thermal 90%',
		Component._internal.formatResistance(fixture().durability.resistance)
	)
end

function suite:testResistanceNilWhenAllFull()
	self:assertEquals(nil, Component._internal.formatResistance({ physical = 1, energy = 1 }))
end

function suite:testResistanceNilWhenAbsent()
	self:assertEquals(nil, Component._internal.formatResistance(nil))
end

-- getSections()

function suite:testSectionRows()
	local sections = Component.getSections(fixture(), {})
	self:assertEquals(1, #sections)
	local s = sections[1]
	self:assertEquals('component', s.key)
	self:assertEquals('860', findItem(s.items, 'Health').content)
	self:assertEquals('9,900', findItem(s.items, 'EM signature').content)
	self:assertEquals('0', findItem(s.items, 'IR signature').content)
	self:assertEquals('7,500', findItem(s.items, 'Distortion').content)
	self:assertEquals('Physical 15% · Energy 30% · Thermal 90%', findItem(s.items, 'Resistance').content)
end

function suite:testSectionEmptyWhenNoStats()
	self:assertEquals(0, #Component.getSections({ durability = {} }, {}))
end

-- getStructuredData()

function suite:testStructuredData()
	local data = Component.getStructuredData(fixture(), {})
	self:assertEquals(860, data.health)
	self:assertEquals(9900, data.em_signature)
	self:assertEquals(0, data.ir_signature)
	self:assertEquals(7500, data.distortion)
end

return suite
