require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Shield = require('Module:Entity/Item/Shield')
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

function suite:testShieldStatsRows()
	local sections = Shield.getSections({
		shield = {
			max_health = 3168,
			regen_rate = 697,
			regen_delay = { damage = 4.79, downed = 9.58 },
			absorption = {
				physical = { min = 0, max = 0.45 },
				energy = { min = 1, max = 1 },
				distortion = { min = 1, max = 1 },
			},
			resistance = {
				physical = { min = 0, max = 0.25 },
				energy = { min = 0, max = 0 },
				distortion = { min = 0.75, max = 0.95 },
			},
		},
	}, {})
	self:assertEquals(1, #sections)
	self:assertEquals('shield', sections[1].key)
	self:assertEquals('3,168', findItem(sections[1].items, 'Shield HP').content)
	self:assertEquals('697 HP/s', findItem(sections[1].items, 'Regeneration').content)
	self:assertEquals('4.79 s', findItem(sections[1].items, 'Regen delay').content)
	self:assertEquals('9.58 s', findItem(sections[1].items, 'Downed delay').content)
	-- Only the partially-bypassing type (max < 1) shows under Absorption.
	self:assertEquals('Physical 0–45%', findItem(sections[1].items, 'Absorption').content)
	-- Only non-zero-resistance types show; physical before distortion (stable order).
	self:assertEquals('Physical 0–25% · Distortion 75–95%', findItem(sections[1].items, 'Resistance').content)
end

function suite:testDamageMapEqualBoundsCollapse()
	-- Equal min/max renders as a single percentage, not a range.
	local out = Shield._internal.formatDamageMap({ distortion = { min = 0.9, max = 0.9 } }, function(_, hi)
		return hi > 0
	end)
	self:assertEquals('Distortion 90%', out)
end

function suite:testDamageMapNoneQualifyReturnsNil()
	-- All types fully absorbed (max >= 1) -> Absorption row collapses.
	self:assertEquals(
		nil,
		Shield._internal.formatDamageMap(
			{ physical = { min = 1, max = 1 }, energy = { min = 1, max = 1 } },
			function(_, hi)
				return hi < 1
			end
		)
	)
end

function suite:testDownedDelayOmittedWhenAbsent()
	local sections = Shield.getSections({ shield = { max_health = 1000, regen_rate = 200 } }, {})
	self:assertEquals(nil, findItem(sections[1].items, 'Regen delay'))
	self:assertEquals(nil, findItem(sections[1].items, 'Downed delay'))
end

function suite:testEmptyWhenNoBlock()
	self:assertEquals(0, #Shield.getSections({}, {}))
end

function suite:testStructuredData()
	local data = Shield.getStructuredData({
		shield = { max_health = 3168, regen_rate = 697, regen_delay = { damage = 4.79 } },
	})
	self:assertEquals(3168, data.shield_health)
	self:assertEquals(697, data.shield_regeneration)
	self:assertEquals(4.79, data.shield_regen_delay)
end

function suite:testResolveSubtypeReturnsShield()
	self:assertEquals(Shield, Item.resolveSubtype({ type = 'Shield' }))
end

return suite
