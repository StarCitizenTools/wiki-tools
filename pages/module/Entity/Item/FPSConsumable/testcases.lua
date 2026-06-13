require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local FPSConsumable = require('Module:Entity/Item/FPSConsumable')
local Item = require('Module:Entity/Item')

local suite = ScribuntoUnit:new()

local function info(sub)
	return FPSConsumable.getTypeInfo({ sub_type = sub }, {})
end

function suite:testMedicalSubTypes()
	-- Three API sub_types collapse to the one player-facing "Medical consumable".
	self:assertEquals('Medical consumable', info('Medical').name)
	self:assertEquals('Medical consumables', info('Medical').category)
	self:assertEquals('Medical consumables', info('MedPack').category)
	self:assertEquals('Medical consumables', info('OxygenCap').category)
end

function suite:testHackingSubType()
	self:assertEquals('Cryptokey', info('Hacking').name)
	self:assertEquals('Cryptokeys', info('Hacking').category)
end

-- An unrecognized sub_type falls back to the generic types.json mapping.
function suite:testUnknownSubType()
	self:assertEquals(nil, info('Sparkle'))
	self:assertEquals(nil, FPSConsumable.getTypeInfo({}, {}))
end

function suite:testResolveSubtype()
	self:assertEquals(FPSConsumable, Item.resolveSubtype({ type = 'FPS_Consumable' }))
end

return suite
