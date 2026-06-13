require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Magazine = require('Module:Entity/Facet/Magazine')

local suite = ScribuntoUnit:new()

local function findSection(sections, key)
	for _, s in ipairs(sections or {}) do
		if s.key == key then
			return s
		end
	end
	return nil
end

local function findItem(items, label)
	for _, it in ipairs(items or {}) do
		if it.label == label then
			return it
		end
	end
	return nil
end

-- A03 Sniper Rifle Magazine: ballistic, 15 cap, physical impact damage.
local function ballistic()
	return {
		sub_type = 'Magazine',
		magazine = { max_ammo_count = 15, max_restock_count = 3 },
		ammunition = { size = 1, speed = 800, range = 1600, lifetime = 2, impact_damage_map = { physical = 42.5 } },
	}
end

-- Animus Missile Launcher Magazine: missile, 0 cap, detonation + explosion radius.
local function missile()
	return {
		sub_type = 'Magazine',
		magazine = { max_ammo_count = 0, max_restock_count = 3 },
		ammunition = {
			size = 0,
			speed = 700,
			range = 2100,
			detonation_damage_map = { physical = 150 },
			explosion_radius = { min = 0.5, max = 4 },
			bullet_type = -1,
		},
	}
end

function suite:testMatches()
	self:assertEquals(true, Magazine.matches(ballistic()))
	self:assertEquals(true, Magazine.matches(missile()))
	self:assertEquals(false, Magazine.matches({ ammunition = {} }))
	self:assertEquals(false, Magazine.matches(nil))
end

function suite:testBallistic()
	local sec = findSection(Magazine.getSections(ballistic(), {}), 'magazine')
	self:assertEquals('Magazine', sec.label)
	self:assertEquals('15', findItem(sec.items, 'Capacity').content)
	self:assertEquals('800 m/s', findItem(sec.items, 'Velocity').content)
	self:assertEquals('1,600 m', findItem(sec.items, 'Range').content)
	self:assertEquals('Physical 42.5', findItem(sec.items, 'Damage').content)
	self:assertEquals(nil, findItem(sec.items, 'Explosion radius'))
end

function suite:testMissile()
	local sec = findSection(Magazine.getSections(missile(), {}), 'magazine')
	-- max_ammo_count 0 -> Capacity suppressed.
	self:assertEquals(nil, findItem(sec.items, 'Capacity'))
	self:assertEquals('700 m/s', findItem(sec.items, 'Velocity').content)
	self:assertEquals('Physical 150', findItem(sec.items, 'Damage').content)
	self:assertEquals('0.5 — 4 m', findItem(sec.items, 'Explosion radius').content)
end

function suite:testStructuredData()
	local d = Magazine.getStructuredData(ballistic())
	self:assertEquals(15, d.capacity)
	self:assertEquals(800, d.velocity)
	self:assertEquals(1600, d.ammo_range)
	self:assertEquals(42.5, d.damage)
	-- Missile mag: capacity 0 gated out; detonation damage summed.
	local m = Magazine.getStructuredData(missile())
	self:assertEquals(nil, m.capacity)
	self:assertEquals(150, m.damage)
end

return suite
