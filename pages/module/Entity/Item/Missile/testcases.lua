require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Missile = require('Module:Entity/Item/Missile')
local Item = require('Module:Entity/Item')

local suite = ScribuntoUnit:new()

local function findItem(items, label)
	for _, it in ipairs(items or {}) do
		if it.label == label then
			return it
		end
	end
	return nil
end

-- The Marksman I block: an infrared, single (non-cluster) warhead.
local function sampleData()
	return {
		size = 1,
		missile = {
			signal_type = 'Infrared',
			damage_total = 650,
			explosion_radius_min = 3,
			explosion_radius_max = 5,
			lock_time = 0.5,
			lock_range_min = 1700,
			lock_range_max = 10000,
			lock_angle = 60,
			speed = 1372,
			flight = { range = 20580 },
		},
	}
end

function suite:testMissileRows()
	local sections = Missile.getSections(sampleData(), {})
	self:assertEquals(1, #sections)
	self:assertEquals('missile', sections[1].key)
	self:assertEquals('Infrared', findItem(sections[1].items, 'Signal type').content)
	self:assertEquals('650', findItem(sections[1].items, 'Damage').content)
	self:assertEquals('3–5 m', findItem(sections[1].items, 'Explosion radius').content)
	self:assertEquals('0.5 s', findItem(sections[1].items, 'Lock time').content)
	self:assertEquals('1,700–10,000 m', findItem(sections[1].items, 'Lock range').content)
	self:assertEquals('60°', findItem(sections[1].items, 'Lock angle').content)
	self:assertEquals('1,372 m/s', findItem(sections[1].items, 'Speed').content)
	self:assertEquals('20,580 m', findItem(sections[1].items, 'Range').content)
end

-- Equal explosion bounds collapse to a single value, not a "5–5 m" range.
function suite:testEqualRangeCollapses()
	local sections = Missile.getSections({
		missile = { signal_type = 'Cross Section', explosion_radius_min = 5, explosion_radius_max = 5 },
	}, {})
	self:assertEquals('5 m', findItem(sections[1].items, 'Explosion radius').content)
end

-- The API's CamelCase "CrossSection" is normalized to "Cross Section" for
-- display, the facet, and the short description.
function suite:testCrossSectionNormalized()
	local api = { size = 3, missile = { signal_type = 'CrossSection', damage_total = 3200 } }
	local sections = Missile.getSections(api, {})
	self:assertEquals('Cross Section', findItem(sections[1].items, 'Signal type').content)
	self:assertEquals('Cross Section', Missile.getStructuredData(api).signal_type)
	self:assertEquals(
		'S3 cross section missile by Firestorm Kinetics',
		Missile.getShortDescription(api, { manufacturer = 'Firestorm Kinetics' }, { name = 'Missile' })
	)
end

function suite:testEmptyWhenNoBlock()
	self:assertEquals(0, #Missile.getSections({}, {}))
end

-- Short description surfaces the signal type gun-style: "S1 infrared missile by X".
function suite:testShortDescriptionUsesSignalType()
	local desc = Missile.getShortDescription(sampleData(), { manufacturer = 'Behring' }, { name = 'Missile' })
	self:assertEquals('S1 infrared missile by Behring', desc)
end

-- No signal type (dumbfire / unknown) falls back to the plain type name.
function suite:testShortDescriptionFallsBack()
	local desc = Missile.getShortDescription(
		{ size = 2, missile = {} },
		{ manufacturer = 'Behring' },
		{ name = 'Missile' }
	)
	self:assertEquals('S2 missile by Behring', desc)
end

function suite:testStructuredData()
	local data = Missile.getStructuredData(sampleData())
	self:assertEquals('Infrared', data.signal_type)
	self:assertEquals(650, data.warhead_damage)
	self:assertEquals(5, data.explosion_radius)
	self:assertEquals(10000, data.lock_range)
	self:assertEquals(1372, data.missile_speed)
	self:assertEquals(20580, data.missile_range)
end

function suite:testResolveSubtype()
	self:assertEquals(Missile, Item.resolveSubtype({ type = 'Missile' }))
	self:assertEquals(Missile, Item.resolveSubtype({ type = 'WeaponMissile' }))
end

return suite
