require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local MiningModule = require('Module:Entity/Item/MiningModule')
local Item = require('Module:Entity/Item')

local suite = ScribuntoUnit:new()

-- mining_modifier rendering + structured data is covered by
-- Module:Entity/Facet/Mining/testcases; this subtype now only owns the
-- size-prefixed short description and its type resolution.

function suite:testShortDescription()
	local desc = MiningModule.getShortDescription(
		{ size = 1 },
		{ manufacturer = 'Musashi Industrial and Starflight Concern' },
		{ name = 'Mining module' }
	)
	-- formatShortDescription uses the manufacturer's short form (MISC for Musashi).
	self:assertEquals('S1 mining module by MISC', desc)
end

function suite:testResolveSubtype()
	self:assertEquals(MiningModule, Item.resolveSubtype({ type = 'MiningModifier' }))
end

return suite
