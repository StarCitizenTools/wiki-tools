local ScribuntoUnit = require('Module:ScribuntoUnit')
local Profile = require('Module:Entity/Vehicle/Stats/Profile')
local suite = ScribuntoUnit:new()

local function stub(rows)
	local r = mw.smw
	mw.smw = {
		ask = function()
			return rows
		end,
	}
	return r
end

function suite:testFirepowerAndStealth()
	local real = stub({
		{ pilot_sustained_dps = '1000', ir_emission = '9000' },
		{ pilot_sustained_dps = '2000', ir_emission = '8000' },
		{ pilot_sustained_dps = '3000', ir_emission = '7000' },
		{ pilot_sustained_dps = '4000', ir_emission = '6000' },
		{ pilot_sustained_dps = '5000', ir_emission = '1000' },
	})
	local axes = Profile.axisScores(
		{ is_spaceship = true, weaponry = { pilot_sustained_dps = 5000 }, emission = { ir = 1000 } },
		'ship',
		993
	)
	mw.smw = real
	local byKey = {}
	for _, a in ipairs(axes) do
		byKey[a.key] = a.score
	end
	self:assertEquals(90, byKey.offense) -- highest sustained DPS, Hazen leader
	self:assertEquals(90, byKey.stealth) -- lowest IR emission -> inverted top
end

