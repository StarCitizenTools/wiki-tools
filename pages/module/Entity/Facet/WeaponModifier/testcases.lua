require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local WM = require('Module:Entity/Facet/WeaponModifier')

local suite = ScribuntoUnit:new()

local function findItem(items, label)
	for _, it in ipairs(items or {}) do
		if it.label == label then
			return it
		end
	end
	return nil
end

function suite:testMatches()
	self:assertEquals(true, WM.matches({ weapon_modifier = {} }))
	self:assertEquals(false, WM.matches({}))
	self:assertEquals(false, WM.matches(nil))
end

-- XDL-style: two-stage zoom, all multipliers default (1) -> only Magnification.
function suite:testMagnificationOnly()
	local sections = WM.getSections({
		weapon_modifier = {
			aim = { zoom_scale = 8, second_zoom_scale = 16 },
			fire_rate_multiplier = 1,
			damage_multiplier = 1,
		},
	}, {})
	self:assertEquals(1, #sections)
	self:assertEquals('Modifier', sections[1].label)
	self:assertEquals('8× / 16×', findItem(sections[1].items, 'Magnification').content)
	self:assertEquals(nil, findItem(sections[1].items, 'Fire rate'))
	self:assertEquals(nil, findItem(sections[1].items, 'Damage'))
end

-- A non-default multiplier shows; equal zoom collapses to one stage.
function suite:testMultipliers()
	local sections = WM.getSections({
		weapon_modifier = {
			aim = { zoom_scale = 4, second_zoom_scale = 4 },
			damage_multiplier = 1.5,
			sound_radius_multiplier = 0.5,
		},
	}, {})
	self:assertEquals('4×', findItem(sections[1].items, 'Magnification').content)
	self:assertEquals('×1.5', findItem(sections[1].items, 'Damage').content)
	self:assertEquals('×0.5', findItem(sections[1].items, 'Sound radius').content)
end

-- 1× zoom + all-default multipliers -> nothing renders.
function suite:testNoOpCollapses()
	local sections = WM.getSections({
		weapon_modifier = { aim = { zoom_scale = 1, second_zoom_scale = 1 }, fire_rate_multiplier = 1 },
	}, {})
	self:assertEquals(0, #sections)
end

function suite:testStructuredData()
	self:assertEquals(8, WM.getStructuredData({ weapon_modifier = { aim = { zoom_scale = 8 } } }).magnification)
	self:assertEquals(nil, WM.getStructuredData({ weapon_modifier = { aim = { zoom_scale = 1 } } }).magnification)
end

return suite
