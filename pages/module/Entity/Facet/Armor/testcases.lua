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
	self:assertEquals('Super heavy', wc({ sub_type = 'SuperHeavy' }))
	-- CIG ships the BUL-H4 exo-suits as ordinary Heavy armor in the undersuit
	-- slot; the class name is the only field that says otherwise.
	self:assertEquals('Super heavy', wc({ sub_type = 'Heavy', class_name = 'cds_combat_superheavy_suit_01_01_01' }))
	self:assertEquals(
		'Super heavy',
		wc({ sub_type = 'Personal', class_name = 'cds_combat_superheavy_backpack_01_01_01' })
	)
	-- An ordinary heavy piece keeps its own weight class.
	self:assertEquals('Heavy', wc({ sub_type = 'Heavy', class_name = 'cds_combat_heavy_core_01_02_02' }))
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
	-- Tiles carry no per-tile colour now; the renderer applies a single accent.
	self:assertEquals(nil, phy.color)
	self:assertEquals(60, tileByTitle(tiles, 'Stun').value)
	self:assertEquals(35, tileByTitle(tiles, 'Impact').value)
end

function suite:testSection()
	local sections = Armor.getSections(heavyTorso(), {})
	self:assertEquals(1, #sections)
	self:assertEquals('armor', sections[1].key)
	self:assertEquals('Damage resistance', sections[1].label)
	-- The tile row is a full-width, label-less item.
	self:assertEquals(1, #sections[1].items)
	self:assertEquals('t-infobox-item--block', sections[1].items[1].class)
	self:assertEquals('string', type(sections[1].items[1].content))
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