function suite:testNoCohortNoScores()
	local real = mw.smw
	mw.smw = nil
	local axes = Profile.axisScores({ is_spaceship = true, weaponry = { pilot_dps = 5000 } }, 'ship', 4)
	mw.smw = real
	self:assertEquals(0, #axes)
end

function suite:testAxisOmittedWhenNoData()
	local real = stub({ { health = '1' }, { health = '2' }, { health = '3' }, { health = '4' }, { health = '5' } })
	-- ship with only health: Survivability present, Stealth/Travel/etc omitted
	local axes = Profile.axisScores({ is_spaceship = true, health = 3 }, 'ship', 992)
	mw.smw = real
	local keys = {}
	for _, a in ipairs(axes) do
		keys[a.key] = true
	end
	self:assertEquals(true, keys.defense)
	self:assertEquals(nil, keys.stealth)
end

function suite:testTravelAxisQuantumRangeUnits()
	local real = mw.smw
	mw.smw = {
		ask = function()
			return {
				{ quantum_range = '100' },
				{ quantum_range = '200' },
				{ quantum_range = '300' },
				{ quantum_range = '400' },
				{ quantum_range = '500' },
			}
		end,
	}
	local axes = Profile.axisScores({ is_spaceship = true, quantum = { quantum_range = 300000000000 } }, 'ship', 995)
	mw.smw = real
	local byKey = {}
	for _, a in ipairs(axes) do
		byKey[a.key] = a.score
	end
	self:assertEquals(50, byKey.travel) -- Hazen: (2 below + 0.5 equal)/5
end

function suite:testAxisBreakdownExposed()
	local real = stub({
		{ pilot_sustained_dps = '1000' },
		{ pilot_sustained_dps = '2000' },
		{ pilot_sustained_dps = '3000' },
		{ pilot_sustained_dps = '4000' },
		{ pilot_sustained_dps = '5000' },
	})
	local axes = Profile.axisScores({ is_spaceship = true, weaponry = { pilot_sustained_dps = 5000 } }, 'ship', 996)
	mw.smw = real
	local fire
	for _, a in ipairs(axes) do
		if a.key == 'offense' then
			fire = a
		end
	end
	self:assertEquals(5, fire.cohortSize)
	self:assertEquals(1, #fire.components) -- only sustained_dps contributed (no missiles)
	self:assertEquals('Sustained DPS', fire.components[1].label)
	self:assertEquals('5,000', fire.components[1].valueText)
end

function suite:testMobilityIncludesRoll()
	local real = stub({
		{ scm_speed = '100', pitch_rate = '10', yaw_rate = '10', roll_rate = '50' },
		{ scm_speed = '200', pitch_rate = '20', yaw_rate = '20', roll_rate = '100' },
		{ scm_speed = '300', pitch_rate = '30', yaw_rate = '30', roll_rate = '150' },
		{ scm_speed = '400', pitch_rate = '40', yaw_rate = '40', roll_rate = '200' },
		{ scm_speed = '500', pitch_rate = '50', yaw_rate = '50', roll_rate = '250' },
	})
	local axes = Profile.axisScores(
		{ is_spaceship = true, speed = { scm = 300 }, agility = { pitch = 30, yaw = 30, roll = 250 } },
		'ship',
		997
	)
	mw.smw = real
	local mob
	for _, a in ipairs(axes) do
		if a.key == 'mobility' then
			mob = a
		end
	end
	self:assertEquals(4, #mob.components) -- scm + pitch + yaw + roll
	self:assertEquals(60, mob.score) -- Hazen: mean(scm 50, pitch 50, yaw 50, roll 90)
	local roll
	for _, c in ipairs(mob.components) do
		if c.label == 'Roll rate' then
			roll = c.valueText
		end
	end
	self:assertEquals('250 \194\176/s', roll)
end

function suite:testDefenseSplitShieldHullArmor()
	local real = stub({
		{ health = '1000', shield_hp = '1000', armor_deflection = '10' },
		{ health = '2000', shield_hp = '2000', armor_deflection = '20' },
		{ health = '3000', shield_hp = '3000', armor_deflection = '30' },
		{ health = '4000', shield_hp = '4000', armor_deflection = '40' },
		{ health = '5000', shield_hp = '5000', armor_deflection = '50' },
	})
	local axes = Profile.axisScores({
		is_spaceship = true,
		health = 3000,
		shield_hp = 3000,
		armor = { deflection = { physical = 30, energy = 30 } },
	}, 'ship', 998)
	mw.smw = real
	local def
	for _, a in ipairs(axes) do
		if a.key == 'defense' then
			def = a
		end
	end
	self:assertEquals(3, #def.components) -- Shield + Hull + Armor
	self:assertEquals(50, def.score) -- mean(shield 50, hull 50, deflection 50)
	self:assertEquals('Shield', def.components[1].label)
	self:assertEquals('3,000 HP', def.components[1].valueText)
	self:assertEquals(3, def.components[1].rank) -- 3rd of 5 on shield
	self:assertEquals('Hull', def.components[2].label)
	self:assertEquals('3,000 HP', def.components[2].valueText)
	self:assertEquals(3, def.components[2].rank)
	self:assertEquals('Armor deflection', def.components[3].label)
	self:assertEquals(3, def.components[3].rank)
end

function suite:testFirepowerAlphaAnnotation()
	local real = stub({
		{ pilot_sustained_dps = '1000' },
		{ pilot_sustained_dps = '2000' },
		{ pilot_sustained_dps = '3000' },
		{ pilot_sustained_dps = '4000' },
		{ pilot_sustained_dps = '5000' },
	})
	local axes = Profile.axisScores({
		is_spaceship = true,
		weaponry = { pilot_sustained_dps = 2000, missiles = { count = 3, damage = { total = 1200000 } } },
	}, 'ship', 999)
	mw.smw = real
	local fire
	for _, a in ipairs(axes) do
		if a.key == 'offense' then
			fire = a
		end
	end
	self:assertEquals(30, fire.score) -- ranks sustained DPS only: Hazen 2000 in 1000..5000
	self:assertEquals(2, #fire.components) -- sustained DPS + alpha annotation
	self:assertEquals(true, fire.components[2].annotation)
	self:assertEquals('Alpha payload', fire.components[2].label)
	self:assertEquals('1,200,000 (3 shots)', fire.components[2].valueText)
	self:assertEquals(30, fire.components[1].percentile) -- scored driver's percentile (feeds the score)
	self:assertEquals(4, fire.components[1].rank) -- sustained 2000 -> 4th of 5 (shown in the tooltip)
	self:assertEquals(nil, fire.components[2].percentile) -- alpha annotation: not scored
	self:assertEquals(nil, fire.components[2].rank)
end

function suite:testSustainedDpsDropsZeroMembers()
	local real = stub({
		{ pilot_sustained_dps = '0' }, -- unarmed member: dropped, must not deflate the floor
		{ pilot_sustained_dps = '1000' },
		{ pilot_sustained_dps = '2000' },
		{ pilot_sustained_dps = '3000' },
		{ pilot_sustained_dps = '4000' },
		{ pilot_sustained_dps = '5000' },
	})
	local axes = Profile.axisScores({ is_spaceship = true, weaponry = { pilot_sustained_dps = 1000 } }, 'ship', 990)
	mw.smw = real
	local fire
	for _, a in ipairs(axes) do
		if a.key == 'offense' then
			fire = a
		end
	end
	self:assertEquals(10, fire.score) -- cohort {1000..5000}; ship 1000 -> Hazen floor (0 + 0.5)/5
end

function suite:testFirepowerOmittedWhenNoSustainedGuns()
	local real = stub({
		{ pilot_sustained_dps = '1000' },
		{ pilot_sustained_dps = '2000' },
		{ pilot_sustained_dps = '3000' },
		{ pilot_sustained_dps = '4000' },
		{ pilot_sustained_dps = '5000' },
	})
	local axes = Profile.axisScores({
		is_spaceship = true,
		weaponry = { missiles = { count = 2, damage = { total = 500000 } } },
	}, 'ship', 989)
	mw.smw = real
	local hasFirepower = false
	for _, a in ipairs(axes) do
		if a.key == 'offense' then
			hasFirepower = true
		end
	end
	self:assertEquals(false, hasFirepower)
end

function suite:testFirepowerAlphaSingularShot()
	local real = stub({
		{ pilot_sustained_dps = '1000' },
		{ pilot_sustained_dps = '2000' },
		{ pilot_sustained_dps = '3000' },
		{ pilot_sustained_dps = '4000' },
		{ pilot_sustained_dps = '5000' },
	})
	local axes = Profile.axisScores({
		is_spaceship = true,
		weaponry = { pilot_sustained_dps = 3000, missiles = { count = 1, damage = { total = 300000 } } },
	}, 'ship', 988)
	mw.smw = real
	local fire
	for _, a in ipairs(axes) do
		if a.key == 'offense' then
			fire = a
		end
	end
	self:assertEquals('300,000 (1 shot)', fire.components[2].valueText)
end

return suite
