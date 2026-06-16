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

-- A multiplier row is now a colorByDirection span: assert it shows the value AND the
-- expected colour (color-success = green buff, color-destructive = red nerf).
local function assertColored(self, content, value, color)
	self:assertStringContains(value, content, true)
	self:assertStringContains(color, content, true)
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
	-- Magnification is a spec figure, left uncoloured.
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
	-- Damage ×1.5: higher is better -> green buff.
	assertColored(self, findItem(sections[1].items, 'Damage').content, '×1.5', 'color-success')
	-- Sound radius ×0.5: lower is better -> green buff.
	assertColored(self, findItem(sections[1].items, 'Sound radius').content, '×0.5', 'color-success')
end

-- Barrel/compensator: nested recoil + spread + ADS-time penalty.
function suite:testRecoilSpread()
	local sections = WM.getSections({
		weapon_modifier = {
			sound_radius_multiplier = 1.2,
			recoil = { multiplier = 0.7, decay_multiplier = 0.7 },
			spread = {
				min_multiplier = 0.8,
				max_multiplier = 0.8,
				first_attack_multiplier = 0.8,
				per_attack_multiplier = 0.8,
				decay_multiplier = 1,
			},
			aim = { zoom_scale = 1, second_zoom_scale = 1, zoom_time_scale = 1.15 },
		},
	}, {})
	local items = sections[1].items
	-- Sound radius ×1.2: lower is better -> red nerf (louder).
	assertColored(self, findItem(items, 'Sound radius').content, '×1.2', 'color-destructive')
	-- Recoil ×0.7: lower is better -> green buff.
	assertColored(self, findItem(items, 'Recoil').content, '×0.7', 'color-success')
	-- Recoil recovery ×0.7: higher is better -> red nerf (slower recovery).
	assertColored(self, findItem(items, 'Recoil recovery').content, '×0.7', 'color-destructive')
	-- Four equal spread multipliers collapse to one row; lower is better -> green.
	assertColored(self, findItem(items, 'Spread').content, '×0.8', 'color-success')
	-- spread.decay 1 is a no-op -> no Spread recovery row.
	self:assertEquals(nil, findItem(items, 'Spread recovery'))
	-- ADS time ×1.15: lower is better -> red nerf (slower aim-down-sights).
	assertColored(self, findItem(items, 'ADS time').content, '×1.15', 'color-destructive')
	-- zoom 1× is a no-op -> no Magnification.
	self:assertEquals(nil, findItem(items, 'Magnification'))
end

-- Differing spread multipliers are shown distinctly, not silently collapsed.
function suite:testSpreadDiffers()
	local sections = WM.getSections({
		weapon_modifier = {
			spread = {
				min_multiplier = 0.8,
				max_multiplier = 0.9,
				first_attack_multiplier = 0.8,
				per_attack_multiplier = 0.8,
			},
		},
	}, {})
	-- Both <1 (less spread) -> green; coloured by the first non-1 (max 0.9).
	assertColored(self, findItem(sections[1].items, 'Spread').content, '×0.8 / ×0.9', 'color-success')
end

-- 1× zoom + all-default multipliers/handling -> nothing renders.
function suite:testNoOpCollapses()
	local sections = WM.getSections({
		weapon_modifier = {
			aim = { zoom_scale = 1, second_zoom_scale = 1, zoom_time_scale = 1 },
			fire_rate_multiplier = 1,
			recoil = { multiplier = 1 },
			spread = { min_multiplier = 1, max_multiplier = 1 },
		},
	}, {})
	self:assertEquals(0, #sections)
end

function suite:testStructuredData()
	self:assertEquals(8, WM.getStructuredData({ weapon_modifier = { aim = { zoom_scale = 8 } } }).magnification)
	self:assertEquals(nil, WM.getStructuredData({ weapon_modifier = { aim = { zoom_scale = 1 } } }).magnification)
end

return suite
