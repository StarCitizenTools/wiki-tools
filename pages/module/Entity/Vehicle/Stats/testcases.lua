local ScribuntoUnit = require('Module:ScribuntoUnit')
local Stats = require('Module:Entity/Vehicle/Stats')

local suite = ScribuntoUnit:new()

-- Minimal Editorial.view stand-in: value(field, apiFallback) → apiFallback.
local function ed()
	return {
		value = function(_, _, apiFallback)
			return apiFallback
		end,
	}
end

-- Headless (no mw.smw): Overview is cohort-gated to nil, so the first real axis leads.
function suite:testStatsLeadsWithDefenseHeadless()
	local section = Stats.build({
		is_spaceship = true,
		size_class = 4,
		speed = { scm = 190, max = 1000 },
		agility = { roll = 30, pitch = 38, yaw = 36 },
		health = 180844,
		shield_hp = 100000,
	}, {}, {
		value = function(_, _, apiFallback)
			return apiFallback
		end,
	})
	self:assertEquals('stats', section.key)
	self:assertEquals('Defense', section.sections[1].label) -- no weaponry, so Firepower is skipped
	self:assertEquals(nil, section.sections[1].key)
end

-- An Offense tab appears when weaponry is present.
function suite:testOffenseTabPresent()
	local section = Stats.build({
		is_spaceship = true,
		size_class = 4,
		speed = { scm = 190, max = 1000 },
		weaponry = { pilot_dps = 4910, turret_dps = 2182 },
	}, {}, {
		value = function(_, _, apiFallback)
			return apiFallback
		end,
	})
	local labels = {}
	for _, t in ipairs(section.sections) do
		labels[t.label] = true
	end
	self:assertEquals(true, labels['Offense'])
end

-- The Offense tab renders a Missiles row from weaponry.missiles.damage.total: the
-- salvo TOTAL only (no count — consistent with the gun DPS rows).
function suite:testOffenseTabMissileRow()
	local section = Stats.build({
		is_spaceship = true,
		size_class = 4,
		speed = { scm = 190, max = 1000 },
		weaponry = {
			pilot_dps = 1598,
			missiles = { count = 6, damage = { total = 12160 } },
		},
	}, {}, {
		value = function(_, _, apiFallback)
			return apiFallback
		end,
	})
	local offense
	for _, t in ipairs(section.sections) do
		if t.label == 'Offense' then
			offense = t
		end
	end
	self:assertEquals('Offense', offense.label)
	local missiles
	for _, item in ipairs(offense.items) do
		if item.label == 'Missiles' then
			missiles = item.content
		end
	end
	self:assertEquals('12,160', missiles)
end

-- The Defense tab splits armor deflection into separate Physical and Energy
-- threshold rows (the averaged value matched neither). Physical rounds for display;
-- a 0 threshold drops via positiveUnit.
function suite:testDeflectionSplitRows()
	local section = Stats.build({
		is_spaceship = true,
		size_class = 4,
		health = 3000,
		armor = { deflection = { physical = 235.7, energy = 0 } },
	}, {}, {
		value = function(_, _, apiFallback)
			return apiFallback
		end,
	})
	local defense
	for _, t in ipairs(section.sections) do
		if t.label == 'Defense' then
			defense = t
		end
	end
	local physical, energyPresent = nil, false
	for _, item in ipairs(defense.items) do
		if item.label == 'Physical deflection' then
			physical = item.content
		end
		if item.label == 'Energy deflection' then
			energyPresent = true
		end
	end
	self:assertEquals('236', physical) -- 235.7 -> roundInt 236, plain row (headless, no cohort)
	self:assertEquals(false, energyPresent) -- energy 0 dropped
end

-- percentileRow ranks a stat only against a real distribution. A lone cohort member
-- (here the only missile carrier in its class) shows a plain value, not a bar that
-- would read 1st while filling to the Hazen-of-one 50%. A stat with differing peers
-- DOES rank into a bar — including an inverted stat (IR emission, lower is better).
-- Barred rows are labelless (the label rides inside the stubbed RangeBar), so they
-- are counted by their block class.
function suite:testPercentileRowRanksPeersNotLoners()
	local real = mw.smw
	mw.smw = {
		ask = function()
			-- 5-ship cohort (>= MIN_COHORT); only the first row carries missiles.
			return {
				{ missile_damage = '18000', pilot_dps = '5000', ir_emission = '5000' },
				{ pilot_dps = '1000', ir_emission = '4000' },
				{ pilot_dps = '2000', ir_emission = '3000' },
				{ pilot_dps = '3000', ir_emission = '2000' },
				{ pilot_dps = '4000', ir_emission = '1000' },
			}
		end,
	}
	local section = Stats.build({
		is_spaceship = true,
		size_class = 987,
		weaponry = { pilot_dps = 5000, missiles = { count = 20, damage = { total = 18000 } } },
		emission = { ir = 5000 },
	}, {}, {
		value = function(_, _, apiFallback)
			return apiFallback
		end,
	})
	mw.smw = real

	local offense, stealth
	for _, t in ipairs(section.sections) do
		if t.label == 'Offense' then
			offense = t
		elseif t.label == 'Stealth' then
			stealth = t
		end
	end

	-- Lone stat: plain labelled value, no bar block.
	local missiles
	local offenseBars = 0
	for _, item in ipairs(offense.items) do
		if item.label == 'Missiles' then
			missiles = item
		end
		if item.class == 't-infobox-item--block' then
			offenseBars = offenseBars + 1
		end
	end
	self:assertEquals('18,000', missiles.content)
	self:assertEquals(nil, missiles.class)
	-- Peered stat (Pilot DPS 5000 vs {1000..5000}) ranks into a bar block.
	self:assertEquals(1, offenseBars)

	-- Inverted peered stat (IR emission, lower is better) also ranks into a bar block.
	local stealthBars = 0
	for _, item in ipairs(stealth.items) do
		if item.class == 't-infobox-item--block' then
			stealthBars = stealthBars + 1
		end
	end
	self:assertEquals(1, stealthBars)
end

-- Cross-section is shown per axis (length/width/height), each effective (raw × the armor
-- cross-section multiplier) with the modifier suffix. No cohort here, so they are plain
-- labelled rows, not bars.
function suite:testStealthCrossSectionPerAxis()
	local real = mw.smw
	mw.smw = nil -- no cohort -> plain rows
	local section = Stats.build({
		is_spaceship = true,
		cross_section = { length = 1000, width = 2000, height = 3000 },
		armor = { signal_cross_section = 0.5 },
	}, {}, ed())
	mw.smw = real

	local stealth
	for _, t in ipairs(section.sections) do
		if t.label == 'Stealth' then
			stealth = t
		end
	end
	local function content(label)
		for _, item in ipairs(stealth.items) do
			if item.label == label then
				return item.content
			end
		end
	end
	-- effective = raw × 0.5; modifier suffix -50%.
	local len = content('Cross-section (length)')
	self:assertTrue(len:find('500', 1, true) ~= nil)
	self:assertTrue(len:find('50%', 1, true) ~= nil)
	self:assertTrue(content('Cross-section (width)'):find('1,000', 1, true) ~= nil)
	self:assertTrue(content('Cross-section (height)'):find('1,500', 1, true) ~= nil)
end

return suite
