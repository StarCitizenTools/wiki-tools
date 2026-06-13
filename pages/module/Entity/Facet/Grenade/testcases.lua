require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Grenade = require('Module:Entity/Facet/Grenade')

local suite = ScribuntoUnit:new()

local function findItem(items, label)
	for _, it in ipairs(items or {}) do
		if it.label == label then
			return it
		end
	end
	return nil
end

-- The MK-4 Frag Grenade: physical, 20 damage, 4–5.5 m blast.
local function fragData()
	return { grenade = { damage_type = 'Physical', damage = 20, aoe = { min = 4, max = 5.5 } } }
end

function suite:testMatches()
	self:assertEquals(true, Grenade.matches(fragData()))
	-- A present-but-empty block (a flare) still matches; the section collapses.
	self:assertEquals(true, Grenade.matches({ grenade = {} }))
	self:assertEquals(false, Grenade.matches({}))
	self:assertEquals(false, Grenade.matches(nil))
end

function suite:testRows()
	local sections = Grenade.getSections(fragData(), {})
	self:assertEquals(1, #sections)
	self:assertEquals('grenade', sections[1].key)
	self:assertEquals('Grenade', sections[1].label)
	self:assertEquals('Physical', findItem(sections[1].items, 'Damage type').content)
	self:assertEquals('20', findItem(sections[1].items, 'Damage').content)
	self:assertEquals('4–5.5 m', findItem(sections[1].items, 'Blast radius').content)
end

-- A flare carries an all-null grenade block; the section drops entirely.
function suite:testCollapsesNullFlare()
	local sections = Grenade.getSections({
		grenade = { damage_type = nil, damage = nil, aoe = { min = nil, max = nil } },
	}, {})
	self:assertEquals(0, #sections)
end

-- Equal blast bounds collapse to a single value.
function suite:testEqualRadius()
	local sections = Grenade.getSections({ grenade = { damage = 5, aoe = { min = 3, max = 3 } } }, {})
	self:assertEquals('3 m', findItem(sections[1].items, 'Blast radius').content)
end

function suite:testStructuredData()
	local data = Grenade.getStructuredData(fragData())
	self:assertEquals(20, data.damage)
	self:assertEquals('Physical', data.damage_type)
	self:assertEquals(5.5, data.blast_radius)
end

return suite
