require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local IronSight = require('Module:Entity/Facet/IronSight')

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

-- Black Prism: a telescopic scope with a populated ranging block.
local function telescopic()
	return {
		sub_type = 'IronSight',
		iron_sight = {
			default_range = 0,
			max_range = 1000,
			range_increment = 100,
			auto_zeroing_time = 0,
			zoom_scale = 8,
		},
	}
end

-- Delta: a 1x reflex sight — ranging fields all null.
local function reflex()
	return {
		sub_type = 'IronSight',
		iron_sight = {
			default_range = nil,
			max_range = nil,
			range_increment = nil,
			auto_zeroing_time = nil,
			zoom_scale = 1,
		},
	}
end

function suite:testMatches()
	self:assertEquals(true, IronSight.matches(telescopic()))
	self:assertEquals(true, IronSight.matches(reflex()))
	self:assertEquals(false, IronSight.matches({}))
	self:assertEquals(false, IronSight.matches(nil))
end

function suite:testTelescopicRanging()
	local sec = findSection(IronSight.getSections(telescopic(), {}), 'iron_sight')
	self:assertEquals('Sight', sec.label)
	self:assertEquals('1,000 m', findItem(sec.items, 'Max range').content)
	self:assertEquals('100 m', findItem(sec.items, 'Range increment').content)
	self:assertEquals('0 s', findItem(sec.items, 'Auto-zeroing').content)
	-- Magnification is NOT rendered here (WeaponModifier owns it).
	self:assertEquals(nil, findItem(sec.items, 'Magnification'))
end

-- A reflex sight has no ranging data -> no section.
function suite:testReflexNoSection()
	self:assertEquals(0, #IronSight.getSections(reflex(), {}))
end

function suite:testStructuredData()
	local d = IronSight.getStructuredData(telescopic())
	self:assertEquals(1000, d.max_range)
	self:assertEquals(100, d.range_increment)
end

return suite
