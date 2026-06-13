require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local LaserPointer = require('Module:Entity/Facet/LaserPointer')

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
	self:assertEquals(true, LaserPointer.matches({ laser_pointer = { range = 20 } }))
	self:assertEquals(false, LaserPointer.matches({}))
	self:assertEquals(false, LaserPointer.matches(nil))
end

function suite:testRange()
	local sections = LaserPointer.getSections({ laser_pointer = { range = 20, color = nil, color_css = nil } }, {})
	self:assertEquals('Laser pointer', sections[1].label)
	self:assertEquals('20 m', findItem(sections[1].items, 'Range').content)
end

function suite:testNoRange()
	self:assertEquals(0, #LaserPointer.getSections({ laser_pointer = {} }, {}))
end

function suite:testStructuredData()
	self:assertEquals(20, LaserPointer.getStructuredData({ laser_pointer = { range = 20 } }).laser_range)
end

return suite
