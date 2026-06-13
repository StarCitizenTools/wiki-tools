require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Medical = require('Module:Entity/Facet/Medical')

local suite = ScribuntoUnit:new()

local function findItem(items, label)
	for _, it in ipairs(items or {}) do
		if it.label == label then
			return it
		end
	end
	return nil
end

-- AdrenaPen: a combat stimulant — raises blood drug level and grants the full
-- set of combat buffs + impact resistances.
local function adrenaPenData()
	return {
		sub_type = 'Medical',
		medical = {
			nutrition = { blood_drug_level = 15 },
			combat_buffs = {
				stun_recovery = true,
				move_speed = true,
				weapon_sway = true,
				a_d_s_enter = true,
			},
			impact_resistances = {
				knockdown = true,
				stagger = true,
				twitch = true,
				flinch = true,
			},
			debuffs = {},
		},
	}
end

-- BoostPen: same buffs, but carries a debuff as a magnitude map ({atrophic=900})
-- rather than a boolean flag map.
local function boostPenData()
	return {
		sub_type = 'Medical',
		medical = {
			nutrition = { blood_drug_level = 15 },
			combat_buffs = { move_speed = true },
			impact_resistances = {},
			debuffs = { atrophic = 900 },
		},
	}
end

function suite:testMatches()
	self:assertEquals(true, Medical.matches(adrenaPenData()))
	self:assertEquals(false, Medical.matches({}))
	self:assertEquals(false, Medical.matches(nil))
	-- A food-block consumable (OxyPen) is the Consumable facet's job, not ours.
	self:assertEquals(false, Medical.matches({ food = {} }))
end

function suite:testBuffsAndResistances()
	local sections = Medical.getSections(adrenaPenData(), {})
	self:assertEquals(1, #sections)
	self:assertEquals('medical', sections[1].key)
	self:assertEquals('Medical', sections[1].label)
	self:assertEquals('15', findItem(sections[1].items, 'Blood drug level').content)
	-- Sorted, labelled, comma-joined; snake_case keys map to friendly labels.
	self:assertEquals(
		'Aim-down-sights, Movement speed, Stun recovery, Weapon sway',
		findItem(sections[1].items, 'Combat buffs').content
	)
	-- Unmapped keys fall back to title-case.
	self:assertEquals('Flinch, Knockdown, Stagger, Twitch', findItem(sections[1].items, 'Impact resistances').content)
	-- Empty debuffs array contributes no row.
	self:assertEquals(nil, findItem(sections[1].items, 'Debuffs'))
end

-- The debuffs map uses magnitudes, not booleans; a key still counts as active.
function suite:testDebuffsMagnitudeMap()
	local sections = Medical.getSections(boostPenData(), {})
	self:assertEquals('Atrophy', findItem(sections[1].items, 'Debuffs').content)
	self:assertEquals('Movement speed', findItem(sections[1].items, 'Combat buffs').content)
	self:assertEquals(nil, findItem(sections[1].items, 'Impact resistances'))
end

-- A medical block with nothing displayable (empty nutrition + empty effect
-- arrays, as DetoxPen / Drema Injector carry) yields no section.
function suite:testEmptyBlockNoSection()
	local sections = Medical.getSections({
		medical = {
			nutrition = {},
			combat_buffs = {},
			impact_resistances = {},
			debuffs = {},
		},
	}, {})
	self:assertEquals(0, #sections)
end

function suite:testEmptyWhenNoBlock()
	self:assertEquals(0, #Medical.getSections({}, {}))
end

-- blood_drug_level is fractional on some doses (SLAM = 79.5) and absent on
-- pure nutrition pens; both must behave.
function suite:testFractionalAndMissingBloodDrugLevel()
	local fractional = Medical.getSections({
		medical = { nutrition = { blood_drug_level = 79.5 }, combat_buffs = {}, impact_resistances = {} },
	}, {})
	self:assertEquals('79.5', findItem(fractional[1].items, 'Blood drug level').content)
	-- No blood_drug_level, no other stat -> no section.
	self:assertEquals(0, #Medical.getSections({
		medical = { nutrition = {}, combat_buffs = {}, impact_resistances = {} },
	}, {}))
end

function suite:testStructuredData()
	self:assertEquals(15, Medical.getStructuredData(adrenaPenData()).blood_drug_level)
	self:assertEquals(nil, Medical.getStructuredData({ medical = { nutrition = {} } }).blood_drug_level)
end

-- effectList tolerates a non-table (the API hands [] when there is nothing).
function suite:testEffectListShapes()
	local effectList = Medical._internal.effectList
	self:assertEquals(nil, effectList(nil))
	self:assertEquals(nil, effectList({}))
	self:assertEquals('Stun recovery', effectList({ stun_recovery = true }))
	-- An explicit false flag is not active.
	self:assertEquals(nil, effectList({ stun_recovery = false }))
end

return suite
