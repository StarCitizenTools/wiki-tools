require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Bomb = require('Module:Entity/Item/Bomb')
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

-- A bomb with explosion radii directly on the block (Stormburst-style).
local function sampleData()
	return {
		size = 5,
		bomb = {
			damage_total = 200000.5,
			explosion_radius_min = 10,
			explosion_radius_max = 30,
			arm_time = 3,
			maximum_drop_angle = 90,
		},
	}
end

function suite:testBombRows()
	local sections = Bomb.getSections(sampleData(), {})
	self:assertEquals(1, #sections)
	self:assertEquals('bomb', sections[1].key)
	self:assertEquals('Bomb', sections[1].label)
	-- Fractional total rounds to a whole number.
	self:assertEquals('200,001', findItem(sections[1].items, 'Damage').content)
	self:assertEquals('10–30 m', findItem(sections[1].items, 'Explosion radius').content)
	self:assertEquals('3 s', findItem(sections[1].items, 'Arm time').content)
	self:assertEquals('90°', findItem(sections[1].items, 'Drop angle').content)
end

-- Radii nested under `explosion`, and arm time under `delays`, still resolve.
function suite:testNestedExplosionAndDelays()
	local sections = Bomb.getSections({
		bomb = {
			damage_total = 568297,
			explosion = { radius_min = 18, radius_max = 22 },
			delays = { arm_time = 5 },
		},
	}, {})
	self:assertEquals('18–22 m', findItem(sections[1].items, 'Explosion radius').content)
	self:assertEquals('5 s', findItem(sections[1].items, 'Arm time').content)
end

-- The Colossus reports null radii: the row collapses, damage still shows.
function suite:testNullRadiusCollapses()
	local sections = Bomb.getSections({
		bomb = { damage_total = 568297, explosion_radius_min = nil, explosion_radius_max = nil },
	}, {})
	self:assertEquals(nil, findItem(sections[1].items, 'Explosion radius'))
	self:assertEquals('568,297', findItem(sections[1].items, 'Damage').content)
end

function suite:testEmptyWhenNoBlock()
	self:assertEquals(0, #Bomb.getSections({}, {}))
end

function suite:testShortDescription()
	local desc = Bomb.getShortDescription(sampleData(), { manufacturer = 'FireStorm Kinetics' }, { name = 'Bomb' })
	self:assertEquals('S5 bomb by FireStorm Kinetics', desc)
end

function suite:testStructuredData()
	local data = Bomb.getStructuredData(sampleData())
	self:assertEquals(200001, data.warhead_damage)
	self:assertEquals(30, data.explosion_radius)
	self:assertEquals(3, data.arm_time)
	self:assertEquals(90, data.drop_angle)
end

function suite:testResolveSubtype()
	self:assertEquals(Bomb, Item.resolveSubtype({ type = 'Bomb' }))
end

return suite
