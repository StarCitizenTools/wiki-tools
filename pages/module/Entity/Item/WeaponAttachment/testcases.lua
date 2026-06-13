require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local WeaponAttachment = require('Module:Entity/Item/WeaponAttachment')
local Item = require('Module:Entity/Item')

local suite = ScribuntoUnit:new()

local function info(sub)
	return WeaponAttachment.getTypeInfo({ sub_type = sub }, {})
end

function suite:testGetTypeInfo()
	self:assertEquals('Magazines', info('Magazine').category)
	self:assertEquals('Magazine', info('Magazine').name)
	self:assertEquals('Optics attachments', info('IronSight').category)
	self:assertEquals('Barrel attachments', info('Barrel').category)
	self:assertEquals('Underbarrel attachments', info('BottomAttachment').category)
	self:assertEquals('Multi-Tool attachments', info('Utility').category)
end

-- An unrecognized sub_type falls back to the generic types.json mapping.
function suite:testUnknownSubType()
	self:assertEquals(nil, info('Sparkle'))
	self:assertEquals(nil, WeaponAttachment.getTypeInfo({}, {}))
end

function suite:testResolveSubtype()
	self:assertEquals(WeaponAttachment, Item.resolveSubtype({ type = 'WeaponAttachment' }))
end

return suite
