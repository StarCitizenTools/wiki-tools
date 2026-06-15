require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local DamageFalloff = require('Module:Entity/Facet/DamageFalloff')

local suite = ScribuntoUnit:new()
local I = DamageFalloff._internal

-- P4-AR: ballistic, object form WITH total.
local function p4ar()
	return {
		personal_weapon = {
			damage = { alpha_total = 12, alpha = { physical = 12 } },
			ammunition = {
				range = 1100,
				damage_drop_min_distance = { total = 40, physical = 40 },
				damage_drop_per_meter = { total = 0.05, physical = 0.05 },
				damage_drop_min_damage = { total = 10, physical = 10 },
			},
		},
	}
end

-- LH86: ballistic, per-type object WITHOUT total.
local function lh86()
	return {
		personal_weapon = {
			damage = { alpha_total = 13, alpha = { physical = 13 } },
			ammunition = {
				range = 950,
				damage_drop_min_distance = { physical = 20 },
				damage_drop_per_meter = { physical = 0.1 },
				damage_drop_min_damage = { physical = 5 },
			},
		},
	}
end

-- Arrowhead: laser, all-zero drop.
local function arrowhead()
	return {
		personal_weapon = {
			damage = { alpha_total = 75, alpha = { energy = 75 } },
			ammunition = {
				range = 4000,
				damage_drop_min_distance = { total = 0 },
				damage_drop_per_meter = { total = 0 },
				damage_drop_min_damage = { total = 0 },
			},
		},
	}
end

-- Atzkav: multi-type; falloff begins beyond range (minDist 1050 > range 1000).
local function atzkav()
	return {
		personal_weapon = {
			damage = { alpha_total = 165, alpha = { energy = 120, distortion = 35, stun = 10 } },
			ammunition = {
				range = 1000,
				damage_drop_min_distance = { total = 1050 },
				damage_drop_per_meter = { total = 0.03 },
				damage_drop_min_damage = { total = 56 },
			},
		},
	}
end

-- Clean synthetic model (exact binary fractions) for the geometry helpers.
local function cleanModel()
	return { alpha = 20, minDist = 10, perMeter = 0.25, minDamage = 10, range = 1000 }
end

function suite:testResolveTotal()
	local m = I.resolveFalloff(p4ar().personal_weapon)
	self:assertEquals(12, m.alpha)
	self:assertEquals(40, m.minDist)
	self:assertEquals(0.05, m.perMeter)
	self:assertEquals(10, m.minDamage)
	self:assertEquals(1100, m.range)
end

function suite:testResolveDominantTypeFallback()
	local m = I.resolveFalloff(lh86().personal_weapon)
	self:assertEquals(20, m.minDist)
	self:assertEquals(0.1, m.perMeter)
	self:assertEquals(5, m.minDamage)
end

function suite:testResolveMissing()
	self:assertEquals(nil, I.resolveFalloff(nil))
	self:assertEquals(nil, I.resolveFalloff({}))
end

function suite:testPrimaryDamageType()
	self:assertEquals('energy', I.primaryDamageType(atzkav().personal_weapon.damage))
	self:assertEquals('physical', I.primaryDamageType(p4ar().personal_weapon.damage))
end

function suite:testHasMeaningfulFalloff()
	self:assertEquals(true, I.hasMeaningfulFalloff(I.resolveFalloff(p4ar().personal_weapon)))
	self:assertEquals(false, I.hasMeaningfulFalloff(I.resolveFalloff(arrowhead().personal_weapon)))
	self:assertEquals(false, I.hasMeaningfulFalloff(I.resolveFalloff(atzkav().personal_weapon)))
	self:assertEquals(false, I.hasMeaningfulFalloff(nil))
end

function suite:testDamageAt()
	local m = cleanModel()
	self:assertEquals(20, I.damageAt(m, 0))
	self:assertEquals(20, I.damageAt(m, 10))
	self:assertEquals(15, I.damageAt(m, 30)) -- 20 - (30-10)*0.25
	self:assertEquals(10, I.damageAt(m, 50)) -- floor reached
	self:assertEquals(10, I.damageAt(m, 800)) -- clamped at floor
end

function suite:testFloorDistance()
	-- 10 + (20-10)/0.25 = 50 (exact in binary).
	self:assertEquals(50, I.floorDistance(cleanModel()))
end

function suite:testAdaptiveDomainHeadroom()
	-- Floor (50) within range -> 50 * 1.25 = 62.5 (exact).
	self:assertEquals(62.5, I.adaptiveDomain(cleanModel()))
end

function suite:testAdaptiveDomainClampedToRange()
	-- Floor beyond range -> clamp to range.
	local dev = { alpha = 150, minDist = 14, perMeter = 0.1, minDamage = 5.5, range = 600 }
	self:assertEquals(600, I.adaptiveDomain(dev))
end

function suite:testChartDomainUsesClassScale()
	local m = I.resolveFalloff(p4ar().personal_weapon)
	-- Known classes use their fixed shared scale.
	self:assertEquals(150, I.chartDomain({ personal_weapon = { type = 'Assault Rifle' } }, m))
	self:assertEquals(600, I.chartDomain({ personal_weapon = { type = 'Sniper Rifle' } }, m))
	self:assertEquals(200, I.chartDomain({ personal_weapon = { type = 'Pistol' } }, m))
	-- Unknown class -> adaptive fallback (p4ar floorDistance 80 * 1.25 = 100).
	self:assertEquals(100, I.chartDomain({ personal_weapon = { type = 'Mystery' } }, m))
end

function suite:testMatches()
	self:assertEquals(true, DamageFalloff.matches(p4ar()))
	self:assertEquals(true, DamageFalloff.matches(lh86()))
	self:assertEquals(false, DamageFalloff.matches(arrowhead()))
	self:assertEquals(false, DamageFalloff.matches(atzkav()))
	self:assertEquals(false, DamageFalloff.matches({}))
	self:assertEquals(false, DamageFalloff.matches(nil))
end

function suite:testGetSectionsInlinesIntoWeapon()
	local sections = DamageFalloff.getSections(p4ar(), {})
	self:assertEquals(1, #sections)
	self:assertEquals('personal_weapon', sections[1].key)
	self:assertEquals('t-infobox-item--block', sections[1].items[1].class)
	self:assertEquals('string', type(sections[1].items[1].content))
end

function suite:testGetSectionsEmptyWhenFlat()
	self:assertEquals(0, #DamageFalloff.getSections(arrowhead(), {}))
end

function suite:testStructuredData()
	local data = DamageFalloff.getStructuredData(p4ar())
	self:assertEquals(40, data.full_damage_range)
	self:assertEquals(10, data.min_damage)
	self:assertEquals(nil, DamageFalloff.getStructuredData(arrowhead()).full_damage_range)
end

return suite
