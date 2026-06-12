require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Shield = require('Module:Entity/Item/Shield')
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

function suite:testShieldStatsRows()
	local sections = Shield.getSections({
		shield = { max_health = 3168, regen_rate = 697, regen_delay = { damage = 4.79, downed = 9.58 } },
	}, {})
	self:assertEquals(1, #sections)
	self:assertEquals('shield', sections[1].key)
	self:assertEquals('3,168', findItem(sections[1].items, 'Shield HP').content)
	self:assertEquals('697 HP/s', findItem(sections[1].items, 'Regeneration').content)
	self:assertEquals('4.79 s', findItem(sections[1].items, 'Regen delay').content)
	self:assertEquals('9.58 s', findItem(sections[1].items, 'Downed delay').content)
end

function suite:testDownedDelayOmittedWhenAbsent()
	local sections = Shield.getSections({ shield = { max_health = 1000, regen_rate = 200 } }, {})
	self:assertEquals(nil, findItem(sections[1].items, 'Regen delay'))
	self:assertEquals(nil, findItem(sections[1].items, 'Downed delay'))
end

function suite:testEmptyWhenNoBlock()
	self:assertEquals(0, #Shield.getSections({}, {}))
end

function suite:testStructuredData()
	local data = Shield.getStructuredData({
		shield = { max_health = 3168, regen_rate = 697, regen_delay = { damage = 4.79 } },
	})
	self:assertEquals(3168, data.shield_health)
	self:assertEquals(697, data.shield_regeneration)
	self:assertEquals(4.79, data.shield_regen_delay)
end

function suite:testResolveSubtypeReturnsShield()
	self:assertEquals(Shield, Item.resolveSubtype({ type = 'Shield' }))
end

return suite
