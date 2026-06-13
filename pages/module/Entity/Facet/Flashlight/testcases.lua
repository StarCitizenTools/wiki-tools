require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Flashlight = require('Module:Entity/Facet/Flashlight')

local suite = ScribuntoUnit:new()

local function findItem(items, label)
	for _, it in ipairs(items or {}) do
		if it.label == label then
			return it
		end
	end
	return nil
end

-- Brightspot Flashlight: two named modes, narrow (light_1) + wide (light_2).
local function brightspot()
	return {
		sub_type = 'BottomAttachment',
		flashlight = {
			wide = { port_name = 'light_2', name = 'Wide', light_type = 'Omni', light_radius = 50, intensity = 0.5 },
			narrow = {
				port_name = 'light_1',
				name = 'Narrow',
				light_type = 'Projector',
				light_radius = 35,
				intensity = 3,
			},
		},
	}
end

function suite:testMatches()
	self:assertEquals(true, Flashlight.matches(brightspot()))
	self:assertEquals(false, Flashlight.matches({}))
	self:assertEquals(false, Flashlight.matches(nil))
end

function suite:testModes()
	local sections = Flashlight.getSections(brightspot(), {})
	self:assertEquals('Flashlight', sections[1].label)
	-- Ordered by port_name: Narrow (light_1) before Wide (light_2).
	self:assertEquals('Narrow', sections[1].items[1].label)
	self:assertEquals('Projector, 35 m', sections[1].items[1].content)
	self:assertEquals('Wide', sections[1].items[2].label)
	self:assertEquals('Omni, 50 m', findItem(sections[1].items, 'Wide').content)
end

function suite:testEmpty()
	self:assertEquals(0, #Flashlight.getSections({ flashlight = {} }, {}))
end

return suite
