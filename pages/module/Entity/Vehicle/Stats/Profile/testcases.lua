local ScribuntoUnit = require('Module:ScribuntoUnit')
local Profile = require('Module:Entity/Vehicle/Stats/Profile')
local ClassStats = require('Module:Entity/Vehicle/ClassStats')
local store = require('Module:Entity/Store')
local bucketLib = require('mw.ext.bucket')
local suite = ScribuntoUnit:new()

-- Bucket selector for a cohort stat key, resolved through the real manifest
-- (Module:Entity/Store) rather than a hardcoded field-naming rule.
local function selectorFor(key)
	local entry = store.resolve(ClassStats._internal.cohortProps[key], 'Vehicle')
	if entry.bucket == 'entity' then
		return entry.field
	end
	return entry.bucket .. '.' .. entry.field
end

-- Rows as the real extension returns them for a joined query: keyed by the
-- qualified selector; Store maps them to the stat keys.
local function row(fields)
	local r = {}
	for k, v in pairs(fields) do
		r[selectorFor(k)] = v
	end
	return r
end

function suite:testFirepowerAndStealth()
	bucketLib._reset()
	ClassStats._internal.clearCache()
	bucketLib._setRows('entity', {
		row({ pilot_sustained_dps = 1000, ir_emission = 9000 }),
		row({ pilot_sustained_dps = 2000, ir_emission = 8000 }),
		row({ pilot_sustained_dps = 3000, ir_emission = 7000 }),
		row({ pilot_sustained_dps = 4000, ir_emission = 6000 }),
		row({ pilot_sustained_dps = 5000, ir_emission = 1000 }),
	})
	local axes = Profile.axisScores(
		{ is_spaceship = true, weaponry = { pilot_sustained_dps = 5000 }, emission = { ir = 1000 } },
		'ship',
		993
	)
	local byKey = {}
	for _, a in ipairs(axes) do
		byKey[a.key] = a.score
	end
	self:assertEquals(90, byKey.offense) -- highest sustained DPS, Hazen leader
	self:assertEquals(90, byKey.stealth) -- lowest IR emission -> inverted top
end

function suite:testStealthAppliesArmorModifier()
	bucketLib._reset()
	ClassStats._internal.clearCache()
	-- Ship has a loud raw IR (10000) but stealth-coating armor (×0.5) → effective 5000.
	-- The cohort folds each member's own multiplier, so ranking is effective-vs-effective:
	-- the modifier lifts the ship from near-worst (raw) to upper-mid (effective).
	bucketLib._setRows('entity', {
		row({ ir_emission = 10000, ir_modifier = 1 }), -- effective 10000
		row({ ir_emission = 8000, ir_modifier = 1 }), -- 8000
		row({ ir_emission = 6000, ir_modifier = 1 }), -- 6000
		row({ ir_emission = 4000, ir_modifier = 1 }), -- 4000
		row({ ir_emission = 10000, ir_modifier = 0.5 }), -- 5000
	})
	-- size 984: unique across the vehicle suites (rowCache is shared per family|size).
	local axes = Profile.axisScores(
		{ is_spaceship = true, emission = { ir = 10000 }, armor = { signal_infrared = 0.5 } },
		'ship',
		984
	)
	local byKey = {}
	for _, a in ipairs(axes) do
		byKey[a.key] = a.score
	end
	-- Effective cohort {10000,8000,6000,4000,5000}; ship effective 5000 (lower = better,
	-- inverted): 3 louder + the tie → Hazen (3 + 0.5)/5 = 70. Raw-only would score 20.
	self:assertEquals(70, byKey.stealth)
end

