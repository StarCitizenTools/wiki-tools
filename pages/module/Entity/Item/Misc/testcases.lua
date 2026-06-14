require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Misc = require('Module:Entity/Item/Misc')

local suite = ScribuntoUnit:new()

function suite:testWallPictureRoutesToWallFlair()
	local info = Misc.getTypeInfo({ sub_type = 'Flair_Wall_Picture' }, {})
	self:assertEquals('Wall flair', info.name)
	self:assertEquals('Wall flair', info.category)
end

-- Unknown sub_type returns nil so the generic types.json Misc -> Misc items
-- mapping applies.
function suite:testUnknownSubTypeReturnsNil()
	self:assertEquals(nil, Misc.getTypeInfo({ sub_type = 'SomethingElse' }, {}))
end

function suite:testMissingSubTypeReturnsNil()
	self:assertEquals(nil, Misc.getTypeInfo({}, {}))
end

return suite
