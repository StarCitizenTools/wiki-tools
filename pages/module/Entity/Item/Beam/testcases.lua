require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Beam = require('Module:Entity/Item/Beam')
local Item = require('Module:Entity/Item')

local suite = ScribuntoUnit:new()

-- The Durus tractor beam. (Stat rendering moved to Module:Entity/Facet/Beam; this
-- subtype now owns only the short description + subtype routing.)
local function tractorData()
	return {
		type = 'TractorBeam',
		size = 1,
		tractor_beam = {
			force = { min = 1500, max = 500000 },
			range = { max = 75, max_angle = 60 },
			tether = { tether_break_time = 1.5 },
			cargo_mode_override = { max_force = 9500000, max_distance = 225 },
		},
	}
end

function suite:testShortDescription()
	local desc = Beam.getShortDescription(
		tractorData(),
		{ manufacturer = 'Greycat Industrial' },
		{ name = 'Tractor beam' }
	)
	-- formatShortDescription uses the manufacturer's short form (Greycat for GRIN).
	self:assertEquals('S1 tractor beam by Greycat', desc)
end

function suite:testResolveSubtype()
	self:assertEquals(Beam, Item.resolveSubtype({ type = 'TractorBeam' }))
	self:assertEquals(Beam, Item.resolveSubtype({ type = 'TowingBeam' }))
end

return suite
