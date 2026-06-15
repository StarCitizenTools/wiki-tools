require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Armor = require('Module:Entity/Facet/Armor')

local suite = ScribuntoUnit:new()

local function tileByTitle(tiles, title)
	for _, t in ipairs(tiles or {}) do
		if t.title == title then
			return t
		end
	end
	return nil
end

-- A heavy torso (ADP Core): physical/energy/distortion/thermal/biochemical 0.6
-- multiplier (40% resistance), stun 0.4 (60%), impact 0.65 (35%).
local function heavyTorso()
	return {
		sub_type = 'Heavy',
		suit_armor = {
			slot = 'Torso',
			damage_resistance_map = {
				impact = 0.65,
				impact_change = -0.35,
				physical = 0.6,
				physical_change = -0.4,
				energy = 0.6,
				energy_change = -0.4,
				distortion = 0.6,
				distortion_change = -0.4,
				thermal = 0.6,
				thermal_change = -0.4,
				biochemical = 0.6,
				biochemical_change = -0.4,
				stun = 0.4,
				stun_change = -0.6,
			},
		},
	}
end

-- A flight helmet: suit_armor present, but sub_type "Helmet" (not a weight class)
-- and in-game Item Type "Flight Helmet".
local function flightHelmet()
	return {
		sub_type = 'Helmet',
		description_data = { { name = 'Item Type', value = 'Flight Helmet' } },
		suit_armor = {
			slot = 'Helmet',
			damage_resistance_map = { physical = 0.9, physical_change = -0.1 },
		},
	}
end

function suite:testMatches()
	self:assertEquals(true, Armor.matches(heavyTorso()))
	self:assertEquals(false, Armor.matches({}))
	self:assertEquals(false, Armor.matches(nil))
end

function suite:testResistancePercent()
	local rp = Armor._internal.resistancePercent
	self:assertEquals(40, rp({ physical = 0.6 }, 'physical'))
	self:assertEquals(60, rp({ stun = 0.4 }, 'stun'))
	self:assertEquals(35, rp({ impact = 0.65 }, 'impact'))
	self:assertEquals(nil, rp({}, 'physical'))
end

function suite:testWeightClass()
	local wc = Armor._internal.weightClass
	self:assertEquals('Heavy', wc({ sub_type = 'Heavy' }))
	self:assertEquals('Medium', wc({ sub_type = 'Medium' }))
	self:assertEquals('Light', wc({ sub_type = 'Light' }))
	self:assertEquals('Super Heavy', wc({ sub_type = 'SuperHeavy' }))
	-- "Helmet" (flight helmet) is NOT a weight class — gating it prevents the
	-- "Helmet helmet" short description.
	self:assertEquals(nil, wc({ sub_type = 'Helmet' }))
	self:assertEquals(nil, wc({ sub_type = 'UNDEFINED' }))
	self:assertEquals(nil, wc({ sub_type = '' }))
	self:assertEquals(nil, wc({}))
end

function suite:testDescriptorPrefix()
	local dp = Armor._internal.descriptorPrefix
	-- Armor pieces: weight class.
	self:assertEquals('Heavy', dp(heavyTorso()))
	-- Flight gear: "Flight" from the in-game item type, NOT the "Helmet" sub_type.
	self:assertEquals('Flight', dp(flightHelmet()))
	-- No weight class and not flight gear -> no prefix.
	self:assertEquals(nil, dp({ sub_type = 'UNDEFINED' }))
end

function suite:testTiles()
	local tiles = Armor._internal.buildTiles(heavyTorso().suit_armor.damage_resistance_map)
	self:assertEquals(7, #tiles)
	local phy = tileByTitle(tiles, 'Physical')
	self:assertEquals(40, phy.value)
	self:assertEquals('PHY', phy.label)
	self:assertEquals('var(--color-warning)', phy.color)
	-- 60% stun reads strong (green), 35% impact mid (amber)
	self:assertEquals('var(--color-success)', tileByTitle(tiles, 'Stun').color)
	self:assertEquals(35, tileByTitle(tiles, 'Impact').value)
	self:assertEquals('var(--color-warning)', tileByTitle(tiles, 'Impact').color)
end

function suite:testSection()
	local sections = Armor.getSections(heavyTorso(), {})
	self:assertEquals(1, #sections)
	self:assertEquals('armor', sections[1].key)
	self:assertEquals('Damage resistance', sections[1].label)
	self:assertEquals('string', type(sections[1].content))
end

function suite:testShortDescriptionPrefix()
	self:assertEquals('Heavy', Armor.getShortDescriptionPrefix(heavyTorso(), {}))
	-- Flight helmet -> "Flight helmet" (not "Helmet helmet").
	self:assertEquals('Flight', Armor.getShortDescriptionPrefix(flightHelmet(), {}))
	-- Undersuit: suit_armor present but no weight class / not flight -> no prefix.
	self:assertEquals(nil, Armor.getShortDescriptionPrefix({ sub_type = 'UNDEFINED', suit_armor = {} }, {}))
	self:assertEquals(nil, Armor.getShortDescriptionPrefix({}, {}))
end

function suite:testStructuredData()
	local data = Armor.getStructuredData(heavyTorso())
	self:assertEquals('Heavy', data.weight_class)
	self:assertEquals(40, data.physical_resistance)
	self:assertEquals(40, data.energy_resistance)
	self:assertEquals(60, data.stun_resistance)
	self:assertEquals(35, data.impact_resistance)
end

function suite:testEmptyWhenNoBlock()
	self:assertEquals(0, #Armor.getSections({}, {}))
	self:assertEquals(nil, next(Armor.getStructuredData({})))
end

return suite
