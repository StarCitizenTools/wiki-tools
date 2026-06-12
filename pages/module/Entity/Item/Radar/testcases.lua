require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Radar = require('Module:Entity/Item/Radar')
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

function suite:testRadarStatsRows()
	local sections = Radar.getSections({
		radar = {
			cooldown = 2.5,
			sensitivity = { infrared = 0.9, cross_section = 0.9, electromagnetic = 0.9, resource = 0.85 },
			aim_assist = { distance_max_assignment = 1610 },
		},
	}, {})
	self:assertEquals(1, #sections)
	self:assertEquals('radar', sections[1].key)
	self:assertEquals('90%', findItem(sections[1].items, 'Sensitivity').content)
	self:assertEquals('85%', findItem(sections[1].items, 'Resource sensitivity').content)
	self:assertEquals('2.5 s', findItem(sections[1].items, 'Cooldown').content)
	self:assertEquals('1,610 m', findItem(sections[1].items, 'Aim assist range').content)
end

function suite:testEmptyWhenNoBlock()
	self:assertEquals(0, #Radar.getSections({}, {}))
end

function suite:testStructuredData()
	local data = Radar.getStructuredData({
		radar = {
			cooldown = 2.5,
			sensitivity = { infrared = 0.8, resource = 1 },
			aim_assist = { distance_max_assignment = 1062.5 },
		},
	})
	self:assertEquals(0.8, data.radar_sensitivity)
	self:assertEquals(1, data.radar_resource_sensitivity)
	self:assertEquals(2.5, data.radar_cooldown)
	self:assertEquals(1062.5, data.radar_aim_assist_range)
end

function suite:testResolveSubtypeReturnsRadar()
	self:assertEquals(Radar, Item.resolveSubtype({ type = 'Radar' }))
end

return suite