-- No rows installed: Bucket returns none for size 4, so cohortRows is nil.
function suite:testNoCohortNoScores()
	bucketLib._reset()
	ClassStats._internal.clearCache()
	local axes = Profile.axisScores({ is_spaceship = true, weaponry = { pilot_dps = 5000 } }, 'ship', 4)
	self:assertEquals(0, #axes)
end

function suite:testAxisOmittedWhenNoData()
	bucketLib._reset()
	ClassStats._internal.clearCache()
	bucketLib._setRows('entity', {
		row({ health = 1 }),
		row({ health = 2 }),
		row({ health = 3 }),
		row({ health = 4 }),
		row({ health = 5 }),
	})
	-- ship with only health: Survivability present, Stealth/Travel/etc omitted
	local axes = Profile.axisScores({ is_spaceship = true, health = 3 }, 'ship', 992)
	local keys = {}
	for _, a in ipairs(axes) do
		keys[a.key] = true
	end
	self:assertEquals(true, keys.defense)
	self:assertEquals(nil, keys.stealth)
end

function suite:testTravelAxisQuantumRangeUnits()
	bucketLib._reset()
	ClassStats._internal.clearCache()
	bucketLib._setRows('entity', {
		row({ quantum_range = 100 }),
		row({ quantum_range = 200 }),
		row({ quantum_range = 300 }),
		row({ quantum_range = 400 }),
		row({ quantum_range = 500 }),
	})
	local axes = Profile.axisScores({ is_spaceship = true, quantum = { quantum_range = 300000000000 } }, 'ship', 995)
	local byKey = {}
	for _, a in ipairs(axes) do
		byKey[a.key] = a.score
	end
	self:assertEquals(50, byKey.travel) -- Hazen: (2 below + 0.5 equal)/5
end

function suite:testAxisBreakdownExposed()
	bucketLib._reset()
	ClassStats._internal.clearCache()
	bucketLib._setRows('entity', {
		row({ pilot_sustained_dps = 1000 }),
		row({ pilot_sustained_dps = 2000 }),
		row({ pilot_sustained_dps = 3000 }),
		row({ pilot_sustained_dps = 4000 }),
		row({ pilot_sustained_dps = 5000 }),
	})
	local axes = Profile.axisScores({ is_spaceship = true, weaponry = { pilot_sustained_dps = 5000 } }, 'ship', 996)
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
	bucketLib._reset()
	ClassStats._internal.clearCache()
	bucketLib._setRows('entity', {
		row({ scm_speed = 100, pitch_rate = 10, yaw_rate = 10, roll_rate = 50 }),
		row({ scm_speed = 200, pitch_rate = 20, yaw_rate = 20, roll_rate = 100 }),
		row({ scm_speed = 300, pitch_rate = 30, yaw_rate = 30, roll_rate = 150 }),
		row({ scm_speed = 400, pitch_rate = 40, yaw_rate = 40, roll_rate = 200 }),
		row({ scm_speed = 500, pitch_rate = 50, yaw_rate = 50, roll_rate = 250 }),
	})
	local axes = Profile.axisScores(
		{ is_spaceship = true, speed = { scm = 300 }, agility = { pitch = 30, yaw = 30, roll = 250 } },
		'ship',
		997
	)
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
	bucketLib._reset()
	ClassStats._internal.clearCache()
	bucketLib._setRows('entity', {
		row({ health = 1000, shield_hp = 1000, armor_deflection = 10 }),
		row({ health = 2000, shield_hp = 2000, armor_deflection = 20 }),
		row({ health = 3000, shield_hp = 3000, armor_deflection = 30 }),
		row({ health = 4000, shield_hp = 4000, armor_deflection = 40 }),
		row({ health = 5000, shield_hp = 5000, armor_deflection = 50 }),
	})
	local axes = Profile.axisScores({
		is_spaceship = true,
		health = 3000,
		shield_hp = 3000,
		armor = { deflection = { physical = 30, energy = 30 } },
	}, 'ship', 998)
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
	bucketLib._reset()
	ClassStats._internal.clearCache()
	bucketLib._setRows('entity', {
		row({ pilot_sustained_dps = 1000 }),
		row({ pilot_sustained_dps = 2000 }),
		row({ pilot_sustained_dps = 3000 }),
		row({ pilot_sustained_dps = 4000 }),
		row({ pilot_sustained_dps = 5000 }),
	})
	local axes = Profile.axisScores({
		is_spaceship = true,
		weaponry = { pilot_sustained_dps = 2000, missiles = { count = 3, damage = { total = 1200000 } } },
	}, 'ship', 999)
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
	bucketLib._reset()
	ClassStats._internal.clearCache()
	bucketLib._setRows('entity', {
		row({ pilot_sustained_dps = 0 }), -- unarmed member: dropped, must not deflate the floor
		row({ pilot_sustained_dps = 1000 }),
		row({ pilot_sustained_dps = 2000 }),
		row({ pilot_sustained_dps = 3000 }),
		row({ pilot_sustained_dps = 4000 }),
		row({ pilot_sustained_dps = 5000 }),
	})
	local axes = Profile.axisScores({ is_spaceship = true, weaponry = { pilot_sustained_dps = 1000 } }, 'ship', 990)
	local fire
	for _, a in ipairs(axes) do
		if a.key == 'offense' then
			fire = a
		end
	end
	self:assertEquals(10, fire.score) -- cohort {1000..5000}; ship 1000 -> Hazen floor (0 + 0.5)/5
end

function suite:testFirepowerOmittedWhenNoSustainedGuns()
	bucketLib._reset()
	ClassStats._internal.clearCache()
	bucketLib._setRows('entity', {
		row({ pilot_sustained_dps = 1000 }),
		row({ pilot_sustained_dps = 2000 }),
		row({ pilot_sustained_dps = 3000 }),
		row({ pilot_sustained_dps = 4000 }),
		row({ pilot_sustained_dps = 5000 }),
	})
	local axes = Profile.axisScores({
		is_spaceship = true,
		weaponry = { missiles = { count = 2, damage = { total = 500000 } } },
	}, 'ship', 989)
	local hasFirepower = false
	for _, a in ipairs(axes) do
		if a.key == 'offense' then
			hasFirepower = true
		end
	end
	self:assertEquals(false, hasFirepower)
end

function suite:testFirepowerAlphaSingularShot()
	bucketLib._reset()
	ClassStats._internal.clearCache()
	bucketLib._setRows('entity', {
		row({ pilot_sustained_dps = 1000 }),
		row({ pilot_sustained_dps = 2000 }),
		row({ pilot_sustained_dps = 3000 }),
		row({ pilot_sustained_dps = 4000 }),
		row({ pilot_sustained_dps = 5000 }),
	})
	local axes = Profile.axisScores({
		is_spaceship = true,
		weaponry = { pilot_sustained_dps = 3000, missiles = { count = 1, damage = { total = 300000 } } },
	}, 'ship', 988)
	local fire
	for _, a in ipairs(axes) do
		if a.key == 'offense' then
			fire = a
		end
	end
	self:assertEquals('300,000 (1 shot)', fire.components[2].valueText)
end

return suite
